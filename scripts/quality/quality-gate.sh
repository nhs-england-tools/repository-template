#!/usr/bin/env bash

set -euo pipefail

# Run the quality gates listed in 'scripts/config/quality-gates.yaml', each a
# Make target, when a Copilot agent finishes a turn and on demand. It is
# registered as a Copilot command hook in '.github/hooks/quality-gate.json', and
# 'make quality-gate' runs the same gates for a developer. A gate that fails
# makes the agent continue with a short report, at most 'max_blocks' times per
# turn.
#
# Usage:
#   $ ./scripts/quality/quality-gate.sh hook  # Copilot hook, the event JSON
#                                             # arrives on stdin
#   $ [options] ./scripts/quality/quality-gate.sh run
#   $ ./scripts/quality/quality-gate.sh list
#   $ [options] ./scripts/quality/quality-gate.sh pause
#   $ ./scripts/quality/quality-gate.sh resume
#
# Options:
#   scope={changed,all}          # 'changed' skips a gate whose 'paths' match no
#                                # changed file, default is 'changed'
#   hours=1..8                   # Length of a pause, default is '1'
#   QUALITY_GATE_BUDGET=seconds  # Time all gates may use in the hook, default
#                                # is '240'
#   VERBOSE=true                 # Show all the executed commands, default is
#                                # 'false'
#
# Exit codes:
#   0   - The command succeeded, 'hook' returns 0 once it has read the event
#   1   - A blocking gate failed or could not run, jq or yq cannot run, or an
#         option is invalid
#   2   - The gate configuration is missing or invalid
#   126 - The command or scope is not recognised
#
# Notes:
#   1) A turn starts with the first prompt after the agent last finished. The
#      hook records a baseline then and keeps it when more prompts arrive
#      before the agent finishes, such as a subagent's prompt or the next one
#      after a cancelled turn. At the stop it runs no gate when the turn changed
#      nothing, and only the gates whose 'paths' match a changed path. It
#      stores the changed paths with hashes of their contents and modes, never
#      the prompt.
#   2) The hook reads the gate list and its rules from the commit at the start
#      of the turn, so a change or a commit made during the turn applies from
#      the next one. 'run' and 'list' read the working tree.
#   3) State is kept in '$(git rev-parse --git-path quality-gate)', which is per
#      worktree and never tracked. 'pause' writes a file there that makes the
#      hook skip the gates for the given hours, from the next prompt on.
#   4) A gate prints 'PREREQUISITE: <fix>' when it cannot run for a reason that
#      is not the code, for example Docker is stopped. The existing 'ERROR ...
#      cannot run: ...' line of the Docker test suite is recognised too. The
#      hook then tells the user instead of making the agent continue.
#   5) The hook does nothing in GitHub Actions, which also runs Copilot cloud
#      agent, because its gates need tools and network access it lacks.
#   6) The script needs Bash 5.2, jq and yq. When the hook starts it with an
#      older Bash from the editor's PATH, it runs itself with a newer one.

# ==============================================================================

if [[ ${BASH_VERSINFO[0]} -lt 5 ]]; then
  newer=""
  while IFS= read -r candidate; do
    # shellcheck disable=SC2016
    if [[ -x $candidate && $("$candidate" -c 'echo "${BASH_VERSINFO[0]}"' < /dev/null) -ge 5 ]]; then
      newer="$candidate"
      break
    fi
  done < <(type -aP bash; printf '%s\n' /opt/homebrew/bin/bash /usr/local/bin/bash)
  # Outside the loop, so the newer Bash reads the hook event from this script's
  # stdin
  if [[ -n $newer ]]; then
    exec "$newer" "$0" "$@"
  fi
  echo "ERROR: quality-gate.sh needs Bash 5.2 or later, run 'make toolchain-install-gnu-macos'" >&2
  exit 1
fi

readonly CONFIG_FILE=scripts/config/quality-gates.yaml
readonly CONFIG_DIR=scripts/config/quality-gates.d
readonly CONFIG_RULES=scripts/quality/quality-gate.jq
readonly EXCERPT_LINES=40
readonly REASON_BYTES=8000
readonly NOTE_CHARACTERS=200
readonly SESSION_PATTERN='^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$'
readonly DROP_IN_PATTERN='^[A-Za-z0-9][A-Za-z0-9._-]*\.ya?ml$'
readonly PREREQUISITE_PATTERN='^(PREREQUISITE:|ERROR .* cannot run:)'
# A jq function that turns a 'paths' glob into an anchored extended regular
# expression: '**/' is any number of directories, '*' and '**' are any
# characters, '?' is one character and every other character stands for itself.
readonly GLOB_TO_ERE='def ere: "^" + ([scan("\\*\\*/|\\*\\*|\\*|\\?|[^*?]") | if . == "**/" then "(.*/)?" elif . == "**" or . == "*" then ".*" elif . == "?" then "." elif test("^[.\\[()^$+{|\\\\]$") then "\\" + . else . end] | join("")) + "$";'
# Changes to these paths are reported, because they decide which gates run
readonly -a GUARDED_PATHS=("$CONFIG_FILE" "$CONFIG_DIR/*" scripts/quality/quality-gate.sh "$CONFIG_RULES" .github/hooks/quality-gate.json)

# The state directory, set once from the repository's top level
STATE_DIR=""
# Process group of the gate that is running, stopped with the hook
RUNNING_GATE=""
# Results of the last run of the gates, one entry per gate that was considered
declare -a RESULT_NAME=() RESULT_TARGET=() RESULT_MODE=() RESULT_STATE=() RESULT_RC=() RESULT_SECONDS=() RESULT_LOG=()

