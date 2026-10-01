#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034,SC2317,SC2329

set -euo pipefail

# Test suite for the Markdown links check script. Each test runs the script in
# a scratch repository with 'lychee' and 'docker' stubbed, so the suite needs
# neither tool nor a Docker daemon.
#
# Usage:
#   $ ./scripts/quality/tests/check-markdown-links.test.sh
#
# Arguments (provided as environment variables):
#   VERBOSE=true  # Show all the executed commands, default is 'false'

# ==============================================================================

readonly EXIT_STATUS_LABEL='exit status'

function main() {

  cd "$(git rev-parse --show-toplevel)"
  source ./scripts/tests/test.lib.sh
  source ./scripts/quality/tests/quality-test.lib.sh
  QUALITY_FIXTURE_PATHS=(scripts/quality/check-markdown-links.sh scripts/docker/docker.lib.sh scripts/config/lychee.toml)
  QUALITY_FIXTURE_FORMAT='# %s\n'

  # The caller's options must not reach the script under test
  unset -v MISE_TOML match_version check files BRANCH_NAME FORCE_USE_DOCKER

  LYCHEE_IMAGE=lycheeverse/lychee:5.0.0@sha256:5555555555555555555555555555555555555555555555555555555555555555
  DOCKER_OPTIONS="--config /workdir/scripts/config/lychee.toml --no-progress --quiet"

  test-run-suite \
    test-check-markdown-links-rejects-unknown-mode \
    test-check-markdown-links-does-nothing-without-markdown-changes \
    test-check-markdown-links-all-passes-each-existing-file \
    test-check-markdown-links-working-tree-and-staged-select-the-right-files \
    test-check-markdown-links-branch-skips-deleted-files \
    test-check-markdown-links-fails-when-the-base-branch-is-missing \
    test-check-markdown-links-propagates-lychee-failure \
    test-check-markdown-links-uses-docker-when-forced \
    test-check-markdown-links-uses-docker-when-lychee-is-missing \
    test-check-markdown-links-keeps-paths-with-spaces-intact

  return 0
}

# ==============================================================================

function test-check-markdown-links-rejects-unknown-mode() {

  # Arrange
  quality-create-fixture-repo README.md
  test-isolate-path
  test-stub lychee
  test-stub docker
  cd "$TEST_TMP/repo"
  # Act
  test-capture env check=bogus ./scripts/quality/check-markdown-links.sh
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "Unrecognised check mode: bogus"
  assert-stub-not-called lychee
  assert-stub-not-called docker

  return 0
}

function test-check-markdown-links-does-nothing-without-markdown-changes() {

  # Arrange
  quality-create-fixture-repo README.md
  test-isolate-path
  test-stub lychee
  test-stub docker
  cd "$TEST_TMP/repo"
  # Act
  test-capture ./scripts/quality/check-markdown-links.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-stub-not-called lychee
  assert-stub-not-called docker

  return 0
}

function test-check-markdown-links-all-passes-each-existing-file() {

  # Arrange
  local options="--config $TEST_TMP/repo/scripts/config/lychee.toml --no-progress --quiet"
  quality-create-fixture-repo README.md docs/guide.md gone.md
  test-isolate-path
  test-stub lychee
  rm "$TEST_TMP/repo/gone.md"
  cd "$TEST_TMP/repo"
  # Act
  test-capture env check=all ./scripts/quality/check-markdown-links.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "$options README.md docs/guide.md" "$(test-stub-calls lychee)" "the only lychee call"

  return 0
}

function test-check-markdown-links-working-tree-and-staged-select-the-right-files() {

  # Arrange
  local options="--config $TEST_TMP/repo/scripts/config/lychee.toml --no-progress --quiet"
  local working_tree_status
  quality-create-fixture-repo README.md docs/guide.md
  test-isolate-path
  test-stub lychee
  echo changed >> "$TEST_TMP/repo/README.md"
  echo changed >> "$TEST_TMP/repo/docs/guide.md"
  git -C "$TEST_TMP/repo" add docs/guide.md
  cd "$TEST_TMP/repo"
  # Act
  test-capture env check=working-tree-changes ./scripts/quality/check-markdown-links.sh
  working_tree_status="$TEST_STATUS"
  test-capture env check=staged-changes ./scripts/quality/check-markdown-links.sh
  # Assert
  assert-equal 0 "$working_tree_status" "exit status of working-tree-changes"
  assert-equal 0 "$TEST_STATUS" "exit status of staged-changes"
  assert-equal "$options README.md" "$(test-stub-calls lychee | sed -n 1p)" "working-tree-changes call"
  assert-equal "$options docs/guide.md" "$(test-stub-calls lychee | sed -n 2p)" "staged-changes call"

  return 0
}

