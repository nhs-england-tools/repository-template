#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034,SC2317,SC2329

set -euo pipefail

# Test security readiness with workflows, local actions, repository metadata
# and deterministic review dates in scratch repositories using real yq and jq.
#
# Usage:
#   $ ./scripts/quality/tests/check-security-readiness.test.sh
#
# Options:
#   VERBOSE=true  # Show all the executed commands, default is 'false'

# ==============================================================================

source "$(dirname "${BASH_SOURCE[0]}")/../../tests/test.lib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/quality-test.lib.sh"

readonly SAFE_WORKFLOW='name: test
on:
  push:
permissions: {}
jobs:
  check:
    permissions:
      contents: read
    runs-on: ubuntu-latest
    timeout-minutes: 1
    steps:
      - uses: actions/checkout@0123456789012345678901234567890123456789
        with:
          persist-credentials: false'
readonly SAFE_JOB=$'name: test\non:\n  push:\npermissions: {}\njobs:\n  check:\n    permissions:\n      contents: read\n    runs-on: ubuntu-latest\n'
readonly EXIT_STATUS_LABEL='exit status'
readonly DIAGNOSTIC_LABEL='diagnostic'
readonly STDOUT_LABEL='stdout'
readonly CODEOWNERS_ERROR='ERROR: .github/CODEOWNERS:'
readonly PRIVILEGED_TRIGGER_ERROR='privileged triggers pull_request_target and workflow_run are prohibited'
readonly PRIVILEGED_WORKFLOW=$'name: test\non: pull_request_target\npermissions: {}\njobs:\n  check:\n    permissions:\n      contents: read\n    runs-on: ubuntu-latest'
readonly SECRET_SCOPE_ERROR='secret values must not be set in workflow, job, container, or service environment'
readonly TIMEOUT_ERROR="job 'check' must set timeout-minutes to a positive number or an expression"
readonly MISE_CACHE_ERROR='jdx/mise-action must set cache: false in a workflow that never runs for a pull request, a merge queue or a caller'
readonly TIMEOUT_AND_MISE_STEPS=$'    timeout-minutes: 1\n    steps:\n      - uses: jdx/mise-action@0123456789012345678901234567890123456789\n        with:\n          persist_github_token: false\n'
readonly SAFE_OWNERS=$'# Review-by: 2027-01-01\n* @nhs-england-tools/engineering-experience'
readonly SAFE_SECURITY=$'# Security\n## Reporting a vulnerability\ncybersecurity@nhs.net\nNCSC\n## General security enquiries'
readonly REVIEW_DATE_STUB="printf '%s\\n' \"\${REVIEW_TODAY:-2026-11-14}\""

# Set up the suite fixtures and run every test.
function main() {

  cd "$(git rev-parse --show-toplevel)"

  QUALITY_FIXTURE_PATHS=(LICENCE.md scripts/quality/check-security-readiness.sh scripts/quality/check-security-readiness.jq scripts/quality/git-files.lib.sh scripts/quality/git-base.lib.sh scripts/cicd/github-actions.lib.sh)
  QUALITY_FIXTURE_FORMAT='# %s\n'

  # The caller's options must not reach the script under test
  unset -v check dir actions_dir allowlist BRANCH_NAME GITHUB_BASE_REF QUALITY_PR_BASE FORCE_USE_DOCKER
  unset -v REVIEW_TODAY TEST_DATE_STUB GITHUB_ACTIONS

  test-run-suite \
    test-security-readiness-rejects-unknown-mode \
    test-security-readiness-skips-untracked-files \
    test-security-readiness-fails-without-tracked-workflows \
    test-security-readiness-scoped-mode-checks-only-changed-files \
    test-security-readiness-scoped-mode-without-changes-passes \
    test-security-readiness-scoped-mode-checks-every-file-when-the-allowlist-changes \
    test-security-readiness-scoped-mode-checks-every-file-when-the-rules-change \
    test-security-readiness-branch-checks-changed-files \
    test-security-readiness-reports-a-missing-base \
    test-security-readiness-accepts-safe-workflow \
    test-security-readiness-rejects-inherited-workflow-permissions \
    test-security-readiness-rejects-job-without-permissions \
    test-security-readiness-rejects-persisted-checkout-credentials \
    test-security-readiness-matches-action-names-case-insensitively \
    test-security-readiness-rejects-unpinned-action \
    test-security-readiness-rejects-secret-expression-in-run \
    test-security-readiness-rejects-expression-in-run \
    test-security-readiness-rejects-expression-in-github-script \
    test-security-readiness-rejects-privileged-trigger \
    test-security-readiness-rejects-privileged-trigger-string \
    test-security-readiness-rejects-privileged-trigger-list \
    test-security-readiness-annotates-errors-in-github-actions \
    test-security-readiness-annotates-a-captured-allowlist-error \
    test-security-readiness-rejects-inherited-secrets \
    test-security-readiness-rejects-job-wide-secret \
    test-security-readiness-rejects-job-wide-secret-inside-expression \
    test-security-readiness-rejects-job-wide-secret-index-syntax \
    test-security-readiness-rejects-job-wide-multi-line-secret \
    test-security-readiness-rejects-container-secret \
    test-security-readiness-rejects-service-secret \
    test-security-readiness-allows-job-wide-secret-presence-check \
    test-security-readiness-allows-step-scoped-secret \
    test-security-readiness-rejects-unapproved-write-permission \
    test-security-readiness-accepts-approved-write-permission \
    test-security-readiness-rejects-write-permission-approved-for-another-workflow \
    test-security-readiness-requires-explicit-mise-token-non-persistence \
    test-security-readiness-rejects-mise-cache-in-publish-workflow \
    test-security-readiness-rejects-mise-cache-left-at-its-true-default-in-deploy-workflow \
    test-security-readiness-accepts-mise-cache-off-in-publish-workflow \
    test-security-readiness-allows-mise-cache-for-pull-request-merge-queue-and-called-workflows \
    test-security-readiness-rejects-job-without-timeout \
    test-security-readiness-rejects-zero-timeout \
    test-security-readiness-accepts-timeout-expression \
    test-security-readiness-exempts-reusable-workflow-call-from-timeout \
    test-security-readiness-rejects-unquoted-github-output \
    test-security-readiness-rejects-unquoted-github-env-in-action \
    test-security-readiness-rejects-unquoted-github-output-through-tee \
    test-security-readiness-rejects-every-unquoted-tee-operand \
    test-security-readiness-names-an-unquoted-github-file-with-a-default \
    test-security-readiness-ignores-variables-that-only-start-with-a-github-file-name \
    test-security-readiness-accepts-quoted-github-output \
    test-security-readiness-rejects-expression-in-action-run \
    test-security-readiness-rejects-unpinned-action-step \
    test-security-readiness-rejects-unparseable-file \
    test-security-readiness-reports-yaml-parse-error \
    test-security-readiness-rejects-dockerised-quality-action-without-force-docker \
    test-security-readiness-accepts-dockerised-quality-action-with-force-docker \
    test-security-readiness-warns-once-for-dockerised-quality-action-optout \
    test-security-readiness-rejects-mixed-docker-action-mode \
    test-security-readiness-accepts-dockerised-quality-action-with-boolean-force-docker \
    test-security-readiness-rejects-mise-in-dockerised-quality-job \
    test-security-readiness-review-date-boundaries \
    test-security-readiness-review-date-year-limit \
    test-security-readiness-review-date-month-ends \
    test-security-readiness-review-date-invalid-headers \
    test-security-readiness-review-date-missing-file \
    test-security-readiness-review-date-rejects-symlink \
    test-security-readiness-review-date-scoped-runs \
    test-security-readiness-review-date-clock-failure \
    test-security-readiness-review-date-ci-warning \
    test-security-readiness-review-date-ci-error \
    test-security-readiness-combined-failures \
    test-security-readiness-combined-unchanged-baseline \
    test-security-readiness-combined-warning-once \
    test-security-readiness-warns-once-when-docker-is-disabled \
    test-security-readiness-repository-accepts-safe-baseline \
    test-security-readiness-repository-rejects-invalid-owners \
    test-security-readiness-repository-ignores-comment-owners \
    test-security-readiness-repository-rejects-unsupported-patterns \
    test-security-readiness-repository-requires-effective-team-catchall \
    test-security-readiness-repository-accepts-escaped-paths-and-exclusions \
    test-security-readiness-repository-ignores-escape-examples-in-comments \
    test-security-readiness-repository-rejects-missing-files \
    test-security-readiness-repository-rejects-empty-documents \
    test-security-readiness-repository-resolves-supported-document-locations \
    test-security-readiness-repository-rejects-invalid-preferred-document \
    test-security-readiness-repository-ignores-untracked-documents \
    test-security-readiness-repository-ignores-untracked-codeowners \
    test-security-readiness-repository-requires-security-markers \
    test-security-readiness-repository-warns-for-adoption-placeholders \
    test-security-readiness-repository-warns-for-todos \
    test-security-readiness-repository-todos-in-every-mode \
    test-security-readiness-repository-todos-respect-document-selection \
    test-security-readiness-repository-ignores-todo-without-colon \
    test-security-readiness-repository-accepts-approved-licences \
    test-security-readiness-repository-rejects-modified-licences \
    test-security-readiness-repository-allows-licence-formatting-and-copyright \
    test-security-readiness-repository-checks-unchanged-scoped-runs \
    test-security-readiness-repository-rejects-unknown-mode \
    test-security-readiness-repository-reports-missing-tool \
    test-security-readiness-repository-fails-on-jq-error \
    test-security-readiness-repository-policy-cannot-be-configured \
    test-security-readiness-precommit-order \
    test-security-readiness-ci-order \
    test-security-readiness-checks-repository-workflows

  return 0
}

