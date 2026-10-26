#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034,SC2317,SC2329

set -euo pipefail

# Test suite for the workflow security check script. Each test writes workflow,
# local action and allowlist fixtures to a scratch directory and runs the check
# against them with the real yq and jq.
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
readonly SECRET_SCOPE_ERROR='secret values must not be set in workflow, job, container, or service environment'

# Set up the suite fixtures and run every test.
function main() {

  cd "$(git rev-parse --show-toplevel)"
  source ./scripts/tests/test.lib.sh
  unset -v dir actions_dir allowlist

  test-run-suite \
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

# ==============================================================================

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
  mkdir -p "$(dirname "$TEST_TMP/$relative_path")"
  printf '%s\n' "$content" > "$TEST_TMP/$relative_path"

  return 0
}

# Run the policy checker against the fixture workflows, actions and allowlist.
function workflow-security-run-fixture() {

  test-capture env \
    dir="$TEST_TMP/workflows" \
    actions_dir="$TEST_TMP/actions" \
    allowlist="$TEST_TMP/allowlist.yaml" \
    ./scripts/quality/check-workflow-security.sh

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
