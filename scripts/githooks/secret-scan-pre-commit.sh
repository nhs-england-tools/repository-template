#!/bin/bash

set -e

# Pre-commit git hook to scan for secrets hardcoded in the codebase.
#
# Usage:
#   $ ./secret-scan-pre-commit.sh
#
# Options:
#   ALL_FILES=true  # Check all files, default is `false`
#   VERBOSE=true    # Show all the executed commands, default is `false`
#
# Exit codes:
#   0 - No leaks present
#   1 - Leaks or error encountered
#   126 - Unknown flag

# ==============================================================================

image_version=v8.16.3@sha256:05b48ff3f4fd7daa9487b42cbf9d576f2dc0dbe2551e3d0a8738e18ba2278091 # v8.16.3

# ==============================================================================

function main() {

  if is_arg_true "$ALL_FILES"; then

    # Check all files
    docker run --rm --platform linux/amd64 \
      --volume=$PWD:/check \
      ghcr.io/gitleaks/gitleaks:$image_version \
        detect --source=/check --verbose --redact

  else

    # Check changed files only
    docker run --rm --platform linux/amd64 \
      --volume=$PWD:/check \
      ghcr.io/gitleaks/gitleaks:$image_version \
        protect --source=/check --verbose --redact --staged

  fi
}

function is_arg_true() {

  if [[ "$1" =~ ^(true|yes|y|on|1|TRUE|YES|Y|ON)$ ]]; then
    return 0
  else
    return 1
  fi
}

# ==============================================================================

is_arg_true "$VERBOSE" && set -x

main $*

exit 0
