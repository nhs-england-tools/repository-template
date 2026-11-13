#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034,SC2317,SC2329

set -euo pipefail

# Test suite for the pipeline contract check script. Each test writes workflow
# fixtures, commits them to a scratch repository and runs the check there with
# the real yq and jq.
#
# Usage:
#   $ ./scripts/quality/tests/check-pipeline-contract.test.sh
#
# Options:
#   VERBOSE=true  # Show all the executed commands, default is 'false'

# ==============================================================================

readonly NOTIFY_IF="\${{ !cancelled() && github.ref == 'refs/heads/main' }}"
readonly SILENT_WORKFLOW=$'name: test\non: push\npermissions: {}\njobs:\n  check:\n    permissions:\n      contents: read\n    runs-on: ubuntu-latest'
readonly EXIT_STATUS_LABEL='exit status'
readonly NOTIFY_ERROR='workflow must call ./.github/workflows/notify-pipeline-status.yaml'
readonly NOTIFY_IF_ERROR='job notify must start its if: condition with !cancelled(), so it reports failures and stays cancellable'

# Set up the suite fixtures and run every test.
function main() {

  cd "$(git rev-parse --show-toplevel)"
  source ./scripts/tests/test.lib.sh
  source ./scripts/quality/tests/quality-test.lib.sh
  NOTIFYING_WORKFLOW="$(pipeline-contract-notifying-workflow "$NOTIFY_IF" '[build, test]')"
  QUALITY_FIXTURE_PATHS=(scripts/quality/check-pipeline-contract.sh scripts/quality/check-pipeline-contract.jq scripts/quality/git-files.lib.sh scripts/quality/git-base.lib.sh)
  QUALITY_FIXTURE_FORMAT='# %s\n'

  # The caller's options must not reach the script under test
  unset -v check dir BRANCH_NAME GITHUB_BASE_REF QUALITY_PR_BASE

  test-run-suite \
    test-pipeline-contract-rejects-unknown-mode \
    test-pipeline-contract-fails-without-tracked-workflows \
    test-pipeline-contract-accepts-cicd-workflow-that-notifies \
    test-pipeline-contract-rejects-cicd-workflow-without-notification \
    test-pipeline-contract-rejects-notification-skipped-on-failure \
    test-pipeline-contract-rejects-notification-that-cannot-be-cancelled \
    test-pipeline-contract-rejects-notification-that-misses-a-job \
    test-pipeline-contract-accepts-notification-that-needs-one-job \
    test-pipeline-contract-rejects-notification-from-another-workflow \
    test-pipeline-contract-ignores-other-workflows \
    test-pipeline-contract-rejects-unparseable-file \
    test-pipeline-contract-scoped-mode-checks-only-changed-files \
    test-pipeline-contract-scoped-mode-checks-every-file-when-the-rules-change \
    test-pipeline-contract-checks-repository-workflows

  return 0
}

# Build the fixture repository once, every test starts from a copy.
function test-suite-setup() {

  quality-build-fixture-base

  return 0
}

# ==============================================================================

function test-pipeline-contract-rejects-unknown-mode() {

  # Arrange
  pipeline-contract-write-fixture cicd-1-test.yaml "$NOTIFYING_WORKFLOW"
  pipeline-contract-create-repo
  # Act
  pipeline-contract-run-check check=bogus
  # Assert
  assert-equal 126 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "Use check=all, check=staged-changes, check=working-tree-changes, check=branch" "accepted modes"

  return 0
}

function test-pipeline-contract-fails-without-tracked-workflows() {

  # Arrange
  pipeline-contract-write-fixture cicd-1-test.yaml "$NOTIFYING_WORKFLOW"
  pipeline-contract-create-repo
  git -C "$TEST_TMP/repo" rm -q --cached .github/workflows/cicd-1-test.yaml
  # Act
  pipeline-contract-run-check
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "no tracked workflow files found under .github/workflows" "no workflows diagnostic"

  return 0
}

function test-pipeline-contract-accepts-cicd-workflow-that-notifies() {

  # Arrange
  pipeline-contract-write-fixture cicd-1-test.yaml "$NOTIFYING_WORKFLOW"
  pipeline-contract-create-repo
  # Act
  pipeline-contract-run-check
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-equal "" "$TEST_STDERR" "stderr"

  return 0
}

