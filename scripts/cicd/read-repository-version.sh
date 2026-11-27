#!/usr/bin/env bash

set -euo pipefail

# Read and validate the repository version from VERSION in the current
# directory, then print it for the calling workflow.
#
# Usage:
#   $ ./scripts/cicd/read-repository-version.sh
#
# Options:
#   VERBOSE=true
#       Show all the executed commands, default is 'false'
#
# Exit codes:
#   0 - The version is valid
#   1 - VERSION cannot be read or is not a stable semantic version
#
# Notes:
#   1) Run from the repository root.

# ==============================================================================

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/github-actions.lib.sh"

# Print the validated repository version.
function main() {

  local version
  if ! version="$(cat VERSION)"; then
    print-diagnostic error "Cannot read the repository VERSION file."
    return 1
  fi
  if [[ ! "$version" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
    print-diagnostic error "VERSION must contain a stable semantic version such as 1.2.3."
    return 1
  fi
  printf '%s\n' "$version" || return "$?"

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