# Run the requested command.
function main() {

  local command="${1:-}"
  cd "$(git rev-parse --show-toplevel)"
  STATE_DIR="$(git rev-parse --git-path quality-gate)"
  [[ $STATE_DIR == /* ]] || STATE_DIR="$PWD/$STATE_DIR"
  case $command in
    hook)
      if is-github-actions; then
        cat > /dev/null
        echo '{}'
        return 0
      fi
      if ! prepare-tools; then
        cat > /dev/null
        return 1
      fi
      handle-hook || return "$?"
      ;;
    run)
      prepare-tools || return "$?"
      run-command "${scope:-changed}" || return "$?"
      ;;
    list)
      prepare-tools || return "$?"
      list-command || return "$?"
      ;;
    pause)
      pause-command "${hours:-1}" || return "$?"
      ;;
    resume)
      resume-command || return "$?"
      ;;
    *)
      echo "Unrecognised command: '$command'. Use one of: hook, run, list, pause, resume" >&2
      return 126
      ;;
  esac

  return 0
}

# Succeed in GitHub Actions, which also runs Copilot cloud agent. Its sandbox
# sets COPILOT_AGENT_PROMPT, which is tested only for presence.
function is-github-actions() {

  if [[ ${GITHUB_ACTIONS:-} == true || -n ${COPILOT_AGENT_PROMPT+set} ]]; then
    return 0
  fi

  return 1
}

# Put the mise shims first on PATH, as 'scripts/init.mk' does for recipes, and
# check that jq and yq run. A shim exists even when mise.toml is not trusted or
# the tool is not installed, so finding the command is not enough. Another
# program called 'yq' cannot read YAML the way mikefarah yq 4 does.
function prepare-tools() {

  local shims version
  if command -v mise > /dev/null 2>&1 && shims="$(mise activate bash --shims 2> /dev/null | sed -n 's/^export PATH="\([^:]*\):.*/\1/p')" && [[ -n $shims ]]; then
    PATH="$shims:$PATH"
    export PATH
  fi
  if ! jq --version > /dev/null 2>&1; then
    echo "ERROR: the quality gate cannot run jq, run 'mise trust' and 'make config'" >&2
    return 1
  fi
  if ! version="$(yq --version 2>&1)"; then
    echo "ERROR: the quality gate cannot run yq, run 'mise trust' and 'make config'" >&2
    return 1
  fi
  if [[ $version != *mikefarah/yq*'version v4.'* ]]; then
    echo "ERROR: the quality gate needs mikefarah yq version 4, run 'mise trust' and 'make config'" >&2
    return 1
  fi

  return 0
}

# ==============================================================================
# Hook

# Read the hook event and dispatch it. Only the event name, the session
# identifier, the re-entry flag and the subagent identifier are taken from the
# payload, so the prompt text never reaches a shell variable.
function handle-hook() {

  local fields event session active agent
  if ! fields="$(jq -r '[.hook_event_name, .session_id, .stop_hook_active, .agent_id] | map(. // "" | tostring) | join("\u001f")')"; then
    emit-allow "Quality gate: the hook payload is not valid JSON, so no gate ran."
    return 0
  fi
  IFS=$'\x1f' read -r event session active agent <<< "$fields"
  if [[ ! $session =~ $SESSION_PATTERN ]]; then
    session=""
  fi
  # The Copilot harness marks events from inside a subagent, whose parent's stop
  # runs the gates
  if [[ -n $agent ]]; then
    emit-allow
    return 0
  fi
  case $event in
    UserPromptSubmit)
      record-baseline "$session" || return "$?"
      ;;
    Stop)
      handle-stop "$session" "$active" || return "$?"
      ;;
    *)
      emit-allow
      ;;
  esac

  return 0
}

# Start a turn by storing the working tree state, unless a turn is already open
# because the agent has not finished since an earlier prompt.
# Arguments:
#   $1=[session identifier, empty when unknown]
function record-baseline() {

  local session="$1" state action=baseline-recorded
  if ! state="$(state-dir)"; then
    emit-allow "Quality gate: cannot create its state directory, so no baseline was recorded."
    return 0
  fi
  remove-old-state "$state"
  if [[ -n $session ]]; then
    if [[ -f $state/$session.baseline ]]; then
      action=turn-already-open
    else
      rm -f "$state/$session.blocks"
      if ! write-baseline "$state/$session.baseline"; then
        action=snapshot-failed
      fi
    fi
  fi
  note-hook "$state" UserPromptSubmit "$session" "$action"
  emit-allow

  return 0
}

# Write the working tree state atomically. When it cannot be read, write only
# the commit and a marker, which keeps the turn open, keeps the gate list of the
# start of the turn and makes the stop run every gate.
# Arguments:
#   $1=[baseline file]
function write-baseline() {

  local tmp="" head
  if tmp="$(mktemp "$1.XXXXXX")" && snapshot-tree "$tmp" && mv "$tmp" "$1"; then
    return 0
  fi
  if [[ -n $tmp ]]; then
    rm -f "$tmp"
  fi
  head="$(git rev-parse --verify --quiet HEAD)" || head=none
  printf '=\t%s\0!\tunreadable\0' "$head" > "$1"

  return 1
}

# Remove state files and empty directories older than a week. A newer empty
# directory may belong to another session's gate that is about to write its log.
# Arguments:
#   $1=[state directory]
function remove-old-state() {

  if ! find "$1" -type f -mtime +7 -delete || ! find "$1" -mindepth 1 -type d -empty -mtime +7 -delete; then
    echo "Quality gate: cannot remove old state files from $1" >&2
  fi

  return 0
}

# Decide at the end of a turn whether to let the agent finish, using a scratch
# directory that is always removed.
# Arguments:
#   $1=[session identifier, empty when unknown]
#   $2=[stop_hook_active, 'true' when an earlier Stop hook already blocked this
#     turn]
function handle-stop() {

  local scratch rc=0
  if ! scratch="$(make-temp -d)"; then
    emit-allow "Quality gate: cannot create a temporary directory, so no gate ran."
    return 0
  fi
  decide-stop "$1" "$2" "$scratch" || rc=$?
  rm -rf "$scratch"

  return "$rc"
}

