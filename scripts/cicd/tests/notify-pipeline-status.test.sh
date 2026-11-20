#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034,SC2317,SC2329

set -euo pipefail

# Test suite for the pipeline status notification script. Each test sets the
# GitHub Actions variables, stubs the GitHub CLI with recorded API responses and
# checks the step outputs the script writes.
#
# Usage:
#   $ ./scripts/cicd/tests/notify-pipeline-status.test.sh
#
# Options:
#   VERBOSE=true  # Show all the executed commands, default is 'false'

# ==============================================================================

readonly EXIT_STATUS_LABEL='exit status'
readonly STATUS_NONE_OUTPUT='status=none'
readonly STATUS_FAILURE_OUTPUT='status=failure'
readonly OUTPUTS_LABEL='outputs'
readonly WARNING_LABEL='warning'
readonly REPO_URL='https://github.com/nhs-england-tools/example'
readonly RUN_URL="$REPO_URL/actions/runs"
readonly COMMIT_SHA='abcdef1234567890abcdef1234567890abcdef12'
readonly COMMIT_LINE="[abcdef1]($REPO_URL/commit/$COMMIT_SHA) Add widget export (#42)"
readonly PASSED_NEEDS='{"metadata":{"result":"success","outputs":{}},"test-stage":{"result":"success","outputs":{}}}'
readonly FAILED_NEEDS='{"metadata":{"result":"success","outputs":{}},"test-stage":{"result":"failure","outputs":{}},"acceptance-stage":{"result":"cancelled","outputs":{}}}'
readonly JOBS_RESPONSE='{"total_count":4,"jobs":[
  {"name":"🧪 Test stage / 🧪 Unit tests","conclusion":"failure","html_url":"'"$RUN_URL"'/100/job/11"},
  {"name":"✅ Acceptance stage / Smoke","conclusion":"cancelled","html_url":"'"$RUN_URL"'/100/job/12"},
  {"name":"🔍 Commit stage / Scan secrets","conclusion":"success","html_url":"'"$RUN_URL"'/100/job/13"},
  {"name":"📣 Notify","conclusion":null,"html_url":"'"$RUN_URL"'/100/job/14"}]}'
readonly COMMIT_RESPONSE='{"sha":"'"$COMMIT_SHA"'","html_url":"'"$REPO_URL"'/commit/'"$COMMIT_SHA"'","commit":{"message":"Add widget export (#42)\n\nLonger description"}}'
readonly PASSED_RUNS_RESPONSE='[{"conclusion":"success","number":9,"url":"'"$RUN_URL"'/90","createdAt":"2026-11-10T11:50:00Z"}]'
readonly BROKEN_RUNS_RESPONSE='[
  {"conclusion":"failure","number":9,"url":"'"$RUN_URL"'/90","createdAt":"2026-11-10T11:50:00Z"},
  {"conclusion":"cancelled","number":8,"url":"'"$RUN_URL"'/80","createdAt":"2026-11-10T11:40:00Z"},
  {"conclusion":"timed_out","number":7,"url":"'"$RUN_URL"'/70","createdAt":"2026-11-10T11:23:00Z"},
  {"conclusion":"success","number":6,"url":"'"$RUN_URL"'/60","createdAt":"2026-11-10T11:00:00Z"}]'
readonly FAILED_ATTEMPT_RESPONSE='{"conclusion":"failure","run_number":10,"html_url":"'"$RUN_URL"'/100","created_at":"2026-11-10T11:45:00Z"}'