# Build the fixture repository once, every test starts from a copy.
function test-suite-setup() {

  quality-build-fixture-base

  return 0
}

# ==============================================================================

function test-security-readiness-rejects-unknown-mode() {

  # Arrange
  security-readiness-write-fixture workflows/test.yaml "$SAFE_WORKFLOW"
  security-readiness-create-repo
  # Act
  security-readiness-run-check check=bogus
  # Assert
  assert-equal 126 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "Use check=all, check=staged-changes, check=working-tree-changes, check=branch" "accepted modes"

  return 0
}

function test-security-readiness-skips-untracked-files() {

  # Arrange
  security-readiness-write-fixture workflows/test.yaml "$SAFE_WORKFLOW"
  security-readiness-create-repo
  printf '%s\n' "$PRIVILEGED_WORKFLOW" > "$TEST_TMP/repo/.github/workflows/untracked.yaml"
  mkdir -p "$TEST_TMP/repo/.github/actions/untracked"
  printf 'name: untracked\nruns:\n  using: composite\n  steps:\n    - uses: example/action@v1\n' > "$TEST_TMP/repo/.github/actions/untracked/action.yaml"
  # Act
  security-readiness-run-check
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-equal "" "$TEST_STDERR" "stderr"

  return 0
}

function test-security-readiness-fails-without-tracked-workflows() {

  # Arrange
  security-readiness-write-fixture workflows/test.yaml "$SAFE_WORKFLOW"
  security-readiness-create-repo
  git -C "$TEST_TMP/repo" rm -q --cached .github/workflows/test.yaml
  # Act
  security-readiness-run-check
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "no tracked workflow files found under .github/workflows" "no workflows diagnostic"

  return 0
}

function test-security-readiness-scoped-mode-checks-only-changed-files() {

  # Arrange
  security-readiness-write-fixture workflows/existing.yaml "$PRIVILEGED_WORKFLOW"
  security-readiness-write-fixture workflows/test.yaml "$SAFE_WORKFLOW"
  security-readiness-create-repo
  printf '%s\n' "${SAFE_WORKFLOW/name: test/name: changed}" > "$TEST_TMP/repo/.github/workflows/test.yaml"
  security-readiness-write-fixture repo/.github/workflows/new.yaml "$PRIVILEGED_WORKFLOW"
  git -C "$TEST_TMP/repo" add .github/workflows/new.yaml
  # Act
  security-readiness-run-check check=staged-changes
  # Assert
  assert-equal 1 "$TEST_STATUS" "staged-changes $EXIT_STATUS_LABEL"
  assert-equal "ERROR: .github/workflows/new.yaml: $PRIVILEGED_TRIGGER_ERROR" "$TEST_STDERR" "only the staged workflow"
  # Act
  security-readiness-run-check check=working-tree-changes
  # Assert
  assert-equal 0 "$TEST_STATUS" "working-tree-changes $EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-equal "" "$TEST_STDERR" "only the unstaged safe workflow"

  return 0
}

function test-security-readiness-scoped-mode-without-changes-passes() {

  # Arrange
  security-readiness-write-fixture workflows/test.yaml "$PRIVILEGED_WORKFLOW"
  security-readiness-create-repo
  # Act
  security-readiness-run-check check=staged-changes
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "" "$TEST_STDERR" "stderr"

  return 0
}

function test-security-readiness-scoped-mode-checks-every-file-when-the-allowlist-changes() {

  # Arrange
  security-readiness-write-fixture workflows/test.yaml "${SAFE_JOB/contents: read/contents: write}"
  security-readiness-write-fixture allowlist.yaml $'approved_write_permissions:\n  - workflow: test.yaml\n    job: check\n    permission: contents'
  security-readiness-create-repo
  printf 'approved_write_permissions: []\n' > "$TEST_TMP/repo/scripts/config/security-readiness.yaml"
  git -C "$TEST_TMP/repo" add scripts/config/security-readiness.yaml
  # Act
  security-readiness-run-check check=staged-changes
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" ".github/workflows/test.yaml: write permission is not approved for job 'check'" "the unchanged workflow"

  return 0
}

function test-security-readiness-scoped-mode-checks-every-file-when-the-rules-change() {

  # Arrange
  local rule_file content
  security-readiness-write-fixture workflows/test.yaml "$PRIVILEGED_WORKFLOW"
  security-readiness-create-repo
  for rule_file in scripts/quality/check-security-readiness.jq scripts/quality/check-security-readiness.sh; do
    # Replace the file, as an executable fixture links to the real script
    content="$(cat "$TEST_TMP/repo/$rule_file")"
    rm "$TEST_TMP/repo/$rule_file"
    printf '%s\n# changed\n' "$content" > "$TEST_TMP/repo/$rule_file"
    chmod 755 "$TEST_TMP/repo/$rule_file"
    git -C "$TEST_TMP/repo" add "$rule_file"
    # Act
    security-readiness-run-check check=staged-changes
    # Assert
    assert-equal 1 "$TEST_STATUS" "$rule_file $EXIT_STATUS_LABEL"
    assert-equal "ERROR: .github/workflows/test.yaml: $PRIVILEGED_TRIGGER_ERROR" "$TEST_STDERR" "$rule_file: the unchanged workflow"
    git -C "$TEST_TMP/repo" checkout -q HEAD -- "$rule_file"
  done

  return 0
}

function test-security-readiness-branch-checks-changed-files() {

  # Arrange
  security-readiness-write-fixture workflows/existing.yaml "$PRIVILEGED_WORKFLOW"
  security-readiness-write-fixture workflows/test.yaml "$SAFE_WORKFLOW"
  security-readiness-create-repo
  git -C "$TEST_TMP/repo" switch -q -c feature
  printf '%s\n' "$PRIVILEGED_WORKFLOW" > "$TEST_TMP/repo/.github/workflows/test.yaml"
  git -C "$TEST_TMP/repo" commit -q -am 'privileged trigger'
  # Act
  security-readiness-run-check check=branch BRANCH_NAME=main
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" ".github/workflows/test.yaml: $PRIVILEGED_TRIGGER_ERROR" "the changed workflow"
  assert-not-contains "$TEST_STDERR" "existing.yaml" "the unchanged workflow"

  return 0
}

function test-security-readiness-reports-a-missing-base() {

  # Arrange
  security-readiness-write-fixture workflows/test.yaml "$SAFE_WORKFLOW"
  security-readiness-create-repo
  git -C "$TEST_TMP/repo" switch -q -c feature
  # Act
  security-readiness-run-check check=branch BRANCH_NAME=missing
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "Branch to compare with not found: missing" "missing base diagnostic"

  return 0
}

function test-security-readiness-accepts-safe-workflow() {

  security-readiness-check-fixture "$SAFE_WORKFLOW"
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"

  return 0
}

function test-security-readiness-rejects-inherited-workflow-permissions() {

  local workflow=$'name: test\non:\n  push\npermissions:\n  contents: read\njobs:\n  check:\n    permissions:\n      contents: read\n    runs-on: ubuntu-latest\n'
  security-readiness-check-fixture "$workflow"
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "workflow permissions must be empty"

  return 0
}

function test-security-readiness-rejects-job-without-permissions() {

  local workflow=$'name: test\non:\n  push\npermissions: {}\njobs:\n  check:\n    runs-on: ubuntu-latest\n'
  security-readiness-check-fixture "$workflow"
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "job 'check' must declare permissions"

  return 0
}

function test-security-readiness-rejects-persisted-checkout-credentials() {

  local workflow=$'name: test\non:\n  push\npermissions: {}\njobs:\n  check:\n    permissions:\n      contents: read\n    runs-on: ubuntu-latest\n    steps:\n      - uses: actions/checkout@0123456789012345678901234567890123456789\n        with:\n          persist-credentials: true\n'
  security-readiness-check-fixture "$workflow"
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "actions/checkout must set persist-credentials: false"

  return 0
}

