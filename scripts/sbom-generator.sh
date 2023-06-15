#!/bin/bash

set -e

# Script to generate SBOM (Software Bill of Materials) for the repository
# content and any artefact created by the CI/CD pipeline.
#
# Usage:
#   $ ./generate-sbom.sh
#
# Options:
#   VERBOSE=true  # Show all the executed commands, default is `false`

# ==============================================================================

image_version=v0.83.0@sha256:aa3c040294b0a46b5cf38859fc245da929772161431e1003bfe43cb2852d128d

# ==============================================================================

function main() {

  docker run --rm --platform linux/amd64 \
    --volume $PWD:/scan \
    ghcr.io/anchore/syft:$image_version \
      packages dir:/scan --output spdx-json=/scan/sbom-spdx.json
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
