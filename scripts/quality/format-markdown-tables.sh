#!/bin/bash

set -euo pipefail

# Format markdown tables to satisfy MD060 aligned style. This is a prettier
# command wrapper. It will run prettier natively via npx if Node.js is
# available, otherwise it will run it in a Docker container.
#
# Usage:
#   $ [options] ./format-markdown-tables.sh
#
# Options:
#   FORCE_USE_DOCKER=true   # If set to true the command is run in a Docker container, default is 'false'
#   VERBOSE=true            # Show all the executed commands, default is `false`
#
# Exit codes:
#   0 - All files formatted successfully
#   1 - Formatting failed

# ==============================================================================

# Format markdown tables natively or in Docker.
function main() {

  cd "$(git rev-parse --show-toplevel)"

  # Filter to tracked markdown files that still exist on disk, so prettier is
  # never handed a path deleted in the working tree but not yet staged. Ignore
  # rules are applied by prettier itself via --ignore-path below.
  local files
  files="$(git ls-files "*.md" | while IFS= read -r f; do if [ -f "$f" ]; then printf '%s\n' "$f"; fi; done)"

  if [ -z "$files" ]; then
    return 0
  fi

  if command -v npx > /dev/null 2>&1 && ! is-arg-true "${FORCE_USE_DOCKER:-false}"; then
    files="$files" run-prettier-natively
  else
    files="$files" run-prettier-in-docker
  fi

  return 0
}

# Run prettier natively via npx.
# Arguments (provided as environment variables):
#   files=[newline-separated list of markdown files to format]
function run-prettier-natively() {

  # shellcheck disable=SC2086
  npx --yes prettier@3 \
    --config "$PWD/scripts/config/prettierrc.yaml" \
    --ignore-path "$PWD/scripts/config/.prettierignore" \
    --write \
    $files

  return 0
}

# Run prettier in a Docker container.
# Arguments (provided as environment variables):
#   files=[newline-separated list of markdown files to format]
function run-prettier-in-docker() {

  # shellcheck disable=SC1091
  source ./scripts/docker/docker.lib.sh

  # shellcheck disable=SC2155
  local image=$(name=node docker-get-image-version-and-pull)
  # shellcheck disable=SC2086
  docker run --rm --platform linux/amd64 \
    --volume "$PWD":/workdir \
    --workdir /workdir \
    "$image" \
    npx --yes prettier@3 \
      --config /workdir/scripts/config/prettierrc.yaml \
      --ignore-path /workdir/scripts/config/.prettierignore \
      --write \
      $files

  return 0
}

# ==============================================================================

# Check whether the supplied argument represents a true boolean value.
# Arguments:
#   $1=[value to evaluate]
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
