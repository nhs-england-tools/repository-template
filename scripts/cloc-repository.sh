#!/bin/bash

set -e

# Count lines of code of this repository.
#
# Usage:
#   $ ./cloc-repository.sh
#
# Options:
#   VERBOSE=true    # Show all the executed commands, default is `false`
#   FORMAT=[format] # Set output format [default,cloc-xml,sloccount,json], default is `default`

# ==============================================================================

image_version=latest

# ==============================================================================

function main() {

  docker run --rm --platform linux/amd64 \
    --volume=$PWD:/workdir \
    ghcr.io/make-ops-tools/gocloc:$image_version \
      --output-type=${FORMAT:-default} .
}

function is-arg-true() {

  if [[ "$1" =~ ^(true|yes|y|on|1|TRUE|YES|Y|ON)$ ]]; then
    return 0
  else
    return 1
  fi
}

# ==============================================================================

is-arg-true "$VERBOSE" && set -x

main $*

exit 0
