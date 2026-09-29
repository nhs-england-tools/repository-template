#!/bin/bash
# shellcheck disable=SC1091,SC2034,SC2317,SC2329

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
    test-docker-image-from-signature \
    test-docker-version-file \
    test-docker-test \
    test-docker-run \
    test-docker-clean \
    test-docker-get-image-version-and-pull \
    test-docker-toml-table-entries \
    test-docker-get-image-version \
  )
  local status=0
  for test in "${tests[@]}"; do
    {
      echo -n "$test"
      # shellcheck disable=SC2015
      $test && echo " PASS" || { echo " FAIL"; status=$((status + 1)); }
    }
  done
  echo "Total: ${#tests[@]}, Passed: $(( ${#tests[@]} - status )), Failed: $status"
  test-docker-suite-teardown
  [[ $status -gt 0 ]] && return 1 || return 0
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

  # Arrange
  export BUILD_DATETIME="2023-09-04T15:46:34+0000"
  # Act
  docker-build > /dev/null 2>&1
  # Assert
  docker image inspect "${DOCKER_IMAGE}:$(_get-effective-version)" > /dev/null 2>&1 && return 0 || return 1
}

function test-docker-image-from-signature() {

  # Arrange
  MISE_TOML="$(git rev-parse --show-toplevel)/scripts/docker/tests/mise.toml.test"
  cp Dockerfile Dockerfile.effective
  # Act
  _replace-image-latest-by-specific-version
  # Assert
  grep -q "FROM python:.*-alpine.*@sha256:.*" Dockerfile.effective && return 0 || return 1
}

function test-docker-version-file() {

  # Arrange
  export BUILD_DATETIME="2023-09-04T15:46:34+0000"
  # Act
  version-create-effective-file
  # Assert
  # shellcheck disable=SC2002
  (
      cat .version | grep -q "20230904-" &&
      cat .version | grep -q "2023.09.04-" &&
      cat .version | grep -q "somme-name-yyyyeah"
  ) && return 0 || return 1
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
  version="$(_get-effective-version)"
  # Act
  docker-clean
  # Assert
  docker image inspect "${DOCKER_IMAGE}:${version}" > /dev/null 2>&1 && return 1 || return 0
}

function test-docker-get-image-version-and-pull() {

  # Arrange
  name="ghcr.io/nhs-england-tools/github-runner-image"
  match_version=".*-rt.*"
  # Act
  docker-get-image-version-and-pull > /dev/null 2>&1
  # Assert
  docker images \
    --filter=reference="$name" \
    --format "{{.Tag}}" \
  | grep -vq "<none>"
}

function test-docker-toml-table-entries() {

  # Arrange
  local config_file expected_docker expected_tools
  config_file="$(git rev-parse --show-toplevel)/scripts/docker/tests/mise.toml.test"
  expected_docker="$(printf '%s\n' \
    "python 3.11.4-alpine3.18@sha256:0135ae6442d1269379860b361760ad2cf6ab7c403d21935a8015b48d5bf78a86" \
    "cimg/python 3.12.0@sha256:1111111111111111111111111111111111111111111111111111111111111111" \
    "ghcr.io/org/single-quoted 1.0.0@sha256:2222222222222222222222222222222222222222222222222222222222222222")"
  expected_tools="python 3.14.7"
  # Act
  local actual_docker actual_tools
  actual_docker="$(_toml-table-entries "_.docker" "$config_file")"
  actual_tools="$(_toml-table-entries "tools" "$config_file")"
  # Assert
  [[ "$actual_docker" == "$expected_docker" && "$actual_tools" == "$expected_tools" ]] && return 0 || return 1
}

function test-docker-get-image-version() {

  # Arrange
  MISE_TOML="$(git rev-parse --show-toplevel)/scripts/docker/tests/mise.toml.test"
  # Earlier tests leave match_version set globally
  unset match_version
  # Act
  local exact suffix quoted missing filtered
  exact="$(name=python _get-docker-image-version)"
  suffix="$(name=cimg/python _get-docker-image-version)"
  quoted="$(name=ghcr.io/org/single-quoted _get-docker-image-version)"
  missing="$(name=org/not-pinned _get-docker-image-version)"
  filtered="$(name=python match_version=".*-rt.*" _get-docker-image-version)"
  # Assert
  [[ "$exact" == "3.11.4-alpine3.18@sha256:0135ae6442d1269379860b361760ad2cf6ab7c403d21935a8015b48d5bf78a86" ]] &&
  [[ "$suffix" == "3.12.0@sha256:1111111111111111111111111111111111111111111111111111111111111111" ]] &&
  [[ "$quoted" == "1.0.0@sha256:2222222222222222222222222222222222222222222222222222222222222222" ]] &&
  [[ "$missing" == "latest" ]] &&
  [[ "$filtered" == "latest" ]] &&
  return 0 || return 1
}

# ==============================================================================

function is-arg-true() {

  if [[ "$1" =~ ^(true|yes|y|on|1|TRUE|YES|Y|ON)$ ]]; then
    return 0
  else
    return 1
  fi
}

# ==============================================================================

is-arg-true "${VERBOSE:-false}" && set -x

main "$@"

exit 0