function test-pipeline-contract-rejects-cicd-workflow-without-notification() {

  # Arrange
  pipeline-contract-write-fixture cicd-1-test.yaml "$SILENT_WORKFLOW"
  pipeline-contract-create-repo
  # Act
  pipeline-contract-run-check
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "ERROR: .github/workflows/cicd-1-test.yaml: $NOTIFY_ERROR" "$TEST_STDERR" "diagnostic"

  return 0
}

function test-pipeline-contract-rejects-notification-skipped-on-failure() {

  # Arrange
  pipeline-contract-write-fixture cicd-1-test.yaml \
    "$(pipeline-contract-notifying-workflow "github.ref == 'refs/heads/main'" '[build, test]')"
  pipeline-contract-create-repo
  # Act
  pipeline-contract-run-check
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "ERROR: .github/workflows/cicd-1-test.yaml: $NOTIFY_IF_ERROR" "$TEST_STDERR" "diagnostic"

  return 0
}

function test-pipeline-contract-rejects-notification-that-cannot-be-cancelled() {

  # Arrange
  local condition
  for condition in "always() && github.ref == 'refs/heads/main'" '!cancelled() || true' "\${{ !always() }}"; do
    pipeline-contract-write-fixture cicd-1-test.yaml "$(pipeline-contract-notifying-workflow "\"$condition\"" '[build, test]')"
    pipeline-contract-create-repo
    # Act
    pipeline-contract-run-check
    # Assert
    assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL for $condition"
    assert-equal "ERROR: .github/workflows/cicd-1-test.yaml: $NOTIFY_IF_ERROR" "$TEST_STDERR" "diagnostic for $condition"
    cd "$TEST_TMP"
    rm -rf "$TEST_TMP/repo"
  done

  return 0
}

function test-pipeline-contract-rejects-notification-that-misses-a-job() {

  # Arrange
  pipeline-contract-write-fixture cicd-1-test.yaml "$(pipeline-contract-notifying-workflow "$NOTIFY_IF" '[]')"
  pipeline-contract-create-repo
  # Act
  pipeline-contract-run-check
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "ERROR: .github/workflows/cicd-1-test.yaml: job notify must need every other job, missing: build, test" "$TEST_STDERR" "diagnostic"

  return 0
}

function test-pipeline-contract-accepts-notification-that-needs-one-job() {

  # Arrange
  pipeline-contract-write-fixture cicd-1-test.yaml "$(pipeline-contract-notifying-workflow "'!cancelled()'" build build)"
  pipeline-contract-create-repo
  # Act
  pipeline-contract-run-check
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-equal "" "$TEST_STDERR" "stderr"

  return 0
}

function test-pipeline-contract-rejects-notification-from-another-workflow() {

  # Arrange
  pipeline-contract-write-fixture cicd-1-test.yaml "${NOTIFYING_WORKFLOW/notify-pipeline-status.yaml/stage-1-commit.yaml}"
  pipeline-contract-create-repo
  # Act
  pipeline-contract-run-check
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "$NOTIFY_ERROR" "diagnostic"

  return 0
}

function test-pipeline-contract-ignores-other-workflows() {

  # Arrange
  pipeline-contract-write-fixture stage-1-test.yaml "$SILENT_WORKFLOW"
  pipeline-contract-write-fixture notify-pipeline-status.yaml "$SILENT_WORKFLOW"
  pipeline-contract-create-repo
  # Act
  pipeline-contract-run-check
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-equal "" "$TEST_STDERR" "stderr"

  return 0
}

function test-pipeline-contract-rejects-unparseable-file() {

  # Arrange
  pipeline-contract-write-fixture cicd-1-test.yaml $'name: test\non: push\njobs:\n  check:\n    steps: [\n'
  pipeline-contract-create-repo
  # Act
  pipeline-contract-run-check
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "did not find expected node content" "YAML parser diagnostic"
  assert-contains "$TEST_STDERR" "file is not a valid YAML mapping" "diagnostic"

  return 0
}

