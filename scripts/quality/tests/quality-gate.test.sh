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
# Time limits count whole seconds, so a limit of 2 gives the gate at least a
# second to start its processes
readonly SHORT_LINT_GATE=$'version: 1\ngates:\n  - name: lint\n    timeout: 2'
# The prompt text is a marker the tests look for
readonly PROMPT_JSON_FORMAT='{"hook_event_name":"UserPromptSubmit","session_id":"%s","prompt":"PROMPT-MARKER-4711"}'

# Set up the suite fixtures and run every test.
function main() {

  cd "$(git rev-parse --show-toplevel)"
  source ./scripts/tests/test.lib.sh

  # The caller's options must not reach the script under test
  unset -v scope hours QUALITY_GATE_BUDGET QUALITY_GATE_ACTIVE GITHUB_ACTIONS COPILOT_AGENT_PROMPT

  # The tests that wait for time limits or run many turns come first, slowest
  # first, so the short ones fill the gaps and none starts late
  test-run-suite \
    test-quality-gate-reports-gates-the-time-budget-did-not-allow \
    test-quality-gate-lets-the-processes-of-a-stopped-gate-clean-up \
    test-quality-gate-times-out-a-gate-and-stops-its-process-group \
    test-quality-gate-warnings-have-diagnostic-context \
    test-quality-gate-keeps-success-and-timeouts-authoritative \
    test-quality-gate-rejects-delimiter-injection \
    test-quality-gate-canonicalises-payload-fields \
    test-quality-gate-rejects-multiple-or-nonobject-payloads \
    test-quality-gate-keeps-atomic-run-on-encoding-failure \
    test-quality-gate-keeps-atomic-run-on-publication-failure \
    test-quality-gate-prunes-concurrent-same-session-history \
    test-quality-gate-classifies-session-provenance \
    test-quality-gate-records-comparison-fallback \
    test-quality-gate-bounds-and-isolates-history \
    test-quality-gate-batches-history-validation \
    test-quality-gate-recovers-from-history-validator-failures \
    test-quality-gate-audit-failure-preserves-decisions \
    test-quality-gate-retains-useful-history-on-malformed-records \
    test-quality-gate-records-manual-provenance \
    test-quality-gate-keeps-atomic-latest-on-publish-failure \
    test-quality-gate-isolates-concurrent-history \
    test-quality-gate-reports-history-retention-errors \
    test-quality-gate-requires-an-explicit-prerequisite-verdict \
    test-quality-gate-does-not-reuse-a-producer-verdict \
    test-quality-gate-gives-scope-safe-recovery \
    test-quality-gate-consumes-real-runner-outcomes \
    test-quality-gate-blocks-on-a-mixed-producer-result \
    test-quality-gate-reports-block-state-errors \
    test-quality-gate-does-not-rerun-when-nothing-changed-since-a-block \
    test-quality-gate-keeps-the-caller-locale-for-gates \
    test-quality-gate-still-blocks-when-a-later-gate-cannot-start \
    test-quality-gate-reports-cli-change-scan-errors \
    test-quality-gate-reports-state-and-log-errors \
    test-quality-gate-reports-unreadable-configuration \
    test-quality-gate-matches-path-globs \
    test-quality-gate-stops-the-running-gate-when-the-hook-is-stopped \
    test-quality-gate-honours-max-blocks-and-a-new-prompt-resets-it \
    test-quality-gate-rejects-invalid-gate-configuration \
    test-quality-gate-accepts-whole-numbers-written-as-decimals \
    test-quality-gate-fails-when-a-mise-shim-cannot-run-a-tool \
    test-quality-gate-skips-a-gate-whose-paths-match-no-change \
    test-quality-gate-copes-with-rules-that-print-decimals \
    test-quality-gate-keeps-the-logs-of-each-session-apart \
    test-quality-gate-blocks-again-after-a-cancelled-continuation \
    test-quality-gate-starts-a-new-turn-after-the-agent-finishes \
    test-quality-gate-keeps-a-baseline-per-session \
    test-quality-gate-pauses-from-the-next-prompt-and-resumes \
    test-quality-gate-keeps-the-block-count-when-another-prompt-arrives-mid-turn \
    test-quality-gate-reads-drop-ins-in-byte-order \
    test-quality-gate-sees-changes-inside-a-nested-repository \
    test-quality-gate-reruns-itself-with-a-newer-bash \
    test-quality-gate-ignores-warnings-while-reading-the-configuration \
    test-quality-gate-hashes-more-files-than-one-chunk \
    test-quality-gate-does-not-match-paths-outside-the-globs \
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
    test-quality-gate-works-when-the-temporary-directory-is-unusable \
    test-quality-gate-runs-every-gate-without-a-session-id \
    test-quality-gate-treats-an-unsafe-session-id-as-missing \
    test-quality-gate-keeps-the-baseline-when-another-prompt-arrives-mid-turn \
    test-quality-gate-records-the-time-of-the-last-hook-and-run-in-utc \
    test-quality-gate-ignores-subagent-events \
    test-quality-gate-passes-the-changed-paths-to-a-gate \
    test-quality-gate-keeps-awkward-file-names-intact \
    test-quality-gate-matches-paths-of-a-commit-made-during-the-turn \
    test-quality-gate-runs-every-gate-when-the-first-commit-is-made-during-the-turn \
    test-quality-gate-matches-file-names-that-are-not-utf-8 \
    test-quality-gate-blocks-with-valid-output-for-both-harnesses \
    test-quality-gate-lets-the-agent-finish-without-a-session-after-a-block \
    test-quality-gate-does-not-downgrade-legacy-docker-markers \
    test-quality-gate-reports-the-prerequisite-marker \
    test-quality-gate-tells-the-agent-about-a-gate-that-could-not-run \
    test-quality-gate-keeps-fresh-log-directories-of-other-sessions \
    test-quality-gate-limits-the-size-of-the-report \
    test-quality-gate-reports-metadata-overflow \
    test-quality-gate-blocking-summary-keeps-mixed-context \
    test-quality-gate-shares-the-report-size-between-failing-gates \
    test-quality-gate-strips-colour-from-the-report \
    test-quality-gate-ignores-gate-list-edits-made-during-the-turn \
    test-quality-gate-uses-the-gate-list-from-the-start-of-the-turn \
    test-quality-gate-reads-the-rules-from-the-start-of-the-turn \
    test-quality-gate-says-when-no-commit-holds-the-gate-list \
    test-quality-gate-uses-the-start-commit-when-the-tree-could-not-be-read-at-the-start \
    test-quality-gate-reads-an-empty-baseline-as-unreadable \
    test-quality-gate-names-the-gate-list-it-used-without-a-baseline \
    test-quality-gate-warns-about-an-invalid-committed-configuration \
    test-quality-gate-rejects-drop-in-names-that-are-not-plain-ascii \
    test-quality-gate-reads-a-budget-with-leading-zeros-as-decimal \
    test-quality-gate-names-the-missing-tool \
    test-quality-gate-names-yq-when-it-cannot-run \
    test-quality-gate-needs-mikefarah-yq \
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
    test-quality-gate-registers-both-hook-events \
    test-quality-gate-pre-commit-runs-make-test-last

  return 0
}

# ==============================================================================
# Helpers

# Create the scratch repository "$TEST_TMP/repo" with the script, its rules and
# the default gate list, commit it with a README and a source file, stub 'make'
# and change into it.
function gate-create-repo() {

  local repo="$TEST_TMP/repo"
  cp -Rp "$SUITE_TMP/repo-template" "$repo"
  test-isolate-path jq yq readlink mkfifo
  test-stub make
  cd "$repo"

  return 0
}

# Build the committed fixture repository once, every test starts from a copy.
function test-suite-setup() {

  gate-build-repo "$SUITE_TMP/repo-template"

  return 0
}

# Build the committed fixture repository in one commit. It starts few processes,
# as this runs before any test and the whole run starts at once.
# Arguments:
#   $1=[directory]
function gate-build-repo() {

  local repo="$1" line
  git init -q -b main "$repo"
  mkdir -p "$repo/scripts/quality" "$repo/scripts/config" "$repo/src"
  ln -s "$TEST_REPO_ROOT/scripts/quality/quality-gate.sh" "$repo/scripts/quality/quality-gate.sh"
  cp -p "$TEST_REPO_ROOT/scripts/quality/quality-gate.jq" "$repo/scripts/quality/quality-gate.jq"
  # Pin the block limit so the tests do not depend on the project's setting
  while IFS= read -r line || [[ -n $line ]]; do
    [[ $line != max_blocks:* ]] || line='max_blocks: 1'
    printf '%s\n' "$line"
  done < "$TEST_REPO_ROOT/scripts/config/quality-gates.yaml" > "$repo/scripts/config/quality-gates.yaml"
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

  test-mkdir-parent "$1"
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

  "$SCRIPT" hook <<< "$1"

  return 0
}

