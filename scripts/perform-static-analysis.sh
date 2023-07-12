#!/bin/bash

set -e

# Script to perform static analysis of the repository content and upload the
# report to SonarCloud.
#
# Usage:
#   $ ./perform-static-analysis.sh
#
# Expects:
#  SONAR_TOKEN    # SonarCloud token
#
# Options:
#   VERBOSE=true  # Show all the executed commands, default is `false`

# ==============================================================================

# SEE: https://hub.docker.com/r/sonarsource/sonar-scanner-cli/tags, use the `linux/amd64` os/arch
image_version=4.8.0@sha256:71ffa933dfa3b58a77d62568dd2d2f41c87271ffe0f7ea7fddb26006d13625d5

# ==============================================================================

function main() {

  docker run --rm --platform linux/amd64 \
    --volume $PWD:/usr/src \
    sonarsource/sonar-scanner-cli:$image_version \
      -Dproject.settings=/usr/src/scripts/config/sonar-scanner.properties \
      -Dsonar.login="$(echo $SONAR_TOKEN)"
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
