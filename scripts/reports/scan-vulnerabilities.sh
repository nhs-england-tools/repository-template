#!/bin/bash

set -e

# Script to scan an SBOM file for CVEs (Common Vulnerabilities and Exposures).
#
# Usage:
#   $ ./scan-vulnerabilities.sh
#
# Options:
#   VERBOSE=true  # Show all the executed commands, default is `false`

# ==============================================================================

# SEE: https://github.com/anchore/grype/pkgs/container/grype, use the `linux/amd64` os/arch
image_version=v0.64.2@sha256:f24e2282b5ff43a2a4df2280e9afcdac5a645df860b03db269049cbfb2cc25b4

# ==============================================================================

function main() {

  docker run --rm --platform linux/amd64 \
    --volume $PWD:/scan \
    ghcr.io/anchore/grype:$image_version \
      sbom:/scan/sbom-report.json \
      --config /scan/scripts/config/.grype.yaml \
      --output json \
      --file /scan/vulnerabilities-report.json
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
