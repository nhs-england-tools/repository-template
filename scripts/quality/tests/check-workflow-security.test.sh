#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034,SC2317,SC2329

set -euo pipefail

# Test suite for the workflow security check script. Each test writes workflow,
# local action and allowlist fixtures, commits them to a scratch repository and
# runs the check there with the real yq and jq.
#
# Usage:
#   $ ./scripts/quality/tests/check-workflow-security.test.sh
#
# Options:
#   VERBOSE=true  # Show all the executed commands, default is 'false'

# ==============================================================================

readonly SAFE_WORKFLOW='name: test
on:
  push:
permissions: {}
jobs:
  check:
    permissions:
      contents: read
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@0123456789012345678901234567890123456789
        with:
          persist-credentials: false'
readonly SAFE_JOB=$'name: test\non:\n  push:\npermissions: {}\njobs:\n  check:\n    permissions:\n      contents: read\n    runs-on: ubuntu-latest\n'
readonly EXIT_STATUS_LABEL='exit status'
readonly PRIVILEGED_TRIGGER_ERROR='privileged triggers pull_request_target and workflow_run are prohibited'
readonly PRIVILEGED_WORKFLOW=$'name: test\non: pull_request_target\npermissions: {}\njobs:\n  check:\n    permissions:\n      contents: read\n    runs-on: ubuntu-latest'
readonly SECRET_SCOPE_ERROR='secret values must not be set in workflow, job, container, or service environment'

# Set up the suite fixtures and run every test.
function main() {

  cd "$(git rev-parse --show-toplevel)"
  source ./scripts/tests/test.lib.sh
  source ./scripts/quality/tests/quality-test.lib.sh
  QUALITY_FIXTURE_PATHS=(scripts/quality/check-workflow-security.sh scripts/quality/check-workflow-security.jq scripts/quality/git-files.lib.sh scripts/quality/git-base.lib.sh)
  QUALITY_FIXTURE_FORMAT='# %s\n'

  # The caller's options must not reach the script under test
  unset -v check dir actions_dir allowlist BRANCH_NAME GITHUB_BASE_REF QUALITY_PR_BASE

  test-run-suite \
    test-workflow-security-rejects-unknown-mode \
    test-workflow-security-skips-untracked-files \
    test-workflow-security-fails-without-tracked-workflows \
    test-workflow-security-scoped-mode-checks-only-changed-files \
    test-workflow-security-scoped-mode-without-changes-passes \
    test-workflow-security-scoped-mode-checks-every-file-when-the-allowlist-changes \
    test-workflow-security-scoped-mode-checks-every-file-when-the-rules-change \
    test-workflow-security-branch-checks-changed-files \
    test-workflow-security-reports-a-missing-base \
    test-workflow-security-accepts-safe-workflow \
    test-workflow-security-rejects-inherited-workflow-permissions \
    test-workflow-security-rejects-job-without-permissions \
    test-workflow-security-rejects-persisted-checkout-credentials \
    test-workflow-security-matches-action-names-case-insensitively \
    test-workflow-security-rejects-unpinned-action \
    test-workflow-security-rejects-secret-expression-in-run \
    test-workflow-security-rejects-expression-in-run \
    test-workflow-security-rejects-expression-in-github-script \
    test-workflow-security-rejects-privileged-trigger \
    test-workflow-security-rejects-privileged-trigger-string \
    test-workflow-security-rejects-privileged-trigger-list \
    test-workflow-security-rejects-inherited-secrets \
    test-workflow-security-rejects-job-wide-secret \
    test-workflow-security-rejects-job-wide-secret-inside-expression \
    test-workflow-security-rejects-job-wide-secret-index-syntax \
    test-workflow-security-rejects-job-wide-multi-line-secret \
    test-workflow-security-rejects-container-secret \
    test-workflow-security-rejects-service-secret \
    test-workflow-security-allows-job-wide-secret-presence-check \
    test-workflow-security-allows-step-scoped-secret \
    test-workflow-security-rejects-unapproved-write-permission \
    test-workflow-security-accepts-approved-write-permission \
    test-workflow-security-rejects-write-permission-approved-for-another-workflow \
    test-workflow-security-requires-explicit-mise-token-non-persistence \
    test-workflow-security-rejects-expression-in-action-run \
    test-workflow-security-rejects-unpinned-action-step \
    test-workflow-security-rejects-unparseable-file \
    test-workflow-security-reports-yaml-parse-error \
    test-workflow-security-rejects-dockerised-quality-action-without-force-docker \
    test-workflow-security-accepts-dockerised-quality-action-with-force-docker \
    test-workflow-security-accepts-dockerised-quality-action-with-boolean-force-docker \
    test-workflow-security-rejects-mise-in-dockerised-quality-job \
    test-workflow-security-checks-repository-workflows

  return 0
}

