#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2016,SC2034,SC2317,SC2329

set -euo pipefail

# Test suite for the quality gate script. Each test runs the script in a
# scratch Git repository with the real jq and yq and with 'make' stubbed, so a
# gate is a stub body that passes, fails, prints or sleeps. The suite needs
# neither Docker nor the network.
#
# Usage:
#   $ ./scripts/quality/tests/quality-gate.test.sh
#
# Options:
#   VERBOSE=true  # Show all the executed commands, default is 'false'

# ==============================================================================

readonly EXIT_STATUS_LABEL='exit status'
readonly SESSION=session-1
readonly SCRIPT=./scripts/quality/quality-gate.sh
readonly LINT_CALL='--no-print-directory lint'
readonly TEST_CALL='--no-print-directory test'
readonly FAILING_LINT='if [[ "${*: -1}" == lint ]]; then echo "lint finding on line 7"; exit 1; fi'
# Time limits count whole seconds, so a limit of 2 gives the gate at least a second to start its processes
readonly SHORT_LINT_GATE=$'version: 1\ngates:\n  - name: lint\n    timeout: 2'

# Set up the suite fixtures and run every test.
function main() {

  cd "$(git rev-parse --show-toplevel)"
  source ./scripts/tests/test.lib.sh

  # The caller's options must not reach the script under test
  unset -v scope hours QUALITY_GATE_BUDGET QUALITY_GATE_ACTIVE GITHUB_ACTIONS COPILOT_AGENT_PROMPT

  # The tests that wait for time limits or run many turns come first, so the others run alongside them
  test-run-suite \
    test-quality-gate-reports-gates-the-time-budget-did-not-allow \
    test-quality-gate-matches-path-globs \
    test-quality-gate-does-not-match-paths-outside-the-globs \
    test-quality-gate-times-out-a-gate-and-stops-its-process-group \
    test-quality-gate-stops-processes-a-gate-started \
    test-quality-gate-lets-the-processes-of-a-stopped-gate-clean-up \
    test-quality-gate-stops-the-running-gate-when-the-hook-is-stopped \
    test-quality-gate-rejects-an-unknown-command \
    test-quality-gate-ignores-events-it-does-not-handle \
    test-quality-gate-reports-an-unreadable-payload \
    test-quality-gate-does-nothing-in-github-actions \
    test-quality-gate-skips-the-gates-when-the-turn-changed-nothing \
    test-quality-gate-runs-the-gates-after-a-tracked-edit \
    test-quality-gate-runs-the-gates-after-a-staged-change \
    test-quality-gate-runs-the-gates-after-a-commit \
    test-quality-gate-runs-the-gates-after-an-untracked-file-changes-content \
    test-quality-gate-runs-the-gates-with-untracked-links \
    test-quality-gate-detects-a-changed-link-target \
    test-quality-gate-detects-a-mode-change \
    test-quality-gate-runs-every-gate-when-the-tree-cannot-be-read \
    test-quality-gate-runs-every-gate-when-the-tree-could-not-be-read-at-the-start \
    test-quality-gate-runs-every-gate-when-a-directory-cannot-be-read \
    test-quality-gate-sees-changes-inside-a-nested-repository \
    test-quality-gate-works-when-the-temporary-directory-is-unusable \
    test-quality-gate-runs-every-gate-and-says-why-without-a-baseline \
    test-quality-gate-runs-every-gate-without-a-session-id \
    test-quality-gate-treats-an-unsafe-session-id-as-missing \
    test-quality-gate-keeps-a-baseline-per-session \
    test-quality-gate-keeps-the-baseline-when-another-prompt-arrives-mid-turn \
    test-quality-gate-records-the-time-of-the-last-hook-and-run-in-utc \
    test-quality-gate-starts-a-new-turn-after-the-agent-finishes \
    test-quality-gate-ignores-subagent-events \
    test-quality-gate-passes-the-changed-paths-to-a-gate \
    test-quality-gate-keeps-awkward-file-names-intact \
    test-quality-gate-hashes-more-files-than-one-chunk \
    test-quality-gate-matches-paths-of-a-commit-made-during-the-turn \
    test-quality-gate-runs-every-gate-when-the-first-commit-is-made-during-the-turn \
    test-quality-gate-matches-file-names-that-are-not-utf-8 \
    test-quality-gate-blocks-with-valid-output-for-both-harnesses \
    test-quality-gate-runs-the-remaining-gates-after-a-failure \
    test-quality-gate-blocks-once-then-lets-the-agent-finish \
    test-quality-gate-keeps-the-block-count-when-another-prompt-arrives-mid-turn \
    test-quality-gate-blocks-again-after-a-cancelled-continuation \
    test-quality-gate-lets-the-agent-finish-without-a-session-after-a-block \
    test-quality-gate-honours-max-blocks-and-a-new-prompt-resets-it \
    test-quality-gate-reports-a-docker-prerequisite-without-blocking \
    test-quality-gate-reports-the-prerequisite-marker \
    test-quality-gate-tells-the-agent-about-a-gate-that-could-not-run \
    test-quality-gate-keeps-the-logs-of-each-session-apart \
    test-quality-gate-keeps-fresh-log-directories-of-other-sessions \
    test-quality-gate-limits-the-size-of-the-report \
    test-quality-gate-shares-the-report-size-between-failing-gates \
    test-quality-gate-strips-colour-from-the-report \
    test-quality-gate-does-not-block-on-a-warn-gate \
    test-quality-gate-skips-a-gate-whose-paths-match-no-change \
    test-quality-gate-ignores-gate-list-edits-made-during-the-turn \
    test-quality-gate-uses-the-gate-list-from-the-start-of-the-turn \
    test-quality-gate-reads-the-rules-from-the-start-of-the-turn \
    test-quality-gate-says-when-no-commit-holds-the-gate-list \
    test-quality-gate-uses-the-start-commit-when-the-tree-could-not-be-read-at-the-start \
    test-quality-gate-reads-an-empty-baseline-as-unreadable \
    test-quality-gate-names-the-gate-list-it-used-without-a-baseline \
    test-quality-gate-applies-a-committed-drop-in \
    test-quality-gate-reads-drop-ins-in-byte-order \
    test-quality-gate-warns-about-an-invalid-committed-configuration \
    test-quality-gate-rejects-invalid-gate-configuration \
    test-quality-gate-rejects-drop-in-names-that-are-not-plain-ascii \
    test-quality-gate-accepts-whole-numbers-written-as-decimals \
    test-quality-gate-copes-with-rules-that-print-decimals \
    test-quality-gate-ignores-warnings-while-reading-the-configuration \
    test-quality-gate-reads-a-budget-with-leading-zeros-as-decimal \
    test-quality-gate-names-the-missing-tool \
    test-quality-gate-names-yq-when-it-cannot-run \
    test-quality-gate-fails-when-a-mise-shim-cannot-run-a-tool \
    test-quality-gate-needs-mikefarah-yq \
    test-quality-gate-pauses-from-the-next-prompt-and-resumes \
    test-quality-gate-ignores-a-pause-made-during-the-turn \
    test-quality-gate-removes-an-expired-pause \
    test-quality-gate-rejects-an-out-of-range-pause \
    test-quality-gate-never-stores-or-prints-the-prompt \
    test-quality-gate-run-runs-every-gate \
    test-quality-gate-run-fails-when-a-gate-fails \
    test-quality-gate-run-fails-when-a-gate-cannot-run \
    test-quality-gate-run-rejects-an-unknown-scope \
    test-quality-gate-run-refuses-to-run-inside-a-gate \
    test-quality-gate-lists-the-gates \
    test-quality-gate-reruns-itself-with-a-newer-bash \
    test-quality-gate-registers-both-hook-events \
    test-quality-gate-pre-commit-runs-make-test-last \
    test-quality-gate-default-configuration-is-valid

  return 0
}

# ==============================================================================
# Helpers

# Create the scratch repository "$TEST_TMP/repo" with the script, its rules and the
# default gate list, commit it with a README and a source file, stub 'make' and
# change into it.
function gate-create-repo() {

  local repo="$TEST_TMP/repo"
  cp -Rp "$SUITE_TMP/repo-template" "$repo"
  test-isolate-path jq yq readlink
  test-stub make
  cd "$repo"

  return 0
}

# Build the committed fixture repository once, every test starts from a copy.
function test-suite-setup() {

  gate-build-repo "$SUITE_TMP/repo-template"

  return 0
}