function test-check-markdown-links-branch-skips-deleted-files() {

  # Arrange
  quality-create-fixture-repo README.md gone.md
  test-isolate-path
  test-stub lychee
  echo changed >> "$TEST_TMP/repo/README.md"
  git -C "$TEST_TMP/repo" commit -q -am change
  rm "$TEST_TMP/repo/gone.md"
  cd "$TEST_TMP/repo"
  # Act
  test-capture env check=branch ./scripts/quality/check-markdown-links.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$(test-stub-calls lychee) " " README.md "
  assert-not-contains "$(test-stub-calls lychee)" "gone.md"

  return 0
}

function test-check-markdown-links-fails-when-the-base-branch-is-missing() {

  # Arrange
  quality-create-fixture-repo README.md
  test-isolate-path
  test-stub lychee
  echo changed >> "$TEST_TMP/repo/README.md"
  git -C "$TEST_TMP/repo" update-ref -d refs/remotes/origin/main
  cd "$TEST_TMP/repo"
  # Act
  test-capture env check=branch ./scripts/quality/check-markdown-links.sh
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "Branch to compare with not found: origin/main"
  assert-stub-not-called lychee

  return 0
}

function test-check-markdown-links-propagates-lychee-failure() {

  # Arrange
  quality-create-fixture-repo README.md
  test-isolate-path
  test-stub lychee 'exit 1'
  cd "$TEST_TMP/repo"
  # Act
  test-capture env check=all ./scripts/quality/check-markdown-links.sh
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"

  return 0
}

function test-check-markdown-links-uses-docker-when-forced() {

  # Arrange
  quality-create-fixture-repo README.md
  test-isolate-path
  test-stub lychee
  test-stub docker
  cd "$TEST_TMP/repo"
  # Act
  test-capture env FORCE_USE_DOCKER=true check=all ./scripts/quality/check-markdown-links.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-stub-not-called lychee
  assert-stub-called docker \
    "run --rm --platform linux/amd64 --volume $TEST_TMP/repo:/workdir --workdir /workdir $LYCHEE_IMAGE $DOCKER_OPTIONS README.md"
  quality-assert-one-docker-run

  return 0
}

function test-check-markdown-links-uses-docker-when-lychee-is-missing() {

  # Arrange
  quality-create-fixture-repo README.md
  test-isolate-path
  test-stub docker
  cd "$TEST_TMP/repo"
  # Act
  test-capture env check=all ./scripts/quality/check-markdown-links.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-stub-called docker \
    "run --rm --platform linux/amd64 --volume $TEST_TMP/repo:/workdir --workdir /workdir $LYCHEE_IMAGE $DOCKER_OPTIONS README.md"
  quality-assert-one-docker-run

  return 0
}

function test-check-markdown-links-keeps-paths-with-spaces-intact() {

  # Arrange
  local options="--config $TEST_TMP/repo/scripts/config/lychee.toml --no-progress --quiet"
  local native_status
  quality-create-fixture-repo "docs/my doc.md"
  test-isolate-path
  test-stub lychee
  test-stub docker
  cd "$TEST_TMP/repo"
  # Act
  test-capture env check=all ./scripts/quality/check-markdown-links.sh
  native_status="$TEST_STATUS"
  test-capture env FORCE_USE_DOCKER=true check=all ./scripts/quality/check-markdown-links.sh
  # Assert
  assert-equal 0 "$native_status" "exit status of the native run"
  assert-equal 0 "$TEST_STATUS" "exit status of the Docker run"
  assert-equal "$options docs/my\\ doc.md" "$(test-stub-calls lychee)" "the only lychee call"
  assert-stub-called docker \
    "run --rm --platform linux/amd64 --volume $TEST_TMP/repo:/workdir --workdir /workdir $LYCHEE_IMAGE $DOCKER_OPTIONS docs/my\\ doc.md"
  quality-assert-one-docker-run

  return 0
}

# ==============================================================================

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