function test-security-readiness-matches-action-names-case-insensitively() {

  security-readiness-check-fixture "$SAFE_JOB"$'    steps:\n      - uses: Actions/Checkout@0123456789012345678901234567890123456789\n'
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "actions/checkout must set persist-credentials: false"

  return 0
}

function test-security-readiness-rejects-unpinned-action() {

  local workflow=$'name: test\non:\n  push\npermissions: {}\njobs:\n  check:\n    permissions:\n      contents: read\n    runs-on: ubuntu-latest\n    steps:\n      - uses: example/action@v1\n'
  security-readiness-check-fixture "$workflow"
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "action ref is not a full 40-character SHA"

  return 0
}

function test-security-readiness-rejects-secret-expression-in-run() {

  local workflow=$'name: test\non:\n  push\npermissions: {}\njobs:\n  check:\n    permissions:\n      contents: read\n    runs-on: ubuntu-latest\n    steps:\n      - run: echo \'${{ secrets.TOKEN }}\'\n'
  security-readiness-check-fixture "$workflow"
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "secrets must not be interpolated into run scripts"

  return 0
}

function test-security-readiness-rejects-expression-in-run() {

  local workflow=$'name: test\non:\n  push\npermissions: {}\njobs:\n  check:\n    permissions:\n      contents: read\n    runs-on: ubuntu-latest\n    steps:\n      - run: echo "${{ github.event.pull_request.title }}"\n'
  security-readiness-check-fixture "$workflow"
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "expressions must not be interpolated into run scripts"

  return 0
}

function test-security-readiness-rejects-expression-in-github-script() {

  security-readiness-check-fixture "$SAFE_JOB"$'    steps:\n      - uses: actions/github-script@0123456789012345678901234567890123456789\n        with:\n          script: core.info("${{ github.event.issue.title }}")\n'
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "expressions must not be interpolated into actions/github-script scripts"

  return 0
}

function test-security-readiness-rejects-privileged-trigger() {

  local workflow=$'name: test\non:\n  pull_request_target:\n    types: [opened]\npermissions: {}\njobs:\n  check:\n    permissions:\n      contents: read\n    runs-on: ubuntu-latest\n'
  security-readiness-check-fixture "$workflow"
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "$PRIVILEGED_TRIGGER_ERROR"

  return 0
}

function test-security-readiness-rejects-inherited-secrets() {

  local workflow=$'name: test\non:\n  push\npermissions: {}\njobs:\n  check:\n    permissions:\n      contents: read\n    secrets: inherit\n    runs-on: ubuntu-latest\n'
  security-readiness-check-fixture "$workflow"
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "secrets: inherit is prohibited"

  return 0
}

function test-security-readiness-rejects-job-wide-secret() {

  local workflow=$'name: test\non:\n  push\npermissions: {}\njobs:\n  check:\n    permissions:\n      contents: read\n    env:\n      TOKEN: "${{ secrets.TOKEN }}"\n    runs-on: ubuntu-latest\n'
  security-readiness-check-fixture "$workflow"
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "$SECRET_SCOPE_ERROR"

  return 0
}

function test-security-readiness-allows-step-scoped-secret() {

  local workflow=$'name: test\non:\n  push\npermissions: {}\njobs:\n  check:\n    permissions:\n      contents: read\n    runs-on: ubuntu-latest\n    timeout-minutes: 1\n    steps:\n      - uses: example/action@0123456789012345678901234567890123456789\n        env:\n          TOKEN: "${{ secrets.TOKEN }}"\n'
  security-readiness-check-fixture "$workflow"
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"

  return 0
}

function test-security-readiness-rejects-unapproved-write-permission() {

  local workflow=$'name: test\non:\n  push\npermissions: {}\njobs:\n  check:\n    permissions:\n      contents: write\n    runs-on: ubuntu-latest\n'
  security-readiness-check-fixture "$workflow"
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "write permission is not approved for job 'check'"

  return 0
}

function test-security-readiness-requires-explicit-mise-token-non-persistence() {

  local workflow=$'name: test\non:\n  push\npermissions: {}\njobs:\n  check:\n    permissions:\n      contents: read\n    runs-on: ubuntu-latest\n    steps:\n      - uses: jdx/mise-action@0123456789012345678901234567890123456789\n'
  security-readiness-check-fixture "$workflow"
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "jdx/mise-action must set persist_github_token: false"

  return 0
}

function test-security-readiness-rejects-mise-cache-in-publish-workflow() {

  security-readiness-check-fixture "$SAFE_JOB$TIMEOUT_AND_MISE_STEPS"$'          cache: true\n'
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "ERROR: .github/workflows/test.yaml: $MISE_CACHE_ERROR" "$TEST_STDERR" "$DIAGNOSTIC_LABEL"

  return 0
}

# jdx/mise-action defaults its cache input to "true" in its action.yml.
function test-security-readiness-rejects-mise-cache-left-at-its-true-default-in-deploy-workflow() {

  security-readiness-check-fixture "${SAFE_JOB/push:/workflow_dispatch:}$TIMEOUT_AND_MISE_STEPS"
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "ERROR: .github/workflows/test.yaml: $MISE_CACHE_ERROR" "$TEST_STDERR" "$DIAGNOSTIC_LABEL"

  return 0
}

function test-security-readiness-accepts-mise-cache-off-in-publish-workflow() {

  security-readiness-check-fixture "$SAFE_JOB$TIMEOUT_AND_MISE_STEPS"$'          cache: false\n'
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"

  return 0
}

function test-security-readiness-allows-mise-cache-for-pull-request-merge-queue-and-called-workflows() {

  local trigger triggers
  for trigger in pull_request merge_group workflow_call; do
    triggers=$'push:\n  '"$trigger:"
    security-readiness-check-fixture "${SAFE_JOB/push:/$triggers}$TIMEOUT_AND_MISE_STEPS"$'          cache: true\n'
    assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL for $trigger: $TEST_STDERR"
    rm -rf "$TEST_TMP/repo"
  done

  return 0
}

function test-security-readiness-rejects-job-without-timeout() {

  security-readiness-check-fixture "$SAFE_JOB"$'    steps:\n      - run: echo ok\n'
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "$TIMEOUT_ERROR"

  return 0
}

function test-security-readiness-rejects-zero-timeout() {

  security-readiness-check-fixture "$SAFE_JOB"$'    timeout-minutes: 0\n    steps:\n      - run: echo ok\n'
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "$TIMEOUT_ERROR"

  return 0
}

function test-security-readiness-accepts-timeout-expression() {

  security-readiness-check-fixture "$SAFE_JOB"$'    timeout-minutes: ${{ inputs.timeout }}\n    steps:\n      - run: echo ok\n'
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"

  return 0
}

function test-security-readiness-exempts-reusable-workflow-call-from-timeout() {

  security-readiness-check-fixture $'name: test\non:\n  push:\npermissions: {}\njobs:\n  call:\n    permissions:\n      contents: read\n    uses: ./.github/workflows/other.yaml\n'
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"

  return 0
}

function test-security-readiness-rejects-unquoted-github-output() {

  # shellcheck disable=SC2016
  security-readiness-check-fixture "$SAFE_JOB"$'    timeout-minutes: 1\n    steps:\n      - run: |\n          echo "a=b" >> "$GITHUB_OUTPUT"\n          echo "c=d" >>$GITHUB_OUTPUT\n'
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  # shellcheck disable=SC2016
  assert-equal 'ERROR: .github/workflows/test.yaml: run scripts must quote $GITHUB_OUTPUT where they write to it, as >> "$GITHUB_OUTPUT"' "$TEST_STDERR" "$DIAGNOSTIC_LABEL"

  return 0
}

function test-security-readiness-rejects-unquoted-github-env-in-action() {

  # shellcheck disable=SC2016
  security-readiness-write-fixture actions/example/action.yaml $'name: example\nruns:\n  using: composite\n  steps:\n    - shell: bash\n      run: echo "A=b" > ${GITHUB_ENV}'
  security-readiness-check-fixture "$SAFE_WORKFLOW"
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  # shellcheck disable=SC2016
  assert-contains "$TEST_STDERR" 'actions/example/action.yaml: run scripts must quote $GITHUB_ENV where they write to it, as >> "$GITHUB_ENV"'

  return 0
}

function test-security-readiness-rejects-unquoted-github-output-through-tee() {

  security-readiness-check-fixture "$SAFE_JOB"$'    timeout-minutes: 1\n    steps:\n      - run: echo "a=b" | tee -a $GITHUB_OUTPUT\n'
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  # shellcheck disable=SC2016
  assert-contains "$TEST_STDERR" 'run scripts must quote $GITHUB_OUTPUT where they write to it' "$DIAGNOSTIC_LABEL"

  return 0
}

