#!/usr/bin/env bash

set -euo pipefail

# Format Markdown files with Prettier, including table alignment. It runs
# Prettier natively when installed, otherwise in a Docker container.
#
# Usage:
#   $ [options] ./scripts/quality/format-markdown.sh
#
# Options:
#   check={all,staged-changes,working-tree-changes,branch}  # Check mode, default is 'working-tree-changes'
#   BRANCH_NAME=other-branch-than-main                      # Branch to compare with, default is 'origin/main'
#   FORCE_USE_DOCKER=true                                   # If set to true the command is run in a Docker container, default is 'false'
#   VERBOSE=true                                            # Show all the executed commands, default is 'false'
#
# Exit codes:
#   0 - All files formatted successfully
#   1 - Formatting failed, the check mode is not recognised, or Docker mode has no exact Prettier pin
#
# Notes:
#   1) Check modes select existing Markdown files known to Git, as described in
#      './scripts/quality/git-files.lib.sh'. Untracked files are never formatted.
#   2) Prettier rewrites the files in place. Its exact version is the
#      'npm:prettier' entry in the '[tools]' table of 'mise.toml', which
#      'make config' installs. In Docker, npx downloads that version at run
#      time, so the container needs network access.

# ==============================================================================

# Format Markdown files in native or Docker mode.
function main() {

  cd "$(git rev-parse --show-toplevel)"

  # shellcheck disable=SC1091
  source ./scripts/quality/git-files.lib.sh
  local check_mode=${check:-working-tree-changes}
  local -a files=()
  quality-collect-git-files files "$check_mode" '*.md' || return "$?"

  if [[ ${#files[@]} -eq 0 ]]; then
    return 0
  fi

  if command -v prettier > /dev/null 2>&1 && ! is-arg-true "${FORCE_USE_DOCKER:-false}"; then
    run-prettier-natively "${files[@]}" || return "$?"
  else
    run-prettier-in-docker "${files[@]}" || return "$?"
  fi

  return 0
}

# Run Prettier natively.
# Arguments:
#   $@=[Markdown file paths to format, relative to the project's top-level directory]
function run-prettier-natively() {

  local rc=0
  prettier \
    --config "$PWD/scripts/config/prettierrc.yaml" \
    --ignore-path "$PWD/scripts/config/.prettierignore" \
    --write \
    "$@" || rc=$?

  return "$rc"
}

# Run Prettier in a Docker container, at the version pinned in 'mise.toml'.
# Arguments:
#   $@=[Markdown file paths to format, relative to the project's top-level directory]
function run-prettier-in-docker() {

  # shellcheck disable=SC1091
  source ./scripts/docker/docker.lib.sh

  local config_file="${MISE_TOML:-$PWD/mise.toml}" version
  if ! version="$(_toml-table-entry tools npm:prettier "$config_file")" \
    || [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "ERROR: no exact 'npm:prettier' version in the [tools] table of $config_file" >&2
    return 1
  fi
  local image
  image=$(name=node docker-get-image-version-and-pull) || return "$?"

  local rc=0
  # No '--network none' or read-only mount: npx downloads Prettier at run time, which then rewrites files
  docker run --rm --platform linux/amd64 \
    --volume "$PWD":/workdir \
    --workdir /workdir \
    "$image" \
    npx --yes "prettier@$version" \
      --config /workdir/scripts/config/prettierrc.yaml \
      --ignore-path /workdir/scripts/config/.prettierignore \
      --write \
      "$@" || rc=$?

  return "$rc"
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
