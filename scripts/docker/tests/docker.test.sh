#!/bin/bash
# shellcheck disable=SC1091,SC2034,SC2317

# WARNING: Please, DO NOT edit this file! It is maintained in the Repository Template (https://github.com/nhs-england-tools/repository-template). Raise a PR instead.

set -euo pipefail

# Test suite for Docker functions.
#
# Usage:
#   $ ./docker.test.sh
#
# Arguments (provided as environment variables):
#   VERBOSE=true  # Show all the executed commands, default is 'false'

# ==============================================================================

function main() {

  cd "$(git rev-parse --show-toplevel)"
  source ./scripts/docker/docker.lib.sh
  cd ./scripts/docker/tests

  DOCKER_IMAGE=repository-template/docker-test
  DOCKER_TITLE="Repository Template Docker Test"

  test-docker-suite-setup
  tests=( \
    test-docker-build \
    test-docker-test \
    test-docker-run \
    test-docker-clean \
  )
  for test in "${tests[@]}"; do
    (
      echo -n "$test"
      $test && echo " PASS" || echo " FAIL"
    )
  done
  test-docker-suite-teardown
}

# ==============================================================================

function test-docker-suite-setup() {

  :
}

function test-docker-suite-teardown() {

  :
}

# ==============================================================================

function test-docker-build() {

  # Act
  docker-build > /dev/null 2>&1
  # Assert
  docker image inspect "${DOCKER_IMAGE}:$(cat .version)" > /dev/null 2>&1 && return 0 || return 1
}

function test-docker-test() {

  # Arrange
  cmd="python --version"
  check="Python"
  # Act
  output=$(docker-check-test)
  # Assert
  echo "$output" | grep -q "PASS"
}

function test-docker-run() {

  # Arrange
  cmd="python --version"
  # Act
  output=$(docker-run)
  # Assert
  echo "$output" | grep -Eq "Python [0-9]+\.[0-9]+\.[0-9]+"
}

function test-docker-clean() {

  # Arrange
  version="$(cat .version)"
  # Act
  docker-clean
  # Assert
  docker image inspect "${DOCKER_IMAGE}:${version}" > /dev/null 2>&1 && return 1 || return 0
}

# ==============================================================================

function is_arg_true() {

  if [[ "$1" =~ ^(true|yes|y|on|1|TRUE|YES|Y|ON)$ ]]; then
    return 0
  else
    return 1
  fi
}

# ==============================================================================

is_arg_true "${VERBOSE:-false}" && set -x

main "$@"

exit 0