# Build the committed fixture repository.
# Arguments:
#   $1=[directory]
function gate-build-repo() {

  local repo="$1"
  test-create-repo "$repo" scripts/quality/quality-gate.sh scripts/quality/quality-gate.jq scripts/config/quality-gates.yaml
  mkdir -p "$repo/src"
  printf 'one\n' > "$repo/README.md"
  printf 'int a;\n' > "$repo/src/a.c"
  git -C "$repo" add -A
  git -C "$repo" commit -q -m fixture

  return 0
}

# Write a file in the repository and commit it.
# Arguments:
#   $1=[path] $2=[content]
function gate-commit-file() {

  mkdir -p "$(dirname "$1")"
  printf '%s\n' "$2" > "$1"
  git add -- "$1"
  git commit -q -m "update $1"

  return 0
}

# Replace the make stub body.
# Arguments:
#   $1=[bash code, the target is "${*: -1}"]
function gate-make() {

  test-stub make "$1"

  return 0
}

# Send a hook event to the script.
# Arguments:
#   $1=[event JSON]
function gate-send() {

  printf '%s' "$1" | "$SCRIPT" hook

  return 0
}

# Print a UserPromptSubmit event. The prompt text is a marker the tests look for.
# Arguments:
#   $1=[session identifier, default is the suite's]
function gate-prompt-json() {

  printf '{"hook_event_name":"UserPromptSubmit","session_id":"%s","prompt":"PROMPT-MARKER-4711"}' "${1-$SESSION}"

  return 0
}

# Print a Stop event.
# Arguments:
#   $1=[session identifier, default is the suite's]
#   $2=[stop_hook_active, default is 'false']
function gate-stop-json() {

  printf '{"hook_event_name":"Stop","session_id":"%s","stop_hook_active":%s}' "${1-$SESSION}" "${2:-false}"

  return 0
}

# Start a turn: record the baseline.
function gate-start-turn() {

  gate-send "$(gate-prompt-json "$@")" > /dev/null

  return 0
}

# Print the list of make calls, one per line.
function gate-calls() {

  test-stub-calls make

  return 0
}

# ==============================================================================
# Events and the no-change guard

function test-quality-gate-rejects-an-unknown-command() {

  # Arrange
  gate-create-repo
  # Act
  test-capture "$SCRIPT" bogus
  # Assert
  assert-equal 126 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "Unrecognised command: 'bogus'. Use one of: hook, run, list, pause, resume"

  return 0
}

function test-quality-gate-ignores-events-it-does-not-handle() {

  # Arrange
  gate-create-repo
  # Act
  test-capture gate-send '{"hook_event_name":"SessionStart","session_id":"s"}'
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal '{}' "$TEST_STDOUT" "hook output"
  assert-stub-not-called make

  return 0
}

function test-quality-gate-reports-an-unreadable-payload() {

  # Arrange
  gate-create-repo
  # Act
  test-capture gate-send 'this is not JSON'
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDOUT" "not valid JSON"
  assert-stub-not-called make

  return 0
}

function test-quality-gate-does-nothing-in-github-actions() {

  # Arrange
  gate-create-repo
  gate-start-turn
  printf 'two\n' >> README.md
  # Act
  export COPILOT_AGENT_PROMPT='fix the build'
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal '{}' "$TEST_STDOUT" "hook output in Copilot cloud agent"
  # Act
  unset -v COPILOT_AGENT_PROMPT
  export GITHUB_ACTIONS=true
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-equal '{}' "$TEST_STDOUT" "hook output in GitHub Actions"
  assert-stub-not-called make

  return 0
}

function test-quality-gate-skips-the-gates-when-the-turn-changed-nothing() {

  # Arrange
  gate-create-repo
  gate-start-turn
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal '{}' "$TEST_STDOUT" "hook output"
  assert-stub-not-called make
  assert-contains "$(< .git/quality-gate/last-hook.json)" '"action":"unchanged"'

  return 0
}

function test-quality-gate-runs-the-gates-after-a-tracked-edit() {

  # Arrange
  gate-create-repo
  gate-start-turn
  printf 'two\n' >> README.md
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal '{}' "$TEST_STDOUT" "hook output"
  assert-equal "$LINT_CALL"$'\n'"$TEST_CALL" "$(gate-calls)" "make calls"

  return 0
}

function test-quality-gate-runs-the-gates-after-a-staged-change() {

  # Arrange
  gate-create-repo
  gate-start-turn
  printf 'two\n' >> README.md
  git add README.md
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-equal "$LINT_CALL"$'\n'"$TEST_CALL" "$(gate-calls)" "make calls"

  return 0
}

function test-quality-gate-runs-the-gates-after-a-commit() {

  # Arrange
  gate-create-repo
  gate-start-turn
  gate-commit-file README.md changed
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-equal "$LINT_CALL"$'\n'"$TEST_CALL" "$(gate-calls)" "make calls"

  return 0
}

function test-quality-gate-runs-the-gates-after-an-untracked-file-changes-content() {

  # Arrange
  gate-create-repo
  printf 'draft\n' > notes.md
  gate-start-turn
  printf 'edited\n' > notes.md
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-equal "$LINT_CALL"$'\n'"$TEST_CALL" "$(gate-calls)" "make calls"

  return 0
}

function test-quality-gate-runs-the-gates-with-untracked-links() {

  # Arrange
  gate-create-repo
  mkdir -p "$TEST_TMP/elsewhere"
  ln -s does-not-exist dangling-link
  ln -s "$TEST_TMP/elsewhere" directory-link
  gate-start-turn
  printf 'two\n' >> README.md
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal '{}' "$TEST_STDOUT" "hook output"
  assert-equal "$LINT_CALL"$'\n'"$TEST_CALL" "$(gate-calls)" "make calls"

  return 0
}

function test-quality-gate-detects-a-changed-link-target() {

  # Arrange
  gate-create-repo
  printf 'same\n' > target-a.txt
  printf 'same\n' > target-b.txt
  ln -s target-a.txt link
  gate-start-turn
  ln -sfn target-b.txt link
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-equal "$LINT_CALL"$'\n'"$TEST_CALL" "$(gate-calls)" "make calls"

  return 0
}

function test-quality-gate-detects-a-mode-change() {

  # Arrange
  gate-create-repo
  printf 'two\n' >> README.md
  gate-start-turn
  chmod +x README.md
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-equal "$LINT_CALL"$'\n'"$TEST_CALL" "$(gate-calls)" "make calls"

  return 0
}

function test-quality-gate-runs-every-gate-when-the-tree-cannot-be-read() {

  # Arrange
  gate-create-repo
  if [[ $EUID -eq 0 ]]; then
    echo "skipped: root can read a file without read permission"
    return 0
  fi
  gate-start-turn
  printf 'secret\n' > unreadable.txt
  chmod 000 unreadable.txt
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDOUT" "The working tree could not be read, so the hook ran every enabled gate."
  assert-equal "$LINT_CALL"$'\n'"$TEST_CALL" "$(gate-calls)" "make calls"

  return 0
}

function test-quality-gate-runs-every-gate-when-the-tree-could-not-be-read-at-the-start() {

  # Arrange
  gate-create-repo
  if [[ $EUID -eq 0 ]]; then
    echo "skipped: root can read a file without read permission"
    return 0
  fi
  printf 'secret\n' > unreadable.txt
  chmod 000 unreadable.txt
  gate-start-turn
  chmod 600 unreadable.txt
  gate-start-turn
  printf 'two\n' >> README.md
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-contains "$TEST_STDOUT" "The working tree could not be read at the start of the turn, so the hook ran every enabled gate."
  assert-equal "$LINT_CALL"$'\n'"$TEST_CALL" "$(gate-calls)" "make calls"

  return 0
}

function test-quality-gate-runs-every-gate-when-a-directory-cannot-be-read() {

  # Arrange
  gate-create-repo
  if [[ $EUID -eq 0 ]]; then
    echo "skipped: root can read a directory without read permission"
    return 0
  fi
  gate-start-turn
  mkdir secret
  printf 'x\n' > secret/a.txt
  chmod 000 secret
  # Act
  test-capture gate-send "$(gate-stop-json)"
  chmod 700 secret
  # Assert
  assert-contains "$TEST_STDOUT" "The working tree could not be read, so the hook ran every enabled gate."
  assert-equal "$LINT_CALL"$'\n'"$TEST_CALL" "$(gate-calls)" "make calls"

  return 0
}