# Set up the suite and run every test.
function main() {

  cd "$(git rev-parse --show-toplevel)"
  source ./scripts/tests/test.lib.sh

  test-run-suite \
    test-notify-reports-nothing-when-every-job-passes \
    test-notify-reports-a-broken-trunk \
    test-notify-reports-a-failure-without-stopping-the-line \
    test-notify-falls-back-to-job-ids-when-the-jobs-are-not-found \
    test-notify-falls-back-to-the-ref-when-the-commit-is-not-found \
    test-notify-reports-the-recovery-of-a-broken-trunk \
    test-notify-reports-the-recovery-after-a-passing-re-run \
    test-notify-warns-when-the-previous-attempt-is-not-found \
    test-notify-reports-nothing-when-the-previous-run-passed \
    test-notify-reports-nothing-when-the-runs-before-were-cancelled \
    test-notify-reports-nothing-when-the-previous-runs-are-not-found \
    test-notify-reports-a-broken-trunk-when-the-previous-runs-are-not-found \
    test-notify-reports-nothing-when-a-newer-run-has-finished \
    test-notify-ignores-a-newer-run-that-was-cancelled \
    test-notify-checks-recovery-only-when-stopping-the-line \
    test-notify-cleans-text-the-pipeline-does-not-control \
    test-notify-shows-a-bot-as-the-trigger \
    test-notify-shows-details \
    test-notify-shows-the-attempt-of-a-re-run \
    test-notify-looks-up-the-given-commit \
    test-notify-accepts-a-tag-with-build-metadata \
    test-notify-falls-back-to-the-run-commit-when-the-ref-is-unsafe \
    test-notify-reports-a-success-when-asked \
    test-notify-ignores-an-unsafe-success-link \
    test-notify-reports-a-failure-instead-of-a-success \
    test-notify-warns-when-the-webhook-is-not-configured \
    test-notify-writes-the-step-summary \
    test-notify-rejects-needs-that-are-not-json \
    test-notify-requires-the-github-actions-variables

  return 0
}

# ==============================================================================

function test-notify-reports-nothing-when-every-job-passes() {

  # Arrange
  notify-set-up "$PASSED_NEEDS"
  # Act
  notify-run STOP_THE_LINE=false
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-equal "$STATUS_NONE_OUTPUT" "$(cat "$GITHUB_OUTPUT")" "$OUTPUTS_LABEL"
  assert-stub-not-called gh

  return 0
}

function test-notify-reports-a-broken-trunk() {

  # Arrange
  local expected_text expected_facts
  notify-set-up "$FAILED_NEEDS"
  expected_text="$(printf '%s\n' \
    '**Pipeline broken.** Stop merging until it is green again. Fix forward or revert within 10 minutes.' \
    '' \
    '**Failed jobs:**' \
    '' \
    "- [🧪 Test stage / 🧪 Unit tests]($RUN_URL/100/job/11)" \
    "- [✅ Acceptance stage / Smoke]($RUN_URL/100/job/12)" \
    '' \
    "**Commit:** $COMMIT_LINE")"
  expected_facts="$(printf '%s\n' 'Workflow: 🔀 CI/CD pull request' 'Triggered by: jdoe via push')"
  # Act
  notify-run
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-file-has-line "$GITHUB_OUTPUT" "$STATUS_FAILURE_OUTPUT"
  assert-file-has-line "$GITHUB_OUTPUT" "title=🔴 PIPELINE BROKEN"
  assert-file-has-line "$GITHUB_OUTPUT" "colour=attention"
  assert-file-has-line "$GITHUB_OUTPUT" "link=$RUN_URL/100"
  assert-file-has-line "$GITHUB_OUTPUT" "link_title=View the run"
  assert-file-has-line "$GITHUB_OUTPUT" "commit=$COMMIT_SHA"
  assert-file-has-line "$GITHUB_OUTPUT" "webhook_configured=true"
  assert-equal "$expected_text" "$(notify-output text)" "text"
  assert-equal "$expected_facts" "$(notify-output facts)" "facts"
  assert-not-contains "$(cat "$GITHUB_OUTPUT")" "Scan secrets" "passed job"
  assert-not-contains "$(cat "$GITHUB_OUTPUT")" "Notify" "running job"

  return 0
}