# Run the gates for the end of a turn and print the hook response. The turn ends
# unless a gate blocks, so the next prompt records a new baseline.
# Arguments:
#   $1=[session identifier] $2=[stop_hook_active] $3=[scratch directory]
function decide-stop() {

  local session="$1" active="$2" scratch="$3" state baseline="" pause config source start="" max_blocks blocks=0 budget="${QUALITY_GATE_BUDGET:-}"
  local current="$scratch/current" changes="$scratch/changes" known=true guard_note="" notes message
  if [[ $budget =~ ^[0-9]{1,6}$ ]] && (( 10#$budget > 0 )); then
    budget=$((10#$budget))
  else
    budget=240
  fi
  if ! state="$(state-dir)"; then
    emit-allow "Quality gate: cannot create its state directory, so no gate ran."
    return 0
  fi
  if [[ -n $session ]]; then
    baseline="$state/$session.baseline"
  fi
  pause="$(pause-state "$state" "$baseline")"
  case $pause in
    until:*)
      finish-turn "$state" "$session"
      note-hook "$state" Stop "$session" paused
      emit-allow "Quality gate is paused until $(format-time "${pause#until:}"). Resume it with: make quality-gate-resume"
      return 0
      ;;
    during-turn)
      guard_note="The gate was paused during this turn, so the pause applies from the next prompt."
      ;;
  esac
  if [[ -n $baseline && -f $baseline ]]; then
    start="$(snapshot-head "$baseline")"
  fi
  source="$(config-source "$start")"
  # Errors go to their own file, as a warning on stderr would corrupt the JSON
  if ! config="$(load-config "$source" 2> "$scratch/config-errors")"; then
    finish-turn "$state" "$session"
    note-hook "$state" Stop "$session" invalid-configuration
    emit-allow "Quality gate: no gate ran. $(< "$scratch/config-errors")"
    return 0
  fi
  # Rules from the start of the turn may print a whole number as 1.0
  max_blocks="$(jq -r '.max_blocks | floor' <<< "$config")" || max_blocks=1
  [[ $max_blocks =~ ^[0-9]+$ ]] || max_blocks=1
  # Blocks are counted only across continuations, so a stop after a cancelled
  # continuation starts at zero
  if [[ $active == true ]]; then
    if [[ -z $session ]]; then
      note-hook "$state" Stop "$session" already-continued
      emit-allow "Quality gate not run: an earlier block already continued this turn. Run 'make quality-gate' to check."
      return 0
    fi
    if [[ -f $state/$session.blocks ]]; then
      blocks="$(< "$state/$session.blocks")"
      [[ $blocks =~ ^[0-9]+$ ]] || blocks=0
    fi
  fi
  if (( blocks >= max_blocks )); then
    finish-turn "$state" "$session"
    note-hook "$state" Stop "$session" block-limit-reached
    emit-allow "Quality gate not run: it already blocked $blocks time(s) this turn. Run 'make quality-gate' to check."
    return 0
  fi

  if ! snapshot-tree "$current"; then
    known=false
    guard_note="${guard_note:+$guard_note }The working tree could not be read, so the hook ran every enabled gate."
  elif [[ -z $baseline || ! -f $baseline ]]; then
    known=false
    guard_note="${guard_note:+$guard_note }No baseline was recorded for this turn, so the hook ran every enabled gate."
  elif baseline-unreadable "$baseline"; then
    known=false
    guard_note="${guard_note:+$guard_note }The working tree could not be read at the start of the turn, so the hook ran every enabled gate."
  elif cmp -s "$baseline" "$current"; then
    finish-turn "$state" "$session"
    note-hook "$state" Stop "$session" unchanged
    emit-allow "${guard_note:+Quality gate: $guard_note}"
    return 0
  elif ! diff-snapshots "$baseline" "$current" "$changes"; then
    known=false
    guard_note="${guard_note:+$guard_note }The changes of this turn could not be compared with its start, so the hook ran every enabled gate."
  fi

  if [[ $known == true ]]; then
    notes="$(changed-guarded-paths "$changes")"
    if [[ -n $notes ]]; then
      guard_note="${guard_note:+$guard_note }This turn changed quality gate files ($notes). $(describe-source "$source" "$start") Review that change."
    fi
    execute-gates "$config" "$changes" changed "$budget" false "$state/logs/${session:-hook}"
  else
    # Without the turn's changes, a gate list that is not the start's may have
    # been changed in it
    if [[ $source != "$start" ]]; then
      guard_note="${guard_note:+$guard_note }$(describe-source "$source" "$start")"
    fi
    execute-gates "$config" "" all "$budget" false "$state/logs/${session:-hook}"
  fi
  write-last-run "$state" Stop "$session"
  notes="$(summary-notes)"
  if blocking-failure; then
    if [[ -n $session ]]; then
      printf '%s\n' "$((blocks + 1))" > "$state/$session.blocks"
    fi
    note-hook "$state" Stop "$session" blocked
    emit-block "$(build-reason)" "Quality gate blocked the stop: $(failed-names)${notes:+. $notes}${guard_note:+. $guard_note}"
    return 0
  fi
  finish-turn "$state" "$session"
  note-hook "$state" Stop "$session" allowed
  message="${notes:+$notes. }$guard_note"
  emit-allow "${message:+Quality gate: ${message% }}"

  return 0
}

# End the turn, so the next prompt records a new baseline.
# Arguments:
#   $1=[state directory] $2=[session identifier, empty when unknown]
function finish-turn() {

  if [[ -n $2 ]]; then
    rm -f "$1/$2.baseline" "$1/$2.blocks"
  fi

  return 0
}

# Print 'until:<epoch seconds>' when a pause applies to this stop, 'during-turn'
# when it was made after the turn started and so applies from the next prompt,
# or 'none'. Remove an expired pause.
# Arguments:
#   $1=[state directory] $2=[baseline of the turn, empty when unknown]
function pause-state() {

  local file="$1/paused" expiry
  if [[ ! -f $file ]]; then
    echo none
    return 0
  fi
  expiry="$(< "$file")"
  if [[ ! $expiry =~ ^[0-9]{1,12}$ ]] || (( 10#$expiry <= $(date +%s) )); then
    rm -f "$file"
    echo none
    return 0
  fi
  if [[ -n $2 && -f $2 && $file -nt $2 ]]; then
    echo during-turn
    return 0
  fi
  echo "until:$((10#$expiry))"

  return 0
}

# Say where the hook read the gate list from.
# Arguments:
#   $1=[a commit, or 'working-tree']
#   $2=[commit at the start of the turn, 'none' before the first commit, empty
#     when unknown]
function describe-source() {

  if [[ -n $2 && $1 == "$2" ]]; then
    echo "The hook used the gate list from commit ${1:0:7}, where the turn started."
  elif [[ $1 != working-tree ]]; then
    echo "The hook could not tell where the turn started, so it used the gate list from commit ${1:0:7}."
  elif [[ -n $2 ]]; then
    echo "No commit held the gate list when the turn started, so the hook used the working tree."
  else
    echo "No commit holds the gate list, so the hook used the working tree."
  fi

  return 0
}

# Write a record of the last hook event, for diagnosing the hook. It holds no
# prompt.
# Arguments:
#   $1=[state directory]
#   $2=[event name]
#   $3=[session identifier]
#   $4=[what the hook did]
function note-hook() {

  if ! jq -nc --arg event "$2" --arg session "$3" --arg action "$4" \
    '{time: (now | floor | todate), event: $event, session: $session, action: $action}' > "$1/last-hook.json"; then
    echo "Quality gate: cannot write $1/last-hook.json" >&2
  fi

  return 0
}

# ==============================================================================
# Commands for developers

# Run the gates and print the result.
# Arguments:
#   $1=[scope]
function run-command() {

  local scope="$1" scratch rc=0
  case $scope in
    changed | all) ;;
    *)
      echo "Unrecognised scope: '$scope'. Use one of: changed, all" >&2
      return 126
      ;;
  esac
  if [[ -n ${QUALITY_GATE_ACTIVE:-} ]]; then
    echo "ERROR: quality-gate is running inside a gate, remove the gate that calls it" >&2
    return 1
  fi
  scratch="$(make-temp -d)" || return "$?"
  run-gates "$scope" "$scratch" || rc=$?
  rm -rf "$scratch"

  return "$rc"
}

# Collect the changed paths, run the gates and print a table.
# Arguments:
#   $1=[scope] $2=[scratch directory]
function run-gates() {

  local scope="$1" changes="$2/changes" config state
  if ! config="$(load-config working-tree)"; then
    return 2
  fi
  state="$(state-dir)" || return "$?"
  collect-changed-paths "$changes" || return "$?"
  execute-gates "$config" "$changes" "$scope" 0 true "$state/logs/run"
  write-last-run "$state" run ""
  summarise-results
  if run-failed; then
    return 1
  fi

  return 0
}

# Print the configured gates.
function list-command() {

  local config rows
  if ! config="$(load-config working-tree)"; then
    return 2
  fi
  rows="$(jq -r '.gates[] | [.name, .target, .mode, "\(.timeout | floor)s", (if (.paths | length) == 0 then "all" else (.paths | join(" ")) end), .description] | @tsv' <<< "$config")" || return 2
  printf '%s\n' "$rows" \
    | awk -F'\t' 'BEGIN { printf "%-22s %-22s %-6s %-8s %-24s %s\n", "NAME", "TARGET", "MODE", "TIMEOUT", "PATHS", "DESCRIPTION" } NF > 0 { printf "%-22s %-22s %-6s %-8s %-24s %s\n", $1, $2, $3, $4, $5, $6 }'

  return 0
}

# Make the hook skip the gates for a number of hours, from the next prompt on.
# Arguments:
#   $1=[hours from 1 to 8]
function pause-command() {

  local hours="$1" state expiry
  if [[ ! $hours =~ ^[1-8]$ ]]; then
    echo "ERROR: hours must be a whole number from 1 to 8, for example: make quality-gate-pause hours=2" >&2
    return 1
  fi
  state="$(state-dir)" || return "$?"
  expiry=$(( $(date +%s) + hours * 3600 ))
  printf '%s\n' "$expiry" > "$state/paused"
  echo "Quality gate paused from the next prompt until $(format-time "$expiry"). Resume it with: make quality-gate-resume"

  return 0
}

# Remove a pause.
function resume-command() {

  local state
  state="$(state-dir)" || return "$?"
  rm -f "$state/paused"
  echo "Quality gate resumed"

  return 0
}

# ==============================================================================
# Configuration

# Print the commit to read the gate configuration from: the one at the start of
# the turn, or HEAD when the start is unknown. Print 'working-tree' when that
# commit does not hold the gate list.
# Arguments:
#   $1=[commit at the start of the turn, 'none' before the first commit, empty
#     when unknown]
function config-source() {

  local commit="$1"
  if [[ -z $commit ]]; then
    commit="$(git rev-parse --verify --quiet HEAD)" || commit=none
  fi
  if [[ $commit != none ]] && git cat-file -e "$commit:$CONFIG_FILE" 2> /dev/null; then
    printf '%s\n' "$commit"
  else
    echo working-tree
  fi

  return 0
}

# Print the validated gate configuration as JSON, or why it is invalid.
# Arguments:
#   $1=[a commit to read the files and rules from, or 'working-tree']
function load-config() {

  local scratch rc=0
  scratch="$(make-temp -d)" || return 2
  read-config "$1" "$scratch" || rc=$?
  rm -rf "$scratch"

  return "$rc"
}

# Read and validate the gate configuration. A commit without the rules file uses
# the working tree's rules.
# Arguments:
#   $1=[a commit, or 'working-tree']
#   $2=[scratch directory]
function read-config() {

  local from="$1" names="$2/names" rules="$CONFIG_RULES" file doc out rc=0
  local -a docs=() files=("$CONFIG_FILE")
  if [[ $from == working-tree && ! -f $CONFIG_FILE ]]; then
    echo "ERROR: $CONFIG_FILE is missing. Restore it from the repository template." >&2
    return 2
  fi
  if ! list-drop-ins "$from" > "$names"; then
    echo "ERROR: cannot list the files in $CONFIG_DIR." >&2
    return 2
  fi
  while IFS= read -r -d '' file; do
    if ! is-drop-in-name "${file##*/}"; then
      echo "ERROR: $file: drop-in file names may use only ASCII letters, digits, '.', '_' and '-', and end in .yaml or .yml." >&2
      return 2
    fi
    files+=("$file")
  done < "$names"
  if [[ $from != working-tree ]] && git cat-file -e "$from:$CONFIG_RULES" 2> /dev/null; then
    rules="$2/rules.jq"
    git show "$from:$CONFIG_RULES" > "$rules" || return 2
  fi
  for file in "${files[@]}"; do
    if [[ $from == working-tree ]]; then
      doc="$(yq -o=json 'explode(.)' "$file")" || { echo "ERROR: $file is not valid YAML." >&2; return 2; }
    else
      doc="$(git show "$from:$file" | yq -o=json 'explode(.)' -)" || { echo "ERROR: $file at commit ${from:0:7} is not valid YAML." >&2; return 2; }
    fi
    docs+=("$doc")
  done
  out="$(printf '%s\n' "${docs[@]}" | jq -c -s -f "$rules" 2> "$2/errors")" || rc=$?
  if [[ $rc -ne 0 ]]; then
    out="$(< "$2/errors")"
    echo "ERROR: gate configuration: ${out#jq: error (at *): }" >&2
    return 2
  fi
  printf '%s\n' "$out"

  return 0
}

# Succeed when a drop-in file name is plain ASCII, so a commit and the working
# tree, which may store other names in different Unicode forms, order it alike.
# The C locale in a subshell compares bytes and leaves the caller's locale
# alone.
# Arguments:
#   $1=[file name]
function is-drop-in-name() {

  (
    LC_ALL=C
    [[ $1 =~ $DROP_IN_PATTERN ]]
  ) || return 1

  return 0
}

# Print the drop-in files, NUL-separated and in byte order of their names, the
# same for a commit and the working tree. Only regular '*.yaml' and '*.yml'
# files count, not dot files.
# Arguments:
#   $1=[a commit, or 'working-tree']
function list-drop-ins() {

  local entry path
  if [[ $1 == working-tree ]]; then
    for path in "$CONFIG_DIR"/*.yaml "$CONFIG_DIR"/*.yml; do
      if [[ -f $path && ! -L $path ]]; then
        printf '%s\0' "$path"
      fi
    done | LC_ALL=C sort -z || return "$?"
  else
    git ls-tree -z "$1" -- "$CONFIG_DIR/" | while IFS= read -r -d '' entry; do
      path="${entry#*$'\t'}"
      if [[ ${entry%% *} =~ ^100(644|755)$ && ${path##*/} != .* && $path =~ \.ya?ml$ ]]; then
        printf '%s\0' "$path"
      fi
    done | LC_ALL=C sort -z || return "$?"
  fi

  return 0
}

