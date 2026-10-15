#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034,SC2317,SC2329

set -euo pipefail

# Test suite for the ShellCheck wrapper script. Each test runs the script in a
# scratch repository with 'shellcheck' and 'docker' stubbed, so the suite needs
# neither tool nor a Docker daemon.
#
# Usage:
#   $ ./scripts/quality/tests/check-shell-lint.test.sh
#
# Arguments (provided as environment variables):
#   VERBOSE=true  # Show all the executed commands, default is 'false'

# ==============================================================================

readonly EXIT_STATUS_LABEL='exit status'

function main() {

  cd "$(git rev-parse --show-toplevel)"
  source ./scripts/tests/test.lib.sh
  source ./scripts/quality/tests/quality-test.lib.sh
  QUALITY_FIXTURE_PATHS=(scripts/quality/check-shell-lint.sh scripts/docker/docker.lib.sh)
  QUALITY_FIXTURE_FORMAT='# %s\n'

  # The caller's options must not reach the script under test
  unset -v MISE_TOML match_version file FORCE_USE_DOCKER

  SHELLCHECK_IMAGE=koalaman/shellcheck:v4.0.0@sha256:4444444444444444444444444444444444444444444444444444444444444444

  test-run-suite \
    test-check-shell-lint-defaults-to-itself \
    test-check-shell-lint-makes-an-absolute-path-relative \
    test-check-shell-lint-propagates-shellcheck-failure \
    test-check-shell-lint-uses-docker-when-forced \
    test-check-shell-lint-uses-docker-when-shellcheck-is-missing \
    test-check-shell-lint-stops-when-the-image-pull-fails

  return 0
}

# ==============================================================================

function test-check-shell-lint-defaults-to-itself() {

  # Arrange
  quality-create-fixture-repo scripts/x.sh
  test-isolate-path
  test-stub shellcheck
  cd "$TEST_TMP/repo"
  # Act
  test-capture ./scripts/quality/check-shell-lint.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "WARNING: 'file' variable not set, defaulting to itself" "$TEST_STDOUT" "stdout"
  assert-equal "scripts/quality/check-shell-lint.sh" "$(test-stub-calls shellcheck)" "the only shellcheck call"

  return 0
}

function test-check-shell-lint-makes-an-absolute-path-relative() {

  # Arrange
  quality-create-fixture-repo scripts/x.sh
  test-isolate-path
  test-stub shellcheck
  cd "$TEST_TMP/repo"
  # Act
  test-capture env file="$TEST_TMP/repo/scripts/x.sh" ./scripts/quality/check-shell-lint.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "./scripts/x.sh" "$(test-stub-calls shellcheck)" "the only shellcheck call"

  return 0
}

function test-check-shell-lint-propagates-shellcheck-failure() {

  # Arrange
  quality-create-fixture-repo scripts/x.sh
  test-isolate-path
  test-stub shellcheck 'exit 1'
  cd "$TEST_TMP/repo"
  # Act
  test-capture env file=scripts/x.sh ./scripts/quality/check-shell-lint.sh
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"

  return 0
}

function test-check-shell-lint-uses-docker-when-forced() {

  # Arrange
  quality-create-fixture-repo scripts/x.sh
  test-isolate-path
  test-stub shellcheck
  test-stub docker
  cd "$TEST_TMP/repo"
  # Act
  test-capture env FORCE_USE_DOCKER=true file=scripts/x.sh ./scripts/quality/check-shell-lint.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-stub-not-called shellcheck
  assert-stub-called docker \
    "run --rm --platform linux/amd64 --volume $TEST_TMP/repo:/workdir --workdir /workdir $SHELLCHECK_IMAGE /workdir/scripts/x.sh"
  quality-assert-one-docker-run

  return 0
}

function test-check-shell-lint-uses-docker-when-shellcheck-is-missing() {

  # Arrange
  quality-create-fixture-repo scripts/x.sh
  test-isolate-path
  test-stub docker
  cd "$TEST_TMP/repo"
  # Act
  test-capture env file=scripts/x.sh ./scripts/quality/check-shell-lint.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-stub-called docker \
    "run --rm --platform linux/amd64 --volume $TEST_TMP/repo:/workdir --workdir /workdir $SHELLCHECK_IMAGE /workdir/scripts/x.sh"
  quality-assert-one-docker-run

  return 0
}

function test-check-shell-lint-stops-when-the-image-pull-fails() {

  # Arrange
  quality-create-fixture-repo scripts/x.sh
  test-isolate-path
  # shellcheck disable=SC2016
  test-stub docker 'if [[ "${1:-} ${2:-}" == "image inspect" ]]; then exit 1; fi; if [[ "${1:-}" == pull ]]; then echo "docker: pull access denied" >&2; exit 23; fi'
  cd "$TEST_TMP/repo"
  # Act
  test-capture env FORCE_USE_DOCKER=true file=scripts/x.sh ./scripts/quality/check-shell-lint.sh
  # Assert
  assert-equal 23 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "docker: pull access denied" "pull error on stderr"
  assert-equal "" "$(test-stub-calls docker | grep '^run ' || true)" "no docker run call"

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