function test-quality-gate-sees-changes-inside-a-nested-repository() {

  # Arrange
  gate-create-repo
  git init -q -b main nested
  printf 'one\n' > nested/file.txt
  git -C nested add file.txt
  git -C nested commit -q -m nested
  printf 'two\n' >> nested/file.txt
  gate-start-turn
  printf 'three\n' >> nested/file.txt
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-equal "$LINT_CALL"$'\n'"$TEST_CALL" "$(gate-calls)" "make calls"
  assert-file-not-exists nested/.git/quality-gate

  return 0
}

function test-quality-gate-works-when-the-temporary-directory-is-unusable() {

  # Arrange
  gate-create-repo
  gate-make "$FAILING_LINT"
  gate-start-turn
  printf 'two\n' >> README.md
  export TMPDIR="$TEST_TMP/missing"
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-contains "$TEST_STDOUT" '"decision":"block"'
  assert-equal "" "$(find .git/quality-gate -name 'tmp.*')" "temporary files left behind"

  return 0
}

function test-quality-gate-runs-every-gate-and-says-why-without-a-baseline() {

  # Arrange
  gate-create-repo
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDOUT" "No baseline was recorded for this turn, so the hook ran every enabled gate."
  assert-equal "$LINT_CALL"$'\n'"$TEST_CALL" "$(gate-calls)" "make calls"

  return 0
}

function test-quality-gate-runs-every-gate-without-a-session-id() {

  # Arrange
  gate-create-repo
  # Act
  test-capture gate-send '{"hook_event_name":"Stop"}'
  # Assert
  assert-contains "$TEST_STDOUT" "No baseline was recorded for this turn, so the hook ran every enabled gate."
  assert-equal "$LINT_CALL"$'\n'"$TEST_CALL" "$(gate-calls)" "make calls"

  return 0
}

function test-quality-gate-treats-an-unsafe-session-id-as-missing() {

  # Arrange
  gate-create-repo
  gate-start-turn '../evil'
  printf 'two\n' >> README.md
  # Act
  test-capture gate-send "$(gate-stop-json '../evil')"
  # Assert
  assert-contains "$TEST_STDOUT" "No baseline was recorded for this turn, so the hook ran every enabled gate."
  assert-file-not-exists .git/evil.baseline
  assert-file-not-exists .git/quality-gate/../evil.baseline
  assert-equal "" "$(find .git -name '*evil*')" "files created for the unsafe id"

  return 0
}

function test-quality-gate-keeps-a-baseline-per-session() {

  # Arrange
  gate-create-repo
  gate-start-turn session-a
  printf 'two\n' >> README.md
  gate-start-turn session-b
  # Act
  test-capture gate-send "$(gate-stop-json session-b)"
  # Assert
  assert-stub-not-called make
  # Act
  test-capture gate-send "$(gate-stop-json session-a)"
  # Assert
  assert-equal "$LINT_CALL"$'\n'"$TEST_CALL" "$(gate-calls)" "make calls"

  return 0
}

# A subagent's prompt arrives with its parent's session, and so does the next
# prompt after a cancelled turn, whose stop never came.
function test-quality-gate-keeps-the-baseline-when-another-prompt-arrives-mid-turn() {

  # Arrange
  gate-create-repo
  gate-start-turn
  printf 'two\n' >> README.md
  gate-start-turn
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-equal "$LINT_CALL"$'\n'"$TEST_CALL" "$(gate-calls)" "make calls"
  assert-contains "$(< .git/quality-gate/last-run.json)" '"event":"Stop"'

  return 0
}

function test-quality-gate-records-the-time-of-the-last-hook-and-run-in-utc() {

  # Arrange
  local file
  gate-create-repo
  export TZ=Asia/Kolkata
  gate-start-turn
  printf 'two\n' >> README.md
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  for file in .git/quality-gate/last-hook.json .git/quality-gate/last-run.json; do
    assert-matches "$(jq -r '.time' "$file")" '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$' "time in $file"
    jq -e '(.time | fromdate) - now | fabs < 60' "$file" > /dev/null ||
      { echo "ASSERTION FAILED: time in $file is not the current UTC time" >&2; return 1; }
  done

  return 0
}

function test-quality-gate-starts-a-new-turn-after-the-agent-finishes() {

  # Arrange
  gate-create-repo
  gate-start-turn
  printf 'two\n' >> README.md
  test-capture gate-send "$(gate-stop-json)"
  assert-file-not-exists ".git/quality-gate/$SESSION.baseline"
  printf 'three\n' >> README.md
  gate-start-turn
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-equal '{}' "$TEST_STDOUT" "hook output"
  assert-equal 2 "$(gate-calls | wc -l | tr -d ' ')" "make calls after both turns"

  return 0
}

function test-quality-gate-ignores-subagent-events() {

  # Arrange
  gate-create-repo
  # Act
  test-capture gate-send "{\"hook_event_name\":\"UserPromptSubmit\",\"session_id\":\"$SESSION\",\"agent_id\":\"sub-1\",\"prompt\":\"x\"}"
  printf 'two\n' >> README.md
  # Assert
  assert-equal '{}' "$TEST_STDOUT" "subagent prompt output"
  assert-file-not-exists ".git/quality-gate/$SESSION.baseline"
  # Act
  test-capture gate-send "{\"hook_event_name\":\"Stop\",\"session_id\":\"$SESSION\",\"agent_id\":\"sub-1\",\"stop_hook_active\":false}"
  # Assert
  assert-equal '{}' "$TEST_STDOUT" "subagent stop output"
  assert-stub-not-called make

  return 0
}

function test-quality-gate-passes-the-changed-paths-to-a-gate() {

  # Arrange
  gate-create-repo
  gate-make 'cp "$QUALITY_GATE_CHANGED_FILES" "$TEST_TMP/changed.nul"'
  gate-start-turn
  printf 'two\n' >> README.md
  printf 'new\n' > src/b.c
  printf '%s\0' README.md src/b.c > "$TEST_TMP/expected.nul"
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-files-identical "$TEST_TMP/expected.nul" "$TEST_TMP/changed.nul"

  return 0
}

function test-quality-gate-keeps-awkward-file-names-intact() {

  # Arrange
  local -a names=('with space.txt' 'notes[draft].md' 'a*b.md' '-dash.md' 'café.md' $'new\nline.md' '$(whoami).md' "quote'd.md" 'back\slash.md')
  local name
  gate-create-repo
  gate-make 'cp "$QUALITY_GATE_CHANGED_FILES" "$TEST_TMP/changed.nul"'
  gate-start-turn
  for name in "${names[@]}"; do
    printf 'x\n' > "./$name"
  done
  printf '%s\0' "${names[@]}" | LC_ALL=C sort -z > "$TEST_TMP/expected.nul"
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-files-identical "$TEST_TMP/expected.nul" "$TEST_TMP/changed.nul"

  return 0
}

function test-quality-gate-hashes-more-files-than-one-chunk() {

  # Arrange
  local i
  local -a sorted=() edited=()
  gate-create-repo
  gate-make 'cp "$QUALITY_GATE_CHANGED_FILES" "$TEST_TMP/changed.nul"'
  for ((i = 1; i <= 205; i++)); do
    printf '%s\n' "$i" > "bulk-$i.txt"
  done
  mapfile -t sorted < <(printf '%s\n' bulk-*.txt | LC_ALL=C sort)
  gate-start-turn
  # One file in each of the three chunks of 100, at their first and last positions
  for i in 0 99 100 199 200 204; do
    edited+=("${sorted[$i]}")
    printf 'changed\n' > "${sorted[$i]}"
  done
  printf '%s\0' "${edited[@]}" | LC_ALL=C sort -z > "$TEST_TMP/expected.nul"
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-files-identical "$TEST_TMP/expected.nul" "$TEST_TMP/changed.nul"

  return 0
}

function test-quality-gate-matches-paths-of-a-commit-made-during-the-turn() {

  # Arrange
  gate-create-repo
  gate-commit-file scripts/config/quality-gates.d/architecture.yaml $'version: 1\ngates:\n  - name: architecture\n    target: check-architecture\n    paths: ["src/*"]'
  gate-make 'cp "$QUALITY_GATE_CHANGED_FILES" "$TEST_TMP/changed-${*: -1}.nul"'
  gate-start-turn
  gate-commit-file src/a.c 'int changed;'
  printf 'src/a.c\0' > "$TEST_TMP/expected.nul"
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-files-identical "$TEST_TMP/expected.nul" "$TEST_TMP/changed-check-architecture.nul"

  return 0
}