# Print a UserPromptSubmit event. The prompt text is a marker the tests look
# for.
# Arguments:
#   $1=[session identifier, default is the suite's]
function gate-prompt-json() {

  # shellcheck disable=SC2059
  printf "$PROMPT_JSON_FORMAT" "${1-$SESSION}"

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
# Arguments:
#   $1=[session identifier, default is the suite's]
function gate-start-turn() {

  local json
  # shellcheck disable=SC2059
  printf -v json "$PROMPT_JSON_FORMAT" "${1-$SESSION}"
  gate-send "$json" > /dev/null

  return 0
}

# Print the list of make calls, one per line.
function gate-calls() {

  test-stub-calls make

  return 0
}

# Assert selection fields in the hook and, unless unchanged, the run audit.
# Arguments:
#   $1=[session status] $2=[selection reason] $3=[scope]
function gate-assert-selection-provenance() {

  local status="$1" reason="$2" scope="$3" file
  local -a files=(.git/quality-gate/last-hook.json)
  if [[ $reason != unchanged ]]; then
    files+=(.git/quality-gate/last-run.json)
    assert-not-contains "$TEST_STDOUT" 'No baseline was recorded'
  fi
  for file in "${files[@]}"; do
    assert-equal "$status $reason $scope" "$(jq -r '[.session_status, .selection_reason, .scope] | join(" ")' "$file")" "$file selection provenance"
  done

  return 0
}

# Supply input to the owning handler inside test-capture's stdin isolation.
# Arguments:
#   $1=[hook event JSON]
function gate-handle-payload() {

  handle-hook <<< "$1" || return "$?"

  return 0
}

# ==============================================================================
# Events and the no-change guard

function test-quality-gate-rejects-delimiter-injection() {

  # Arrange
  gate-create-repo
  # Act
  test-capture gate-send '{"hook_event_name":"UserPromptSubmit\u001f../RAW-INVALID-4711","session_id":true}'
  # Assert
  assert-equal '{}' "$TEST_STDOUT" "unknown event is ignored"
  assert-file-not-exists .git/RAW-INVALID-4711.baseline
  assert-file-not-exists .git/quality-gate/last-hook.json
  assert-not-contains "$TEST_STDOUT$TEST_STDERR" RAW-INVALID-4711
  assert-equal '' "$(find .git -name '*RAW-INVALID-4711*' -print)" "no escaped session path"
  assert-equal '' "$(grep -Rl RAW-INVALID-4711 .git/quality-gate 2>/dev/null || :)" "no raw input in audit"
  assert-stub-not-called make

  return 0
}

function test-quality-gate-canonicalises-payload-fields() {

  # Arrange
  local field value payload
  gate-create-repo
  # shellcheck source=scripts/quality/quality-gate.sh
  source <(sed '/^is-arg-true /,$d' "$SCRIPT")
  STATE_DIR="$PWD/.git/quality-gate"
  # Act and assert
  for field in hook_event_name session_id stop_hook_active agent_id prompt; do
    for value in 'RAW-INVALID-4711\u001fStop' 'RAW-INVALID-4711\nStop' 'RAW-INVALID-4711\u0000Stop'; do
      rm -f .git/quality-gate/safe-session.baseline
      rm -rf .git/quality-gate/history
      payload="$(jq -nc --arg field "$field" --argjson value "\"$value\"" \
        '{hook_event_name:"UserPromptSubmit",session_id:"safe-session"} | .[$field] = $value')"
      test-capture gate-handle-payload "$payload"
      assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
      assert-not-contains "$TEST_STDOUT$TEST_STDERR" RAW-INVALID-4711
      if [[ $field == session_id ]]; then
        assert-equal invalid "$(jq -r '.session_status' .git/quality-gate/last-hook.json)" "control character session rejected"
        assert-equal baseline-not-recorded "$(jq -r '.action' .git/quality-gate/last-hook.json)" "no baseline claim"
      elif [[ $field == stop_hook_active || $field == prompt ]]; then
        assert-file-exists .git/quality-gate/safe-session.baseline
      fi
      if [[ -d .git/quality-gate ]]; then
        assert-equal '' "$(grep -Rl RAW-INVALID-4711 .git/quality-gate || :)" "raw payload not persisted"
      fi
    done
  done
  for value in true '"true"'; do
    test-capture gate-handle-payload "{\"hook_event_name\":\"Stop\",\"stop_hook_active\":$value}"
    assert-contains "$TEST_STDOUT" 'earlier block already continued'
  done
  assert-stub-not-called make

  return 0
}

function test-quality-gate-rejects-multiple-or-nonobject-payloads() {

  # Arrange
  local payload
  gate-create-repo
  # Act and assert
  for payload in 'null' '[]' 'true' '"RAW-INVALID-4711"' '' \
    '{"hook_event_name":"UserPromptSubmit","session_id":"safe-session"} {}' \
    '{} {"hook_event_name":"Stop","session_id":"safe-session"}' \
    '{"hook_event_name":"UserPromptSubmit","session_id":"safe-session"} broken'; do
    test-capture gate-send "$payload"
    assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
    assert-equal 1 "$(jq -s length <<< "$TEST_STDOUT")" "single response"
    assert-contains "$TEST_STDOUT" 'verification is unknown'
    assert-not-contains "$TEST_STDOUT$TEST_STDERR" RAW-INVALID-4711
    assert-file-not-exists .git/quality-gate/safe-session.baseline
    assert-file-not-exists .git/quality-gate/last-hook.json
  done
  assert-stub-not-called make

  return 0
}

function test-quality-gate-classifies-session-provenance() {

  # Arrange
  local value expected file payload
  gate-create-repo
  # shellcheck source=scripts/quality/quality-gate.sh
  source <(sed '/^is-arg-true /,$d' "$SCRIPT")
  STATE_DIR="$PWD/.git/quality-gate"
  # Act and assert
  for value in null '""' '"../RAW-INVALID-4711"' '"safe\n"' 123 true false '[]' '{}' '"safe-session"'; do
    case $value in
      null | '""') expected=missing ;;
      '"safe-session"') expected=valid ;;
      *) expected=invalid ;;
    esac
    rm -rf .git/quality-gate/history
    payload="$(jq -nc --argjson session "$value" '{hook_event_name:"UserPromptSubmit",session_id:$session,prompt:"PROMPT-MARKER-4711"}')"
    test-capture gate-handle-payload "$payload"
    assert-equal "$expected" "$(jq -r '.session_status' .git/quality-gate/last-hook.json)" "session type $value"
    if [[ $expected == valid ]]; then
      assert-equal baseline-recorded "$(jq -r '.action' .git/quality-gate/last-hook.json)" "valid baseline"
    else
      assert-equal baseline-not-recorded "$(jq -r '.action' .git/quality-gate/last-hook.json)" "unidentified baseline"
      assert-contains "$TEST_STDOUT" 'cannot associate a baseline'
    fi
    for file in .git/quality-gate/last-hook.json .git/quality-gate/history/*/*/*.json; do
      assert-not-contains "$(< "$file")" 'RAW-INVALID-4711'
      assert-not-contains "$(< "$file")" 'PROMPT-MARKER-4711'
    done
  done
  assert-file-not-exists .git/quality-gate/123.baseline
  assert-file-not-exists .git/quality-gate/true.baseline

  return 0
}

function test-quality-gate-records-comparison-fallback() {

  # Arrange
  gate-create-repo
  gate-start-turn
  printf '=\tmissing-commit\0' > ".git/quality-gate/$SESSION.baseline"
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-equal comparison-failed "$(jq -r '.selection_reason' .git/quality-gate/last-hook.json)" "comparison fallback"
  assert-equal all "$(jq -r '.scope' .git/quality-gate/last-run.json)" "conservative scope"
  assert-equal "$LINT_CALL"$'\n'"$TEST_CALL" "$(gate-calls)" "fallback gates"

  return 0
}