function test-security-readiness-rejects-every-unquoted-tee-operand() {

  security-readiness-check-fixture "$SAFE_JOB"$'    timeout-minutes: 1\n    steps:\n      - run: echo "a=b" | tee -a "$GITHUB_OUTPUT" $GITHUB_STEP_SUMMARY\n'
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  # shellcheck disable=SC2016
  assert-equal 'ERROR: .github/workflows/test.yaml: run scripts must quote $GITHUB_STEP_SUMMARY where they write to it, as >> "$GITHUB_STEP_SUMMARY"' "$TEST_STDERR" "$DIAGNOSTIC_LABEL"

  return 0
}

function test-security-readiness-names-an-unquoted-github-file-with-a-default() {

  security-readiness-check-fixture "$SAFE_JOB"$'    timeout-minutes: 1\n    steps:\n      - run: echo "a=b" >> ${GITHUB_OUTPUT:-/dev/null}\n'
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  # shellcheck disable=SC2016
  assert-equal 'ERROR: .github/workflows/test.yaml: run scripts must quote $GITHUB_OUTPUT where they write to it, as >> "$GITHUB_OUTPUT"' "$TEST_STDERR" "$DIAGNOSTIC_LABEL"

  return 0
}

function test-security-readiness-ignores-variables-that-only-start-with-a-github-file-name() {

  security-readiness-check-fixture "$SAFE_JOB"$'    timeout-minutes: 1\n    steps:\n      - run: echo "a=b" >> $GITHUB_OUTPUT_COPY\n'
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"

  return 0
}

function test-security-readiness-accepts-quoted-github-output() {

  security-readiness-check-fixture "$SAFE_JOB"$'    timeout-minutes: 1\n    steps:\n      - run: |\n          printf \'a=%s\\n\' "$A" >> "$GITHUB_OUTPUT"\n          echo "### Done" >> "${GITHUB_STEP_SUMMARY}"\n'
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"

  return 0
}

function test-security-readiness-rejects-privileged-trigger-string() {

  security-readiness-check-fixture $'name: test\non: pull_request_target\npermissions: {}\njobs:\n  check:\n    permissions:\n      contents: read\n    runs-on: ubuntu-latest'
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "$PRIVILEGED_TRIGGER_ERROR"

  return 0
}

function test-security-readiness-rejects-privileged-trigger-list() {

  security-readiness-check-fixture $'name: test\non: [push, workflow_run]\npermissions: {}\njobs:\n  check:\n    permissions:\n      contents: read\n    runs-on: ubuntu-latest'
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "$PRIVILEGED_TRIGGER_ERROR"

  return 0
}

function test-security-readiness-annotates-errors-in-github-actions() {

  # Arrange
  security-readiness-write-fixture workflows/test.yaml "$PRIVILEGED_WORKFLOW"
  security-readiness-create-repo
  # Act
  security-readiness-run-check GITHUB_ACTIONS=true
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "::error::.github/workflows/test.yaml: $PRIVILEGED_TRIGGER_ERROR" "$TEST_STDERR" "annotation"
  assert-equal "" "$TEST_STDOUT" "$STDOUT_LABEL"

  return 0
}

function test-security-readiness-annotates-a-captured-allowlist-error() {

  # Arrange
  security-readiness-write-fixture workflows/test.yaml "$SAFE_WORKFLOW"
  security-readiness-write-fixture allowlist.yaml 'approved_write_permissions: invalid'
  security-readiness-create-repo
  # Act
  security-readiness-run-check GITHUB_ACTIONS=true
  # Assert, an annotation captured with the allowlist would not reach stderr
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" \
    '::error::approved_write_permissions in scripts/config/security-readiness.yaml must be a list of mappings' "annotation"
  assert-not-contains "$TEST_STDERR" 'ERROR:' "local text"
  assert-equal "" "$TEST_STDOUT" "$STDOUT_LABEL"

  return 0
}

function test-security-readiness-rejects-job-wide-secret-inside-expression() {

  security-readiness-check-fixture "$SAFE_JOB"$'    env:\n      AUTH: "Bearer ${{ secrets.TOKEN }}"\n'
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "$SECRET_SCOPE_ERROR"

  return 0
}

function test-security-readiness-rejects-job-wide-secret-index-syntax() {

  security-readiness-check-fixture "$SAFE_JOB"$'    env:\n      TOKEN: ${{ secrets[\'TOKEN\'] }}\n'
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "$SECRET_SCOPE_ERROR"

  return 0
}

function test-security-readiness-rejects-job-wide-multi-line-secret() {

  security-readiness-check-fixture "$SAFE_JOB"$'    env:\n      TOKEN: |\n        ${{\n          secrets.TOKEN\n        }}\n'
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "$SECRET_SCOPE_ERROR"

  return 0
}

function test-security-readiness-rejects-container-secret() {

  security-readiness-check-fixture "$SAFE_JOB"$'    container:\n      image: alpine\n      env:\n        TOKEN: ${{ secrets.TOKEN }}\n'
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "$SECRET_SCOPE_ERROR"

  return 0
}

function test-security-readiness-rejects-service-secret() {

  security-readiness-check-fixture "$SAFE_JOB"$'    services:\n      db:\n        image: postgres\n        env:\n          POSTGRES_PASSWORD: ${{ secrets.DB_PASSWORD }}\n'
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "$SECRET_SCOPE_ERROR"

  return 0
}

function test-security-readiness-allows-job-wide-secret-presence-check() {

  security-readiness-check-fixture "$SAFE_JOB"$'    env:\n      HAS_TOKEN: ${{ secrets.TOKEN != \'\' && vars.KEY != \'\' }}\n'
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"

  return 0
}

function test-security-readiness-accepts-approved-write-permission() {

  security-readiness-write-fixture allowlist.yaml $'approved_write_permissions:\n  - workflow: test.yaml\n    job: check\n    permission: contents'
  security-readiness-check-fixture "${SAFE_JOB/contents: read/contents: write}"
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"

  return 0
}

function test-security-readiness-rejects-write-permission-approved-for-another-workflow() {

  security-readiness-write-fixture allowlist.yaml $'approved_write_permissions:\n  - workflow: other.yaml\n    job: check\n    permission: contents'
  security-readiness-check-fixture "${SAFE_JOB/contents: read/contents: write}"
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "write permission is not approved for job 'check'"

  return 0
}

function test-security-readiness-rejects-expression-in-action-run() {

  security-readiness-write-fixture actions/example/action.yaml $'name: example\nruns:\n  using: composite\n  steps:\n    - shell: bash\n      run: echo "${{ github.ref_name }}"'
  security-readiness-check-fixture "$SAFE_WORKFLOW"
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "actions/example/action.yaml: expressions must not be interpolated into run scripts"

  return 0
}

function test-security-readiness-rejects-unpinned-action-step() {

  security-readiness-write-fixture actions/example/action.yaml $'name: example\nruns:\n  using: composite\n  steps:\n    - uses: example/action@v1'
  security-readiness-check-fixture "$SAFE_WORKFLOW"
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "actions/example/action.yaml: action ref is not a full 40-character SHA"

  return 0
}

function test-security-readiness-rejects-unparseable-file() {

  security-readiness-check-fixture $'- not a workflow mapping'
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "file is not a valid YAML mapping"

  return 0
}

function test-security-readiness-reports-yaml-parse-error() {

  security-readiness-check-fixture $'name: test\non: push\njobs:\n  check:\n    steps: [\n'
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "did not find expected node content"
  assert-contains "$TEST_STDERR" "file is not a valid YAML mapping"

  return 0
}

function test-security-readiness-rejects-dockerised-quality-action-without-force-docker() {

  security-readiness-write-fixture actions/check-markdown-format/action.yaml $'name: Check Markdown format\nruns:\n  using: composite\n  steps:\n    - name: Check Markdown format\n      shell: bash\n      run: make check-markdown-format'
  security-readiness-check-fixture "$SAFE_WORKFLOW"
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "actions/check-markdown-format/action.yaml: dockerised quality action must set FORCE_USE_DOCKER=true on every run step"

  return 0
}

function test-security-readiness-accepts-dockerised-quality-action-with-force-docker() {

  security-readiness-write-fixture actions/check-markdown-format/action.yaml $'name: Check Markdown format\nruns:\n  using: composite\n  steps:\n    - name: Check Markdown format\n      shell: bash\n      env:\n        FORCE_USE_DOCKER: "true"\n      run: make check-markdown-format'
  security-readiness-check-fixture "$SAFE_WORKFLOW"
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"

  return 0
}

function test-security-readiness-warns-once-for-dockerised-quality-action-optout() {

  local optout_action=$'name: quality check\nruns:\n  using: composite\n  steps:\n    - shell: bash\n      env:\n        FORCE_USE_DOCKER: "false"\n      run: make lint-markdown-format'
  security-readiness-write-fixture actions/check-file-format/action.yaml "$optout_action"
  security-readiness-write-fixture actions/check-markdown-format/action.yaml "$optout_action"
  security-readiness-check-fixture "$SAFE_WORKFLOW"
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-equal 1 "$(awk '/WARNING: FORCE_USE_DOCKER=false/ { count++ } END { print count + 0 }' <<< "$TEST_STDERR")" \
    'multiple CI opt-outs produce one warning'
  assert-not-contains "$TEST_STDERR" 'ERROR: actions/' 'explicit opt-out is not an error'

  return 0
}

