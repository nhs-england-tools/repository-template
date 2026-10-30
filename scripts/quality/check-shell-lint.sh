#!/usr/bin/env bash

set -euo pipefail

# Lint repository shell scripts with ShellCheck. It runs ShellCheck natively
# when installed, otherwise in a Docker container. It also fails any full-line
# comment longer than 80 characters in a shell script or a '*.mk' file, except
# a line with a URL and the shebang.
#
# Usage:
#   $ [options] ./scripts/quality/check-shell-lint.sh
#
# Options:
#   check={all,staged-changes,working-tree-changes,branch}
#       Check mode, default is 'all'
#   BRANCH_NAME=base-branch
#       Local base for branch mode, chosen automatically when unset, as
#       './scripts/quality/git-base.lib.sh' describes
#   FORCE_USE_DOCKER=true
#       Run in a Docker container, default is 'false'
#   VERBOSE=true
#       Show all the executed commands, default is 'false'
#
# Exit codes:
#   0 - All selected files passed, or no files were selected
#   1 - ShellCheck or comment length findings, the branch to compare with is
#       not found, or a local setup failure
#   126 - The check mode is not recognised
#   Other - Non-zero statuses from Git, Bash, ShellCheck, image pulls or Docker
#           are passed through, even when comment length findings are also
#           reported
#
# Notes:
#   1) Check modes select existing shell scripts known to Git, as described in
#      './scripts/quality/git-files.lib.sh'. Untracked files are never linted.
#   2) Scoped modes also lint the scripts that name a changed, deleted or
#      renamed script, directly or not, and the scripts those name. ShellCheck
#      then sees the same source context as in 'all' mode. A script names
#      another when it contains the other's file name with no letter, digit,
#      '_', '.' or '-' either side. A scoped mode that changes a '.shellcheckrc'
#      or 'shellcheckrc' file, or 'mise.toml', which pins ShellCheck, lints
#      every script.
#   3) Every mode first runs ShellCheck in parallel, quietly, natively or in
#      one container each, over groups of each script and the scripts it names,
#      directly or not. If a group fails, one full call gives the report and
#      exit status.
#   4) The comment length check needs no ShellCheck or Docker and counts bytes
#      in the C locale, so a non-ASCII character counts as more than one. It
#      checks the selected '*.sh' and tracked '*.mk' files, all of them in
#      'all' mode and only the changed ones in scoped modes, since it does not
#      depend on other files. Unreadable files are left to ShellCheck to
#      report.
#   5) A line counts as a comment when its first non-blank character is '#',
#      including such lines in heredocs and embedded awk or Python code. A
#      comment line containing '://' is exempt, so a long URL never fails.
#   6) Paths that './scripts/config/.commentlengthignore' matches, with Git's
#      ignore rules from the repository root, skip the comment length check,
#      for example scripts vendored from another repository. ShellCheck still
#      lints them. A scoped mode that changes this file checks the comments of
#      every script and Make file.

# ==============================================================================