# Build the fixture repository once, every test starts from a copy.
function test-suite-setup() {

  quality-build-fixture-base

  return 0
}

# ==============================================================================

function test-workflow-security-rejects-unknown-mode() {

  # Arrange
  workflow-security-write-fixture workflows/test.yaml "$SAFE_WORKFLOW"
  workflow-security-create-repo
  # Act
  workflow-security-run-check check=bogus
  # Assert
  assert-equal 126 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "Use check=all, check=staged-changes, check=working-tree-changes, check=branch" "accepted modes"

  return 0
}

function test-workflow-security-skips-untracked-files() {

  # Arrange
  workflow-security-write-fixture workflows/test.yaml "$SAFE_WORKFLOW"
  workflow-security-create-repo
  printf '%s\n' "$PRIVILEGED_WORKFLOW" > "$TEST_TMP/repo/.github/workflows/untracked.yaml"
  mkdir -p "$TEST_TMP/repo/.github/actions/untracked"
  printf 'name: untracked\nruns:\n  using: composite\n  steps:\n    - uses: example/action@v1\n' > "$TEST_TMP/repo/.github/actions/untracked/action.yaml"
  # Act
  workflow-security-run-check
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-equal "" "$TEST_STDERR" "stderr"

  return 0
}

function test-workflow-security-fails-without-tracked-workflows() {

  # Arrange
  workflow-security-write-fixture workflows/test.yaml "$SAFE_WORKFLOW"
  workflow-security-create-repo
  git -C "$TEST_TMP/repo" rm -q --cached .github/workflows/test.yaml
  # Act
  workflow-security-run-check
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "no tracked workflow files found under .github/workflows" "no workflows diagnostic"

  return 0
}

function test-workflow-security-scoped-mode-checks-only-changed-files() {

  # Arrange
  workflow-security-write-fixture workflows/existing.yaml "$PRIVILEGED_WORKFLOW"
  workflow-security-write-fixture workflows/test.yaml "$SAFE_WORKFLOW"
  workflow-security-create-repo
  printf '%s\n' "${SAFE_WORKFLOW/name: test/name: changed}" > "$TEST_TMP/repo/.github/workflows/test.yaml"
  workflow-security-write-fixture repo/.github/workflows/new.yaml "$PRIVILEGED_WORKFLOW"
  git -C "$TEST_TMP/repo" add .github/workflows/new.yaml
  # Act
  workflow-security-run-check check=staged-changes
  # Assert
  assert-equal 1 "$TEST_STATUS" "staged-changes $EXIT_STATUS_LABEL"
  assert-equal "ERROR: .github/workflows/new.yaml: $PRIVILEGED_TRIGGER_ERROR" "$TEST_STDERR" "only the staged workflow"
  # Act
  workflow-security-run-check check=working-tree-changes
  # Assert
  assert-equal 0 "$TEST_STATUS" "working-tree-changes $EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-equal "" "$TEST_STDERR" "only the unstaged safe workflow"

  return 0
}

function test-workflow-security-scoped-mode-without-changes-passes() {

  # Arrange
  workflow-security-write-fixture workflows/test.yaml "$PRIVILEGED_WORKFLOW"
  workflow-security-create-repo
  # Act
  workflow-security-run-check check=staged-changes
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "" "$TEST_STDERR" "stderr"

  return 0
}

function test-workflow-security-scoped-mode-checks-every-file-when-the-allowlist-changes() {

  # Arrange
  workflow-security-write-fixture workflows/test.yaml "${SAFE_JOB/contents: read/contents: write}"
  workflow-security-write-fixture allowlist.yaml $'approved_write_permissions:\n  - workflow: test.yaml\n    job: check\n    permission: contents'
  workflow-security-create-repo
  printf 'approved_write_permissions: []\n' > "$TEST_TMP/repo/scripts/config/workflow-security.yaml"
  git -C "$TEST_TMP/repo" add scripts/config/workflow-security.yaml
  # Act
  workflow-security-run-check check=staged-changes
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" ".github/workflows/test.yaml: write permission is not approved for job 'check'" "the unchanged workflow"

  return 0
}