# ==============================================================================
# Working tree state

# Print the directory that holds the hook's state, creating it when needed.
function state-dir() {

  [[ -d $STATE_DIR/logs ]] || mkdir -p "$STATE_DIR/logs" || return "$?"
  printf '%s\n' "$STATE_DIR"

  return 0
}

# Create a temporary file, or a directory with -d, in the state directory, so
# the hook works when the system's temporary directory is unusable.
# Arguments:
#   $1=[-d for a directory, optional]
function make-temp() {

  local state
  state="$(state-dir)" || return "$?"
  mktemp "$@" "$state/tmp.XXXXXX" || return "$?"

  return 0
}

# Write the paths that differ from HEAD, or are tracked in a repository with no
# commit, and the untracked ones that Git does not ignore, NUL-separated and
# sorted.
# Arguments:
#   $1=[output file]
function collect-changed-paths() {

  local out="$1" tmp err rc=0
  tmp="$(make-temp)" || return "$?"
  if ! err="$(make-temp)"; then
    rm -f "$tmp"
    return 1
  fi
  if git rev-parse --verify --quiet HEAD > /dev/null; then
    git diff -z --name-only --no-renames HEAD >> "$tmp" || rc=$?
  else
    git ls-files -z --cached >> "$tmp" || rc=$?
  fi
  # Git only warns about a directory it cannot read, which would hide its files
  git ls-files -z --others --exclude-standard >> "$tmp" 2> "$err" || rc=$?
  if [[ -s $err ]]; then
    cat "$err" >&2
    rc=1
  fi
  if [[ $rc -eq 0 ]]; then
    LC_ALL=C sort -z -u "$tmp" > "$out" || rc=$?
  fi
  rm -f "$tmp" "$err"

  return "$rc"
}