# Lint the selected shell scripts natively or in Docker.
function main() {

  cd "$(git rev-parse --show-toplevel)"

  local check_mode=${check:-all}

  # shellcheck disable=SC1091
  source ./scripts/quality/git-files.lib.sh
  local rc=0
  local -a files=() graph_files=() make_files=() changed=() deleted=()
  local -a comment_paths=()
  # shellcheck disable=SC2034
  local -a dependencies=() callers=()
  local tracked_count settings_changed=false ignore_list_changed=false
  quality-collect-git-files graph_files all '*.sh' || return "$?"
  tracked_count=${#graph_files[@]}
  if [[ "$check_mode" == all ]]; then
    changed=("${graph_files[@]}")
    quality-collect-git-files make_files all '*.mk' || return "$?"
    comment_paths=("${changed[@]}" "${make_files[@]}")
  else
    collect-changed-paths changed make_files deleted settings_changed ignore_list_changed "$check_mode" || return "$?"
    comment_paths=("${changed[@]}" "${make_files[@]}")
    if [[ "$ignore_list_changed" == true ]]; then
      # A shorter ignore list can bring any script back into the check
      comment_paths=("${graph_files[@]}")
      quality-collect-git-files comment_paths all '*.mk' || return "$?"
    fi
    # Deleted scripts join the graph only to select the scripts that name them
    graph_files+=("${deleted[@]}")
  fi

  build-shell-script-name-graph dependencies callers "$tracked_count" "${graph_files[@]}" || return "$?"
  if [[ "$check_mode" == all || "$settings_changed" == true ]]; then
    files=("${graph_files[@]:0:tracked_count}")
  else
    collect-shell-script-context files graph_files dependencies callers "$tracked_count" "${changed[@]}" "${deleted[@]}" || return "$?"
  fi

  if [[ ${#files[@]} -gt 0 ]]; then
    if command -v shellcheck > /dev/null 2>&1 && ! is-arg-true "${FORCE_USE_DOCKER:-false}"; then
      run-shellcheck-natively-all graph_files dependencies "${files[@]}" || rc=$?
    else
      run-shellcheck-in-docker-all graph_files dependencies "${files[@]}" || rc=$?
    fi
  fi
  quality-remove-ignored-paths comment_paths ./scripts/config/.commentlengthignore || return "$?"
  check-comment-length "${comment_paths[@]}" || [[ $rc -ne 0 ]] || rc=1

  return "$rc"
}

# Collect the changed shell scripts and Make files of a scoped check mode, the
# shell scripts it deletes, and whether it changes a ShellCheck setting or the
# comment length ignore list.
# Arguments:
#   $1=[name reference of the changed shell scripts]
#   $2=[name reference of the changed Make files]
#   $3=[name reference of the deleted shell scripts]
#   $4=[name reference of a flag, set to 'true' when a ShellCheck setting
#     changes]
#   $5=[name reference of a flag, set to 'true' when the ignore list changes]
#   $6=[check mode]
function collect-changed-paths() {

  # shellcheck disable=SC2178
  local -n changed_scripts="$1" changed_make_files="$2" deleted_scripts="$3" shellcheck_settings_changed="$4" ignore_list_changed_flag="$5" || return "$?"
  local check_mode="$6" path
  local -a selected=() gone=()
  # One call without a pathspec, so branch mode resolves its base only once
  quality-collect-git-files selected "$check_mode" '' gone || return "$?"
  for path in "${selected[@]}"; do
    case $path in
      *.sh) changed_scripts+=("$path") ;;
      *.mk) changed_make_files+=("$path") ;;
    esac
  done
  for path in "${gone[@]}"; do
    [[ "$path" != *.sh ]] || deleted_scripts+=("$path")
  done
  for path in "${selected[@]}" "${gone[@]}"; do
    case $path in
      .shellcheckrc | */.shellcheckrc | shellcheckrc | */shellcheckrc | mise.toml)
        # shellcheck disable=SC2034
        shellcheck_settings_changed=true
        ;;
      scripts/config/.commentlengthignore)
        # shellcheck disable=SC2034
        ignore_list_changed_flag=true
        ;;
    esac
  done

  return 0
}