function test-workflow-security-scoped-mode-checks-every-file-when-the-rules-change() {

  # Arrange
  local rule_file content
  workflow-security-write-fixture workflows/test.yaml "$PRIVILEGED_WORKFLOW"
  workflow-security-create-repo
  for rule_file in scripts/quality/check-workflow-security.jq scripts/quality/check-workflow-security.sh; do
    # Replace the file, as an executable fixture links to the real script
    content="$(cat "$TEST_TMP/repo/$rule_file")"
    rm "$TEST_TMP/repo/$rule_file"
    printf '%s\n# changed\n' "$content" > "$TEST_TMP/repo/$rule_file"
    chmod 755 "$TEST_TMP/repo/$rule_file"
    git -C "$TEST_TMP/repo" add "$rule_file"
    # Act
    workflow-security-run-check check=staged-changes
    # Assert
    assert-equal 1 "$TEST_STATUS" "$rule_file $EXIT_STATUS_LABEL"
    assert-equal "ERROR: .github/workflows/test.yaml: $PRIVILEGED_TRIGGER_ERROR" "$TEST_STDERR" "$rule_file: the unchanged workflow"
    git -C "$TEST_TMP/repo" checkout -q HEAD -- "$rule_file"
  done

  return 0
}

function test-workflow-security-branch-checks-changed-files() {

  # Arrange
  workflow-security-write-fixture workflows/existing.yaml "$PRIVILEGED_WORKFLOW"
  workflow-security-write-fixture workflows/test.yaml "$SAFE_WORKFLOW"
  workflow-security-create-repo
  git -C "$TEST_TMP/repo" switch -q -c feature
  printf '%s\n' "$PRIVILEGED_WORKFLOW" > "$TEST_TMP/repo/.github/workflows/test.yaml"
  git -C "$TEST_TMP/repo" commit -q -am 'privileged trigger'
  # Act
  workflow-security-run-check check=branch BRANCH_NAME=main
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" ".github/workflows/test.yaml: $PRIVILEGED_TRIGGER_ERROR" "the changed workflow"
  assert-not-contains "$TEST_STDERR" "existing.yaml" "the unchanged workflow"

  return 0
}

function test-workflow-security-reports-a-missing-base() {

  # Arrange
  workflow-security-write-fixture workflows/test.yaml "$SAFE_WORKFLOW"
  workflow-security-create-repo
  git -C "$TEST_TMP/repo" switch -q -c feature
  # Act
  workflow-security-run-check check=branch BRANCH_NAME=missing
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "Branch to compare with not found: missing" "missing base diagnostic"

  return 0
}

function test-workflow-security-accepts-safe-workflow() {

  workflow-security-check-fixture "$SAFE_WORKFLOW"
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"

  return 0
}

function test-workflow-security-rejects-inherited-workflow-permissions() {

  local workflow=$'name: test\non:\n  push\npermissions:\n  contents: read\njobs:\n  check:\n    permissions:\n      contents: read\n    runs-on: ubuntu-latest\n'
  workflow-security-check-fixture "$workflow"
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "workflow permissions must be empty"

  return 0
}

function test-workflow-security-rejects-job-without-permissions() {

  local workflow=$'name: test\non:\n  push\npermissions: {}\njobs:\n  check:\n    runs-on: ubuntu-latest\n'
  workflow-security-check-fixture "$workflow"
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "job 'check' must declare permissions"

  return 0
}

function test-workflow-security-rejects-persisted-checkout-credentials() {

  local workflow=$'name: test\non:\n  push\npermissions: {}\njobs:\n  check:\n    permissions:\n      contents: read\n    runs-on: ubuntu-latest\n    steps:\n      - uses: actions/checkout@0123456789012345678901234567890123456789\n        with:\n          persist-credentials: true\n'
  workflow-security-check-fixture "$workflow"
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "actions/checkout must set persist-credentials: false"

  return 0
}

function test-workflow-security-matches-action-names-case-insensitively() {

  workflow-security-check-fixture "$SAFE_JOB"$'    steps:\n      - uses: Actions/Checkout@0123456789012345678901234567890123456789\n'
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "actions/checkout must set persist-credentials: false"

  return 0
}