function test-quality-gate-runs-every-gate-when-the-first-commit-is-made-during-the-turn() {

  # Arrange
  local repo="$TEST_TMP/empty"
  git init -q -b main "$repo"
  mkdir -p "$repo/scripts/quality" "$repo/scripts/config"
  cp "$TEST_REPO_ROOT/scripts/quality/quality-gate.jq" "$repo/scripts/quality/"
  cp "$TEST_REPO_ROOT/scripts/config/quality-gates.yaml" "$repo/scripts/config/"
  ln -s "$TEST_REPO_ROOT/scripts/quality/quality-gate.sh" "$repo/scripts/quality/quality-gate.sh"
  test-isolate-path jq yq readlink
  test-stub make
  cd "$repo"
  printf 'one\n' > README.md
  gate-start-turn
  git add README.md scripts/config
  git commit -q -m first
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDOUT" "This turn changed quality gate files (scripts/config/quality-gates.yaml). No commit held the gate list when the turn started, so the hook used the working tree. Review that change."
  assert-equal "$LINT_CALL"$'\n'"$TEST_CALL" "$(gate-calls)" "make calls"

  return 0
}

function test-quality-gate-matches-path-globs() {

  # Arrange
  local file
  gate-create-glob-repo
  # Act and assert
  for file in schema.json a/b/schema.json docs/x/y.md docs/y.md 'lib/[x]1.py'; do
    gate-start-turn
    printf 'edit\n' >> "$file"
    test-capture gate-send "$(gate-stop-json)"
    assert-contains "$(gate-calls)" '--no-print-directory check-schema' "make calls after editing $file"
    : > "$STUB_DIR/make.calls"
  done

  return 0
}

function test-quality-gate-does-not-match-paths-outside-the-globs() {

  # Arrange
  local file
  gate-create-glob-repo
  # Act and assert
  for file in other.txt xschema.json docsy.md docs/y.txt lib/x1.py 'lib/[x]10.py'; do
    gate-start-turn
    printf 'edit\n' >> "$file"
    test-capture gate-send "$(gate-stop-json)"
    assert-not-contains "$(gate-calls)" "check-schema" "make calls after editing $file"
    assert-contains "$(gate-calls)" "$LINT_CALL"
    : > "$STUB_DIR/make.calls"
  done

  return 0
}

# Create the scratch repository with a 'schema' gate whose paths are globs.
function gate-create-glob-repo() {

  gate-create-repo
  gate-commit-file scripts/config/quality-gates.d/schema.yaml $'version: 1\ngates:\n  - name: schema\n    target: check-schema\n    paths: ["**/schema.json", "docs/**/*.md", "lib/[x]?.py"]'
  mkdir -p a/b docs/x lib

  return 0
}

# A Linux file name need not be valid UTF-8, and in a UTF-8 locale a regular
# expression's '.' does not match such a byte.
function test-quality-gate-matches-file-names-that-are-not-utf-8() {

  # Arrange
  local name
  name="docs/caf$(printf '\351').md"
  gate-create-repo
  gate-commit-file scripts/config/quality-gates.d/docs.yaml $'version: 1\ngates:\n  - name: docs\n    target: check-docs\n    paths: ["docs/**/*.md"]'
  mkdir -p docs
  gate-start-turn
  if ! { printf 'x\n' > "$name"; } 2> /dev/null; then
    echo "skipped: this file system accepts only UTF-8 file names"
    return 0
  fi
  export LC_ALL=C.UTF-8
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-contains "$(gate-calls)" '--no-print-directory check-docs'

  return 0
}

# ==============================================================================
# Blocking and the report

function test-quality-gate-blocks-with-valid-output-for-both-harnesses() {

  # Arrange
  local reason
  gate-create-repo
  gate-make "$FAILING_LINT"
  gate-start-turn
  printf 'two\n' >> README.md
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal 1 "$(jq -s 'length' <<< "$TEST_STDOUT")" "JSON documents on stdout"
  jq -e '.decision == "block" and .hookSpecificOutput.hookEventName == "Stop" and .hookSpecificOutput.decision == "block" and .hookSpecificOutput.reason == .reason' <<< "$TEST_STDOUT" > /dev/null
  reason="$(jq -r '.reason' <<< "$TEST_STDOUT")"
  assert-contains "$reason" "== lint (make lint) failed with exit status 1 =="
  assert-contains "$reason" "lint finding on line 7"
  assert-contains "$reason" "Rerun: make lint"
  assert-contains "$reason" "Full log: .git/quality-gate/logs/$SESSION/lint.log"
  assert-contains "$(jq -r '.systemMessage' <<< "$TEST_STDOUT")" "Quality gate blocked the stop: lint"
  assert-not-contains "$(jq -r '.systemMessage' <<< "$TEST_STDOUT")" "warning only"

  return 0
}

function test-quality-gate-runs-the-remaining-gates-after-a-failure() {

  # Arrange
  gate-create-repo
  gate-make "$FAILING_LINT"
  gate-start-turn
  printf 'two\n' >> README.md
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-equal "$LINT_CALL"$'\n'"$TEST_CALL" "$(gate-calls)" "make calls"

  return 0
}

function test-quality-gate-blocks-once-then-lets-the-agent-finish() {

  # Arrange
  gate-create-repo
  gate-make "$FAILING_LINT"
  gate-start-turn
  printf 'two\n' >> README.md
  test-capture gate-send "$(gate-stop-json)"
  # Act
  test-capture gate-send "$(gate-stop-json "$SESSION" true)"
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDOUT" "already blocked 1 time(s)"
  assert-not-contains "$TEST_STDOUT" '"decision"'
  assert-equal 2 "$(gate-calls | wc -l | tr -d ' ')" "make calls after the second stop"

  return 0
}

function test-quality-gate-keeps-the-block-count-when-another-prompt-arrives-mid-turn() {

  # Arrange
  gate-create-repo
  gate-make "$FAILING_LINT"
  gate-start-turn
  printf 'two\n' >> README.md
  test-capture gate-send "$(gate-stop-json)"
  assert-contains "$TEST_STDOUT" '"decision":"block"'
  gate-start-turn
  printf 'three\n' >> README.md
  # Act
  test-capture gate-send "$(gate-stop-json "$SESSION" true)"
  # Assert
  assert-contains "$TEST_STDOUT" "already blocked 1 time(s)"
  assert-not-contains "$TEST_STDOUT" '"decision"'

  return 0
}

function test-quality-gate-blocks-again-after-a-cancelled-continuation() {

  # Arrange
  gate-create-repo
  gate-make "$FAILING_LINT"
  gate-start-turn
  printf 'two\n' >> README.md
  test-capture gate-send "$(gate-stop-json)"
  assert-contains "$TEST_STDOUT" '"decision":"block"'
  gate-start-turn
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-contains "$TEST_STDOUT" '"decision":"block"'

  return 0
}

function test-quality-gate-lets-the-agent-finish-without-a-session-after-a-block() {

  # Arrange
  gate-create-repo
  gate-make "$FAILING_LINT"
  # Act
  test-capture gate-send '{"hook_event_name":"Stop","stop_hook_active":true}'
  # Assert
  assert-contains "$TEST_STDOUT" "an earlier block already continued this turn"
  assert-stub-not-called make

  return 0
}

function test-quality-gate-honours-max-blocks-and-a-new-prompt-resets-it() {

  # Arrange
  gate-create-repo
  gate-commit-file scripts/config/quality-gates.d/limits.yaml $'version: 1\nmax_blocks: 2'
  gate-make "$FAILING_LINT"
  gate-start-turn
  printf 'two\n' >> README.md
  # Act
  test-capture gate-send "$(gate-stop-json)"
  assert-contains "$TEST_STDOUT" '"decision":"block"'
  test-capture gate-send "$(gate-stop-json "$SESSION" true)"
  assert-contains "$TEST_STDOUT" '"decision":"block"'
  test-capture gate-send "$(gate-stop-json "$SESSION" true)"
  # Assert
  assert-contains "$TEST_STDOUT" "already blocked 2 time(s)"
  # Act
  gate-start-turn
  printf 'three\n' >> README.md
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-contains "$TEST_STDOUT" '"decision":"block"'

  return 0
}