function test-security-readiness-rejects-mixed-docker-action-mode() {

  security-readiness-write-fixture actions/check-file-format/action.yaml $'name: Check file format\nruns:\n  using: composite\n  steps:\n    - shell: bash\n      env:\n        FORCE_USE_DOCKER: "true"\n      run: make lint-file-format\n    - shell: bash\n      env:\n        FORCE_USE_DOCKER: "false"\n      run: make lint-file-format'
  security-readiness-check-fixture "$SAFE_WORKFLOW"
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" 'dockerised quality action must set FORCE_USE_DOCKER=true on every run step'

  return 0
}

function test-security-readiness-accepts-dockerised-quality-action-with-boolean-force-docker() {

  security-readiness-write-fixture actions/check-shell-lint/action.yaml $'name: Check shell scripts\nruns:\n  using: composite\n  steps:\n    - name: Check shell scripts\n      shell: bash\n      env:\n        FORCE_USE_DOCKER: true\n      run: make check-shell-lint'
  security-readiness-check-fixture "$SAFE_WORKFLOW"
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"

  return 0
}

function test-security-readiness-rejects-mise-in-dockerised-quality-job() {

  security-readiness-write-fixture workflows/stage-1-commit.yaml $'name: Commit stage\non:\n  push\npermissions: {}\njobs:\n  check-markdown-format:\n    permissions:\n      contents: read\n    runs-on: ubuntu-latest\n    steps:\n      - uses: jdx/mise-action@0123456789012345678901234567890123456789\n        with:\n          persist_github_token: false'
  security-readiness-run-fixture
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "job 'check-markdown-format' must use its pinned Docker image instead of jdx/mise-action"

  return 0
}

function test-security-readiness-review-date-boundaries() {

  # Arrange
  security-readiness-write-fixture workflows/test.yaml "$SAFE_WORKFLOW"
  security-readiness-create-repo
  printf '# Review-by: 2026-12-31\n* @example/team\n' > "$TEST_TMP/repo/.github/CODEOWNERS"
  local today expected message
  # Act and Assert
  while read -r today expected message; do
    export REVIEW_TODAY="$today"
    security-readiness-run-check
    assert-equal "$expected" "$TEST_STATUS" "$today exit status: $TEST_STDERR"
    if [[ "$message" == silent ]]; then
      assert-equal "" "$TEST_STDERR" "$today is before the warning window"
    else
      assert-contains "$TEST_STDERR" "$message: .github/CODEOWNERS:" "$today diagnostic"
    fi
  done <<'CASES'
2026-11-29 0 silent
2026-11-30 0 WARNING
2026-12-31 0 WARNING
2027-01-01 1 ERROR
2027-01-30 1 ERROR
CASES
  assert-equal '-u +%F' "$(test-stub-calls date | head -n 1)" "UTC date arguments"

  return 0
}

function test-security-readiness-review-date-year-limit() {

  # Arrange
  security-readiness-write-fixture workflows/test.yaml "$SAFE_WORKFLOW"
  security-readiness-create-repo
  local today due expected
  # Act and Assert
  while read -r today due expected; do
    export REVIEW_TODAY="$today"
    printf '# Review-by: %s\n* @example/team\n' "$due" > "$TEST_TMP/repo/.github/CODEOWNERS"
    security-readiness-run-check
    assert-equal "$expected" "$TEST_STATUS" "$today -> $due: $TEST_STDERR"
    if [[ "$expected" == 1 ]]; then
      assert-contains "$TEST_STDERR" 'more than one calendar year ahead' "future limit"
    else
      assert-equal "" "$TEST_STDERR" "inclusive year limit"
    fi
  done <<'CASES'
2026-11-14 2027-11-14 0
2026-11-14 2027-11-15 1
2028-02-29 2029-02-28 0
2028-02-29 2029-03-01 1
CASES

  return 0
}

function test-security-readiness-review-date-month-ends() {

  # Arrange
  security-readiness-write-fixture workflows/test.yaml "$SAFE_WORKFLOW"
  security-readiness-create-repo
  local today due expected message
  # Act and Assert
  while read -r today due expected message; do
    export REVIEW_TODAY="$today"
    printf '# Review-by: %s\n* @example/team\n' "$due" > "$TEST_TMP/repo/.github/CODEOWNERS"
    security-readiness-run-check
    assert-equal "$expected" "$TEST_STATUS" "$today -> $due: $TEST_STDERR"
    if [[ "$message" == silent ]]; then
      assert-equal "" "$TEST_STDERR" "before clamped warning boundary"
    else
      assert-contains "$TEST_STDERR" "$message: .github/CODEOWNERS:" "clamped boundary"
    fi
  done <<'CASES'
2027-02-27 2027-03-31 0 silent
2027-02-28 2027-03-31 0 WARNING
2028-02-28 2028-03-31 0 silent
2028-02-29 2028-03-31 0 WARNING
2027-01-31 2027-01-31 0 WARNING
2027-02-01 2027-01-31 1 ERROR
2028-02-29 2028-02-29 0 WARNING
2028-03-01 2028-02-29 1 ERROR
2026-12-31 2027-01-31 0 WARNING
CASES

  return 0
}

function test-security-readiness-review-date-invalid-headers() {

  # Arrange
  security-readiness-write-fixture workflows/test.yaml "$SAFE_WORKFLOW"
  security-readiness-create-repo
  local header
  # Act and Assert
  while IFS= read -r header; do
    printf '%b\n' "$header" > "$TEST_TMP/repo/.github/CODEOWNERS"
    security-readiness-run-check
    assert-equal 1 "$TEST_STATUS" "invalid header: $header"
    assert-contains "$TEST_STDERR" "$CODEOWNERS_ERROR" "invalid header diagnostic"
  done <<'CASES'
* @example/team
# Review-by: 2027-02-29
# Review-by: 2026-04-31
# Review-by: 2027-13-01
# Review-by: 2027-00-01
# Review-by: 2027-01-00
# Review-by: 2027-1-01
# Review-by: tomorrow
# Review-by: 2027-01-01 extra
# Review-by: 2027-01-01\n# Review-by: 2027-01-01
# Review-by: 2027-01-01\n# Review-by: invalid
CASES

  return 0
}

function test-security-readiness-review-date-missing-file() {

  # Arrange
  security-readiness-write-fixture workflows/test.yaml "$SAFE_WORKFLOW"
  security-readiness-create-repo
  git -C "$TEST_TMP/repo" rm -q .github/CODEOWNERS
  # Act
  security-readiness-run-check check=staged-changes
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "$CODEOWNERS_ERROR" "missing file diagnostic"

  return 0
}

function test-security-readiness-review-date-rejects-symlink() {

  # Arrange
  security-readiness-write-fixture workflows/test.yaml "$SAFE_WORKFLOW"
  security-readiness-create-repo
  mv "$TEST_TMP/repo/.github/CODEOWNERS" "$TEST_TMP/repo/.github/review.txt"
  ln -s review.txt "$TEST_TMP/repo/.github/CODEOWNERS"
  git -C "$TEST_TMP/repo" add .github/CODEOWNERS
  # Act
  security-readiness-run-check
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "$CODEOWNERS_ERROR" 'symlink cannot satisfy date policy'

  return 0
}

function test-security-readiness-review-date-scoped-runs() {

  # Arrange
  security-readiness-write-fixture workflows/test.yaml "$SAFE_WORKFLOW"
  security-readiness-create-repo
  export REVIEW_TODAY=2027-01-02
  local mode
  # Act and Assert
  for mode in staged-changes working-tree-changes branch; do
    security-readiness-run-check "check=$mode"
    assert-equal 1 "$TEST_STATUS" "$mode still checks the unchanged review date"
    assert-contains "$TEST_STDERR" 'is overdue' "overdue diagnostic"
  done

  return 0
}

function test-security-readiness-review-date-clock-failure() {

  # Arrange
  security-readiness-write-fixture workflows/test.yaml "$SAFE_WORKFLOW"
  security-readiness-create-repo
  local clock
  # Act and Assert
  for clock in 'exit 1' 'echo invalid' 'echo 2026-02-30'; do
    TEST_DATE_STUB="$clock"
    security-readiness-run-check
    assert-equal 1 "$TEST_STATUS" "unavailable or invalid clock must fail"
    assert-contains "$TEST_STDERR" "$CODEOWNERS_ERROR" "clock diagnostic"
  done

  return 0
}

