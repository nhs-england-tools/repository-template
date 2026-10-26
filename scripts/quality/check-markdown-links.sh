#!/usr/bin/env bash

set -euo pipefail

# Check that links in Markdown files resolve. It runs lychee natively when
# installed, otherwise in a Docker container.
#
# Usage:
#   $ [options] ./scripts/quality/check-markdown-links.sh
#
# Options:
#   check={all,staged-changes,working-tree-changes,branch}  # Check mode, default is 'working-tree-changes'
#   BRANCH_NAME=other-branch-than-main                      # Branch to compare with, default is 'origin/main'
#   FORCE_USE_DOCKER=true                                   # If set to true the command is run in a Docker container, default is 'false'
#   VERBOSE=true                                            # Show all the executed commands, default is 'false'
#
# Exit codes:
#   0 - All links are valid
#   1 - The check mode is not recognised, or lychee failed to run
#   2 - Broken links found
#
# Notes:
#   1) Check modes select existing Markdown files known to Git, as described in
#      './scripts/quality/git-files.lib.sh'. Untracked files are never checked.
#   2) The lychee configuration is in './scripts/config/lychee.toml'. For more
#      information, see https://github.com/lycheeverse/lychee

# ==============================================================================

# Run markdown links checks in native or Docker mode.
function main() {

  cd "$(git rev-parse --show-toplevel)"

  # shellcheck disable=SC1091
  source ./scripts/quality/git-files.lib.sh
  local -a files=()
  quality-collect-git-files files "${check:-working-tree-changes}" '*.md' || return "$?"

  if [[ ${#files[@]} -gt 0 ]]; then
    if command -v lychee > /dev/null 2>&1 && ! is-arg-true "${FORCE_USE_DOCKER:-false}"; then
      run-lychee-natively "${files[@]}" || return "$?"
    else
      run-lychee-in-docker "${files[@]}" || return "$?"
    fi
  fi

  return 0
}

# Run lychee natively.
# Arguments:
#   $@=[files to check]
function run-lychee-natively() {

  lychee \
    --config "$PWD/scripts/config/lychee.toml" \
    --no-progress \
    --quiet \
    "$@" || return "$?"

  return 0
}

# Run lychee in a Docker container.
# Arguments:
#   $@=[files to check]
function run-lychee-in-docker() {

  # shellcheck disable=SC1091
  source ./scripts/docker/docker.lib.sh

  local image
  image=$(name=lycheeverse/lychee docker-get-image-version-and-pull) || return "$?"

  docker run --rm --platform linux/amd64 \
    --network none \
    --volume "$PWD":/workdir:ro \
    --workdir /workdir \
    "$image" \
      --config /workdir/scripts/config/lychee.toml \
      --no-progress \
      --quiet \
      "$@" || return "$?"

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
