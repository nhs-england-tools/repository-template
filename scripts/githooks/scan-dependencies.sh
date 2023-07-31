#!/bin/bash

set -e

# Pre-commit git hook to scan dependencies for CVEs (Common Vulnerabilities and Exposures).
#
# Usage:
#   $ ./scan-dependencies.sh
#
# Options:
#   VERBOSE=true  # Show all the executed commands, default is `false`

# ==============================================================================

function main() {

  cd $(git rev-parse --show-toplevel)
  ./scripts/reports/generate-sbom.sh
  ./scripts/reports/scan-vulnerabilities.sh
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