function test-notify-reports-a-failure-without-stopping-the-line() {

  # Arrange
  notify-set-up "$FAILED_NEEDS"
  # Act
  notify-run STOP_THE_LINE=false GITHUB_WORKFLOW='📦 CI/CD publish' GITHUB_EVENT_NAME=pull_request GITHUB_REF_NAME=42/merge
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-file-has-line "$GITHUB_OUTPUT" "title=🔴 FAILED"
  assert-file-has-line "$GITHUB_OUTPUT" "colour=attention"
  assert-file-has-line "$GITHUB_OUTPUT" "**Pipeline failed.**"
  assert-file-has-line "$GITHUB_OUTPUT" "Triggered by: jdoe via pull_request"
  assert-not-contains "$(cat "$GITHUB_OUTPUT")" "Stop merging" "stop the line request"
  assert-not-contains "$(test-stub-calls gh)" "run list" "previous runs lookup"

  return 0
}

function test-notify-falls-back-to-job-ids-when-the-jobs-are-not-found() {

  # Arrange
  notify-set-up "$FAILED_NEEDS"
  rm "$TEST_TMP/jobs.json"
  # Act
  notify-run
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-contains "$TEST_STDOUT" "::warning title=Failed jobs not found::" "$WARNING_LABEL"
  assert-file-has-line "$GITHUB_OUTPUT" "- [test-stage]($RUN_URL/100)"
  assert-file-has-line "$GITHUB_OUTPUT" "- [acceptance-stage]($RUN_URL/100)"

  return 0
}

function test-notify-falls-back-to-the-ref-when-the-commit-is-not-found() {

  # Arrange
  notify-set-up "$FAILED_NEEDS"
  rm "$TEST_TMP/commit.json"
  # Act
  notify-run
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-contains "$TEST_STDOUT" "::warning title=Commit not found::" "$WARNING_LABEL"
  assert-file-has-line "$GITHUB_OUTPUT" "**Commit:** [abcdef1]($REPO_URL/commit/$COMMIT_SHA)"
  assert-file-has-line "$GITHUB_OUTPUT" "commit=$COMMIT_SHA"

  return 0
}

function test-notify-reports-the-recovery-of-a-broken-trunk() {

  # Arrange
  local expected_text
  notify-set-up "$PASSED_NEEDS"
  expected_text="$(printf '%s\n' \
    '**Pipeline is green again.** Merging can resume.' \
    '' \
    "**Broken for:** 37 minutes, since [run 7]($RUN_URL/70)" \
    '' \
    "**Fixed by:** $COMMIT_LINE")"
  printf '%s\n' "$BROKEN_RUNS_RESPONSE" > "$TEST_TMP/runs.json"
  # Act
  notify-run
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-file-has-line "$GITHUB_OUTPUT" "status=recovered"
  assert-file-has-line "$GITHUB_OUTPUT" "title=🟢 RECOVERED"
  assert-file-has-line "$GITHUB_OUTPUT" "colour=good"
  assert-equal "$expected_text" "$(notify-output text)" "text"
  assert-stub-called gh "run list --repo nhs-england-tools/example --workflow cicd-1-pull-request.yaml --branch main --event push --status completed --limit 20 --json conclusion\\,number\\,url\\,createdAt"

  return 0
}

function test-notify-reports-the-recovery-after-a-passing-re-run() {

  # Arrange
  notify-set-up "$PASSED_NEEDS"
  printf '%s\n' "$FAILED_ATTEMPT_RESPONSE" > "$TEST_TMP/attempt.json"
  # Act
  notify-run GITHUB_RUN_ATTEMPT=2
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-file-has-line "$GITHUB_OUTPUT" "status=recovered"
  assert-file-has-line "$GITHUB_OUTPUT" "**Broken for:** 15 minutes, since [run 10]($RUN_URL/100)"
  assert-stub-called gh "api repos/nhs-england-tools/example/actions/runs/100/attempts/1"

  return 0
}

