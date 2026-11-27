#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034,SC2317,SC2329

set -euo pipefail

# Run the CI/CD lifecycle command blocks against a project Makefile fixture.
# Check that each target runs and that its failure fails the workflow step.
#
# Usage:
#   $ ./scripts/cicd/tests/lifecycle-workflows.test.sh
#
# Options:
#   VERBOSE=true  # Show all the executed commands, default is 'false'

# ==============================================================================

source "$(dirname "${BASH_SOURCE[0]}")/../../tests/test.lib.sh"

# Run every lifecycle workflow test.
function main() {

  cd "$(git rev-parse --show-toplevel)"

  test-run-suite \
    test-build-workflow-runs-project-build \
    test-publish-workflow-runs-project-publish \
    test-deploy-workflow-runs-project-deploy \
    test-lifecycle-workflows-propagate-target-failures \
    test-publish-metadata-sets-a-unique-dated-version \
    test-publish-metadata-fails-without-a-version-file

  return 0
}

# ==============================================================================

function test-build-workflow-runs-project-build() {

  # Act
  lifecycle-run stage-3-build.yaml artefact-1 build
  # Assert
  assert-equal 0 "$TEST_STATUS" "build exit status: $TEST_STDERR"
  assert-equal build "$(cat "$TEST_TMP/result")" "project build ran"

  return 0
}

function test-publish-workflow-runs-project-publish() {

  # Act
  lifecycle-run cicd-2-publish.yaml publish publish
  # Assert
  assert-equal 0 "$TEST_STATUS" "publish exit status: $TEST_STDERR"
  assert-equal publish "$(cat "$TEST_TMP/result")" "project publish ran"

  return 0
}

function test-deploy-workflow-runs-project-deploy() {

  # Act
  lifecycle-run cicd-3-deploy.yaml deploy deploy
  # Assert
  assert-equal 0 "$TEST_STATUS" "deploy exit status: $TEST_STDERR"
  assert-equal deploy "$(cat "$TEST_TMP/result")" "project deploy ran"

  return 0
}

function test-lifecycle-workflows-propagate-target-failures() {

  local workflow job target
  while read -r workflow job target; do
    # Act
    lifecycle-run "$workflow" "$job" "$target" "$target"
    # Assert
    assert-equal 2 "$TEST_STATUS" "$target failure exit status: $TEST_STDERR"
    assert-equal "" "$(cat "$TEST_TMP/result")" "$target did not complete"
  done <<'CASES'
stage-3-build.yaml artefact-1 build
cicd-2-publish.yaml publish publish
cicd-3-deploy.yaml deploy deploy
CASES

  return 0
}

function test-publish-metadata-sets-a-unique-dated-version() {

  # Arrange
  metadata-prepare
  cp "$TEST_REPO_ROOT/VERSION" VERSION
  # Act
  metadata-run cicd-2-publish.yaml
  # Assert
  assert-equal 0 "$TEST_STATUS" "publish metadata: $TEST_STDERR"
  assert-matches "$(grep '^version=' "$TEST_TMP/output")" '^version=[0-9]{14}$' "version to the second"

  return 0
}

function test-publish-metadata-fails-without-a-version-file() {

  # Arrange
  metadata-prepare
  rm -f VERSION
  # Act
  metadata-run cicd-2-publish.yaml
  # Assert
  assert-equal 1 "$TEST_STATUS" "publish metadata without VERSION"
  assert-equal "" "$(awk '/^version=/' "$TEST_TMP/output")" "version output"

  return 0
}

# ==============================================================================

function metadata-prepare() {

  test-isolate-path yq make
  test-create-repo "$TEST_TMP/project" Makefile mise.toml
  ln -s "$TEST_REPO_ROOT/scripts" "$TEST_TMP/project/scripts"
  cd "$TEST_TMP/project"

  return 0
}

# Run the metadata variables step without inheriting the caller's environment.
# Arguments:
#   $1=[workflow file name]
function metadata-run() {

  local workflow="$1" commands
  commands="$(yq -r '.jobs.metadata.steps[] | select(.id == "variables") | .run' \
    "$TEST_REPO_ROOT/.github/workflows/$workflow")"
  : > "$TEST_TMP/output"
  test-capture env -i PATH="$PATH" GITHUB_OUTPUT="$TEST_TMP/output" \
    bash --noprofile --norc -eo pipefail -c "$commands"

  return 0
}

# Run a workflow step with real Make and isolated project targets.
# Arguments:
#   $1=[workflow file name]
#   $2=[job ID]
#   $3=[step ID and target name]
#   $4=[target to fail, default is empty]
function lifecycle-run() {

  local workflow="$1" job="$2" target="$3" fail_target="${4:-}" commands
  test-isolate-path yq make
  commands="$(JOB="$job" STEP="$target" yq -r \
    '.jobs[strenv(JOB)].steps[] | select(.id == strenv(STEP)) | .run' \
    "$TEST_REPO_ROOT/.github/workflows/$workflow")"
  mkdir -p "$TEST_TMP/project"
  printf '%s\n' \
    '.PHONY: build publish deploy' \
    'build publish deploy:' \
    $'\t@test "$(FAIL_TARGET)" != "$@"' \
    $'\t@printf "%s\\n" "$@" >> "$(RESULT)"' \
    > "$TEST_TMP/project/Makefile"
  : > "$TEST_TMP/result"
  cd "$TEST_TMP/project"
  test-capture env -i PATH="$PATH" RESULT="$TEST_TMP/result" \
    FAIL_TARGET="$fail_target" bash --noprofile --norc -eo pipefail -c "$commands"

  return 0
}

# ==============================================================================

main "$@"

exit 0