# Write the commit and, for every path from collect-changed-paths, its Git mode
# and content hash. A link is hashed by its target, as Git stores it, a nested
# repository such as a submodule by its own state, and any other path that is
# not a file is recorded with '-'.
# Arguments:
#   $1=[output file]
function snapshot-tree() {

  local out="$1" paths head file hash mode i j hashes readable=true
  local -a regular=() chunk=() lines=()
  paths="$(make-temp)" || return "$?"
  if ! collect-changed-paths "$paths"; then
    rm -f "$paths"
    return 1
  fi
  head="$(git rev-parse --verify --quiet HEAD)" || head=none
  printf '=\t%s\0' "$head" > "$out"
  while IFS= read -r -d '' file; do
    if [[ -L $file ]]; then
      if ! hash="$(readlink -- "$file" | git hash-object --stdin)"; then
        readable=false
        break
      fi
      printf '120000:%s\t%s\0' "$hash" "$file" >> "$out"
    elif [[ -f $file ]]; then
      regular+=("$file")
    elif [[ -d $file && -e $file/.git ]]; then
      if ! hash="$(nested-snapshot-hash "$file" < /dev/null)"; then
        readable=false
        break
      fi
      printf '160000:%s\t%s\0' "$hash" "$file" >> "$out"
    else
      printf -- '-\t%s\0' "$file" >> "$out"
    fi
  done < "$paths"
  rm -f "$paths"
  if [[ $readable == false ]]; then
    return 1
  fi
  for ((i = 0; i < ${#regular[@]}; i += 100)); do
    chunk=("${regular[@]:i:100}")
    hashes="$(git hash-object --no-filters -- "${chunk[@]}")" || return 1
    mapfile -t lines <<< "$hashes"
    for j in "${!chunk[@]}"; do
      mode=100644
      if [[ -x ${chunk[$j]} ]]; then
        mode=100755
      fi
      printf '%s:%s\t%s\0' "$mode" "${lines[$j]}" "${chunk[$j]}" >> "$out"
    done
  done

  return 0
}

# Print the commit recorded in a snapshot, 'none' before the first commit, or
# nothing when the snapshot has no commit.
# Arguments:
#   $1=[snapshot file]
function snapshot-head() {

  local record=""
  IFS= read -r -d '' record < "$1" || true
  if [[ ${record%%$'\t'*} == = ]]; then
    printf '%s\n' "${record#*$'\t'}"
  fi

  return 0
}

# Succeed when a baseline holds no working tree state: write-baseline could not
# read the tree, or the file is empty.
# Arguments:
#   $1=[baseline file]
function baseline-unreadable() {

  local first="" second=""
  { IFS= read -r -d '' first && IFS= read -r -d '' second; } < "$1" || true
  if [[ -z $first || $second == $'!\tunreadable' ]]; then
    return 0
  fi

  return 1
}

# Print a hash of the state of a repository nested in the working tree, such as
# a submodule, so that a change inside it counts as a change.
# Arguments:
#   $1=[path of the nested repository]
function nested-snapshot-hash() {

  local listing rc=0
  listing="$(make-temp)" || return "$?"
  if ( cd "$1" && snapshot-tree "$listing" ); then
    git hash-object --no-filters -- "$listing" || rc=$?
  else
    rc=1
  fi
  rm -f "$listing"

  return "$rc"
}

# Write the paths whose state differs between two snapshots, and the paths of
# commits made between them, NUL-separated. Fail when the commits cannot be
# compared.
# Arguments:
#   $1=[snapshot taken first]
#   $2=[snapshot taken second]
#   $3=[output file]
function diff-snapshots() {

  local -A before=() after=() seen=()
  local head_before="" head_after="" key tmp empty
  read-snapshot "$1" before head_before
  read-snapshot "$2" after head_after
  for key in "${!before[@]}"; do
    if [[ ${after["$key"]+set} != set || ${after["$key"]} != "${before["$key"]}" ]]; then
      seen["$key"]=1
    fi
  done
  for key in "${!after[@]}"; do
    if [[ ${before["$key"]+set} != set ]]; then
      seen["$key"]=1
    fi
  done
  if [[ $head_before != "$head_after" ]]; then
    # Before the first commit, or after HEAD is unborn again, compare with the
    # empty tree
    if [[ $head_before == none || $head_after == none ]]; then
      empty="$(git hash-object -t tree /dev/null)" || return 1
      [[ $head_before != none ]] || head_before="$empty"
      [[ $head_after != none ]] || head_after="$empty"
    fi
    tmp="$(make-temp)" || return 1
    if ! git diff -z --name-only --no-renames "$head_before" "$head_after" > "$tmp"; then
      rm -f "$tmp"
      return 1
    fi
    while IFS= read -r -d '' key; do
      seen["$key"]=1
    done < "$tmp"
    rm -f "$tmp"
  fi
  : > "$3"
  if [[ ${#seen[@]} -gt 0 ]]; then
    printf '%s\0' "${!seen[@]}" | LC_ALL=C sort -z > "$3"
  fi

  return 0
}

# Load a snapshot into an associative array and read its commit.
# Arguments:
#   $1=[snapshot file]
#   $2=[name of the associative array to fill]
#   $3=[name of the variable that receives the commit]
function read-snapshot() {

  local -n hashes="$2" head_ref="$3"
  local record
  while IFS= read -r -d '' record; do
    if [[ ${record%%$'\t'*} == = ]]; then
      # shellcheck disable=SC2034
      head_ref="${record#*$'\t'}"
    else
      hashes["${record#*$'\t'}"]="${record%%$'\t'*}"
    fi
  done < "$1"

  return 0
}

# Print the changed paths that are gate configuration or hook files, comma
# separated.
# Arguments:
#   $1=[file of changed paths, NUL-separated]
function changed-guarded-paths() {

  local file pattern matched=""
  while IFS= read -r -d '' file; do
    for pattern in "${GUARDED_PATHS[@]}"; do
      # shellcheck disable=SC2053
      if [[ $file == $pattern ]]; then
        matched="${matched:+$matched, }$file"
        break
      fi
    done
  done < "$1"
  printf '%s\n' "$matched"

  return 0
}

# ==============================================================================
# Running gates

# Run the gates and record each result in the RESULT_ arrays.
# Arguments:
#   $1=[gate configuration JSON]
#   $2=[file of changed paths, NUL-separated, empty when they are unknown]
#   $3=[scope, 'changed' or 'all']
#   $4=[seconds all gates may use, 0 for no limit]
#   $5=[true to print progress]
#   $6=[directory for the gate logs]
function execute-gates() {

  local config="$1" changes="$2" scope="$3" budget="$4" progress="$5" logs="$6"
  local name target mode timeout patterns limit remaining capped log rc seconds start outcome
  local started=$SECONDS
  mkdir -p "$logs" || return "$?"
  RESULT_NAME=() RESULT_TARGET=() RESULT_MODE=() RESULT_STATE=() RESULT_RC=() RESULT_SECONDS=() RESULT_LOG=()
  while IFS=$'\x1f' read -r name target mode timeout patterns; do
    log="$logs/$name.log"
    if [[ $scope == changed && -n $patterns && -n $changes ]] && ! changes-match "$changes" "$patterns"; then
      record-result "$name" "$target" "$mode" skipped 0 0 "$log"
      continue
    fi
    limit=$timeout
    capped=false
    if (( budget > 0 )); then
      remaining=$(( budget - (SECONDS - started) ))
      if (( remaining < 3 )); then
        record-result "$name" "$target" "$mode" not-run 0 0 "$log"
        continue
      fi
      if (( remaining < limit )); then
        limit=$remaining
        capped=true
      fi
    fi
    if [[ $progress == true ]]; then
      printf 'RUN    %s: make %s\n' "$name" "$target"
    fi
    start=$SECONDS
    rc=0
    if [[ -n $changes ]]; then
      run-with-limit "$limit" "$log" env QUALITY_GATE_ACTIVE=1 QUALITY_GATE_CHANGED_FILES="$changes" make --no-print-directory "$target" || rc=$?
    else
      run-with-limit "$limit" "$log" env QUALITY_GATE_ACTIVE=1 make --no-print-directory "$target" || rc=$?
    fi
    seconds=$(( SECONDS - start ))
    if [[ $rc -eq 0 ]]; then
      outcome=pass
    elif [[ $rc -eq 124 && $capped == true ]]; then
      outcome=incomplete
    elif [[ $rc -eq 124 ]]; then
      outcome=timeout
    elif grep -Eq "$PREREQUISITE_PATTERN" "$log"; then
      outcome=prerequisite
    else
      outcome=fail
    fi
    record-result "$name" "$target" "$mode" "$outcome" "$rc" "$seconds" "$log"
    if [[ $progress == true ]]; then
      printf '%-6s %s (%ss)\n' "${outcome^^}" "$name" "$seconds"
    fi
  done < <(jq -r "$GLOB_TO_ERE"' .gates[] | [.name, .target, .mode, (.timeout | floor | tostring), (.paths | map(ere) | join("\u001e"))] | join("\u001f")' <<< "$config")

  return 0
}

# Append one result.
# Arguments:
#   $1=[gate name] $2=[target] $3=[mode] $4=[state] $5=[exit status]
#   $6=[seconds] $7=[log file]
function record-result() {

  RESULT_NAME+=("$1") RESULT_TARGET+=("$2") RESULT_MODE+=("$3") RESULT_STATE+=("$4") RESULT_RC+=("$5") RESULT_SECONDS+=("$6") RESULT_LOG+=("$7")

  return 0
}

# Succeed when a changed path matches one of the patterns. The C locale in a
# subshell compares bytes, so a name that is not valid UTF-8 still matches, and
# leaves the caller's locale alone.
# Arguments:
#   $1=[file of changed paths, NUL-separated]
#   $2=[anchored extended regular expressions separated by the ASCII record
#     separator]
function changes-match() {

  (
    LC_ALL=C
    regexes=()
    IFS=$'\x1e' read -r -a regexes <<< "$2"
    while IFS= read -r -d '' file; do
      for regex in "${regexes[@]}"; do
        if [[ $file =~ $regex ]]; then
          exit 0
        fi
      done
    done < "$1"
    exit 1
  ) || return 1

  return 0
}

# Run a command in its own process group with its output in a file. Stop it with
# TERM, then KILL, when it exceeds the time limit, or when the hook itself is
# stopped, as the group does not receive the hook's signals.
# Arguments:
#   $1=[seconds]
#   $2=[log file]
#   $@=[command and arguments]
# Returns the command's status, or 124 when it was stopped.
function run-with-limit() {

  local seconds="$1" log="$2" pid rc=0 deadline timed_out=false
  shift 2
  trap 'stop-gate-and-exit 129' HUP
  trap 'stop-gate-and-exit 130' INT
  trap 'stop-gate-and-exit 143' TERM
  set -m
  # The parent also sets the group, so hide the child's setpgid warning
  { "$@" > "$log" 2>&1 < /dev/null & } 2> /dev/null
  pid=$!
  RUNNING_GATE=$pid
  set +m
  deadline=$(( SECONDS + seconds ))
  # Poll quickly at first so short gates finish promptly, then back off to 0.2
  # seconds
  local -a naps=(0.01 0.02 0.05 0.1 0.2)
  local nap=0
  while kill -0 "$pid" 2> /dev/null; do
    if (( SECONDS >= deadline )); then
      timed_out=true
      stop-group "$pid"
      break
    fi
    sleep "${naps[nap]}"
    (( nap >= ${#naps[@]} - 1 )) || nap=$((nap + 1))
  done
  wait "$pid" 2> /dev/null || rc=$?
  RUNNING_GATE=""
  trap - HUP INT TERM
  if [[ $timed_out == true ]]; then
    rc=124
  fi

  return "$rc"
}

# Stop a process group with TERM, then KILL what is left a second later.
# Arguments:
#   $1=[process group identifier]
function stop-group() {

  # The group may already have exited
  kill -TERM -- "-$1" 2> /dev/null || true
  for _ in 1 2 3 4 5; do
    kill -0 -- "-$1" 2> /dev/null || break
    sleep 0.2
  done
  kill -KILL -- "-$1" 2> /dev/null || true

  return 0
}

# Stop the running gate and exit, for a signal that stops the hook. The traps
# that run-with-limit sets call it.
# Arguments:
#   $1=[exit status]
# shellcheck disable=SC2329
function stop-gate-and-exit() {

  if [[ -n $RUNNING_GATE ]]; then
    stop-group "$RUNNING_GATE"
  fi
  exit "$1"
}

# ==============================================================================
# Reporting

# Succeed when a result makes the agent continue: a gate in block mode failed or
# timed out. A gate that could not run is reported to the user instead.
# Arguments:
#   $1=[result index]
function is-blocking() {

  if [[ ${RESULT_MODE[$1]} == block && ${RESULT_STATE[$1]} =~ ^(fail|timeout)$ ]]; then
    return 0
  fi

  return 1
}

# Succeed when a gate makes the agent continue.
function blocking-failure() {

  local i
  for i in "${!RESULT_STATE[@]}"; do
    if is-blocking "$i"; then
      return 0
    fi
  done

  return 1
}

# Succeed when a gate in block mode did not pass, which fails 'make
# quality-gate'.
function run-failed() {

  local i
  for i in "${!RESULT_STATE[@]}"; do
    if [[ ${RESULT_MODE[$i]} == block && ${RESULT_STATE[$i]} != pass && ${RESULT_STATE[$i]} != skipped ]]; then
      return 0
    fi
  done

  return 1
}

# Print the names of the gates that blocked, comma separated.
function failed-names() {

  local i names=""
  for i in "${!RESULT_STATE[@]}"; do
    if is-blocking "$i"; then
      names="${names:+$names, }${RESULT_NAME[$i]}"
    fi
  done
  printf '%s\n' "$names"

  return 0
}

# Print why a gate could not run: its first prerequisite line, without colour or
# the 'PREREQUISITE: ' prefix, cut to NOTE_CHARACTERS.
# Arguments:
#   $1=[result index]
function prerequisite-line() {

  local line
  line="$(grep -E -m1 "$PREREQUISITE_PATTERN" "${RESULT_LOG[$1]}" | strip-ansi)" || true
  line="${line#PREREQUISITE: }"
  printf '%s\n' "${line:0:$NOTE_CHARACTERS}"

  return 0
}

# Describe the results the user should know about that do not block: gates that
# could not run, warnings and the time budget.
function summary-notes() {

  local i notes=""
  for i in "${!RESULT_STATE[@]}"; do
    case ${RESULT_STATE[$i]} in
      prerequisite)
        notes="${notes:+$notes; }${RESULT_NAME[$i]} could not run ($(prerequisite-line "$i")), so its result is unknown. Fix that, then run 'make ${RESULT_TARGET[$i]}'"
        ;;
      fail | timeout)
        if [[ ${RESULT_MODE[$i]} == warn ]]; then
          notes="${notes:+$notes; }${RESULT_NAME[$i]} did not pass (warning only)"
        fi
        ;;
      incomplete) notes="${notes:+$notes; }${RESULT_NAME[$i]} did not finish within the time budget" ;;
      not-run) notes="${notes:+$notes; }${RESULT_NAME[$i]} was not run, the time budget was used up" ;;
    esac
  done
  printf '%s\n' "$notes"

  return 0
}

# Build the message that tells the agent what to fix. It names each blocking
# gate, gives the end of its output and the command to rerun, within
# REASON_BYTES, and names the gates that could not run.
function build-reason() {

  local i count=0 share text
  for i in "${!RESULT_STATE[@]}"; do
    if is-blocking "$i"; then
      count=$((count + 1))
    fi
  done
  share=$(( REASON_BYTES / (count > 0 ? count : 1) ))
  text="Quality gates failed. Fix the cause and rerun the command shown, do not disable or skip a gate."
  for i in "${!RESULT_STATE[@]}"; do
    is-blocking "$i" || continue
    if [[ ${RESULT_STATE[$i]} == timeout ]]; then
      text+=$'\n\n'"== ${RESULT_NAME[$i]} (make ${RESULT_TARGET[$i]}) timed out after ${RESULT_SECONDS[$i]}s =="
    else
      text+=$'\n\n'"== ${RESULT_NAME[$i]} (make ${RESULT_TARGET[$i]}) failed with exit status ${RESULT_RC[$i]} =="
    fi
    text+=$'\n'"$(strip-ansi < "${RESULT_LOG[$i]}" | tail -n "$EXCERPT_LINES" | tail -c "$share")"
    text+=$'\n'"Rerun: make ${RESULT_TARGET[$i]}"$'\n'"Full log: ${RESULT_LOG[$i]#"$PWD"/}"
  done
  for i in "${!RESULT_STATE[@]}"; do
    if [[ ${RESULT_STATE[$i]} == prerequisite ]]; then
      text+=$'\n\n'"make ${RESULT_TARGET[$i]} could not run ($(prerequisite-line "$i")), so its result is unknown. Tell the user, do not change the environment."
    fi
  done
  printf '%s\n' "$text"

  return 0
}

# Print a table of the results.
function summarise-results() {

  local i
  for i in "${!RESULT_STATE[@]}"; do
    printf '%-14s %-12s %s\n' "${RESULT_NAME[$i]}" "${RESULT_STATE[$i]}" "make ${RESULT_TARGET[$i]}"
  done

  return 0
}

# Save the results of the last run as JSON, for diagnosing the hook.
# Arguments:
#   $1=[state directory] $2=[event] $3=[session identifier]
function write-last-run() {

  local i
  for i in "${!RESULT_STATE[@]}"; do
    printf '%s\t%s\t%s\t%s\n' "${RESULT_NAME[$i]}" "${RESULT_STATE[$i]}" "${RESULT_RC[$i]}" "${RESULT_SECONDS[$i]}"
  done | jq -R -s -c --arg event "$2" --arg session "$3" \
    '{time: (now | floor | todate), event: $event, session: $session, gates: (split("\n") | map(select(length > 0) | split("\t") | {name: .[0], state: .[1], status: (.[2] | tonumber), seconds: (.[3] | tonumber)}))}' \
    > "$1/last-run.json" || echo "Quality gate: cannot write $1/last-run.json" >&2

  return 0
}

# Print a hook response that lets the agent finish.
# Arguments:
#   $1=[message for the user, optional]
function emit-allow() {

  if [[ -n ${1:-} ]]; then
    jq -nc --arg message "$1" '{systemMessage: $message}'
  else
    echo '{}'
  fi

  return 0
}

# Print a hook response that makes the agent continue. It carries the decision
# both at the top level, which the Copilot runtime reads, and in
# hookSpecificOutput, which the VS Code Local harness reads.
# Arguments:
#   $1=[reason given to the agent]
#   $2=[message for the user]
function emit-block() {

  jq -nc --arg reason "$1" --arg message "$2" \
    '{decision: "block", reason: $reason, systemMessage: $message, hookSpecificOutput: {hookEventName: "Stop", decision: "block", reason: $reason}}'

  return 0
}

# ==============================================================================
# Utilities

# Remove terminal colour sequences from stdin.
function strip-ansi() {

  sed "s/$(printf '\033')\[[0-9;]*[A-Za-z]//g"

  return 0
}

# Print a clock time for an epoch second, with GNU or BSD date.
# Arguments:
#   $1=[epoch seconds]
function format-time() {

  date -d "@$1" '+%H:%M %Z' 2> /dev/null || date -r "$1" '+%H:%M %Z'

  return 0
}

# ==============================================================================

# Check whether the supplied argument represents a true boolean value.
# Arguments:
#   $1=[value to evaluate]
function is-arg-true() {

  local value="$1"
  if [[ "$value" =~ ^(true|yes|y|on|1|TRUE|YES|Y|ON)$ ]]; then
    return 0
  else
    return 1
  fi
}

# ==============================================================================

is-arg-true "${VERBOSE:-false}" && set -x

main "$@"

exit 0