function test-notify-warns-when-the-previous-attempt-is-not-found() {

  # Arrange
  notify-set-up "$PASSED_NEEDS"
  # Act
  notify-run GITHUB_RUN_ATTEMPT=2
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-contains "$TEST_STDOUT" "::warning title=Previous attempt not found::" "$WARNING_LABEL"
  assert-equal "$STATUS_NONE_OUTPUT" "$(cat "$GITHUB_OUTPUT")" "$OUTPUTS_LABEL"

  return 0
}

function test-notify-reports-nothing-when-the-previous-run-passed() {

  # Arrange
  notify-set-up "$PASSED_NEEDS"
  # Act
  notify-run
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-equal "$STATUS_NONE_OUTPUT" "$(cat "$GITHUB_OUTPUT")" "$OUTPUTS_LABEL"
  assert-equal "" "$TEST_STDERR" "stderr"

  return 0
}

function test-notify-reports-nothing-when-the-runs-before-were-cancelled() {

  # Arrange
  notify-set-up "$PASSED_NEEDS"
  printf '[{"conclusion":"cancelled","number":9,"url":"%s/90","createdAt":"2026-11-10T11:50:00Z"},{"conclusion":"success","number":8,"url":"%s/80","createdAt":"2026-11-10T11:40:00Z"}]\n' \
    "$RUN_URL" "$RUN_URL" > "$TEST_TMP/runs.json"
  # Act
  notify-run
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-equal "$STATUS_NONE_OUTPUT" "$(cat "$GITHUB_OUTPUT")" "$OUTPUTS_LABEL"

  return 0
}

function test-notify-reports-nothing-when-the-previous-runs-are-not-found() {

  # Arrange
  notify-set-up "$PASSED_NEEDS"
  rm "$TEST_TMP/runs.json"
  # Act
  notify-run
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-contains "$TEST_STDOUT" "::warning title=Previous runs not found::" "$WARNING_LABEL"
  assert-equal "$STATUS_NONE_OUTPUT" "$(cat "$GITHUB_OUTPUT")" "$OUTPUTS_LABEL"

  return 0
}

function test-notify-reports-a-broken-trunk-when-the-previous-runs-are-not-found() {

  # Arrange
  notify-set-up "$FAILED_NEEDS"
  rm "$TEST_TMP/runs.json"
  # Act
  notify-run
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-contains "$TEST_STDOUT" "::warning title=Previous runs not found::" "$WARNING_LABEL"
  assert-file-has-line "$GITHUB_OUTPUT" "$STATUS_FAILURE_OUTPUT"

  return 0
}

function test-notify-reports-nothing-when-a-newer-run-has-finished() {

  # Arrange
  local needs
  for needs in "$FAILED_NEEDS" "$PASSED_NEEDS"; do
    notify-set-up "$needs"
    printf '[{"conclusion":"success","number":11,"url":"%s/110","createdAt":"2026-11-10T11:58:00Z"},{"conclusion":"failure","number":9,"url":"%s/90","createdAt":"2026-11-10T11:50:00Z"}]\n' \
      "$RUN_URL" "$RUN_URL" > "$TEST_TMP/runs.json"
    # Act
    notify-run
    # Assert
    assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
    assert-equal "$STATUS_NONE_OUTPUT" "$(cat "$GITHUB_OUTPUT")" "$OUTPUTS_LABEL"
    assert-contains "$TEST_STDOUT" "Run 11 has already reported the state of main" "reason"
  done

  return 0
}

function test-notify-ignores-a-newer-run-that-was-cancelled() {

  # Arrange
  notify-set-up "$FAILED_NEEDS"
  printf '[{"conclusion":"cancelled","number":11,"url":"%s/110","createdAt":"2026-11-10T11:58:00Z"}]\n' "$RUN_URL" > "$TEST_TMP/runs.json"
  # Act
  notify-run
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-file-has-line "$GITHUB_OUTPUT" "$STATUS_FAILURE_OUTPUT"

  return 0
}