# Build the script-name graph used for scoped context and parallel groups.
# Arguments:
#   $1=[name reference of dependency graph]
#   $2=[name reference of caller graph]
#   $3=[number of leading paths to read, the rest are only searched for]
#   $@=[shell-script paths, relative to the repository root]
function build-shell-script-name-graph() {

  # shellcheck disable=SC2178
  local -n dependency_graph="$1" caller_graph="$2" || return "$?"
  local readable_count="$3"
  shift 3
  local -a files=("$@")
  local -A index=()
  local i j path pattern
  dependency_graph=()
  caller_graph=()
  for ((i = 0; i < ${#files[@]}; i++)); do
    index["${files[i]}"]=$i
  done
  # grep without file operands would read stdin
  ((readable_count > 0)) || return 0
  for ((j = 0; j < ${#files[@]}; j++)); do
    # grep treats a newline in a pattern as multiple patterns
    [[ "${files[j]}" == *$'\n'* ]] && continue
    shell-script-name-pattern pattern "${files[j]##*/}"
    while IFS= read -r -d '' path; do
      i="${index["$path"]:-}"
      if [[ -n "$i" && "$i" -ne "$j" ]]; then
        dependency_graph[i]+="$j "
        caller_graph[j]+="$i "
      fi
    done < <(grep -lE --null -e "$pattern" -- "${files[@]:0:readable_count}" 2> /dev/null)
  done

  return 0
}

# Set an extended regular expression that matches a file name, but not as part
# of a longer file name.
# Arguments:
#   $1=[name of the output variable]
#   $2=[file name]
function shell-script-name-pattern() {

  local -n name_pattern="$1" || return "$?"
  local name="$2" escaped='' char i
  for ((i = 0; i < ${#name}; i++)); do
    char="${name:i:1}"
    case $char in
      '^') escaped+='\^' ;;
      '.' | '[' | ']' | \\ | '*' | '$' | '(' | ')' | '+' | '?' | '{' | '}' | '|') escaped+="[$char]" ;;
      *) escaped+="$char" ;;
    esac
  done
  # shellcheck disable=SC2034
  name_pattern="(^|[^[:alnum:]_.-])${escaped}(\$|[^[:alnum:]_.-])"

  return 0
}

# Select changed scripts, their callers and those callers' dependencies. Deleted
# seeds select their callers but are not returned.
# Arguments:
#   $1=[name reference of output paths]
#   $2=[name reference of graph paths]
#   $3=[name reference of dependency graph]
#   $4=[name reference of caller graph]
#   $5=[number of leading graph paths that are tracked, the rest are deleted]
#   $@=[changed and deleted shell-script paths]
function collect-shell-script-context() {

  # shellcheck disable=SC2178
  local -n result="$1" graph_paths="$2" dependency_graph="$3" caller_graph="$4" || return "$?"
  local tracked_count="$5"
  shift 5
  local -a included=()
  local -A index=()
  local i path
  result=()
  for ((i = 0; i < ${#graph_paths[@]}; i++)); do
    index["${graph_paths[i]}"]=$i
  done
  for path in "$@"; do
    i="${index["$path"]:-}"
    [[ -z "$i" ]] || included[i]=1
  done
  add-reachable-nodes included caller_graph || return "$?"
  add-reachable-nodes included dependency_graph || return "$?"
  for ((i = 0; i < tracked_count; i++)); do
    [[ -n "${included[i]:-}" ]] && result+=("${graph_paths[i]}")
  done

  return 0
}

# Add to a set of graph nodes every node reachable from them.
# Arguments:
#   $1=[name reference of the set, an indexed array keyed by node index]
#   $2=[name reference of the graph, space-separated node indexes per node]
function add-reachable-nodes() {

  local -n reachable="$1" edges="$2" || return "$?"
  local -a queue=("${!reachable[@]}")
  local node related
  while ((${#queue[@]} > 0)); do
    node=${queue[0]}
    queue=("${queue[@]:1}")
    for related in ${edges[node]:-}; do
      if [[ -z "${reachable[$related]:-}" ]]; then
        reachable[related]=1
        queue+=("$related")
      fi
    done
  done

  return 0
}

# Print each full-line comment over the length limit, and fail if there is one.
# Arguments:
#   $@=[shell-script and Make file paths, relative to the repository root]
function check-comment-length() {

  local -a paths=()
  local path rc=0
  for path in "$@"; do
    [[ -r "$path" ]] || continue
    # Without a '/', awk would read a name such as 'a=b.sh' as an assignment
    [[ "$path" == /* ]] || path="./$path"
    paths+=("$path")
  done
  # awk would read stdin without any file
  [[ ${#paths[@]} -gt 0 ]] || return 0
  LC_ALL=C awk -v max=80 '
    FNR == 1 && /^#!/ { next }
    /^[[:space:]]*#/ && length($0) > max && $0 !~ /:\/\// {
      name = FILENAME
      sub(/^\.\//, "", name)
      printf "%s:%d: comment is %d characters, the limit is %d\n", name, FNR, length($0), max
      found = 1
    }
    END { exit found }
  ' "${paths[@]}" >&2 || rc=1

  return "$rc"
}

# Run ShellCheck natively over the selected files.
# Arguments:
#   $1=[name reference of graph paths]
#   $2=[name reference of dependency graph]
#   $@=[shell-script paths]
function run-shellcheck-natively-all() {

  local graph_paths_name="$1" dependency_graph_name="$2" rc=0
  shift 2
  run-shellcheck-all shellcheck "$graph_paths_name" "$dependency_graph_name" "$@" || rc=$?

  return "$rc"
}

# Run ShellCheck over parallel groups first, then once over all files if a group
# fails, to provide the complete report and exit status.
# Arguments:
#   $1=[command that accepts ShellCheck options, then '--' and paths]
#   $2=[name reference of graph paths]
#   $3=[name reference of dependency graph]
#   $@=[shell-script paths]
function run-shellcheck-all() {

  local runner="$1" graph_paths_name="$2" dependency_graph_name="$3"
  shift 3
  run-shellcheck-groups-in-parallel "$runner" "$graph_paths_name" "$dependency_graph_name" "$@" && return 0
  local rc=0
  "$runner" -- "$@" || rc=$?

  return "$rc"
}

# Run quiet ShellCheck calls in parallel, one for each group. It fails unless
# the groups cover every selected path.
# Arguments:
#   $1=[command that accepts ShellCheck options, then '--' and paths]
#   $2=[name reference of graph paths]
#   $3=[name reference of dependency graph]
#   $@=[shell-script paths]
function run-shellcheck-groups-in-parallel() {

  local runner="$1" graph_paths_name="$2" dependency_graph_name="$3"
  shift 3
  local -a files=("$@") inputs=() pids=() covered=()
  local group k pid limit rc=0
  limit="$(getconf _NPROCESSORS_ONLN 2> /dev/null || echo 4)"
  while read -r group; do
    ((rc == 0)) || break
    [[ "$group" =~ ^[0-9]+( [0-9]+)*$ ]] || { rc=1; break; }
    inputs=()
    for k in $group; do
      ((10#$k < ${#files[@]})) || { rc=1; break 2; }
      covered[10#$k]=1
      inputs+=("${files[10#$k]}")
    done
    if ((${#pids[@]} >= limit)); then
      wait "${pids[0]}" || rc=1
      pids=("${pids[@]:1}")
    fi
    "$runner" -f quiet -- "${inputs[@]}" > /dev/null 2>&1 &
    pids+=("$!")
  done < <(print-shell-script-groups "$graph_paths_name" "$dependency_graph_name" "${files[@]}")
  for pid in "${pids[@]}"; do
    wait "$pid" || rc=1
  done
  ((${#covered[@]} == ${#files[@]})) || rc=1

  return "$rc"
}

# Print groups of selected-path indexes, largest first, using the shared graph.
# Arguments:
#   $1=[name reference of graph paths]
#   $2=[name reference of dependency graph]
#   $@=[selected shell-script paths]
function print-shell-script-groups() {

  # shellcheck disable=SC2178
  local -n graph_paths="$1" dependency_graph="$2" || return "$?"
  shift 2
  local -a files=("$@") named=() groups=() sizes=() seen=() grouped=()
  local -A graph_index=() selected_index=()
  local count=$# i j k graph_node dependency
  for ((i = 0; i < ${#graph_paths[@]}; i++)); do
    graph_index["${graph_paths[i]}"]=$i
  done
  for ((i = 0; i < count; i++)); do
    graph_node="${graph_index["${files[i]}"]:-}"
    [[ -n "$graph_node" ]] && selected_index[$graph_node]=$i
  done
  for ((i = 0; i < count; i++)); do
    graph_node="${graph_index["${files[i]}"]:-}"
    # An empty subscript would read node 0
    [[ -n "$graph_node" ]] || continue
    for dependency in ${dependency_graph[graph_node]:-}; do
      j="${selected_index[$dependency]:-}"
      [[ -n "$j" && "$j" -ne "$i" ]] && named[i]+="$j "
    done
  done
  for ((i = 0; i < count; i++)); do
    seen=([i]=1)
    add-reachable-nodes seen named || return "$?"
    groups[i]="${!seen[*]}"
    sizes[i]=${#seen[@]}
  done
  while read -r _ i; do
    [[ -n "${grouped[i]:-}" ]] && continue
    for k in ${groups[i]}; do
      grouped[k]=1
    done
    echo "${groups[i]}"
  done < <(for ((i = 0; i < count; i++)); do
    echo "${sizes[i]} $i"
  done | sort -k1,1nr -k2,2n)

  return 0
}

# Run ShellCheck in Docker over the selected files.
# Arguments:
#   $1=[name reference of graph paths]
#   $2=[name reference of dependency graph]
#   $@=[shell-script paths]
function run-shellcheck-in-docker-all() {

  local graph_paths_name="$1" dependency_graph_name="$2" image rc=0
  shift 2
  # shellcheck disable=SC1091
  source ./scripts/docker/docker.lib.sh
  image="$(name=koalaman/shellcheck docker-get-image-version-and-pull)" || return "$?"
  run-shellcheck-all run-shellcheck-container "$graph_paths_name" "$dependency_graph_name" "$@" || rc=$?

  return "$rc"
}

# Run ShellCheck in one Docker container.
# Arguments (provided as environment variables):
#   image=[pulled ShellCheck image]
# Arguments:
#   $@=[ShellCheck options, then '--' and the shell-script paths]
# shellcheck disable=SC2329
function run-shellcheck-container() {

  local -a args=()
  while [[ "$1" != -- ]]; do
    args+=("$1")
    shift
  done
  shift
  args+=(--)
  local file
  for file in "$@"; do
    args+=("/workdir/$file")
  done
  local rc=0
  docker run --rm --platform linux/amd64 \
    --network none \
    --volume "$PWD:/workdir:ro" \
    --workdir /workdir \
    "$image" \
    "${args[@]}" || rc=$?

  return "$rc"
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