function test-workflow-security-rejects-unpinned-action() {

  local workflow=$'name: test\non:\n  push\npermissions: {}\njobs:\n  check:\n    permissions:\n      contents: read\n    runs-on: ubuntu-latest\n    steps:\n      - uses: example/action@v1\n'
  workflow-security-check-fixture "$workflow"
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "action ref is not a full 40-character SHA"

  return 0
}

function test-workflow-security-rejects-secret-expression-in-run() {

  local workflow=$'name: test\non:\n  push\npermissions: {}\njobs:\n  check:\n    permissions:\n      contents: read\n    runs-on: ubuntu-latest\n    steps:\n      - run: echo \'${{ secrets.TOKEN }}\'\n'
  workflow-security-check-fixture "$workflow"
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "secrets must not be interpolated into run scripts"

  return 0
}

function test-workflow-security-rejects-expression-in-run() {

  local workflow=$'name: test\non:\n  push\npermissions: {}\njobs:\n  check:\n    permissions:\n      contents: read\n    runs-on: ubuntu-latest\n    steps:\n      - run: echo "${{ github.event.pull_request.title }}"\n'
  workflow-security-check-fixture "$workflow"
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "expressions must not be interpolated into run scripts"

  return 0
}

function test-workflow-security-rejects-expression-in-github-script() {

  workflow-security-check-fixture "$SAFE_JOB"$'    steps:\n      - uses: actions/github-script@0123456789012345678901234567890123456789\n        with:\n          script: core.info("${{ github.event.issue.title }}")\n'
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "expressions must not be interpolated into actions/github-script scripts"

  return 0
}

function test-workflow-security-rejects-privileged-trigger() {

  local workflow=$'name: test\non:\n  pull_request_target:\n    types: [opened]\npermissions: {}\njobs:\n  check:\n    permissions:\n      contents: read\n    runs-on: ubuntu-latest\n'
  workflow-security-check-fixture "$workflow"
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "$PRIVILEGED_TRIGGER_ERROR"

  return 0
}

function test-workflow-security-rejects-inherited-secrets() {

  local workflow=$'name: test\non:\n  push\npermissions: {}\njobs:\n  check:\n    permissions:\n      contents: read\n    secrets: inherit\n    runs-on: ubuntu-latest\n'
  workflow-security-check-fixture "$workflow"
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "secrets: inherit is prohibited"

  return 0
}

function test-workflow-security-rejects-job-wide-secret() {

  local workflow=$'name: test\non:\n  push\npermissions: {}\njobs:\n  check:\n    permissions:\n      contents: read\n    env:\n      TOKEN: "${{ secrets.TOKEN }}"\n    runs-on: ubuntu-latest\n'
  workflow-security-check-fixture "$workflow"
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "$SECRET_SCOPE_ERROR"

  return 0
}

function test-workflow-security-allows-step-scoped-secret() {

  local workflow=$'name: test\non:\n  push\npermissions: {}\njobs:\n  check:\n    permissions:\n      contents: read\n    runs-on: ubuntu-latest\n    steps:\n      - uses: example/action@0123456789012345678901234567890123456789\n        env:\n          TOKEN: "${{ secrets.TOKEN }}"\n'
  workflow-security-check-fixture "$workflow"
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"

  return 0
}

function test-workflow-security-rejects-unapproved-write-permission() {

  local workflow=$'name: test\non:\n  push\npermissions: {}\njobs:\n  check:\n    permissions:\n      contents: write\n    runs-on: ubuntu-latest\n'
  workflow-security-check-fixture "$workflow"
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "write permission is not approved for job 'check'"

  return 0
}

function test-workflow-security-requires-explicit-mise-token-non-persistence() {

  local workflow=$'name: test\non:\n  push\npermissions: {}\njobs:\n  check:\n    permissions:\n      contents: read\n    runs-on: ubuntu-latest\n    steps:\n      - uses: jdx/mise-action@0123456789012345678901234567890123456789\n'
  workflow-security-check-fixture "$workflow"
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "jdx/mise-action must set persist_github_token: false"

  return 0
}

function test-workflow-security-rejects-privileged-trigger-string() {

  workflow-security-check-fixture $'name: test\non: pull_request_target\npermissions: {}\njobs:\n  check:\n    permissions:\n      contents: read\n    runs-on: ubuntu-latest'
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "$PRIVILEGED_TRIGGER_ERROR"

  return 0
}