function test-notify-checks-recovery-only-when-stopping-the-line() {

  # Arrange
  notify-set-up "$PASSED_NEEDS"
  printf '%s\n' "$BROKEN_RUNS_RESPONSE" > "$TEST_TMP/runs.json"
  # Act
  notify-run STOP_THE_LINE=false
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-equal "$STATUS_NONE_OUTPUT" "$(cat "$GITHUB_OUTPUT")" "$OUTPUTS_LABEL"
  assert-stub-not-called gh

  return 0
}

function test-notify-cleans-text-the-pipeline-does-not-control() {

  # Arrange
  notify-set-up "$FAILED_NEEDS"
  # shellcheck disable=SC2016
  printf '{"jobs":[{"name":"Test [click](https://evil.example) <b>*now*</b> & `run`\\u202e","conclusion":"failure","html_url":"javascript:alert(1)"}]}\n' > "$TEST_TMP/jobs.json"
  printf '{"sha":"%s","html_url":"https://github.com/x","commit":{"message":"Revert \\"Add _widget_\\" 🚀\\u0007\\tnow"}}\n' "$COMMIT_SHA" > "$TEST_TMP/commit.json"
  # Act
  notify-run GITHUB_ACTOR='[jdoe](https://evil.example)'
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-file-has-line "$GITHUB_OUTPUT" "- Test click(https://evil.example) bnow/b run"
  assert-file-has-line "$GITHUB_OUTPUT" "**Commit:** [abcdef1](https://github.com/x) Revert Add widget 🚀 now"
  assert-file-has-line "$GITHUB_OUTPUT" "Triggered by: jdoe(https://evil.example) via push"

  return 0
}

function test-notify-shows-a-bot-as-the-trigger() {

  # Arrange
  notify-set-up "$FAILED_NEEDS"
  # Act
  notify-run 'GITHUB_ACTOR=dependabot[bot]'
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-file-has-line "$GITHUB_OUTPUT" "Triggered by: dependabot (bot) via push"

  return 0
}

function test-notify-shows-details() {

  # Arrange
  local expected_facts
  notify-set-up "$FAILED_NEEDS"
  expected_facts="$(printf '%s\n' \
    'Workflow: 🔀 CI/CD pull request' \
    'Triggered by: jdoe via push' \
    'Tag: v1.2.3' \
    'Environment: production 🏥')"
  # Act
  notify-run DETAILS=$'Tag: v1.2.3\nnot a detail\nVersion: \nEnvironment: production 🏥'
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-equal "$expected_facts" "$(notify-output facts)" "facts"

  return 0
}

function test-notify-shows-the-attempt-of-a-re-run() {

  # Arrange
  notify-set-up "$FAILED_NEEDS"
  # Act
  notify-run GITHUB_RUN_ATTEMPT=2
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-file-has-line "$GITHUB_OUTPUT" "Attempt: 2"
  assert-stub-called gh "api --paginate repos/nhs-england-tools/example/actions/runs/100/attempts/2/jobs\\?per_page=100"

  return 0
}

function test-notify-looks-up-the-given-commit() {

  # Arrange
  notify-set-up "$FAILED_NEEDS"
  # Act
  notify-run COMMIT_REF=v1.2.3
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-stub-called gh "api repos/nhs-england-tools/example/commits/v1.2.3"
  assert-file-has-line "$GITHUB_OUTPUT" "commit=$COMMIT_SHA"

  return 0
}

function test-notify-accepts-a-tag-with-build-metadata() {

  # Arrange
  notify-set-up "$FAILED_NEEDS"
  # Act
  notify-run COMMIT_REF=v1.2.3+build.1
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-stub-called gh "api repos/nhs-england-tools/example/commits/v1.2.3+build.1"
  assert-not-contains "$TEST_STDOUT" "::warning" "$WARNING_LABEL"

  return 0
}