function test-quality-gate-reports-a-docker-prerequisite-without-blocking() {

  # Arrange
  local message
  gate-create-repo
  gate-make 'if [[ "${*: -1}" == test ]]; then echo "ERROR Docker test suite cannot run: docker is not running or is not reachable" >&2; echo "test-real-bug FAIL"; exit 1; fi'
  gate-start-turn
  printf 'two\n' >> README.md
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-not-contains "$TEST_STDOUT" '"decision"'
  message="$(jq -r '.systemMessage' <<< "$TEST_STDOUT")"
  assert-contains "$message" "test could not run (ERROR Docker test suite cannot run: docker is not running or is not reachable), so its result is unknown. Fix that, then run 'make test'"
  assert-file-not-exists ".git/quality-gate/$SESSION.baseline"

  return 0
}

function test-quality-gate-reports-the-prerequisite-marker() {

  # Arrange
  gate-create-repo
  gate-make 'if [[ "${*: -1}" == lint ]]; then echo "PREREQUISITE: install node, then run make config"; exit 3; fi'
  gate-start-turn
  printf 'two\n' >> README.md
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-not-contains "$TEST_STDOUT" '"decision"'
  assert-contains "$(jq -r '.systemMessage' <<< "$TEST_STDOUT")" "lint could not run (install node, then run make config), so its result is unknown"

  return 0
}

function test-quality-gate-tells-the-agent-about-a-gate-that-could-not-run() {

  # Arrange
  local reason
  gate-create-repo
  gate-make 'if [[ "${*: -1}" == lint ]]; then echo "lint finding"; exit 1; fi; echo "PREREQUISITE: start Docker"; exit 1'
  gate-start-turn
  printf 'two\n' >> README.md
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  reason="$(jq -r '.reason' <<< "$TEST_STDOUT")"
  assert-contains "$reason" "== lint (make lint) failed with exit status 1 =="
  assert-contains "$reason" "make test could not run (start Docker), so its result is unknown. Tell the user, do not change the environment."
  assert-not-contains "$reason" "== test (make test)"
  assert-contains "$(jq -r '.systemMessage' <<< "$TEST_STDOUT")" "test could not run (start Docker)"

  return 0
}

function test-quality-gate-keeps-the-logs-of-each-session-apart() {

  # Arrange
  local reason
  gate-create-repo
  gate-make 'if [[ "${*: -1}" == lint ]]; then echo "lint output for $LINT_OWNER"; exit 1; fi'
  gate-start-turn session-a
  gate-start-turn session-b
  printf 'two\n' >> README.md
  # Act
  export LINT_OWNER=a
  test-capture gate-send "$(gate-stop-json session-a)"
  reason="$(jq -r '.reason' <<< "$TEST_STDOUT")"
  export LINT_OWNER=b
  test-capture gate-send "$(gate-stop-json session-b)"
  # Assert
  assert-contains "$reason" "Full log: .git/quality-gate/logs/session-a/lint.log"
  assert-contains "$(< .git/quality-gate/logs/session-a/lint.log)" "lint output for a"
  assert-contains "$(< .git/quality-gate/logs/session-b/lint.log)" "lint output for b"

  return 0
}

# Another session's log directory stays empty until its first gate writes, so
# only old ones are removed.
function test-quality-gate-keeps-fresh-log-directories-of-other-sessions() {

  # Arrange
  gate-create-repo
  mkdir -p .git/quality-gate/logs/old-session .git/quality-gate/logs/busy-session
  touch -t 202001010000 .git/quality-gate/logs/old-session
  # Act
  gate-start-turn
  # Assert
  assert-file-not-exists .git/quality-gate/logs/old-session
  assert-file-exists .git/quality-gate/logs/busy-session

  return 0
}