function test-quality-gate-bounds-and-isolates-history() {

  # Arrange
  local index file prompt_record stop_record history actions newest_prompt
  local -a records
  gate-create-repo
  gate-start-turn other
  gate-send '{"hook_event_name":"UserPromptSubmit"}' > /dev/null
  gate-start-turn missing
  history=".git/quality-gate/history/sessions/$SESSION"
  mkdir -p "$history"
  prompt_record="$(jq -c --arg session "$SESSION" '.session=$session | .time="2000-01-01T00:00:00Z"' .git/quality-gate/last-hook.json)"
  stop_record="$(jq -c '.event="Stop" | .action="unchanged" | .selection_reason="unchanged"' <<< "$prompt_record")"
  for ((index = 0; index < 49; index++)); do
    printf -v file '%s/0946684800%06d-seeded.json' "$history" "$index"
    if (( index % 2 == 0 )); then
      printf '%s\n' "$stop_record" > "$file"
    else
      printf '%s\n' "$prompt_record" > "$file"
    fi
  done
  # Act
  gate-start-turn
  records=("$history"/*.json)
  assert-equal 50 "${#records[@]}" "reaches retention boundary"
  assert-file-exists "$history/0946684800000000-seeded.json"
  newest_prompt="${records[49]}"
  gate-send "$(gate-stop-json)" > /dev/null
  # Assert
  records=("$history"/*.json)
  assert-equal 50 "${#records[@]}" "bounded completed events"
  assert-file-not-exists "$history/0946684800000000-seeded.json"
  assert-file-exists "$history/0946684800000001-seeded.json"
  assert-file-exists "$history/0946684800000048-seeded.json"
  assert-file-exists "$newest_prompt"
  actions="$(jq -sr 'map(.action) | join(" ")' "${records[@]}")"
  assert-equal 1 "$(find .git/quality-gate/history/sessions/other -name '*.json' | wc -l | tr -d ' ')" "other session retained"
  assert-equal 1 "$(find .git/quality-gate/history/sessions/missing -name '*.json' | wc -l | tr -d ' ')" "valid missing session isolated"
  assert-equal 1 "$(find .git/quality-gate/history/unidentified/missing -name '*.json' | wc -l | tr -d ' ')" "unidentified session isolated"
  assert-equal "$(printf 'baseline-recorded unchanged %.0s' {1..25})" "$actions " "lifecycle order"
  assert-stub-not-called make

  return 0
}

function test-quality-gate-batches-history-validation() {

  # Arrange
  local index file history="$TEST_TMP/history" record
  local -a records
  gate-create-repo
  # shellcheck source=scripts/quality/quality-gate.sh
  source <(sed '/^is-arg-true /,$d' "$SCRIPT")
  mkdir -p "$history"
  record='{"time":"2000-01-01T00:00:00Z","session":"session-1","session_status":"valid","selection_reason":"unchanged","scope":"none","event":"Stop","action":"unchanged"}'
  for ((index = 0; index < 51; index++)); do
    printf -v file '%s/%04d.json' "$history" "$index"
    printf '%s\n' "$record" > "$file"
  done
  printf '%s\n' "$record" > "$history/- fresh.json"
  printf '%s\n' "$record" > "$history/"$'z\n0\t\001 odd.json'
  REAL_JQ="$(readlink -f "$(command -v jq)")"
  export REAL_JQ VALIDATION_CALLS="$TEST_TMP/validation-calls"
  test-stub jq 'printf x >> "$VALIDATION_CALLS"; exec "$REAL_JQ" "$@"'
  # Act
  test-capture prune-history "$history" "$history/- fresh.json"
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal '' "$TEST_STDOUT$TEST_STDERR" "clean validation"
  assert-equal x "$(< "$VALIDATION_CALLS")" "one real validator per scan"
  records=("$history"/*.json)
  assert-equal 50 "${#records[@]}" "valid completed record cap"
  assert-file-exists "$history/- fresh.json"
  assert-file-exists "$history/"$'z\n0\t\001 odd.json'
  assert-file-not-exists "$history/0000.json"
  assert-file-not-exists "$history/0002.json"
  assert-file-exists "$history/0003.json"

  return 0
}

function test-quality-gate-audit-failure-preserves-decisions() {

  # Arrange
  gate-create-repo
  gate-start-turn
  printf 'occupied\n' > .git/quality-gate/history-obstruction
  rm -rf .git/quality-gate/history
  mv .git/quality-gate/history-obstruction .git/quality-gate/history
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-equal '{}' "$TEST_STDOUT" "unchanged still allowed"
  assert-contains "$TEST_STDERR" '.git/quality-gate/history'
  assert-contains "$TEST_STDERR" 'Inspect'
  gate-make "$FAILING_LINT"
  test-capture gate-send "$(gate-stop-json)"
  assert-contains "$TEST_STDOUT" '"decision":"block"'
  assert-contains "$TEST_STDERR" '.git/quality-gate/history'
  assert-equal blocked "$(jq -r '.action' .git/quality-gate/last-hook.json)" "latest survives history failure"

  return 0
}

function test-quality-gate-retains-useful-history-on-malformed-records() {

  # Arrange
  local index useful record mutation file history
  gate-create-repo
  gate-start-turn
  history=".git/quality-gate/history/sessions/$SESSION"
  useful="$(find ".git/quality-gate/history/sessions/$SESSION" -name '*.json')"
  record="$(< "$useful")"
  for ((index = 0; index < 51; index++)); do
    printf -v file '%s/%04d.json' "$history" "$index"
    printf '%s\n' "$record" > "$file"
  done
  : > "$history/empty-bad.json"
  printf ' \n\t' > "$history/whitespace-bad.json"
  printf '%s' "${record%\}}" > "$history/cross-1-bad.json"
  printf '}' > "$history/cross-2-bad.json"
  printf '%s\0\n' "$record" > "$history/nul-tail-bad.json"
  printf '\0%s\n' "$record" > "$history/nul-head-bad.json"
  printf '%s\0%s\n' "${record:0:2}" "${record:2}" > "$history/nul-middle-bad.json"
  printf '%s\n' "${record/recorded/$'rec\norded'}" > "$history/newline-bad.json"
  for ((index = 0; index < 10; index++)); do
    printf 'not json\n' > ".git/quality-gate/history/sessions/$SESSION/9999999999999999-$index-bad.json"
    printf '{"event":null,"action":null}\n' > ".git/quality-gate/history/sessions/$SESSION/9999999999999999-$index-schema-bad.json"
    printf '%s\n%s\n' "$record" "$record" > ".git/quality-gate/history/sessions/$SESSION/9999999999999999-$index-multi-bad.json"
  done
  index=0
  for mutation in '.time=null' '.time="not-a-date"' '.session=true' '.session="../unsafe"' \
    '.session_status=null' '.session_status="other"' '.selection_reason=null' '.selection_reason="other"' \
    '.scope=null' '.scope="other"' '.event=null' '.event="other"' '.action=null' '.action="other"' \
    'del(.time)' 'del(.session)' 'del(.session_status)' 'del(.selection_reason)' 'del(.scope)' 'del(.event)' 'del(.action)'; do
    jq "$mutation" "$useful" > ".git/quality-gate/history/sessions/$SESSION/9999999999999999-$index-field-bad.json"
    index=$((index + 1))
  done
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-equal '{}' "$TEST_STDOUT" "malformed audit does not block"
  assert-contains "$TEST_STDERR" 'bad.json'
  assert-contains "$TEST_STDERR" 'schema-bad.json'
  assert-contains "$TEST_STDERR" 'multi-bad.json'
  assert-contains "$TEST_STDERR" 'field-bad.json'
  for file in ".git/quality-gate/history/sessions/$SESSION/"*bad.json; do
    assert-contains "$TEST_STDERR" "${file##*/}"
  done
  assert-file-exists "$useful"
  assert-file-not-exists "$history/0000.json"
  assert-file-not-exists "$history/0002.json"
  assert-file-exists "$history/0003.json"
  assert-equal 50 "$(find "$history" -name '*.json' ! -name '*bad.json' | wc -l | tr -d ' ')" "useful records retained and pruned despite corruption"
  if [[ $EUID -ne 0 ]]; then
    printf '%s\n' "$record" > "$history/unreadable-bad.json"
    chmod 000 "$history/unreadable-bad.json"
    test-capture gate-send "$(gate-prompt-json)"
    assert-equal '{}' "$TEST_STDOUT" "unreadable history still allows"
    assert-contains "$TEST_STDERR" 'history validation failed'
    for file in "$history/"*bad.json; do
      assert-file-exists "$file"
      assert-contains "$TEST_STDERR" "${file##*/}"
    done
    chmod 600 "$history/unreadable-bad.json"
    assert-file-exists "$useful"
    assert-equal 50 "$(find "$history" -name '*.json' ! -name '*bad.json' | wc -l | tr -d ' ')" "readable history pruned during recovery"
  fi

  return 0
}