function test-notify-falls-back-to-the-run-commit-when-the-ref-is-unsafe() {

  # Arrange
  local ref
  for ref in '../../user' 'v1;id' '-v1'; do
    notify-set-up "$FAILED_NEEDS"
    # Act
    notify-run COMMIT_REF="$ref"
    # Assert
    assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL for $ref: $TEST_STDERR"
    assert-contains "$TEST_STDOUT" "::warning title=Unsafe commit ref::" "warning for $ref"
    assert-file-has-line "$GITHUB_OUTPUT" "$STATUS_FAILURE_OUTPUT"
    assert-stub-called gh "api repos/nhs-england-tools/example/commits/$COMMIT_SHA"
    assert-not-contains "$(test-stub-calls gh)" "$ref" "lookup of $ref"
  done

  return 0
}

function test-notify-reports-a-success-when-asked() {

  # Arrange
  local expected_text
  notify-set-up "$PASSED_NEEDS"
  expected_text="$(printf '%s\n' 'Release 1.2.3 is published.' '' "**Commit:** $COMMIT_LINE")"
  # Act
  notify-run STOP_THE_LINE=false SUCCESS_TITLE='PUBLISHED: Release 1.2.3' \
    SUCCESS_TEXT='Release 1.2.3 is published.' SUCCESS_LINK="$REPO_URL/releases/tag/1.2.3"
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-file-has-line "$GITHUB_OUTPUT" "status=success"
  assert-file-has-line "$GITHUB_OUTPUT" "title=🟢 PUBLISHED: Release 1.2.3"
  assert-file-has-line "$GITHUB_OUTPUT" "colour=good"
  assert-file-has-line "$GITHUB_OUTPUT" "link=$REPO_URL/releases/tag/1.2.3"
  assert-file-has-line "$GITHUB_OUTPUT" "link_title=View"
  assert-equal "$expected_text" "$(notify-output text)" "text"

  return 0
}

function test-notify-ignores-an-unsafe-success-link() {

  # Arrange
  notify-set-up "$PASSED_NEEDS"
  # Act
  notify-run STOP_THE_LINE=false SUCCESS_TITLE='DEPLOYED: v1.2.3' SUCCESS_LINK='javascript:alert(1)'
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-file-has-line "$GITHUB_OUTPUT" "link=$RUN_URL/100"
  assert-file-has-line "$GITHUB_OUTPUT" "link_title=View the run"

  return 0
}

function test-notify-reports-a-failure-instead-of-a-success() {

  # Arrange
  notify-set-up "$FAILED_NEEDS"
  # Act
  notify-run STOP_THE_LINE=false SUCCESS_TITLE='DEPLOYED: v1.2.3'
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-file-has-line "$GITHUB_OUTPUT" "$STATUS_FAILURE_OUTPUT"
  assert-not-contains "$(cat "$GITHUB_OUTPUT")" "DEPLOYED" "success title"

  return 0
}

function test-notify-warns-when-the-webhook-is-not-configured() {

  # Arrange
  notify-set-up "$FAILED_NEEDS"
  # Act
  notify-run WEBHOOK_CONFIGURED=false
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-file-has-line "$GITHUB_OUTPUT" "webhook_configured=false"
  assert-contains "$TEST_STDOUT" "::warning title=Team not notified::Set the TEAMS_NOTIFICATION_WEBHOOK_URL secret" "$WARNING_LABEL"

  return 0
}

function test-notify-writes-the-step-summary() {

  # Arrange
  notify-set-up "$FAILED_NEEDS"
  # Act
  notify-run
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-file-has-line "$GITHUB_STEP_SUMMARY" "### 🔴 PIPELINE BROKEN"
  assert-file-has-line "$GITHUB_STEP_SUMMARY" "- [🧪 Test stage / 🧪 Unit tests]($RUN_URL/100/job/11)"
  assert-file-has-line "$GITHUB_STEP_SUMMARY" "- **Workflow:** 🔀 CI/CD pull request"
  assert-file-has-line "$GITHUB_STEP_SUMMARY" "- **Triggered by:** jdoe via push"
  assert-file-has-line "$GITHUB_STEP_SUMMARY" "[View the run]($RUN_URL/100)"

  return 0
}