function test-quality-gate-limits-the-size-of-the-report() {

  # Arrange
  local reason
  gate-create-repo
  gate-make 'if [[ "${*: -1}" == lint ]]; then for ((i = 1; i <= 3000; i++)); do echo "finding $i xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"; done; exit 1; fi'
  gate-start-turn
  printf 'two\n' >> README.md
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  reason="$(jq -r '.reason' <<< "$TEST_STDOUT")"
  assert-contains "$reason" "finding 3000 "
  assert-not-contains "$reason" "finding 2900 "
  [[ ${#reason} -lt 8500 ]] || { echo "ASSERTION FAILED: report has ${#reason} characters" >&2; return 1; }

  return 0
}

function test-quality-gate-shares-the-report-size-between-failing-gates() {

  # Arrange
  local reason line
  line="$(printf 'x%.0s' {1..500})"
  gate-create-repo
  gate-make "for ((i = 1; i <= 40; i++)); do echo \"\${*: -1} row \$i $line\"; done; exit 1"
  gate-start-turn
  printf 'two\n' >> README.md
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  reason="$(jq -r '.reason' <<< "$TEST_STDOUT")"
  assert-contains "$reason" "== lint (make lint) failed"
  assert-contains "$reason" "== test (make test) failed"
  assert-contains "$reason" "lint row 40 "
  assert-contains "$reason" "test row 40 "
  [[ ${#reason} -lt 8600 ]] || { echo "ASSERTION FAILED: report has ${#reason} characters" >&2; return 1; }
  assert-equal 1 "$(jq -s 'length' <<< "$TEST_STDOUT")" "JSON documents on stdout"

  return 0
}

function test-quality-gate-strips-colour-from-the-report() {

  # Arrange
  local reason
  gate-create-repo
  gate-make 'if [[ "${*: -1}" == lint ]]; then printf "\033[31mred finding\033[0m\n"; exit 1; fi'
  gate-start-turn
  printf 'two\n' >> README.md
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  reason="$(jq -r '.reason' <<< "$TEST_STDOUT")"
  assert-contains "$reason" "red finding"
  assert-not-contains "$reason" $'\033'

  return 0
}

function test-quality-gate-does-not-block-on-a-warn-gate() {

  # Arrange
  gate-create-repo
  gate-commit-file scripts/config/quality-gates.d/warn.yaml $'version: 1\ngates:\n  - name: lint\n    mode: warn'
  gate-make "$FAILING_LINT"
  gate-start-turn
  printf 'two\n' >> README.md
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDOUT" "lint did not pass (warning only)"
  assert-not-contains "$TEST_STDOUT" '"decision"'

  return 0
}

# ==============================================================================
# Configuration

function test-quality-gate-skips-a-gate-whose-paths-match-no-change() {

  # Arrange
  gate-create-repo
  gate-commit-file scripts/config/quality-gates.d/architecture.yaml $'version: 1\ngates:\n  - name: architecture\n    target: check-architecture\n    paths: ["src/*", "**/schema.json"]'
  gate-start-turn
  printf 'two\n' >> README.md
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-equal "$LINT_CALL"$'\n'"$TEST_CALL" "$(gate-calls)" "make calls for a README change"
  # Arrange
  gate-start-turn
  printf 'int b;\n' >> src/a.c
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-contains "$(gate-calls)" "--no-print-directory check-architecture"

  return 0
}

function test-quality-gate-ignores-gate-list-edits-made-during-the-turn() {

  # Arrange
  gate-create-repo
  gate-start-turn
  printf 'version: 1\ngates:\n  - name: lint\n    enabled: false\n  - name: test\n    enabled: false\n' > scripts/config/quality-gates.yaml
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-equal "$LINT_CALL"$'\n'"$TEST_CALL" "$(gate-calls)" "make calls"
  assert-contains "$TEST_STDOUT" "This turn changed quality gate files (scripts/config/quality-gates.yaml). The hook used the gate list from commit $(git rev-parse --short=7 HEAD), where the turn started. Review that change."

  return 0
}

function test-quality-gate-uses-the-gate-list-from-the-start-of-the-turn() {

  # Arrange
  local start
  gate-create-repo
  start="$(git rev-parse --short=7 HEAD)"
  gate-start-turn
  gate-commit-file scripts/config/quality-gates.d/off.yaml $'version: 1\ngates:\n  - {name: lint, enabled: false}\n  - {name: test, enabled: false}'
  printf 'two\n' >> README.md
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-equal "$LINT_CALL"$'\n'"$TEST_CALL" "$(gate-calls)" "make calls"
  assert-contains "$TEST_STDOUT" "(scripts/config/quality-gates.d/off.yaml). The hook used the gate list from commit $start"

  return 0
}

function test-quality-gate-reads-the-rules-from-the-start-of-the-turn() {

  # Arrange
  gate-create-repo
  gate-start-turn
  printf '{max_blocks: 1, gates: []}\n' > scripts/quality/quality-gate.jq
  printf 'two\n' >> README.md
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-equal "$LINT_CALL"$'\n'"$TEST_CALL" "$(gate-calls)" "make calls"
  assert-contains "$TEST_STDOUT" "This turn changed quality gate files (scripts/quality/quality-gate.jq)."

  return 0
}

function test-quality-gate-says-when-no-commit-holds-the-gate-list() {

  # Arrange
  gate-create-repo
  git rm -q --cached scripts/config/quality-gates.yaml
  git commit -q -m "untrack the gate list"
  gate-start-turn
  printf '# edited\n' >> scripts/config/quality-gates.yaml
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-equal "$LINT_CALL"$'\n'"$TEST_CALL" "$(gate-calls)" "make calls"
  assert-contains "$TEST_STDOUT" "This turn changed quality gate files (scripts/config/quality-gates.yaml). No commit held the gate list when the turn started, so the hook used the working tree. Review that change."

  return 0
}

function test-quality-gate-uses-the-start-commit-when-the-tree-could-not-be-read-at-the-start() {

  # Arrange
  gate-create-repo
  if [[ $EUID -eq 0 ]]; then
    echo "skipped: root can read a file without read permission"
    return 0
  fi
  printf 'secret\n' > unreadable.txt
  chmod 000 unreadable.txt
  gate-start-turn
  chmod 600 unreadable.txt
  gate-commit-file scripts/config/quality-gates.d/off.yaml $'version: 1\ngates:\n  - {name: lint, enabled: false}\n  - {name: test, enabled: false}'
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-equal "$LINT_CALL"$'\n'"$TEST_CALL" "$(gate-calls)" "make calls"
  assert-contains "$TEST_STDOUT" "The working tree could not be read at the start of the turn, so the hook ran every enabled gate."

  return 0
}

# The previous version wrote an empty baseline when it could not read the tree.
function test-quality-gate-reads-an-empty-baseline-as-unreadable() {

  # Arrange
  gate-create-repo
  gate-start-turn
  : > ".git/quality-gate/$SESSION.baseline"
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-contains "$TEST_STDOUT" "The working tree could not be read at the start of the turn, so the hook ran every enabled gate."
  assert-equal "$LINT_CALL"$'\n'"$TEST_CALL" "$(gate-calls)" "make calls"

  return 0
}

function test-quality-gate-names-the-gate-list-it-used-without-a-baseline() {

  # Arrange
  gate-create-repo
  gate-commit-file scripts/config/quality-gates.d/off.yaml $'version: 1\ngates:\n  - {name: test, enabled: false}'
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-equal "$LINT_CALL" "$(gate-calls)" "make calls"
  assert-contains "$TEST_STDOUT" "No baseline was recorded for this turn, so the hook ran every enabled gate. The hook could not tell where the turn started, so it used the gate list from commit $(git rev-parse --short=7 HEAD)."

  return 0
}

function test-quality-gate-applies-a-committed-drop-in() {

  # Arrange
  gate-create-repo
  gate-commit-file scripts/config/quality-gates.d/project.yaml $'version: 1\ngates:\n  - name: test\n    enabled: false'
  gate-start-turn
  printf 'two\n' >> README.md
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-equal "$LINT_CALL" "$(gate-calls)" "make calls"

  return 0
}

# Byte order puts B.yaml before a.yaml, whereas many locales sort them the other
# way round, and a dot file is never read.
function test-quality-gate-reads-drop-ins-in-byte-order() {

  # Arrange
  gate-create-repo
  gate-make "$FAILING_LINT"
  mkdir -p scripts/config/quality-gates.d
  printf 'version: 1\ngates:\n  - {name: lint, mode: warn}\n' > scripts/config/quality-gates.d/B.yaml
  printf 'version: 1\ngates:\n  - {name: lint, mode: block}\n' > scripts/config/quality-gates.d/a.yaml
  printf 'version: 1\ngates:\n  - {name: lint, enabled: false}\n' > scripts/config/quality-gates.d/.off.yaml
  git add -A
  git commit -q -m drop-ins
  export LC_ALL=en_US.UTF-8
  # Act
  test-capture "$SCRIPT" list
  # Assert
  assert-matches "$TEST_STDOUT" 'lint +lint +block '
  # Act
  gate-start-turn
  printf 'two\n' >> README.md
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-contains "$TEST_STDOUT" '"decision":"block"'

  return 0
}

function test-quality-gate-warns-about-an-invalid-committed-configuration() {

  # Arrange
  gate-create-repo
  gate-commit-file scripts/config/quality-gates.d/bad.yaml $'version: 1\nmax_blocks: 9'
  gate-start-turn
  printf 'two\n' >> README.md
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDOUT" "no gate ran"
  assert-contains "$TEST_STDOUT" "max_blocks must be a whole number from 1 to 5"
  assert-stub-not-called make

  return 0
}

# Assert that a gate list is rejected with a message.
# Arguments:
#   $1=[YAML of the gate list] $2=[text the message contains]
function gate-assert-invalid() {

  printf '%b' "$1" > scripts/config/quality-gates.yaml
  test-capture "$SCRIPT" list
  assert-equal 2 "$TEST_STATUS" "$EXIT_STATUS_LABEL for: $1"
  assert-contains "$TEST_STDERR" "$2"
  assert-not-contains "$TEST_STDERR" "jq: error"

  return 0
}

function test-quality-gate-rejects-invalid-gate-configuration() {

  # Arrange
  gate-create-repo
  # Act and assert
  gate-assert-invalid 'version: 1\ngates:\n  - {name: a, target: "-rf"}\n' "target must be a Make target name"
  gate-assert-invalid 'version: 1\ngates:\n  - {name: a, target: "a b"}\n' "target must be a Make target name"
  gate-assert-invalid 'version: 1\ngates:\n  - {name: a, target: lint, cmd: x}\n' "unknown key(s): cmd"
  gate-assert-invalid 'version: 1\ngates:\n  - {name: a, target: lint, stages: [stop]}\n' "unknown key(s): stages"
  gate-assert-invalid 'version: 1\ngates:\n  - {name: a, target: lint, timeout: 0}\n' "timeout must be a whole number of seconds from 1 to 1800"
  gate-assert-invalid 'version: 1\ngates:\n  - {name: a, target: lint, mode: maybe}\n' "mode must be block or warn"
  gate-assert-invalid 'version: 1\ngates:\n  - {name: "Bad Name", target: lint}\n' "gate name must match"
  gate-assert-invalid 'version: 1\ngates:\n  - {name: a, target: lint, paths: [""]}\n' "paths must be a list of non-empty globs"
  gate-assert-invalid 'version: 1\ngates:\n  - {name: a, target: lint, description: {owner: me}}\n' "description must be text"
  gate-assert-invalid 'version: 1\nmax_blocks: 1.5\n' "max_blocks must be a whole number from 1 to 5"
  gate-assert-invalid 'version: 2\n' "version must be 1"
  gate-assert-invalid 'version: 1\nowner: me\n' "unknown key(s): owner"
  gate-assert-invalid 'version: 1\ngates:\n  - {name: a}\n' "target must be a Make target name"
  gate-assert-invalid 'version: [\n' "is not valid YAML"

  return 0
}

# Git and macOS may store a non-ASCII name in different Unicode forms, which
# would order drop-ins differently in a commit and in the working tree.
function test-quality-gate-rejects-drop-in-names-that-are-not-plain-ascii() {

  # Arrange
  local name
  name="scripts/config/quality-gates.d/caf$(printf '\303\251').yaml"
  gate-create-repo
  gate-commit-file "$name" $'version: 1\ngates:\n  - {name: test, enabled: false}'
  # Act
  test-capture "$SCRIPT" list
  # Assert
  assert-equal 2 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "drop-in file names may use only ASCII letters, digits, '.', '_' and '-'"
  # Act
  gate-start-turn
  printf 'two\n' >> README.md
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-contains "$TEST_STDOUT" "no gate ran"
  assert-stub-not-called make

  return 0
}

function test-quality-gate-accepts-whole-numbers-written-as-decimals() {

  # Arrange
  gate-create-repo
  gate-commit-file scripts/config/quality-gates.d/numbers.yaml $'version: 1\nmax_blocks: 2.0\ngates:\n  - {name: lint, timeout: 1.2e2}\n  - {name: test, timeout: 120.0}'
  gate-make "$FAILING_LINT"
  gate-start-turn
  printf 'two\n' >> README.md
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-contains "$TEST_STDOUT" '"decision":"block"'
  assert-equal "" "$TEST_STDERR" "stderr"
  # Act
  test-capture gate-send "$(gate-stop-json "$SESSION" true)"
  # Assert
  assert-contains "$TEST_STDOUT" '"decision":"block"' "second stop"
  # Act
  test-capture gate-send "$(gate-stop-json "$SESSION" true)"
  # Assert
  assert-contains "$TEST_STDOUT" "already blocked 2 time(s)"
  # Act
  test-capture "$SCRIPT" list
  # Assert
  assert-matches "$TEST_STDOUT" 'lint +lint +block +120s '
  assert-matches "$TEST_STDOUT" 'test +test +block +120s '

  return 0
}

# Rules read from the start of the turn may predate the script, so the script
# turns their numbers into whole numbers itself.
function test-quality-gate-copes-with-rules-that-print-decimals() {

  # Arrange
  gate-create-repo
  gate-commit-file scripts/quality/quality-gate.jq '{max_blocks: 2.0, gates: [{name: "lint", target: "lint", mode: "block", timeout: 120.0, paths: [], description: ""}]}'
  gate-make "$FAILING_LINT"
  gate-start-turn
  printf 'two\n' >> README.md
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-contains "$TEST_STDOUT" '"decision":"block"'
  assert-equal "" "$TEST_STDERR" "stderr"
  # Act
  test-capture gate-send "$(gate-stop-json "$SESSION" true)"
  # Assert
  assert-contains "$TEST_STDOUT" '"decision":"block"' "second stop"
  # Act
  test-capture gate-send "$(gate-stop-json "$SESSION" true)"
  # Assert
  assert-contains "$TEST_STDOUT" "already blocked 2 time(s)"

  return 0
}

# A tool may warn on stderr, for example about the locale, and the warning must
# not end up in the configuration JSON.
function test-quality-gate-ignores-warnings-while-reading-the-configuration() {

  # Arrange
  gate-create-repo
  test-stub yq 'echo "yq: a warning" >&2; exec "$TEST_TMP/.bin/yq" "$@"'
  gate-make "$FAILING_LINT"
  gate-start-turn
  printf 'two\n' >> README.md
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-contains "$TEST_STDOUT" '"decision":"block"'
  # Act
  test-capture "$SCRIPT" list
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-matches "$TEST_STDOUT" 'lint +lint +block +120s '

  return 0
}

# ==============================================================================
# Time limits

function test-quality-gate-times-out-a-gate-and-stops-its-process-group() {

  # Arrange
  local pid
  gate-create-repo
  gate-commit-file scripts/config/quality-gates.d/short.yaml "$SHORT_LINT_GATE"
  gate-make 'if [[ "${*: -1}" == lint ]]; then echo $$ > "$TEST_TMP/pid"; sleep 30; fi'
  gate-start-turn
  printf 'two\n' >> README.md
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-contains "$(jq -r '.reason' <<< "$TEST_STDOUT")" "== lint (make lint) timed out after "
  pid="$(< "$TEST_TMP/pid")"
  ! kill -0 "$pid" 2> /dev/null || { echo "ASSERTION FAILED: gate process $pid is still running" >&2; return 1; }

  return 0
}

function test-quality-gate-stops-processes-a-gate-started() {

  # Arrange
  local child started
  gate-create-repo
  gate-commit-file scripts/config/quality-gates.d/short.yaml "$SHORT_LINT_GATE"
  gate-make 'if [[ "${*: -1}" == lint ]]; then sleep 300 & echo $! > "$TEST_TMP/child"; wait; fi'
  gate-start-turn
  printf 'two\n' >> README.md
  started=$SECONDS
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-contains "$(jq -r '.reason' <<< "$TEST_STDOUT")" "timed out after"
  [[ $((SECONDS - started)) -lt 12 ]] || { echo "ASSERTION FAILED: the hook waited for the gate's child" >&2; return 1; }
  child="$(< "$TEST_TMP/child")"
  ! kill -0 "$child" 2> /dev/null || { echo "ASSERTION FAILED: gate child $child is still running" >&2; return 1; }

  return 0
}

# Every gate process gets TERM before KILL, so it can clean up.
function test-quality-gate-lets-the-processes-of-a-stopped-gate-clean-up() {

  # Arrange
  gate-create-repo
  gate-commit-file scripts/config/quality-gates.d/short.yaml "$SHORT_LINT_GATE"
  cat > "$TEST_TMP/child.sh" << 'EOF'
#!/usr/bin/env bash
trap 'touch "$TEST_TMP/child-cleaned"; exit 0' TERM
sleep 300 &
wait
EOF
  chmod +x "$TEST_TMP/child.sh"
  gate-make 'if [[ "${*: -1}" == lint ]]; then "$TEST_TMP/child.sh" & wait; fi'
  gate-start-turn
  printf 'two\n' >> README.md
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-contains "$(jq -r '.reason' <<< "$TEST_STDOUT")" "timed out after"
  assert-file-exists "$TEST_TMP/child-cleaned"

  return 0
}

# The editor stops a hook that runs too long or a turn the user cancels.
function test-quality-gate-stops-the-running-gate-when-the-hook-is-stopped() {

  # Arrange
  local hook gate i
  gate-create-repo
  gate-make 'if [[ "${*: -1}" == lint ]]; then echo $$ > "$TEST_TMP/gate.pid"; sleep 30; fi'
  gate-start-turn
  printf 'two\n' >> README.md
  gate-stop-json > "$TEST_TMP/stop.json"
  "$SCRIPT" hook < "$TEST_TMP/stop.json" > "$TEST_TMP/hook.out" 2>&1 &
  hook=$!
  for ((i = 0; i < 100; i++)); do
    [[ ! -s $TEST_TMP/gate.pid ]] || break
    sleep 0.1
  done
  assert-file-exists "$TEST_TMP/gate.pid"
  gate="$(< "$TEST_TMP/gate.pid")"
  # Act
  kill -TERM "$hook"
  wait "$hook" || true
  for ((i = 0; i < 50; i++)); do
    kill -0 "$gate" 2> /dev/null || break
    sleep 0.1
  done
  # Assert
  if kill -0 "$gate" 2> /dev/null; then
    kill -KILL -- "-$gate" 2> /dev/null || true
    echo "ASSERTION FAILED: gate process $gate is still running after the hook was stopped" >&2
    return 1
  fi

  return 0
}

function test-quality-gate-reads-a-budget-with-leading-zeros-as-decimal() {

  # Arrange
  gate-create-repo
  gate-make "$FAILING_LINT"
  gate-start-turn
  printf 'two\n' >> README.md
  export QUALITY_GATE_BUDGET=090
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-contains "$TEST_STDOUT" '"decision":"block"'
  assert-equal "" "$TEST_STDERR" "stderr"

  return 0
}

function test-quality-gate-reports-gates-the-time-budget-did-not-allow() {

  # Arrange
  gate-create-repo
  gate-make 'if [[ "${*: -1}" == lint ]]; then sleep 30; fi'
  gate-start-turn
  printf 'two\n' >> README.md
  export QUALITY_GATE_BUDGET=4
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDOUT" "lint did not finish within the time budget"
  assert-contains "$TEST_STDOUT" "test was not run, the time budget was used up"
  assert-not-contains "$TEST_STDOUT" '"decision"'

  return 0
}

function test-quality-gate-names-the-missing-tool() {

  # Arrange
  gate-create-repo
  rm -f "$TEST_TMP/.bin/jq"
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "the quality gate cannot run jq, run 'mise trust' and 'make config'"
  assert-equal "" "$TEST_STDOUT" "stdout"

  return 0
}

function test-quality-gate-names-yq-when-it-cannot-run() {

  # Arrange
  gate-create-repo
  rm -f "$TEST_TMP/.bin/yq"
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "the quality gate cannot run yq, run 'mise trust' and 'make config'"
  assert-equal "" "$TEST_STDOUT" "stdout"

  return 0
}

function test-quality-gate-fails-when-a-mise-shim-cannot-run-a-tool() {

  # Arrange
  local shims="$TEST_TMP/shims"
  gate-create-repo
  mkdir -p "$shims"
  printf '#!/usr/bin/env bash\necho "mise ERROR Config files are not trusted." >&2\nexit 1\n' > "$shims/jq"
  chmod +x "$shims/jq"
  test-stub mise "printf 'export PATH=\"%s:\$PATH\"\\n' '$shims'"
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "the quality gate cannot run jq"
  assert-equal "" "$TEST_STDOUT" "stdout"
  assert-stub-called mise 'activate bash --shims'

  return 0
}

# The Python 'yq' wraps jq and cannot read YAML the way mikefarah yq 4 does.
function test-quality-gate-needs-mikefarah-yq() {

  # Arrange
  gate-create-repo
  test-stub yq 'echo "yq 3.4.3"'
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "the quality gate needs mikefarah yq version 4, run 'mise trust' and 'make config'"
  assert-equal "" "$TEST_STDOUT" "stdout"

  return 0
}

# ==============================================================================
# Pause

function test-quality-gate-pauses-from-the-next-prompt-and-resumes() {

  # Arrange
  gate-create-repo
  # Act
  test-capture env hours=2 "$SCRIPT" pause
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDOUT" "Quality gate paused from the next prompt until"
  # Act
  gate-start-turn
  printf 'two\n' >> README.md
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-contains "$TEST_STDOUT" "Quality gate is paused until"
  assert-contains "$TEST_STDOUT" "make quality-gate-resume"
  assert-stub-not-called make
  # Act
  test-capture "$SCRIPT" resume
  gate-start-turn
  printf 'three\n' >> README.md
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-equal "$LINT_CALL"$'\n'"$TEST_CALL" "$(gate-calls)" "make calls"

  return 0
}

function test-quality-gate-ignores-a-pause-made-during-the-turn() {

  # Arrange
  gate-create-repo
  gate-make "$FAILING_LINT"
  gate-start-turn
  touch -t 202001010000 ".git/quality-gate/$SESSION.baseline"
  printf 'two\n' >> README.md
  test-capture env hours=8 "$SCRIPT" pause
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-contains "$TEST_STDOUT" '"decision":"block"'
  assert-contains "$(jq -r '.systemMessage' <<< "$TEST_STDOUT")" "The gate was paused during this turn, so the pause applies from the next prompt."

  return 0
}

function test-quality-gate-removes-an-expired-pause() {

  # Arrange
  gate-create-repo
  gate-start-turn
  printf 'two\n' >> README.md
  printf '%s\n' "$(( $(date +%s) - 10 ))" > .git/quality-gate/paused
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-file-not-exists .git/quality-gate/paused
  assert-equal "$LINT_CALL"$'\n'"$TEST_CALL" "$(gate-calls)" "make calls"

  return 0
}

function test-quality-gate-rejects-an-out-of-range-pause() {

  # Arrange
  local hours
  gate-create-repo
  # Act and assert
  for hours in 0 9 abc 1.5 -1 ' 2'; do
    test-capture env hours="$hours" "$SCRIPT" pause
    assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL for hours='$hours'"
    assert-contains "$TEST_STDERR" "hours must be a whole number from 1 to 8"
  done
  assert-file-not-exists .git/quality-gate/paused

  return 0
}

# ==============================================================================
# Privacy

function test-quality-gate-never-stores-or-prints-the-prompt() {

  # Arrange
  gate-create-repo
  export VERBOSE=true
  # Act
  test-capture gate-send "$(gate-prompt-json)"
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-not-contains "$TEST_STDOUT" "PROMPT-MARKER-4711"
  assert-not-contains "$TEST_STDERR" "PROMPT-MARKER-4711"
  assert-equal "" "$(grep -rl 'PROMPT-MARKER-4711' .git 2> /dev/null || true)" "state files that hold the prompt"

  return 0
}

# ==============================================================================
# Commands for developers

function test-quality-gate-run-runs-every-gate() {

  # Arrange
  gate-create-repo
  # Act
  test-capture "$SCRIPT" run
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "$LINT_CALL"$'\n'"$TEST_CALL" "$(gate-calls)" "make calls"
  assert-contains "$TEST_STDOUT" "PASS   lint"
  assert-contains "$TEST_STDOUT" "PASS   test"

  return 0
}

function test-quality-gate-run-fails-when-a-gate-fails() {

  # Arrange
  gate-create-repo
  gate-make "$FAILING_LINT"
  # Act
  test-capture "$SCRIPT" run
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDOUT" "FAIL   lint"
  assert-contains "$TEST_STDOUT" "PASS   test"

  return 0
}

function test-quality-gate-run-fails-when-a-gate-cannot-run() {

  # Arrange
  gate-create-repo
  gate-make 'if [[ "${*: -1}" == lint ]]; then echo "PREREQUISITE: start Docker"; exit 1; fi'
  # Act
  test-capture "$SCRIPT" run
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-matches "$TEST_STDOUT" 'lint +prerequisite +make lint'

  return 0
}

function test-quality-gate-run-rejects-an-unknown-scope() {

  # Arrange
  gate-create-repo
  # Act
  test-capture env scope=everything "$SCRIPT" run
  # Assert
  assert-equal 126 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "Unrecognised scope: 'everything'. Use one of: changed, all"
  assert-stub-not-called make

  return 0
}

function test-quality-gate-run-refuses-to-run-inside-a-gate() {

  # Arrange
  gate-create-repo
  # Act
  test-capture env QUALITY_GATE_ACTIVE=1 "$SCRIPT" run
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "running inside a gate"
  assert-stub-not-called make

  return 0
}

function test-quality-gate-lists-the-gates() {

  # Arrange
  gate-create-repo
  # Act
  test-capture "$SCRIPT" list
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-matches "$TEST_STDOUT" 'NAME +TARGET +MODE +TIMEOUT +PATHS +DESCRIPTION'
  assert-matches "$TEST_STDOUT" 'lint +lint +block +120s +all'
  assert-matches "$TEST_STDOUT" 'test +test +block +240s +all'

  return 0
}

function test-quality-gate-reruns-itself-with-a-newer-bash() {

  # Arrange
  gate-create-repo
  if [[ ! -x /bin/bash ]] || [[ "$(/bin/bash -c 'echo "${BASH_VERSINFO[0]}"')" -ge 5 ]]; then
    echo "skipped: /bin/bash is already Bash 5 or later on this host"
    return 0
  fi
  gate-make "$FAILING_LINT"
  # Act
  test-capture /bin/bash "$SCRIPT" list
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDOUT" "NAME"
  # Act
  gate-send-with-old-bash "$(gate-prompt-json)" > /dev/null
  printf 'two\n' >> README.md
  test-capture gate-send-with-old-bash "$(gate-stop-json)"
  # Assert
  assert-contains "$TEST_STDOUT" '"decision":"block"'
  assert-equal "$LINT_CALL"$'\n'"$TEST_CALL" "$(gate-calls)" "make calls"

  return 0
}

# Send a hook event to the script started by macOS /bin/bash 3.2, as an editor
# whose PATH finds that Bash first would.
# Arguments:
#   $1=[event JSON]
function gate-send-with-old-bash() {

  printf '%s' "$1" | /bin/bash "$SCRIPT" hook

  return 0
}

# ==============================================================================
# Registration

function test-quality-gate-registers-both-hook-events() {

  # Arrange
  local hooks="$TEST_REPO_ROOT/.github/hooks/quality-gate.json"
  # Act and assert
  assert-equal 1 "$(jq -r '.version' "$hooks")" "hook file version"
  assert-equal "./scripts/quality/quality-gate.sh hook" "$(jq -r '.hooks.UserPromptSubmit[0].command' "$hooks")" "UserPromptSubmit command"
  assert-equal "./scripts/quality/quality-gate.sh hook" "$(jq -r '.hooks.Stop[0].command' "$hooks")" "Stop command"
  assert-equal 2 "$(jq '.hooks | length' "$hooks")" "registered events"
  assert-equal "" "$(jq -r '[.. | objects | select(has("timeout"))] | length | select(. > 0)' "$hooks")" "entries using 'timeout' instead of 'timeoutSec'"
  jq -e '.hooks.Stop[0].timeoutSec > 240 and .hooks.UserPromptSubmit[0].timeoutSec >= 10' "$hooks" > /dev/null

  return 0
}

function test-quality-gate-pre-commit-runs-make-test-last() {

  # Arrange
  local config="$TEST_REPO_ROOT/scripts/config/pre-commit.yaml"
  # Act and assert
  assert-equal "make test" "$(yq -r '.repos[-1].hooks[0].entry' "$config")" "last hook entry"
  assert-equal true "$(yq -r '.repos[-1].hooks[0].always_run' "$config")" "always_run"
  assert-equal false "$(yq -r '.repos[-1].hooks[0].pass_filenames' "$config")" "pass_filenames"

  return 0
}

function test-quality-gate-default-configuration-is-valid() {

  # Arrange
  gate-create-repo
  # Act
  test-capture "$SCRIPT" list
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal 3 "$(wc -l <<< "$TEST_STDOUT" | tr -d ' ')" "lines of the gate list"

  return 0
}

# ==============================================================================

main "$@"

exit 0
