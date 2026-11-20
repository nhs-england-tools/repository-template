#!/usr/bin/env bash

set -euo pipefail

# Hadolint command wrapper. It runs in Docker by default and natively only when
# FORCE_USE_DOCKER=false and hadolint is installed.
#
# Usage:
#   $ [options] ./dockerfile-linter.sh
#
# Arguments (provided as environment variables):
#   file=Dockerfile         # Dockerfile to lint, relative to the repository
#                           # root, default is './Dockerfile.effective'
#   FORCE_USE_DOCKER=false  # Opt out of Docker when hadolint is installed
#   VERBOSE=true            # Show all the executed commands, default is 'false'

# ==============================================================================

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/docker.lib.sh"

# Lint the Dockerfile natively or in Docker.
function main() {

  cd "$(git rev-parse --show-toplevel)"

  local file=${file:-./Dockerfile.effective}
  local rc=0
  if command -v hadolint > /dev/null 2>&1 && ! is-arg-true "${FORCE_USE_DOCKER:-true}"; then
    file="$file" run-hadolint-natively || rc=$?
  else
    file="$file" run-hadolint-in-docker || rc=$?
  fi

  return "$rc"
}

# Run hadolint natively.
# Arguments (provided as environment variables):
#   file=[path to the Dockerfile to lint, relative to the repository root]
function run-hadolint-natively() {

  local rc=0
  # shellcheck disable=SC2001
  hadolint \
    --config scripts/config/hadolint.yaml \
    "$(echo "$file" | sed "s#$PWD#.#")" || rc=$?

  return "$rc"
}

# Run hadolint in a Docker container.
# Arguments (provided as environment variables):
#   file=[path to the Dockerfile to lint, relative to the repository root]
function run-hadolint-in-docker() {

  local image
  image=$(name=hadolint/hadolint docker-get-image-version-and-pull) || return "$?"
  local rc=0
  # shellcheck disable=SC2001
  docker run --rm --platform "$DOCKER_PLATFORM" \
    --network none \
    --volume "$PWD:/workdir:ro" \
    --workdir /workdir \
    "$image" \
      hadolint \
        --config /workdir/scripts/config/hadolint.yaml \
        "/workdir/$(echo "$file" | sed "s#$PWD#.#")" || rc=$?

  return "$rc"
}

# ==============================================================================

# Check whether the supplied argument represents a true boolean value.
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