function test-security-readiness-review-date-ci-warning() {

  # Arrange
  security-readiness-write-fixture workflows/test.yaml "$SAFE_WORKFLOW"
  security-readiness-create-repo
  export REVIEW_TODAY=2026-12-01
  # Act
  security-readiness-run-check GITHUB_ACTIONS=true
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-equal 1 "$(printf '%s\n' "$TEST_STDERR" | awk '/^::warning::\.github\/CODEOWNERS: / { count++ } END { print count + 0 }')" 'one CI annotation'
  assert-not-contains "$TEST_STDERR" 'WARNING:' "no local warning"
  assert-not-contains "$TEST_STDERR" '::warning file=' "no second annotation"
  assert-contains "$TEST_STDERR" '2027-01-01' "due date"
  assert-not-contains "$TEST_STDERR" '2027-02-01' "no grace-period date"
  assert-equal "" "$TEST_STDOUT" "stdout is reserved for results"

  return 0
}

function test-security-readiness-review-date-ci-error() {

  # Arrange
  security-readiness-write-fixture workflows/test.yaml "$SAFE_WORKFLOW"
  security-readiness-create-repo
  export REVIEW_TODAY=2027-01-02
  # Act
  security-readiness-run-check GITHUB_ACTIONS=true
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" '::error::.github/CODEOWNERS: Review-by 2027-01-01 is overdue' "CI annotation"
  assert-not-contains "$TEST_STDERR" 'ERROR:' "no local error"

  return 0
}

function test-security-readiness-combined-failures() {

  # Arrange
  security-readiness-write-fixture workflows/test.yaml "$PRIVILEGED_WORKFLOW"
  security-readiness-create-repo
  rm "$TEST_TMP/repo/.github/CODEOWNERS"
  test-isolate-path yq jq
  cd "$TEST_TMP/repo"
  # Act
  test-capture env check=all bash "$TEST_TMP/repo/scripts/quality/check-security-readiness.sh"
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" 'CODEOWNERS' 'repository failure is reported'
  assert-contains "$TEST_STDERR" "$PRIVILEGED_TRIGGER_ERROR" 'workflow failure is also reported'

  return 0
}

function test-security-readiness-combined-unchanged-baseline() {

  # Arrange
  security-readiness-write-fixture workflows/test.yaml "$SAFE_WORKFLOW"
  security-readiness-create-repo
  printf 'Invalid security policy\n' > "$TEST_TMP/repo/.github/SECURITY.md"
  git -C "$TEST_TMP/repo" add .github/SECURITY.md
  git -C "$TEST_TMP/repo" commit -q -m invalid-policy
  test-isolate-path yq jq
  cd "$TEST_TMP/repo"
  # Act
  test-capture env check=working-tree-changes bash "$TEST_TMP/repo/scripts/quality/check-security-readiness.sh"
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" 'ERROR: .github/SECURITY.md:' 'unchanged baseline is still checked'

  return 0
}

function test-security-readiness-combined-warning-once() {

  # Arrange
  security-readiness-write-fixture workflows/test.yaml "$SAFE_WORKFLOW"
  security-readiness-create-repo
  test-isolate-path yq jq
  test-stub date 'printf "2026-12-01\n"'
  cd "$TEST_TMP/repo"
  # Act
  test-capture env check=staged-changes GITHUB_ACTIONS=false bash "$TEST_TMP/repo/scripts/quality/check-security-readiness.sh"
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-equal 1 "$(printf '%s\n' "$TEST_STDERR" | awk '/WARNING: .github\/CODEOWNERS:/ { count++ } END { print count + 0 }')" 'review-date warning is emitted once'
  assert-not-contains "$TEST_STDERR" 'FORCE_USE_DOCKER=false' 'default does not warn about Docker opt-out'

  return 0
}

function test-security-readiness-warns-once-when-docker-is-disabled() {

  # Arrange
  security-readiness-write-fixture workflows/test.yaml "$SAFE_WORKFLOW"
  security-readiness-write-fixture actions/check-file-format/action.yaml $'name: Check file format\nruns:\n  using: composite\n  steps:\n    - shell: bash\n      env:\n        FORCE_USE_DOCKER: "false"\n      run: make lint-file-format'
  security-readiness-create-repo
  test-isolate-path yq jq
  cd "$TEST_TMP/repo"
  # Act
  test-capture env check=staged-changes GITHUB_ACTIONS=false FORCE_USE_DOCKER=false \
    bash "$TEST_TMP/repo/scripts/quality/check-security-readiness.sh"
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-equal 1 "$(awk '/WARNING: FORCE_USE_DOCKER=false/ { count++ } END { print count + 0 }' <<< "$TEST_STDERR")" \
    'Docker opt-out warning is emitted once'
  assert-contains "$TEST_STDERR" 'FORCE_USE_DOCKER=true' 'recommended Docker setting is named'

  return 0
}

function test-security-readiness-checks-repository-workflows() {

  test-isolate-path yq jq
  test-capture ./scripts/quality/check-security-readiness.sh
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"

  return 0
}

# ==============================================================================

# Write one workflow fixture and run the policy checker against the fixtures.
# Arguments:
#   $1=[workflow YAML content]
function security-readiness-check-fixture() {

  local workflow="$1"
  security-readiness-write-fixture workflows/test.yaml "$workflow"
  security-readiness-run-fixture

  return 0
}

# Write one fixture file under the test directory.
# Arguments:
#   $1=[path relative to the test directory]
#   $2=[file content]
function security-readiness-write-fixture() {

  local relative_path="$1" content="$2"
  test-mkdir-parent "$TEST_TMP/$relative_path"
  printf '%s\n' "$content" > "$TEST_TMP/$relative_path"

  return 0
}

# Run the policy checker against the fixture workflows, actions and allowlist.
function security-readiness-run-fixture() {

  security-readiness-create-repo
  security-readiness-run-check

  return 0
}

# Create the scratch repository "$TEST_TMP/repo" with the fixture workflows,
# actions and allowlist in their default places, committed on main with
# origin/main pointing at that commit.
function security-readiness-create-repo() {

  local repo="$TEST_TMP/repo"
  cp -Rp "$SUITE_TMP/quality-fixture-base" "$repo"
  cp "$TEST_REPO_ROOT/scripts/quality/tests/mise.toml.test" "$repo/mise.toml"
  mkdir -p "$repo/.github" "$repo/scripts/config"
  printf '# Review-by: 2027-01-01\n* @example/team\n' > "$repo/.github/CODEOWNERS"
  printf '%s\n' "$SAFE_SECURITY" > "$repo/.github/SECURITY.md"
  printf '# Contributing\nOpen a pull request.\n' > "$repo/.github/CONTRIBUTING.md"
  [[ ! -d "$TEST_TMP/workflows" ]] || cp -R "$TEST_TMP/workflows" "$repo/.github/workflows"
  [[ ! -d "$TEST_TMP/actions" ]] || cp -R "$TEST_TMP/actions" "$repo/.github/actions"
  [[ ! -f "$TEST_TMP/allowlist.yaml" ]] || cp "$TEST_TMP/allowlist.yaml" "$repo/scripts/config/security-readiness.yaml"
  git -C "$repo" add -A
  git -C "$repo" commit -q -m workflows
  git -C "$repo" update-ref refs/remotes/origin/main HEAD

  return 0
}

# Run the policy checker in the scratch repository. The isolated PATH links the
# real yq and jq, as a mise shim is slow to start.
# Arguments:
#   $@=[optional environment assignments for the checker]
function security-readiness-run-check() {

  test-isolate-path yq jq
  test-stub date "${TEST_DATE_STUB:-$REVIEW_DATE_STUB}"
  cd "$TEST_TMP/repo"
  test-capture env GITHUB_ACTIONS=false "$@" ./scripts/quality/check-security-readiness.sh

  return 0
}

function test-security-readiness-repository-accepts-safe-baseline() {

  # Arrange
  security-readiness-repository-create-repo
  # Act
  security-readiness-repository-run-check
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-equal '' "$TEST_STDERR" 'no diagnostics'
  assert-equal '' "$TEST_STDOUT" "$STDOUT_LABEL"

  return 0
}

function test-security-readiness-repository-rejects-invalid-owners() {

  # Arrange
  security-readiness-repository-create-repo
  local owners
  # Act and Assert
  for owners in '* not-an-owner' '* @<organisation>/<team>' '* @org/team extra' '* @org/' '* @user,other' '* @org/ChangeMe' '* @./.' '* @-org/team' '* @org/.'; do
    printf '%s\n' "$owners" > "$TEST_TMP/repo/.github/CODEOWNERS"
    security-readiness-repository-run-check
    assert-equal 1 "$TEST_STATUS" "invalid ownership: $owners"
    assert-contains "$TEST_STDERR" "$CODEOWNERS_ERROR" 'owner diagnostic'
  done

  return 0
}

function test-security-readiness-repository-ignores-comment-owners() {

  # Arrange
  security-readiness-repository-create-repo
  printf '# * @org/team\n/docs/ @org/team\n' > "$TEST_TMP/repo/.github/CODEOWNERS"
  # Act
  security-readiness-repository-run-check
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" 'catch-all' 'comments cannot own files'

  return 0
}