function test-workflow-security-rejects-privileged-trigger-list() {

  workflow-security-check-fixture $'name: test\non: [push, workflow_run]\npermissions: {}\njobs:\n  check:\n    permissions:\n      contents: read\n    runs-on: ubuntu-latest'
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "$PRIVILEGED_TRIGGER_ERROR"

  return 0
}

function test-workflow-security-rejects-job-wide-secret-inside-expression() {

  workflow-security-check-fixture "$SAFE_JOB"$'    env:\n      AUTH: "Bearer ${{ secrets.TOKEN }}"\n'
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "$SECRET_SCOPE_ERROR"

  return 0
}

function test-workflow-security-rejects-job-wide-secret-index-syntax() {

  workflow-security-check-fixture "$SAFE_JOB"$'    env:\n      TOKEN: ${{ secrets[\'TOKEN\'] }}\n'
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "$SECRET_SCOPE_ERROR"

  return 0
}

function test-workflow-security-rejects-job-wide-multi-line-secret() {

  workflow-security-check-fixture "$SAFE_JOB"$'    env:\n      TOKEN: |\n        ${{\n          secrets.TOKEN\n        }}\n'
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "$SECRET_SCOPE_ERROR"

  return 0
}

function test-workflow-security-rejects-container-secret() {

  workflow-security-check-fixture "$SAFE_JOB"$'    container:\n      image: alpine\n      env:\n        TOKEN: ${{ secrets.TOKEN }}\n'
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "$SECRET_SCOPE_ERROR"

  return 0
}

function test-workflow-security-rejects-service-secret() {

  workflow-security-check-fixture "$SAFE_JOB"$'    services:\n      db:\n        image: postgres\n        env:\n          POSTGRES_PASSWORD: ${{ secrets.DB_PASSWORD }}\n'
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "$SECRET_SCOPE_ERROR"

  return 0
}

function test-workflow-security-allows-job-wide-secret-presence-check() {

  workflow-security-check-fixture "$SAFE_JOB"$'    env:\n      HAS_TOKEN: ${{ secrets.TOKEN != \'\' && vars.KEY != \'\' }}\n'
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"

  return 0
}

function test-workflow-security-accepts-approved-write-permission() {

  workflow-security-write-fixture allowlist.yaml $'approved_write_permissions:\n  - workflow: test.yaml\n    job: check\n    permission: contents'
  workflow-security-check-fixture "${SAFE_JOB/contents: read/contents: write}"
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"

  return 0
}

function test-workflow-security-rejects-write-permission-approved-for-another-workflow() {

  workflow-security-write-fixture allowlist.yaml $'approved_write_permissions:\n  - workflow: other.yaml\n    job: check\n    permission: contents'
  workflow-security-check-fixture "${SAFE_JOB/contents: read/contents: write}"
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "write permission is not approved for job 'check'"

  return 0
}

function test-workflow-security-rejects-expression-in-action-run() {

  workflow-security-write-fixture actions/example/action.yaml $'name: example\nruns:\n  using: composite\n  steps:\n    - shell: bash\n      run: echo "${{ github.ref_name }}"'
  workflow-security-check-fixture "$SAFE_WORKFLOW"
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "actions/example/action.yaml: expressions must not be interpolated into run scripts"

  return 0
}

function test-workflow-security-rejects-unpinned-action-step() {

  workflow-security-write-fixture actions/example/action.yaml $'name: example\nruns:\n  using: composite\n  steps:\n    - uses: example/action@v1'
  workflow-security-check-fixture "$SAFE_WORKFLOW"
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "actions/example/action.yaml: action ref is not a full 40-character SHA"

  return 0
}

function test-workflow-security-rejects-unparseable-file() {

  workflow-security-check-fixture $'- not a workflow mapping'
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "file is not a valid YAML mapping"

  return 0
}

function test-workflow-security-reports-yaml-parse-error() {

  workflow-security-check-fixture $'name: test\non: push\njobs:\n  check:\n    steps: [\n'
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "did not find expected node content"
  assert-contains "$TEST_STDERR" "file is not a valid YAML mapping"

  return 0
}