function test-quality-gate-recovers-from-history-validator-failures() {

  # Arrange
  local mode index file record history="$TEST_TMP/history" expected
  local -a records
  gate-create-repo
  # shellcheck source=scripts/quality/quality-gate.sh
  source <(sed '/^is-arg-true /,$d' "$SCRIPT")
  record='{"time":"2000-01-01T00:00:00Z","session":"session-1","session_status":"valid","selection_reason":"unchanged","scope":"none","event":"Stop","action":"unchanged"}'
  REAL_JQ="$(readlink -f "$(command -v jq)")"
  export REAL_JQ HISTORY_SCAN_DIR="$history" HISTORY_FAILURE_MODE
  test-stub jq '
    if [[ $HISTORY_FAILURE_MODE == failed-all ]]; then
      printf 1; echo RAW-INVALID-4711 >&2; exit 1
    fi
    if [[ $1 == -nr ]]; then
      case $HISTORY_FAILURE_MODE in
        failed-partial) printf "1%.0s" {1..53}; exit 1 ;;
        truncated) printf "1%.0s" {1..52}; exit 0 ;;
        invalid) printf "1%.0s" {1..52}; printf x; exit 0 ;;
        vanished) rm -f -- "$HISTORY_SCAN_DIR/0000.json" ;;
      esac
    fi
    exec "$REAL_JQ" "$@"'
  # Act and assert
  for mode in failed-partial truncated invalid failed-all vanished; do
    HISTORY_FAILURE_MODE="$mode"
    mkdir -p "$history"
    for ((index = 0; index < 51; index++)); do
      printf -v file '%s/%04d.json' "$history" "$index"
      printf '%s\n' "$record" > "$file"
    done
    printf '%s\n' "$record" > "$history/- fresh.json"
    printf 'RAW-INVALID-4711' > "$history/"$'z\n1\t\001 bad.json'
    test-capture prune-history "$history" "$history/- fresh.json"
    assert-equal 0 "$TEST_STATUS" "$mode $EXIT_STATUS_LABEL"
    assert-equal '' "$TEST_STDOUT" "$mode emits no hook output"
    assert-not-contains "$TEST_STDERR" RAW-INVALID-4711
    assert-contains "$TEST_STDERR" 'history validation failed'
    assert-contains "$TEST_STDERR" $'z\n1\t\001 bad.json'
    assert-file-exists "$history/"$'z\n1\t\001 bad.json'
    assert-file-exists "$history/- fresh.json"
    assert-file-exists "$history/0002.json"
    expected=51
    if [[ $mode == failed-all ]]; then
      expected=53
      assert-file-exists "$history/0000.json"
      assert-file-exists "$history/0001.json"
      for file in "$history"/*.json; do
        assert-contains "$TEST_STDERR" "$file"
      done
    else
      assert-file-not-exists "$history/0000.json"
      assert-file-not-exists "$history/0001.json"
    fi
    if [[ $mode == vanished ]]; then
      assert-contains "$TEST_STDERR" '0000.json'
    fi
    records=("$history"/*.json)
    assert-equal "$expected" "${#records[@]}" "$mode safe retention"
    rm -rf "$history"
  done

  return 0
}

function test-quality-gate-keeps-atomic-latest-on-publish-failure() {

  # Arrange
  gate-create-repo
  gate-start-turn
  cp .git/quality-gate/last-hook.json "$TEST_TMP/previous.json"
  test-stub mv 'echo "publish denied" >&2; exit 1'
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-equal '{}' "$TEST_STDOUT" "latest publication does not affect allow"
  assert-contains "$TEST_STDERR" 'last-hook.json'
  assert-files-identical "$TEST_TMP/previous.json" .git/quality-gate/last-hook.json
  assert-equal 2 "$(find ".git/quality-gate/history/sessions/$SESSION" -name '*.json' | wc -l | tr -d ' ')" "history survives latest failure"

  return 0
}

function test-quality-gate-isolates-concurrent-history() {

  # Arrange
  local first second
  gate-create-repo
  # Act
  gate-start-turn first &
  first=$!
  gate-start-turn second &
  second=$!
  wait "$first"
  wait "$second"
  # Assert
  assert-equal baseline-recorded "$(jq -r '.action' .git/quality-gate/history/sessions/first/*.json)" "first concurrent event"
  assert-equal baseline-recorded "$(jq -r '.action' .git/quality-gate/history/sessions/second/*.json)" "second concurrent event"
  jq -e '.action == "baseline-recorded"' .git/quality-gate/last-hook.json > /dev/null

  return 0
}

function test-quality-gate-prunes-concurrent-same-session-history() {

  # Arrange
  local index name first second
  gate-create-repo
  gate-start-turn
  export RACE_DIR="$PWD/.git/quality-gate/history/sessions/$SESSION"
  for ((index = 0; index < 49; index++)); do
    printf -v name '%016d-old.json' "$index"
    cp .git/quality-gate/last-hook.json "$RACE_DIR/$name"
  done
  REAL_RM="$(readlink -f "$(command -v rm)")"
  REAL_LN="$(readlink -f "$(command -v ln)")"
  export REAL_RM REAL_LN
  export RACE_READY="$TEST_TMP/ready" RACE_DONE="$TEST_TMP/done"
  export RACE_FIRST_PUBLISHED="$TEST_TMP/first-published" RACE_SECOND_PUBLISHED="$TEST_TMP/second-published"
  export RACE_PUBLICATION_DONE="$TEST_TMP/publication-done"
  mkfifo "$RACE_READY" "$RACE_DONE" "$RACE_FIRST_PUBLISHED" "$RACE_SECOND_PUBLISHED"
  test-stub rm '
    for argument in "$@"; do
      if [[ $argument == "$RACE_DIR/0000000000000000-old.json" ]]; then
        exec 8<> "$RACE_READY" 9<> "$RACE_DONE"
        if [[ $PRUNE_ROLE == first ]]; then
          read -r -t 15 -u 8 token || exit 91
        else
          printf "ready\n" >&8
          read -r -t 15 -u 9 token || exit 92
        fi
      fi
    done
    "$REAL_RM" "$@"
    result=$?
    if [[ ${PRUNE_ROLE:-} == first && ${*: -1} == "$RACE_DIR/0000000000000001-old.json" ]]; then
      exec 9<> "$RACE_DONE"
      printf "done\n" >&9
    fi
    exit "$result"'
  test-stub ln '
    "$REAL_LN" "$@" || exit "$?"
    if [[ $# -eq 2 && $1 == "$RACE_DIR/".* && $2 == "$RACE_DIR/"*.json ]]; then
      exec 8<> "$RACE_FIRST_PUBLISHED" 9<> "$RACE_SECOND_PUBLISHED"
      if [[ $PRUNE_ROLE == first ]]; then
        printf "published\n" >&8
        read -r -t 15 -u 9 token || exit 93
      else
        printf "published\n" >&9
        read -r -t 15 -u 8 token || exit 94
      fi
      printf "complete\n" > "$RACE_PUBLICATION_DONE.$PRUNE_ROLE"
    fi'
  # Act
  PRUNE_ROLE=first "$SCRIPT" hook <<< "$(gate-prompt-json)" > "$TEST_TMP/first.out" 2> "$TEST_TMP/first.err" &
  first=$!
  PRUNE_ROLE=second "$SCRIPT" hook <<< "$(gate-prompt-json)" > "$TEST_TMP/second.out" 2> "$TEST_TMP/second.err" &
  second=$!
  wait "$first"
  wait "$second"
  # Assert
  assert-file-has-line "$RACE_PUBLICATION_DONE.first" complete
  assert-file-has-line "$RACE_PUBLICATION_DONE.second" complete
  assert-equal '{}' "$(< "$TEST_TMP/first.out")" "first prompt allowed"
  assert-equal '{}' "$(< "$TEST_TMP/second.out")" "second prompt allowed"
  assert-equal 50 "$(find "$RACE_DIR" -name '*.json' | wc -l | tr -d ' ')" "same-session pruning does not over-delete"
  assert-equal '' "$(< "$TEST_TMP/first.err")$(< "$TEST_TMP/second.err")" "idempotent pruning has no spurious warnings"
  assert-file-exists "$RACE_DIR/0000000000000002-old.json"

  return 0
}

function test-quality-gate-keeps-atomic-run-on-encoding-failure() {

  # Arrange
  gate-create-repo
  gate-send "$(gate-stop-json)" > /dev/null
  cp .git/quality-gate/last-run.json "$TEST_TMP/previous-run.json"
  REAL_JQ="$(readlink -f "$(command -v jq)")"
  export REAL_JQ
  test-stub jq 'if [[ $1 == -R ]]; then printf "partial"; echo "encoding denied" >&2; exit 1; fi; exec "$REAL_JQ" "$@"'
  # Act and assert
  test-capture gate-send "$(gate-stop-json)"
  assert-not-contains "$TEST_STDOUT" '"decision":"block"'
  assert-contains "$TEST_STDERR" 'cannot write'
  assert-contains "$TEST_STDERR" 'last-run.json'
  assert-files-identical "$TEST_TMP/previous-run.json" .git/quality-gate/last-run.json
  gate-make "$FAILING_LINT"
  test-capture gate-send "$(gate-stop-json)"
  assert-contains "$TEST_STDOUT" '"decision":"block"'
  assert-contains "$TEST_STDERR" 'cannot write'
  assert-files-identical "$TEST_TMP/previous-run.json" .git/quality-gate/last-run.json

  return 0
}

function test-quality-gate-keeps-atomic-run-on-publication-failure() {

  # Arrange
  gate-create-repo
  gate-send "$(gate-stop-json)" > /dev/null
  cp .git/quality-gate/last-run.json "$TEST_TMP/previous-run.json"
  REAL_MV="$(readlink -f "$(command -v mv)")"
  export REAL_MV
  test-stub mv 'if [[ ${*: -1} == */last-run.json ]]; then echo "publish denied" >&2; exit 1; fi; exec "$REAL_MV" "$@"'
  # Act and assert
  test-capture gate-send "$(gate-stop-json)"
  assert-not-contains "$TEST_STDOUT" '"decision":"block"'
  assert-contains "$TEST_STDERR" 'cannot write'
  assert-contains "$TEST_STDERR" 'last-run.json'
  assert-files-identical "$TEST_TMP/previous-run.json" .git/quality-gate/last-run.json
  gate-make "$FAILING_LINT"
  test-capture gate-send "$(gate-stop-json)"
  assert-contains "$TEST_STDOUT" '"decision":"block"'
  assert-contains "$TEST_STDERR" 'cannot write'
  assert-files-identical "$TEST_TMP/previous-run.json" .git/quality-gate/last-run.json

  return 0
}