function test-security-readiness-repository-rejects-unsupported-patterns() {

  # Arrange
  security-readiness-repository-create-repo
  local pattern
  # Act and Assert
  for pattern in '!/private/' '/[abc]/' '\#secret'; do
    printf '%s\n%s @org/team\n' "$SAFE_OWNERS" "$pattern" > "$TEST_TMP/repo/.github/CODEOWNERS"
    security-readiness-repository-run-check
    assert-equal 1 "$TEST_STATUS" "unsupported pattern: $pattern"
    assert-contains "$TEST_STDERR" 'unsupported CODEOWNERS pattern' 'pattern diagnostic'
  done

  return 0
}

function test-security-readiness-repository-requires-effective-team-catchall() {

  # Arrange
  security-readiness-repository-create-repo
  local final_rule
  # Act and Assert
  for final_rule in '*' '* @individual' '* person@example.org' '**' '/**' '** @individual'; do
    printf '%s\n%s\n' "$SAFE_OWNERS" "$final_rule" > "$TEST_TMP/repo/.github/CODEOWNERS"
    security-readiness-repository-run-check
    assert-equal 1 "$TEST_STATUS" "effective ownership: $final_rule"
    assert-contains "$TEST_STDERR" 'catch-all' 'last catch-all must retain team ownership'
  done

  return 0
}

function test-security-readiness-repository-accepts-escaped-paths-and-exclusions() {

  # Arrange
  security-readiness-repository-create-repo
  printf '%s\n/docs/my\\ file.md @org/docs @individual person@example.org # docs owners\n/generated/\n' "$SAFE_OWNERS" > "$TEST_TMP/repo/.github/CODEOWNERS"
  # Act
  security-readiness-repository-run-check
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"

  return 0
}

function test-security-readiness-repository-ignores-escape-examples-in-comments() {

  # Arrange
  security-readiness-repository-create-repo
  printf '%s # example containing \\#\n' "$SAFE_OWNERS" > "$TEST_TMP/repo/.github/CODEOWNERS"
  # Act
  security-readiness-repository-run-check
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"

  return 0
}

function test-security-readiness-repository-rejects-missing-files() {

  # Arrange
  security-readiness-repository-create-repo
  local file
  # Act and Assert
  for file in .github/CODEOWNERS .github/SECURITY.md .github/CONTRIBUTING.md LICENCE.md; do
    mv "$TEST_TMP/repo/$file" "$TEST_TMP/missing"
    security-readiness-repository-run-check check=staged-changes
    assert-equal 1 "$TEST_STATUS" "missing file: $file"
    assert-contains "$TEST_STDERR" 'ERROR:' 'missing file diagnostic'
    mv "$TEST_TMP/missing" "$TEST_TMP/repo/$file"
  done

  return 0
}

function test-security-readiness-repository-rejects-empty-documents() {

  # Arrange
  security-readiness-repository-create-repo
  printf ' \n\t\n' > "$TEST_TMP/repo/.github/CONTRIBUTING.md"
  # Act
  security-readiness-repository-run-check
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" 'CONTRIBUTING.md' 'empty contribution guide'

  return 0
}

function test-security-readiness-repository-resolves-supported-document-locations() {

  # Arrange
  security-readiness-repository-create-repo
  mkdir -p "$TEST_TMP/repo/docs"
  git -C "$TEST_TMP/repo" mv .github/CONTRIBUTING.md docs/CONTRIBUTING.md
  git -C "$TEST_TMP/repo" mv .github/SECURITY.md SECURITY.md
  # Act
  security-readiness-repository-run-check
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"

  return 0
}

function test-security-readiness-repository-rejects-invalid-preferred-document() {

  # Arrange
  security-readiness-repository-create-repo
  printf 'invalid\n' > "$TEST_TMP/repo/SECURITY.md"
  git -C "$TEST_TMP/repo" add SECURITY.md
  # Act
  security-readiness-repository-run-check
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" 'ERROR: SECURITY.md:' 'root policy takes precedence'

  return 0
}

function test-security-readiness-repository-ignores-untracked-documents() {

  # Arrange
  security-readiness-repository-create-repo
  git -C "$TEST_TMP/repo" rm -q --cached .github/CONTRIBUTING.md
  # Act
  security-readiness-repository-run-check
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" 'CONTRIBUTING.md' 'untracked guide cannot satisfy baseline'

  return 0
}

function test-security-readiness-repository-ignores-untracked-codeowners() {

  # Arrange
  security-readiness-repository-create-repo
  git -C "$TEST_TMP/repo" rm -q --cached .github/CODEOWNERS
  # Act
  security-readiness-repository-run-check
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "$CODEOWNERS_ERROR" 'untracked preferred file cannot satisfy baseline'

  return 0
}

function test-security-readiness-repository-requires-security-markers() {

  # Arrange
  security-readiness-repository-create-repo
  local marker
  # Act and Assert
  for marker in 'Reporting a vulnerability' cybersecurity@nhs.net NCSC 'General security enquiries'; do
    printf '%s\n' "${SAFE_SECURITY/"$marker"/removed}" > "$TEST_TMP/repo/.github/SECURITY.md"
    security-readiness-repository-run-check
    assert-equal 1 "$TEST_STATUS" "missing marker: $marker"
    assert-contains "$TEST_STDERR" 'required security policy content' 'policy diagnostic'
  done

  return 0
}

function test-security-readiness-repository-warns-for-adoption-placeholders() {

  # Arrange
  security-readiness-repository-create-repo
  printf '%s\n[TODO: define supported versions]\n' "$SAFE_SECURITY" > "$TEST_TMP/repo/.github/SECURITY.md"
  # Act
  security-readiness-repository-run-check GITHUB_ACTIONS=true
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-contains "$TEST_STDERR" '::warning::.github/SECURITY.md: ' 'CI adoption warning'
  assert-not-contains "$TEST_STDERR" 'WARNING:' 'no local adoption warning'
  assert-not-contains "$TEST_STDERR" '::warning file=' 'no second annotation'
  assert-equal '' "$TEST_STDOUT" "$STDOUT_LABEL"

  return 0
}

function test-security-readiness-repository-warns-for-todos() {

  # Arrange
  security-readiness-repository-create-repo
  local file content
  for file in Makefile README.md .github/CODE_OF_CONDUCT.md; do
    printf '# Adopted project\n' > "$TEST_TMP/repo/$file"
  done
  git -C "$TEST_TMP/repo" add Makefile README.md .github/CODE_OF_CONDUCT.md
  # Act and Assert
  for file in Makefile README.md .github/CODE_OF_CONDUCT.md .github/CONTRIBUTING.md .github/SECURITY.md; do
    content="$(cat "$TEST_TMP/repo/$file")"
    printf '\nTODO: finish adoption\nTODO: confirm ownership\n' >> "$TEST_TMP/repo/$file"
    security-readiness-repository-run-check
    assert-equal 0 "$TEST_STATUS" "$file: $TEST_STDERR"
    assert-contains "$TEST_STDERR" "WARNING: $file: " 'file-specific TODO warning'
    assert-equal 1 "$(printf '%s\n' "$TEST_STDERR" | wc -l | tr -d '[:space:]')" 'one warning per file'
    assert-equal '' "$TEST_STDOUT" "$STDOUT_LABEL"
    printf '%s\n' "$content" > "$TEST_TMP/repo/$file"
  done

  return 0
}

function test-security-readiness-repository-todos-in-every-mode() {

  # Arrange
  security-readiness-repository-create-repo
  printf 'TODO: ::error::do not echo this\n' > "$TEST_TMP/repo/README.md"
  git -C "$TEST_TMP/repo" add README.md
  git -C "$TEST_TMP/repo" commit -q -m 'unfinished adoption'
  local mode
  # Act and Assert
  for mode in all staged-changes working-tree-changes branch; do
    security-readiness-repository-run-check check="$mode" BRANCH_NAME=main GITHUB_ACTIONS=true
    assert-equal 0 "$TEST_STATUS" "$mode: $TEST_STDERR"
    assert-contains "$TEST_STDERR" '::warning::README.md: ' 'CI TODO annotation'
    assert-not-contains "$TEST_STDERR" 'do not echo this' 'TODO contents stay private'
    assert-equal '' "$TEST_STDOUT" "$STDOUT_LABEL"
  done

  return 0
}

function test-security-readiness-repository-todos-respect-document-selection() {

  # Arrange
  security-readiness-repository-create-repo
  local file
  for file in Makefile README.md .github/CODE_OF_CONDUCT.md; do
    printf 'TODO: finish adoption\n' > "$TEST_TMP/repo/$file"
  done
  # Act
  security-readiness-repository-run-check
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-equal '' "$TEST_STDERR" 'untracked files are not checked'
  # Act
  git -C "$TEST_TMP/repo" add .github/CODE_OF_CONDUCT.md
  security-readiness-repository-run-check
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-contains "$TEST_STDERR" 'WARNING: .github/CODE_OF_CONDUCT.md: ' 'tracked conduct warning'
  # Act
  printf '# Adopted conduct policy\n' > "$TEST_TMP/repo/CODE_OF_CONDUCT.md"
  git -C "$TEST_TMP/repo" add CODE_OF_CONDUCT.md
  security-readiness-repository-run-check
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-equal '' "$TEST_STDERR" 'root conduct policy takes precedence'

  return 0
}