function test-notify-rejects-needs-that-are-not-json() {

  # Arrange
  notify-set-up 'not json'
  # Act
  notify-run
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "NEEDS must be the JSON object of 'toJSON(needs)'" "diagnostic"

  return 0
}

function test-notify-requires-the-github-actions-variables() {

  # Arrange
  notify-set-up "$FAILED_NEEDS"
  # Act
  notify-run GITHUB_OUTPUT=
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "GITHUB_OUTPUT is not set" "diagnostic"

  return 0
}

# ==============================================================================

# Set the GitHub Actions variables of a push to main, isolate PATH and stub the
# GitHub CLI and the clock. 'gh' prints the response file of each API call and
# fails when the file is missing. The clock reads 2026-11-10T12:00:00Z.
# Arguments:
#   $1=[results of the jobs, as toJSON(needs) prints them]
function notify-set-up() {

  local needs="$1" now
  test-isolate-path jq
  now="$(date -u -d 2026-11-10T12:00:00Z +%s)"
  printf '%s\n' "$JOBS_RESPONSE" > "$TEST_TMP/jobs.json"
  printf '%s\n' "$COMMIT_RESPONSE" > "$TEST_TMP/commit.json"
  printf '%s\n' "$PASSED_RUNS_RESPONSE" > "$TEST_TMP/runs.json"
  # shellcheck disable=SC2016
  test-stub gh 'case "$*" in
  "api --paginate "*/jobs\?per_page=100) cat "$TEST_TMP/jobs.json" ;;
  "api "*/attempts/*) cat "$TEST_TMP/attempt.json" ;;
  "api "*/commits/*) cat "$TEST_TMP/commit.json" ;;
  "run list "*) cat "$TEST_TMP/runs.json" ;;
  *) exit 1 ;;
esac'
  test-stub date "echo $now"
  NOTIFY_ENV=(
    NEEDS="$needs"
    STOP_THE_LINE=true
    WEBHOOK_CONFIGURED=true
    GITHUB_REPOSITORY=nhs-england-tools/example
    GITHUB_RUN_ID=100
    GITHUB_RUN_NUMBER=10
    GITHUB_RUN_ATTEMPT=1
    GITHUB_SHA="$COMMIT_SHA"
    GITHUB_REF_NAME=main
    GITHUB_EVENT_NAME=push
    GITHUB_WORKFLOW='🔀 CI/CD pull request'
    GITHUB_WORKFLOW_REF=nhs-england-tools/example/.github/workflows/cicd-1-pull-request.yaml@refs/heads/main
    GITHUB_ACTOR=jdoe
    GITHUB_SERVER_URL=https://github.com
    GITHUB_OUTPUT="$TEST_TMP/output"
    GITHUB_STEP_SUMMARY="$TEST_TMP/summary"
  )
  GITHUB_OUTPUT="$TEST_TMP/output"
  GITHUB_STEP_SUMMARY="$TEST_TMP/summary"

  return 0
}

# Run the script with the variables from notify-set-up, after removing the
# outputs of an earlier run.
# Arguments:
#   $@=[optional environment assignments that replace or add variables]
function notify-run() {

  rm -f "$GITHUB_OUTPUT" "$GITHUB_STEP_SUMMARY"
  touch "$GITHUB_OUTPUT" "$GITHUB_STEP_SUMMARY"
  test-capture env -i PATH="$PATH" TEST_TMP="$TEST_TMP" STUB_DIR="$STUB_DIR" LC_ALL=C \
    GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 \
    "${NOTIFY_ENV[@]}" "$@" ./scripts/cicd/notify-pipeline-status.sh

  return 0
}

# Print a multiline step output, written as 'name<<delimiter'.
# Arguments:
#   $1=[output name]
function notify-output() {

  local name="$1"
  awk -v name="$name" '
    delimiter != "" { if ($0 == delimiter) exit; print; next }
    index($0, name "<<") == 1 { delimiter = substr($0, length(name) + 3) }
  ' "$GITHUB_OUTPUT"

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