function test-workflow-security-rejects-dockerised-quality-action-without-force-docker() {

  workflow-security-write-fixture actions/check-markdown-format/action.yaml $'name: Check Markdown format\nruns:\n  using: composite\n  steps:\n    - name: Check Markdown format\n      shell: bash\n      run: make check-markdown-format'
  workflow-security-check-fixture "$SAFE_WORKFLOW"
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "actions/check-markdown-format/action.yaml: dockerised quality action must set FORCE_USE_DOCKER=true on every run step"

  return 0
}

function test-workflow-security-accepts-dockerised-quality-action-with-force-docker() {

  workflow-security-write-fixture actions/check-markdown-format/action.yaml $'name: Check Markdown format\nruns:\n  using: composite\n  steps:\n    - name: Check Markdown format\n      shell: bash\n      env:\n        FORCE_USE_DOCKER: "true"\n      run: make check-markdown-format'
  workflow-security-check-fixture "$SAFE_WORKFLOW"
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"

  return 0
}

function test-workflow-security-accepts-dockerised-quality-action-with-boolean-force-docker() {

  workflow-security-write-fixture actions/check-shell-lint/action.yaml $'name: Check shell scripts\nruns:\n  using: composite\n  steps:\n    - name: Check shell scripts\n      shell: bash\n      env:\n        FORCE_USE_DOCKER: true\n      run: make check-shell-lint'
  workflow-security-check-fixture "$SAFE_WORKFLOW"
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"

  return 0
}

function test-workflow-security-rejects-mise-in-dockerised-quality-job() {

  workflow-security-write-fixture workflows/stage-1-commit.yaml $'name: Commit stage\non:\n  push\npermissions: {}\njobs:\n  check-markdown-format:\n    permissions:\n      contents: read\n    runs-on: ubuntu-latest\n    steps:\n      - uses: jdx/mise-action@0123456789012345678901234567890123456789\n        with:\n          persist_github_token: false'
  workflow-security-run-fixture
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "job 'check-markdown-format' must use its pinned Docker image instead of jdx/mise-action"

  return 0
}

function test-workflow-security-checks-repository-workflows() {

  test-isolate-path yq jq
  test-capture ./scripts/quality/check-workflow-security.sh
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"

  return 0
}

# ==============================================================================

# Write one workflow fixture and run the policy checker against the fixtures.
# Arguments:
#   $1=[workflow YAML content]
function workflow-security-check-fixture() {

  local workflow="$1"
  workflow-security-write-fixture workflows/test.yaml "$workflow"
  workflow-security-run-fixture

  return 0
}

# Write one fixture file under the test directory.
# Arguments:
#   $1=[path relative to the test directory]
#   $2=[file content]
function workflow-security-write-fixture() {

  local relative_path="$1" content="$2"
  test-mkdir-parent "$TEST_TMP/$relative_path"
  printf '%s\n' "$content" > "$TEST_TMP/$relative_path"

  return 0
}

# Run the policy checker against the fixture workflows, actions and allowlist.
function workflow-security-run-fixture() {

  workflow-security-create-repo
  workflow-security-run-check

  return 0
}

# Create the scratch repository "$TEST_TMP/repo" with the fixture workflows,
# actions and allowlist in their default places, committed on main with
# origin/main pointing at that commit.
function workflow-security-create-repo() {

  local repo="$TEST_TMP/repo"
  # shellcheck disable=SC2119
  quality-create-fixture-repo
  mkdir -p "$repo/.github" "$repo/scripts/config"
  [[ ! -d "$TEST_TMP/workflows" ]] || cp -R "$TEST_TMP/workflows" "$repo/.github/workflows"
  [[ ! -d "$TEST_TMP/actions" ]] || cp -R "$TEST_TMP/actions" "$repo/.github/actions"
  [[ ! -f "$TEST_TMP/allowlist.yaml" ]] || cp "$TEST_TMP/allowlist.yaml" "$repo/scripts/config/workflow-security.yaml"
  git -C "$repo" add -A
  git -C "$repo" commit -q -m workflows
  git -C "$repo" update-ref refs/remotes/origin/main HEAD

  return 0
}

# Run the policy checker in the scratch repository. The isolated PATH links the
# real yq and jq, as a mise shim is slow to start.
# Arguments:
#   $@=[optional environment assignments for the checker]
function workflow-security-run-check() {

  test-isolate-path yq jq
  cd "$TEST_TMP/repo"
  test-capture env "$@" ./scripts/quality/check-workflow-security.sh

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
