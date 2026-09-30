#!/bin/bash
# shellcheck disable=SC1091,SC2034,SC2317,SC2329

set -euo pipefail

# Test suite for the Dockerfile linter script. Each test runs the script in a
# scratch repository with 'hadolint' and 'docker' stubbed, so the suite needs
# neither tool nor a Docker daemon.
#
# Usage:
#   $ ./scripts/docker/tests/dockerfile-linter.test.sh
#
# Arguments (provided as environment variables):
#   VERBOSE=true  # Show all the executed commands, default is 'false'

# ==============================================================================

readonly EXIT_STATUS_LABEL='exit status'

function main() {

  cd "$(git rev-parse --show-toplevel)"
  source ./scripts/tests/test.lib.sh
  source ./scripts/quality/tests/quality-test.lib.sh
  QUALITY_FIXTURE_PATHS=(scripts/docker/dockerfile-linter.sh scripts/docker/docker.lib.sh scripts/config/hadolint.yaml)
  QUALITY_FIXTURE_FORMAT='# %s\n'

  # The caller's options must not reach the script under test
  unset -v MISE_TOML match_version file FORCE_USE_DOCKER

  HADOLINT_IMAGE=hadolint/hadolint:v3.0.0@sha256:3333333333333333333333333333333333333333333333333333333333333333

  test-run-suite \
    test-dockerfile-linter-defaults-to-the-effective-dockerfile \
    test-dockerfile-linter-makes-an-absolute-path-relative \
    test-dockerfile-linter-propagates-hadolint-failure \
    test-dockerfile-linter-uses-docker-when-forced

  return 0
}

# ==============================================================================

function test-dockerfile-linter-defaults-to-the-effective-dockerfile() {

  # Arrange
  quality-create-fixture-repo images/app/Dockerfile
  test-isolate-path
  test-stub hadolint
  cd "$TEST_TMP/repo"
  # Act
  test-capture ./scripts/docker/dockerfile-linter.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "--config scripts/config/hadolint.yaml ./Dockerfile.effective" \
    "$(test-stub-calls hadolint)" "the only hadolint call"

  return 0
}

function test-dockerfile-linter-makes-an-absolute-path-relative() {

  # Arrange
  quality-create-fixture-repo images/app/Dockerfile
  test-isolate-path
  test-stub hadolint
  cd "$TEST_TMP/repo"
  # Act
  test-capture env file="$TEST_TMP/repo/images/app/Dockerfile" ./scripts/docker/dockerfile-linter.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "--config scripts/config/hadolint.yaml ./images/app/Dockerfile" \
    "$(test-stub-calls hadolint)" "the only hadolint call"

  return 0
}

function test-dockerfile-linter-propagates-hadolint-failure() {

  # Arrange
  quality-create-fixture-repo images/app/Dockerfile
  test-isolate-path
  test-stub hadolint 'exit 1'
  cd "$TEST_TMP/repo"
  # Act
  test-capture env file=images/app/Dockerfile ./scripts/docker/dockerfile-linter.sh
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"

  return 0
}

function test-dockerfile-linter-uses-docker-when-forced() {

  # Arrange
  local options="--config /workdir/scripts/config/hadolint.yaml /workdir/images/app/Dockerfile"
  quality-create-fixture-repo images/app/Dockerfile
  test-isolate-path
  test-stub hadolint
  test-stub docker
  cd "$TEST_TMP/repo"
  # Act
  test-capture env FORCE_USE_DOCKER=true file=images/app/Dockerfile ./scripts/docker/dockerfile-linter.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-stub-not-called hadolint
  assert-stub-called docker \
    "run --rm --platform linux/amd64 --volume $TEST_TMP/repo:/workdir --workdir /workdir $HADOLINT_IMAGE hadolint $options"
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