function test-quality-gate-records-manual-provenance() {

  # Arrange
  local scope
  gate-create-repo
  # Act and assert
  for scope in all changed; do
    export scope
    test-capture "$SCRIPT" run
    assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
    assert-equal not-applicable "$(jq -r '.session_status' .git/quality-gate/last-run.json)" "manual session"
    assert-equal "manual-$scope" "$(jq -r '.selection_reason' .git/quality-gate/last-run.json)" "manual reason"
    assert-equal "$scope" "$(jq -r '.scope' .git/quality-gate/last-run.json)" "manual scope"
  done

  return 0
}

function test-quality-gate-reports-history-retention-errors() {

  # Arrange
  local index name record
  gate-create-repo
  gate-start-turn
  record="$(< .git/quality-gate/last-hook.json)"
  for ((index = 0; index < 51; index++)); do
    printf -v name '%016d-old.json' "$index"
    printf '%s\n' "$record" > ".git/quality-gate/history/sessions/$SESSION/$name"
  done
  REAL_RM="$(readlink -f "$(command -v rm)")"
  export REAL_RM
  test-stub rm 'for argument in "$@"; do if [[ $argument == */history/* ]]; then echo "retention denied" >&2; exit 1; fi; done; exec "$REAL_RM" "$@"'
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-equal '{}' "$TEST_STDOUT" "retention failure does not block"
  assert-contains "$TEST_STDERR" 'history retention is incomplete'
  assert-contains "$TEST_STDERR" '.git/quality-gate/history/'
  assert-contains "$TEST_STDERR" 'Inspect'
  assert-equal unchanged "$(jq -r '.action' .git/quality-gate/last-hook.json)" "latest useful event survives"
  assert-stub-not-called make

  return 0
}

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
  gate-assert-selection-provenance valid unchanged none

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
  gate-assert-selection-provenance valid changed-files changed

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
  assert-equal snapshot-failed "$(jq -r '.selection_reason' .git/quality-gate/last-hook.json)" "current snapshot failure retained"
  assert-equal snapshot-failed "$(jq -r '.selection_reason' .git/quality-gate/last-run.json)" "run snapshot failure retained"
  assert-equal all "$(jq -r '.scope' .git/quality-gate/last-run.json)" "snapshot fallback scope"

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
  assert-equal snapshot-failed "$(jq -r '.action' .git/quality-gate/last-hook.json)" "failed prompt snapshot"
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

function test-quality-gate-runs-every-gate-without-a-session-id() {

  # Arrange
  gate-create-repo
  # Act
  test-capture gate-send '{"hook_event_name":"Stop"}'
  # Assert
  assert-contains "$TEST_STDOUT" 'session identifier is missing'
  assert-contains "$TEST_STDOUT" 'conservative fallback, not proof of edits'
  assert-equal "$LINT_CALL"$'\n'"$TEST_CALL" "$(gate-calls)" "make calls"
  gate-assert-selection-provenance missing missing-session-id all

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
  assert-contains "$TEST_STDOUT" 'session identifier is invalid'
  assert-contains "$TEST_STDOUT" 'conservative fallback, not proof of edits'
  assert-file-not-exists .git/evil.baseline
  assert-file-not-exists .git/quality-gate/../evil.baseline
  assert-equal "" "$(find .git -name '*evil*')" "files created for the unsafe id"
  gate-assert-selection-provenance invalid invalid-session-id all

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
  assert-equal turn-already-open "$(jq -r '.action' .git/quality-gate/last-hook.json)" "retained prompt baseline"
  assert-equal valid "$(jq -r '.session_status' .git/quality-gate/last-hook.json)" "retained session"
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
  # One file in each of the three chunks of 100, at their first and last
  # positions
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
  # 'run' matches paths like the hook does and needs no turn for each file
  for file in schema.json a/b/schema.json docs/x/y.md docs/y.md 'lib/[x]1.py'; do
    printf 'edit\n' > "$file"
    test-capture "$SCRIPT" run
    assert-contains "$(gate-calls)" '--no-print-directory check-schema' "make calls after editing $file"
    rm -- "$file"
    : > "$STUB_DIR/make.calls"
  done

  return 0
}