function test-security-readiness-repository-ignores-todo-without-colon() {

  # Arrange
  security-readiness-repository-create-repo
  local file
  for file in Makefile README.md .github/CODE_OF_CONDUCT.md .github/CONTRIBUTING.md .github/SECURITY.md; do
    printf '\nReview TODOs and TODO-marked items.\n' >> "$TEST_TMP/repo/$file"
  done
  git -C "$TEST_TMP/repo" add -A
  # Act
  security-readiness-repository-run-check
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-equal '' "$TEST_STDERR" 'ordinary TODO mentions do not warn'

  return 0
}

function test-security-readiness-repository-accepts-approved-licences() {

  # Arrange
  security-readiness-repository-create-repo
  local licence
  # Act and Assert
  for licence in MIT Apache-2.0 BSD-2-Clause BSD-3-Clause; do
    jq -nr -L "$TEST_TMP/repo/scripts/quality" --arg id "$licence" \
      'include "check-security-readiness"; approved_licences[] | select(.id == $id) | .text' > "$TEST_TMP/repo/LICENCE.md"
    security-readiness-repository-run-check
    assert-equal 0 "$TEST_STATUS" "approved $licence: $TEST_STDERR"
  done

  return 0
}

function test-security-readiness-repository-rejects-modified-licences() {

  # Arrange
  security-readiness-repository-create-repo
  local content licence
  content="$(cat "$TEST_TMP/repo/LICENCE.md")"
  # Act and Assert
  for licence in '# MIT Licence' "$content"$'\nCommercial use is prohibited.' "$content"$'\nCopyright 2026 Example. Commercial use is prohibited.' "${content/free of charge/for a fee}"; do
    printf '%s\n' "$licence" > "$TEST_TMP/repo/LICENCE.md"
    security-readiness-repository-run-check
    assert-equal 1 "$TEST_STATUS" 'licence heading, extra terms or modified terms'
    assert-contains "$TEST_STDERR" 'approved licence text' 'licence diagnostic'
  done

  return 0
}

function test-security-readiness-repository-allows-licence-formatting-and-copyright() {

  # Arrange
  security-readiness-repository-create-repo
  local content
  content="$(cat "$TEST_TMP/repo/LICENCE.md")"
  printf '%s\n' "${content/2026 Crown Copyright NHS England./2030 Example Organisation.}" > "$TEST_TMP/repo/LICENCE.md"
  # Act
  security-readiness-repository-run-check
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"

  return 0
}

function test-security-readiness-repository-checks-unchanged-scoped-runs() {

  # Arrange
  security-readiness-repository-create-repo
  printf '* @individual\n' > "$TEST_TMP/repo/.github/CODEOWNERS"
  git -C "$TEST_TMP/repo" add .github/CODEOWNERS
  git -C "$TEST_TMP/repo" commit -q -m invalid-owners
  git -C "$TEST_TMP/repo" update-ref refs/remotes/origin/main HEAD
  local mode
  # Act and Assert
  for mode in all staged-changes working-tree-changes branch; do
    security-readiness-repository-run-check "check=$mode"
    assert-equal 1 "$TEST_STATUS" "unchanged baseline in $mode"
    assert-contains "$TEST_STDERR" 'catch-all' 'scoped baseline diagnostic'
  done

  return 0
}

function test-security-readiness-repository-rejects-unknown-mode() {

  # Arrange
  security-readiness-repository-create-repo
  # Act
  security-readiness-repository-run-check check=bogus
  # Assert
  assert-equal 126 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" 'check=all' 'accepted modes'

  return 0
}

function test-security-readiness-repository-reports-missing-tool() {

  # Arrange
  security-readiness-repository-create-repo
  test-isolate-path
  # Act
  test-capture env check=all bash "$TEST_TMP/repo/scripts/quality/check-security-readiness.sh"
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" 'yq is required' 'missing tool diagnostic'

  return 0
}

function test-security-readiness-repository-fails-on-jq-error() {

  # Arrange
  security-readiness-repository-create-repo
  test-isolate-path yq jq
  test-stub jq 'exit 1'
  # Act
  security-readiness-repository-run-check
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" 'cannot be evaluated' 'jq failure diagnostic'

  return 0
}

function test-security-readiness-repository-policy-cannot-be-configured() {

  # Arrange
  security-readiness-repository-create-repo
  mkdir -p "$TEST_TMP/repo/scripts/config"
  printf '{"licences":[{"id":"Custom","text":"Unapproved licence"}]}\n' > "$TEST_TMP/repo/scripts/config/approved-licences.json"
  # Act
  security-readiness-repository-run-check
  # Assert
  assert-equal 0 "$TEST_STATUS" "local configuration cannot invalidate approved MIT text: $TEST_STDERR"
  # Act
  printf 'Unapproved licence\n' > "$TEST_TMP/repo/LICENCE.md"
  security-readiness-repository-run-check
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" 'approved licence text' 'local configuration cannot approve another licence'

  return 0
}

# ==============================================================================

# Confirm the combined hook follows pipeline contract and shows passing output.
function test-security-readiness-precommit-order() {

  # Arrange
  test-isolate-path jq yq
  local hooks configuration
  # Act
  hooks="$(yq -o=json '.repos[].hooks[]' "$TEST_REPO_ROOT/scripts/config/pre-commit.yaml" | jq -s '.')"
  configuration="$(jq '.[] | select(.id == "check-security-readiness")' <<< "$hooks")"
  # Assert
  assert-equal 'check-pipeline-contract check-security-readiness' "$(jq -r '[.[] | select(.id | IN("check-pipeline-contract", "check-security-readiness", "check-workflow-security", "check-repository-readiness"))] | map(.id) | join(" ")' <<< "$hooks")" 'only one security hook, after pipeline contract'
  assert-equal true "$(jq -r '.always_run and .verbose and (.pass_filenames == false)' <<< "$configuration")" 'security readiness always runs with visible output'
  assert-equal 'make lint-security-readiness check=all' "$(jq -r '.entry' <<< "$configuration")" 'canonical pre-commit target'

  return 0
}

# Confirm CI enforces execution after pipeline contract, not just display order.
function test-security-readiness-ci-order() {

  # Arrange
  test-isolate-path jq yq
  # Act
  local jobs
  jobs="$(yq -o=json '.jobs' "$TEST_REPO_ROOT/.github/workflows/stage-1-commit.yaml")"
  # Assert
  assert-equal 'check-pipeline-contract check-security-readiness' "$(jq -r 'keys_unsorted | map(select(IN("check-pipeline-contract", "check-security-readiness", "check-workflow-security", "check-repository-readiness"))) | join(" ")' <<< "$jobs")" 'CI job definition order and consolidation'
  assert-equal 'check-pipeline-contract' "$(jq -r '."check-security-readiness".needs' <<< "$jobs")" 'CI execution dependency'
  assert-equal true "$(jq -r 'any(."check-security-readiness".steps[]?; .run == "make lint-security-readiness check=all")' <<< "$jobs")" 'CI runs the canonical target'

  return 0
}

# Create and commit a safe offline baseline in the scratch repository.
function security-readiness-repository-create-repo() {

  local repo="$TEST_TMP/repo"
  cp -Rp "$SUITE_TMP/quality-fixture-base" "$repo"
  cp "$TEST_REPO_ROOT/scripts/quality/tests/mise.toml.test" "$repo/mise.toml"
  mkdir -p "$TEST_TMP/repo/.github"
  printf '%s\n' "$SAFE_OWNERS" > "$TEST_TMP/repo/.github/CODEOWNERS"
  printf '%s\n' "$SAFE_SECURITY" > "$TEST_TMP/repo/.github/SECURITY.md"
  printf '# Contributing\nOpen a pull request.\n' > "$TEST_TMP/repo/.github/CONTRIBUTING.md"
  mkdir -p "$TEST_TMP/repo/.github/workflows"
  printf '%s\n' "$SAFE_WORKFLOW" > "$TEST_TMP/repo/.github/workflows/test.yaml"
  git -C "$TEST_TMP/repo" add -A
  git -C "$TEST_TMP/repo" commit -q -m readiness
  git -C "$TEST_TMP/repo" update-ref refs/remotes/origin/main HEAD

  return 0
}

# Run the checker with optional environment assignments and capture diagnostics.
# Arguments:
#   $@=[environment assignments]
function security-readiness-repository-run-check() {

  security-readiness-run-check "$@"

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