function test-pipeline-contract-scoped-mode-checks-only-changed-files() {

  # Arrange
  pipeline-contract-write-fixture cicd-1-existing.yaml "$SILENT_WORKFLOW"
  pipeline-contract-write-fixture cicd-2-test.yaml "$NOTIFYING_WORKFLOW"
  pipeline-contract-create-repo
  printf '%s\n' "${NOTIFYING_WORKFLOW/name: test/name: changed}" > "$TEST_TMP/repo/.github/workflows/cicd-2-test.yaml"
  printf '%s\n' "$SILENT_WORKFLOW" > "$TEST_TMP/repo/.github/workflows/cicd-3-new.yaml"
  git -C "$TEST_TMP/repo" add .github/workflows/cicd-3-new.yaml
  # Act
  pipeline-contract-run-check check=staged-changes
  # Assert
  assert-equal 1 "$TEST_STATUS" "staged-changes $EXIT_STATUS_LABEL"
  assert-equal "ERROR: .github/workflows/cicd-3-new.yaml: $NOTIFY_ERROR" "$TEST_STDERR" "only the staged workflow"
  # Act
  pipeline-contract-run-check check=working-tree-changes
  # Assert
  assert-equal 0 "$TEST_STATUS" "working-tree-changes $EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-equal "" "$TEST_STDERR" "only the unstaged notifying workflow"

  return 0
}

function test-pipeline-contract-scoped-mode-checks-every-file-when-the-rules-change() {

  # Arrange
  local rule_file content
  pipeline-contract-write-fixture cicd-1-test.yaml "$SILENT_WORKFLOW"
  pipeline-contract-create-repo
  for rule_file in scripts/quality/check-pipeline-contract.jq scripts/quality/check-pipeline-contract.sh; do
    # Replace the file, as an executable fixture links to the real script
    content="$(cat "$TEST_TMP/repo/$rule_file")"
    rm "$TEST_TMP/repo/$rule_file"
    printf '%s\n# changed\n' "$content" > "$TEST_TMP/repo/$rule_file"
    chmod 755 "$TEST_TMP/repo/$rule_file"
    git -C "$TEST_TMP/repo" add "$rule_file"
    # Act
    pipeline-contract-run-check check=staged-changes
    # Assert
    assert-equal 1 "$TEST_STATUS" "$rule_file $EXIT_STATUS_LABEL"
    assert-equal "ERROR: .github/workflows/cicd-1-test.yaml: $NOTIFY_ERROR" "$TEST_STDERR" "$rule_file: the unchanged workflow"
    git -C "$TEST_TMP/repo" checkout -q HEAD -- "$rule_file"
  done

  return 0
}

function test-pipeline-contract-checks-repository-workflows() {

  # Act
  test-isolate-path yq jq
  test-capture ./scripts/quality/check-pipeline-contract.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"

  return 0
}

# ==============================================================================

# Print a CI/CD workflow with other jobs and a notify job.
# Arguments:
#   $1=[if: condition of the notify job, as YAML]
#   $2=[needs: of the notify job, as YAML]
#   $@=[names of the other jobs, default is 'build test']
function pipeline-contract-notifying-workflow() {

  local condition="$1" needs="$2" job
  shift 2
  [[ $# -gt 0 ]] || set -- build test
  printf 'name: test\non: push\npermissions: {}\njobs:\n'
  for job in "$@"; do
    printf '  %s:\n    permissions:\n      contents: read\n    runs-on: ubuntu-latest\n' "$job"
  done
  printf '  notify:\n    permissions:\n      contents: read\n    needs: %s\n    if: %s\n    uses: ./.github/workflows/notify-pipeline-status.yaml\n' \
    "$needs" "$condition"

  return 0
}

# Write one workflow fixture under the test directory.
# Arguments:
#   $1=[workflow file name]
#   $2=[file content]
function pipeline-contract-write-fixture() {

  local name="$1" content="$2"
  test-mkdir-parent "$TEST_TMP/workflows/$name"
  printf '%s\n' "$content" > "$TEST_TMP/workflows/$name"

  return 0
}

# Create the scratch repository "$TEST_TMP/repo" with the fixture workflows,
# committed on main with origin/main pointing at that commit.
function pipeline-contract-create-repo() {

  local repo="$TEST_TMP/repo"
  # shellcheck disable=SC2119
  quality-create-fixture-repo
  mkdir -p "$repo/.github"
  cp -R "$TEST_TMP/workflows" "$repo/.github/workflows"
  git -C "$repo" add -A
  git -C "$repo" commit -q -m workflows
  git -C "$repo" update-ref refs/remotes/origin/main HEAD

  return 0
}

# Run the contract check in the scratch repository. The isolated PATH links the
# real yq and jq, as a mise shim is slow to start.
# Arguments:
#   $@=[optional environment assignments for the check]
function pipeline-contract-run-check() {

  test-isolate-path yq jq
  cd "$TEST_TMP/repo"
  test-capture env "$@" ./scripts/quality/check-pipeline-contract.sh

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