function test-quality-gate-does-not-match-paths-outside-the-globs() {

  # Arrange
  local file
  gate-create-glob-repo
  gate-start-turn
  for file in other.txt xschema.json docsy.md docs/y.txt lib/x1.py 'lib/[x]10.py'; do
    printf 'edit\n' >> "$file"
  done
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-not-contains "$(gate-calls)" "check-schema" "make calls"
  assert-contains "$(gate-calls)" "$LINT_CALL"

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

function test-quality-gate-requires-an-explicit-prerequisite-verdict() {

  # Arrange
  local verdict marker expected
  gate-create-repo
  # Act and assert
  while IFS='|' read -r verdict marker expected; do
    export PRODUCER_VERDICT="$verdict" PRODUCER_MARKER="$marker"
    gate-make 'if [[ "${*: -1}" == lint ]]; then if [[ "$PRODUCER_VERDICT" != missing ]]; then printf "%b" "$PRODUCER_VERDICT" > "${QUALITY_GATE_RESULT_FILE:-$TEST_TMP/unclaimed}"; fi; printf "%b\n" "$PRODUCER_MARKER"; exit 1; fi'
    test-capture "$SCRIPT" run
    assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL for $verdict / $marker"
    assert-equal "$expected" "$(jq -r '.gates[0].state' .git/quality-gate/last-run.json)" "classification for $verdict / $marker"
  done << 'EOF'
prerequisite|PREREQUISITE: unavailable tool|prerequisite
missing|PREREQUISITE: unavailable tool|fail
fail|PREREQUISITE: unavailable tool|fail
prerequisite\nextra|PREREQUISITE: unavailable tool|fail
prerequisite\n\n|PREREQUISITE: unavailable tool|fail
prerequisite\0|PREREQUISITE: unavailable tool|fail
prerequisite|PREREQUISITE:    |fail
prerequisite|PREREQUISITE:|fail
prerequisite|    PREREQUISITE: expected fixture error|fail
prerequisite|ERROR Docker test suite cannot run: unavailable|fail
prerequisite|ordinary assertion failure|fail
EOF

  return 0
}

function test-quality-gate-does-not-reuse-a-producer-verdict() {

  # Arrange
  gate-create-repo
  export QUALITY_GATE_RESULT_FILE="$TEST_TMP/outer-result"
  printf 'outer\n' > "$QUALITY_GATE_RESULT_FILE"
  gate-make '[[ "$QUALITY_GATE_RESULT_FILE" == /* ]] || exit 9; [[ ! -e "$QUALITY_GATE_RESULT_FILE" ]] || exit 8; printf "%s\n" "$QUALITY_GATE_RESULT_FILE" >> "$TEST_TMP/result-paths"; printf prerequisite > "$QUALITY_GATE_RESULT_FILE"; echo "PREREQUISITE: unavailable"; exit 1'
  # Act
  test-capture "$SCRIPT" run
  # Assert
  assert-equal prerequisite "$(jq -r '.gates[0].state' .git/quality-gate/last-run.json)" "fresh producer result"
  assert-equal 2 "$(sort -u "$TEST_TMP/result-paths" | wc -l | tr -d ' ')" "private path per gate"
  assert-equal outer "$(< "$QUALITY_GATE_RESULT_FILE")" "caller result remains private"
  # Arrange
  gate-make 'echo "PREREQUISITE: stale marker"; exit 1'
  # Act
  test-capture "$SCRIPT" run
  # Assert
  assert-equal fail "$(jq -r '.gates[0].state' .git/quality-gate/last-run.json)" "stale verdict is not reused"

  return 0
}

function test-quality-gate-keeps-success-and-timeouts-authoritative() {

  # Arrange
  gate-create-repo
  gate-commit-file scripts/config/quality-gates.d/short.yaml "$SHORT_LINT_GATE"
  gate-make 'printf prerequisite > "${QUALITY_GATE_RESULT_FILE:-$TEST_TMP/unclaimed}"; echo "PREREQUISITE: unavailable"; if [[ "${*: -1}" == lint ]]; then sleep 30; fi'
  # Act
  test-capture "$SCRIPT" run
  # Assert
  assert-equal timeout "$(jq -r '.gates[0].state' .git/quality-gate/last-run.json)" "timeout precedes producer verdict"
  assert-equal pass "$(jq -r '.gates[1].state' .git/quality-gate/last-run.json)" "success precedes producer verdict"

  return 0
}

function test-quality-gate-gives-scope-safe-recovery() {

  # Arrange
  local reason field
  gate-create-repo
  gate-make "$FAILING_LINT"
  gate-start-turn
  printf 'two\n' >> README.md
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  for field in reason systemMessage; do
    reason="$(jq -r --arg field "$field" '.[$field]' <<< "$TEST_STDOUT")"
    assert-contains "$reason" "Review-only tasks: report failures without modifying files"
    assert-contains "$reason" "caused by authorised changes"
    assert-contains "$reason" "unrelated, setup or uncertain"
    assert-contains "$reason" "no permission"
    assert-contains "$reason" "not passed"
    assert-contains "$reason" "exit status 1"
    assert-contains "$reason" "Rerun: make lint"
    assert-contains "$reason" "lint.log"
    assert-not-contains "$reason" "Fix the cause"
  done

  return 0
}

function test-quality-gate-warnings-have-diagnostic-context() {

  # Arrange
  gate-create-repo
  gate-commit-file scripts/config/quality-gates.d/warn.yaml $'version: 1\ngates:\n  - {name: lint, mode: warn, timeout: 2}'
  gate-make "$FAILING_LINT"
  gate-start-turn
  printf 'two\n' >> README.md
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDOUT" "lint did not pass (warning only)"
  assert-not-contains "$TEST_STDOUT" '"decision"'
  assert-contains "$TEST_STDOUT" "exit status 1"
  assert-contains "$TEST_STDOUT" "make lint"
  assert-contains "$TEST_STDOUT" "lint.log"
  # Arrange
  gate-start-turn
  printf 'three\n' >> README.md
  gate-make 'if [[ "${*: -1}" == lint ]]; then sleep 30; fi'
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-not-contains "$TEST_STDOUT" '"decision"'
  assert-contains "$TEST_STDOUT" "timed out after"
  assert-contains "$TEST_STDOUT" "make lint"
  assert-contains "$TEST_STDOUT" "lint.log"

  return 0
}

function test-quality-gate-consumes-real-runner-outcomes() {

  # Arrange
  gate-create-repo
  export REAL_SUITE_RUNNER="$TEST_REPO_ROOT/scripts/tests/run-test-suites.sh"
  mkdir fixtures
  printf '#!/usr/bin/env bash\n[[ ! ${QUALITY_GATE_RESULT_FILE+x} ]] || exit 1\necho "    PREREQUISITE: tool unavailable"\nexit 77\n' > fixtures/setup.test.sh
  chmod +x fixtures/setup.test.sh
  gate-make 'if [[ "${*: -1}" == test ]]; then exec env dir=fixtures "$REAL_SUITE_RUNNER"; fi'
  gate-start-turn
  printf 'two\n' >> README.md
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-not-contains "$TEST_STDOUT" '"decision"'
  assert-equal prerequisite "$(jq -r '.gates[1].state' .git/quality-gate/last-run.json)" "real runner setup-only outcome"
  assert-contains "$TEST_STDOUT" "unknown, not passed"
  # Arrange
  gate-start-turn
  printf '#!/usr/bin/env bash\necho "ASSERTION FAILED: real finding"\nexit 1\n' > fixtures/finding.test.sh
  chmod +x fixtures/finding.test.sh
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-contains "$TEST_STDOUT" '"decision":"block"'
  assert-equal fail "$(jq -r '.gates[1].state' .git/quality-gate/last-run.json)" "real runner mixed outcome"
  assert-contains "$TEST_STDOUT" "ASSERTION FAILED: real finding"

  return 0
}

function test-quality-gate-blocks-on-a-mixed-producer-result() {

  # Arrange
  gate-create-repo
  gate-make 'if [[ "${*: -1}" == test ]]; then printf fail > "${QUALITY_GATE_RESULT_FILE:-$TEST_TMP/unclaimed}"; echo "PREREQUISITE: unavailable tool"; echo "ASSERTION FAILED: finding"; exit 1; fi'
  gate-start-turn
  printf 'two\n' >> README.md
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-contains "$TEST_STDOUT" '"decision":"block"'
  assert-equal fail "$(jq -r '.gates[1].state' .git/quality-gate/last-run.json)" "explicit fail cannot be downgraded by marker"

  return 0
}

function test-quality-gate-reports-block-state-errors() {

  # Arrange
  gate-create-repo
  gate-make "$FAILING_LINT"
  gate-start-turn
  mkdir ".git/quality-gate/$SESSION.blocks"
  printf 'two\n' >> README.md
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-contains "$TEST_STDOUT" '"decision":"block"'
  assert-contains "$TEST_STDERR" "$SESSION.blocks"
  assert-contains "$TEST_STDERR" "continuation count is unknown"
  assert-contains "$TEST_STDERR" "make quality-gate"
  assert-contains "$TEST_STDERR" "Review-only tasks"
  # Act
  printf 'three\n' >> README.md
  test-capture gate-send "$(gate-stop-json "$SESSION" true)"
  # Assert
  assert-not-contains "$TEST_STDOUT" '"decision"'
  assert-contains "$TEST_STDOUT" "continuation count"
  assert-contains "$TEST_STDOUT" "not a pass"
  assert-equal "$LINT_CALL"$'\n'"$TEST_CALL" "$(gate-calls)" "an unknown count does not rerun the gates"

  return 0
}

function test-quality-gate-does-not-rerun-when-nothing-changed-since-a-block() {

  # Arrange
  gate-create-repo
  gate-commit-file scripts/config/quality-gates.d/limits.yaml $'version: 1\nmax_blocks: 3'
  gate-make "$FAILING_LINT"
  gate-start-turn
  printf 'two\n' >> README.md
  test-capture gate-send "$(gate-stop-json)"
  assert-contains "$TEST_STDOUT" '"decision":"block"'
  # Act
  test-capture gate-send "$(gate-stop-json "$SESSION" true)"
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-not-contains "$TEST_STDOUT" '"decision"'
  assert-contains "$TEST_STDOUT" "nothing changed since"
  assert-contains "$TEST_STDOUT" "not a pass"
  assert-contains "$TEST_STDOUT" "last-run.json"
  assert-equal "$LINT_CALL"$'\n'"$TEST_CALL" "$(gate-calls)" "make calls, the gates ran only at the first stop"
  assert-equal unchanged-since-block "$(jq -r '.action' .git/quality-gate/last-hook.json)" "recorded action"
  assert-file-not-exists ".git/quality-gate/$SESSION.baseline"

  return 0
}

function test-quality-gate-keeps-the-caller-locale-for-gates() {

  # Arrange
  gate-create-repo
  export LC_ALL=POSIX
  gate-make 'printf "%s\n" "${LC_ALL-unset}" >> "$TEST_TMP/locale"'
  gate-start-turn
  printf 'two\n' >> README.md
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-equal $'POSIX\nPOSIX' "$(< "$TEST_TMP/locale")" "locale seen by each gate"

  return 0
}

function test-quality-gate-still-blocks-when-a-later-gate-cannot-start() {

  # Arrange
  local reason
  gate-create-repo
  gate-make "$FAILING_LINT"
  REAL_MKTEMP="$(readlink -f "$(command -v mktemp)")"
  export REAL_MKTEMP
  test-stub mktemp 'if [[ ${*: -1} == */test.result.* ]]; then echo "mktemp denied" >&2; exit 1; fi; exec "$REAL_MKTEMP" "$@"'
  gate-start-turn
  printf 'two\n' >> README.md
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDOUT" '"decision":"block"'
  reason="$(jq -r '.reason' <<< "$TEST_STDOUT")"
  assert-contains "$reason" "== lint (make lint) failed with exit status 1"
  assert-contains "$reason" "Verification is unknown"
  assert-equal "$LINT_CALL" "$(gate-calls)" "make calls"
  assert-equal fail "$(jq -r '.gates[0].state' .git/quality-gate/last-run.json)" "recorded partial result"

  return 0
}

function test-quality-gate-reports-cli-change-scan-errors() {

  # Arrange
  gate-create-repo
  export REAL_GIT
  REAL_GIT="$(command -v git)"
  test-stub git 'if [[ ${1:-} == diff ]]; then echo "git scan failed" >&2; exit 1; fi; exec "$REAL_GIT" "$@"'
  # Act
  test-capture "$SCRIPT" run
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "change selection is unknown"
  assert-contains "$TEST_STDERR" "not run"
  assert-contains "$TEST_STDERR" "git status --short"
  assert-contains "$TEST_STDERR" "make quality-gate"

  return 0
}

function test-quality-gate-reports-state-and-log-errors() {

  # Arrange
  gate-create-repo
  gate-start-turn
  rm -f .git/quality-gate/last-hook.json
  mkdir -p .git/quality-gate/last-run.json .git/quality-gate/last-hook.json
  printf 'two\n' >> README.md
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-contains "$TEST_STDERR" "Result history is unavailable"
  assert-contains "$TEST_STDERR" "event audit is incomplete"
  assert-contains "$TEST_STDERR" "make quality-gate"
  # Arrange
  rm -f ".git/quality-gate/logs/$SESSION/lint.log"
  mkdir -p ".git/quality-gate/logs/$SESSION/lint.log"
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-contains "$TEST_STDOUT" "Verification is unknown"
  assert-contains "$TEST_STDOUT" "make quality-gate"
  assert-contains "$TEST_STDOUT" "logs/$SESSION"
  assert-not-contains "$TEST_STDOUT" '"decision"'

  return 0
}

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
  assert-contains "$(jq -r '.systemMessage' <<< "$TEST_STDOUT")" "Quality gate blocked the stop:"
  assert-not-contains "$(jq -r '.systemMessage' <<< "$TEST_STDOUT")" "warning only"
  assert-equal "$LINT_CALL"$'\n'"$TEST_CALL" "$(gate-calls)" "make calls, the gate after the failure still runs"
  gate-assert-selection-provenance valid changed-files changed

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
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDOUT" "already blocked 1 time(s)"
  assert-contains "$TEST_STDOUT" "not a pass"
  assert-contains "$TEST_STDOUT" "last-run.json"
  assert-not-contains "$TEST_STDOUT" '"decision"'
  assert-equal 2 "$(gate-calls | wc -l | tr -d ' ')" "make calls, the gates ran only at the first stop"

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
  printf 'repair\n' >> README.md
  test-capture gate-send "$(gate-stop-json "$SESSION" true)"
  assert-contains "$TEST_STDOUT" '"decision":"block"'
  printf 'repair again\n' >> README.md
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

function test-quality-gate-does-not-downgrade-legacy-docker-markers() {

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
  assert-contains "$TEST_STDOUT" '"decision":"block"'
  message="$(jq -r '.reason' <<< "$TEST_STDOUT")"
  assert-contains "$message" "make test"
  assert-file-exists ".git/quality-gate/$SESSION.baseline"

  return 0
}

function test-quality-gate-reports-the-prerequisite-marker() {

  # Arrange
  gate-create-repo
  gate-make 'if [[ "${*: -1}" == lint ]]; then printf prerequisite > "${QUALITY_GATE_RESULT_FILE:-$TEST_TMP/unclaimed}"; echo "PREREQUISITE: node is unavailable"; exit 3; fi'
  gate-start-turn
  printf 'two\n' >> README.md
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-not-contains "$TEST_STDOUT" '"decision"'
  assert-contains "$(jq -r '.systemMessage' <<< "$TEST_STDOUT")" "lint could not run (node is unavailable), so its result is unknown"
  assert-contains "$TEST_STDOUT" "make lint"
  assert-contains "$TEST_STDOUT" "lint.log"
  assert-not-contains "$TEST_STDOUT" "Fix that"

  return 0
}

function test-quality-gate-tells-the-agent-about-a-gate-that-could-not-run() {

  # Arrange
  local reason
  gate-create-repo
  gate-make 'if [[ "${*: -1}" == lint ]]; then echo "lint finding"; exit 1; fi; printf prerequisite > "${QUALITY_GATE_RESULT_FILE:-$TEST_TMP/unclaimed}"; echo "PREREQUISITE: Docker unavailable"; exit 1'
  gate-start-turn
  printf 'two\n' >> README.md
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  reason="$(jq -r '.reason' <<< "$TEST_STDOUT")"
  assert-contains "$reason" "== lint (make lint) failed with exit status 1 =="
  assert-contains "$reason" "test could not run (Docker unavailable), so its result is unknown"
  assert-not-contains "$reason" "== test (make test)"
  assert-contains "$(jq -r '.systemMessage' <<< "$TEST_STDOUT")" "test could not run (Docker unavailable)"

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
  [[ $(printf '%s' "$reason" | wc -c) -le 8000 ]] || { echo "ASSERTION FAILED: report exceeds 8000 bytes" >&2; return 1; }

  return 0
}

function test-quality-gate-reports-metadata-overflow() {

  # Arrange
  local config=$'version: 1\ngates:' index name target field report omitted included
  gate-create-repo
  for ((index = 1; index <= 30; index++)); do
    printf -v name 'gate-%035d' "$index"
    printf -v target 'target-%092d' "$index"
    config+=$'\n'"  - {name: $name, target: $target}"
  done
  gate-commit-file scripts/config/quality-gates.yaml "$config"
  gate-make 'printf "UTF8: "; printf "\303\251%.0s" {1..5000}; exit 1'
  gate-start-turn
  printf 'two\n' >> README.md
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-equal block "$(jq -r '.decision' <<< "$TEST_STDOUT")" "valid overflowing configuration blocks"
  assert-equal 30 "$(jq '.gates | length' .git/quality-gate/last-run.json)" "all gates ran"
  for field in reason systemMessage; do
    report="$(jq -r --arg field "$field" '.[$field]' <<< "$TEST_STDOUT")"
    assert-contains "$report" "Review-only tasks: report failures without modifying files"
    assert-contains "$report" "no permission"
    assert-contains "$report" "Partial metadata:"
    assert-contains "$report" "make quality-gate scope=all"
    assert-contains "$report" ".git/quality-gate/last-run.json"
    assert-contains "$report" ".git/quality-gate/logs/$SESSION"
    omitted="$(jq -nr --arg text "$report" '$text | capture("Partial metadata: (?<count>[0-9]+) gate\\(s\\) omitted").count')"
    included="$(jq -nr --arg text "$report" '[$text | scan("Rerun: make target-")] | length')"
    assert-equal 30 "$((omitted + included))" "omission count matches complete metadata entries"
    assert-equal "$included" "$(jq -nr --arg text "$report" '[$text | scan("Full log: [^\n]+\\.log")] | length')" "each included gate retains its log"
    jq -en --arg text "$report" --arg field "$field" '$text | utf8bytelength <= (if $field == "reason" then 8000 else 2400 end)' > /dev/null
  done

  return 0
}

function test-quality-gate-blocking-summary-keeps-mixed-context() {

  # Arrange
  local field report
  gate-create-repo
  gate-commit-file scripts/config/quality-gates.d/mixed.yaml $'version: 1\ngates:\n  - {name: test, timeout: 1}\n  - {name: warning, target: warning, mode: warn}\n  - {name: setup, target: setup}'
  gate-make 'case "${*: -1}" in test) sleep 30 ;; setup) printf prerequisite > "$QUALITY_GATE_RESULT_FILE"; echo "PREREQUISITE: missing tool"; exit 77 ;; *) exit 2 ;; esac'
  gate-start-turn
  printf 'two\n' >> README.md
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  for field in reason systemMessage; do
    report="$(jq -r --arg field "$field" '.[$field]' <<< "$TEST_STDOUT")"
    assert-contains "$report" "lint"
    assert-contains "$report" "exit status 2"
    assert-contains "$report" "timed out after"
    assert-contains "$report" "Rerun: make test"
    assert-contains "$report" "test.log"
    assert-contains "$report" "warning only"
    assert-contains "$report" "missing tool"
    assert-contains "$report" "unknown, not passed"
    assert-not-contains "$report" "Fix the cause"
    assert-not-contains "$report" "fix failures"
    assert-equal 1 "$(jq -nr --arg text "$report" '[$text | scan("Review-only tasks:")] | length')" "scope guidance appears once"
    assert-equal 1 "$(jq -nr --arg text "$report" '[$text | scan("warning only")] | length')" "warning appears once"
    assert-equal 1 "$(jq -nr --arg text "$report" '[$text | scan("missing tool")] | length')" "prerequisite appears once"
  done

  return 0
}

function test-quality-gate-shares-the-report-size-between-failing-gates() {

  # Arrange
  local reason line
  line="$(printf 'x%.0s' {1..500})"
  gate-create-repo
  gate-make "for ((i = 1; i <= 40; i++)); do printf '\303\251%.0s' {1..500}; echo \"\${*: -1} row \$i $line\"; done; exit 1"
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
  assert-contains "$reason" $'\xc3\xa9'
  assert-not-contains "$reason" $'\xef\xbf\xbd'
  [[ $(printf '%s' "$reason" | wc -c) -le 8000 ]] || { echo "ASSERTION FAILED: report exceeds 8000 bytes" >&2; return 1; }
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

# ==============================================================================
# Configuration

function test-quality-gate-reports-unreadable-configuration() {

  # Arrange
  gate-create-repo
  if [[ $EUID -eq 0 ]]; then
    echo "skipped: root can read a file without read permission"
    return 0
  fi
  chmod 000 scripts/config/quality-gates.yaml
  # Act
  test-capture "$SCRIPT" list
  # Assert
  assert-equal 2 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "could not be read as valid YAML"
  assert-contains "$TEST_STDERR" "Gates were not run"
  assert-contains "$TEST_STDERR" "scripts/config/quality-gates.yaml"
  assert-contains "$TEST_STDERR" "make quality-gate-list"
  assert-contains "$TEST_STDERR" "Review-only tasks"
  assert-stub-not-called make

  return 0
}

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
  gate-assert-selection-provenance valid unreadable-baseline all

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
  assert-contains "$TEST_STDOUT" 'The baseline file is absent at Stop.'
  assert-contains "$TEST_STDOUT" "The hook could not tell where the turn started, so it used the gate list from commit $(git rev-parse --short=7 HEAD)."
  gate-assert-selection-provenance valid missing-baseline all

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
  gate-assert-invalid 'version: [\n' "could not be read as valid YAML"

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
  printf 'repair\n' >> README.md
  test-capture gate-send "$(gate-stop-json "$SESSION" true)"
  # Assert
  assert-contains "$TEST_STDOUT" '"decision":"block"' "second stop"
  # Act
  printf 'repair again\n' >> README.md
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
  printf 'repair\n' >> README.md
  test-capture gate-send "$(gate-stop-json "$SESSION" true)"
  # Assert
  assert-contains "$TEST_STDOUT" '"decision":"block"' "second stop"
  # Act
  printf 'repair again\n' >> README.md
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
  local pid child started
  gate-create-repo
  gate-commit-file scripts/config/quality-gates.d/short.yaml "$SHORT_LINT_GATE"
  gate-make 'if [[ "${*: -1}" == lint ]]; then echo $$ > "$TEST_TMP/pid"; sleep 300 & echo $! > "$TEST_TMP/child"; wait; fi'
  gate-start-turn
  printf 'two\n' >> README.md
  started=$SECONDS
  # Act
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-contains "$(jq -r '.reason' <<< "$TEST_STDOUT")" "== lint (make lint) timed out after "
  assert-equal timeout "$(jq -r '.gates[0].state' .git/quality-gate/last-run.json)" "individual timeout"
  [[ $((SECONDS - started)) -lt 12 ]] || { echo "ASSERTION FAILED: the hook waited for the gate's child" >&2; return 1; }
  pid="$(< "$TEST_TMP/pid")"
  ! kill -0 "$pid" 2> /dev/null || { echo "ASSERTION FAILED: gate process $pid is still running" >&2; return 1; }
  child="$(< "$TEST_TMP/child")"
  ! kill -0 "$child" 2> /dev/null || { echo "ASSERTION FAILED: gate child $child is still running" >&2; return 1; }

  return 0
}

# Every gate process gets TERM before KILL, so it can clean up.
function test-quality-gate-lets-the-processes-of-a-stopped-gate-clean-up() {

  # Arrange
  gate-create-repo
  # A longer limit than the other time limit tests, so the child has set its
  # trap before the stop even under load
  gate-commit-file scripts/config/quality-gates.d/short.yaml $'version: 1\ngates:\n  - name: lint\n    timeout: 3'
  cat > "$TEST_TMP/child.sh" << 'EOF'
trap 'touch "$TEST_TMP/child-cleaned"; exit 0' TERM
sleep 300 &
wait
EOF
  # Run by bash, as macOS is slow to run a new executable the first time
  gate-make 'if [[ "${*: -1}" == lint ]]; then bash "$TEST_TMP/child.sh" & wait; fi'
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
  gate-make 'if [[ "${*: -1}" == lint ]]; then printf prerequisite > "${QUALITY_GATE_RESULT_FILE:-$TEST_TMP/unclaimed}"; echo "PREREQUISITE: unavailable"; sleep 30; fi'
  export QUALITY_GATE_BUDGET=4
  # Act
  # Without a baseline every gate runs, which skips a prompt on this slow test
  test-capture gate-send "$(gate-stop-json)"
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDOUT" "lint did not finish within the time budget"
  assert-contains "$TEST_STDOUT" "test was not run, the time budget was used up"
  assert-contains "$TEST_STDOUT" "unknown, not passed"
  assert-contains "$TEST_STDOUT" "make lint"
  assert-contains "$TEST_STDOUT" "lint.log"
  assert-contains "$TEST_STDOUT" "make test"
  assert-not-contains "$TEST_STDOUT" '"decision"'
  assert-equal incomplete "$(jq -r '.gates[0].state' .git/quality-gate/last-run.json)" "budget overrides explicit prerequisite"
  assert-equal not-run "$(jq -r '.gates[1].state' .git/quality-gate/last-run.json)" "exhausted budget"

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
  assert-contains "$TEST_STDERR" "the quality gate cannot run jq"
  assert-contains "$TEST_STDERR" "not run"
  assert-contains "$TEST_STDERR" "command -v jq"
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
  assert-contains "$TEST_STDERR" "the quality gate cannot run yq"
  assert-contains "$TEST_STDERR" "command -v yq"
  assert-equal "" "$TEST_STDOUT" "stdout"

  return 0
}

function test-quality-gate-fails-when-a-mise-shim-cannot-run-a-tool() {

  # Arrange
  local shims="$TEST_TMP/shims"
  gate-create-repo
  mkdir -p "$shims"
  # A link to the stub dispatcher, as a new executable is slow to run first
  printf 'echo "mise ERROR Config files are not trusted." >&2\nexit 1\n' > "$shims/jq.body"
  ln -s "$TEST_REPO_ROOT/scripts/tests/stub.sh" "$shims/jq"
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
  assert-contains "$TEST_STDERR" "the quality gate needs mikefarah yq version 4"
  assert-contains "$TEST_STDERR" "yq 3.4.3"
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
  assert-contains "$TEST_STDOUT" "exit status 1"
  assert-contains "$TEST_STDOUT" "Full log:"
  assert-contains "$TEST_STDOUT" "logs/run/lint.log"

  return 0
}

function test-quality-gate-run-fails-when-a-gate-cannot-run() {

  # Arrange
  gate-create-repo
  gate-make 'if [[ "${*: -1}" == lint ]]; then printf prerequisite > "${QUALITY_GATE_RESULT_FILE:-$TEST_TMP/unclaimed}"; echo "PREREQUISITE: Docker unavailable"; exit 1; fi'
  # Act
  test-capture "$SCRIPT" run
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-matches "$TEST_STDOUT" 'lint +prerequisite +make lint'
  assert-contains "$TEST_STDOUT" "unknown"
  assert-contains "$TEST_STDOUT" "lint.log"

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
  assert-equal 3 "$(wc -l <<< "$TEST_STDOUT" | tr -d ' ')" "lines of the gate list"

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
  jq -e '.hooks.Stop[0].timeoutSec < 120 and .hooks.UserPromptSubmit[0].timeoutSec >= 10' "$hooks" > /dev/null

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

# ==============================================================================

main "$@"

exit 0
