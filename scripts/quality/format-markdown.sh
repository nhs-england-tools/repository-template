#!/usr/bin/env bash

set -euo pipefail

# Format Markdown files with Prettier, including table alignment. It runs
# Prettier natively when installed, otherwise in a Docker container.
#
# Usage:
#   $ [options] ./scripts/quality/format-markdown.sh
#
# Options:
#   check={all,staged-changes,working-tree-changes,branch}
#       Check mode, default is 'working-tree-changes'
#   BRANCH_NAME=base-branch
#       Local base for the branch mode, chosen automatically when unset, as
#       './scripts/quality/git-base.lib.sh' describes
#   FORCE_USE_DOCKER=true
#       Run in a Docker container, default is 'false'
#   VERBOSE=true
#       Show all the executed commands, default is 'false'
#
# Exit codes:
#   0 - All files formatted successfully
#   1 - Formatting failed, Docker mode has no exact Prettier pin, or the branch
#       to compare with is not found
#   126 - The check mode is not recognised
#   Other - Non-zero statuses from Git, Prettier, Docker or image pulls
#
# Notes:
#   1) Check modes select existing Markdown files known to Git, as described in
#      './scripts/quality/git-files.lib.sh'. Untracked files are never
#      formatted.
#   2) Prettier rewrites the files in place. Its exact version is the
#      'npm:prettier' entry in the '[tools]' table of 'mise.toml', which
#      'make config' installs. In Docker, npx downloads that version at run
#      time, so the container needs network access.
#   3) Files that match './scripts/config/.prettierignore', read with Git's
#      ignore rules from the repository root, are never formatted. Prettier
#      itself does not read that file, or any other ignore file.

# ==============================================================================

# Format Markdown files in native or Docker mode.
function main() {

  cd "$(git rev-parse --show-toplevel)"

  # shellcheck disable=SC1091
  source ./scripts/quality/git-files.lib.sh
  local check_mode=${check:-working-tree-changes}
  local -a files=()
  quality-collect-git-files files "$check_mode" '*.md' || return "$?"
  # Prettier would read the patterns relative to 'scripts/config/'
  quality-remove-ignored-paths files ./scripts/config/.prettierignore || return "$?"

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
#   $@=[Markdown file paths to format, relative to the repository root]
function run-prettier-natively() {

  local rc=0
  # 'main' already applied the ignore file
  prettier \
    --config "$PWD/scripts/config/prettierrc.yaml" \
    --ignore-path /dev/null \
    --write \
    -- \
    "$@" || rc=$?

  return "$rc"
}

# Run Prettier in a Docker container, at the version pinned in 'mise.toml'.
# Arguments:
#   $@=[Markdown file paths to format, relative to the repository root]
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
  # No '--network none' or read-only mount: npx downloads Prettier at run time,
  # which then rewrites files. 'main' already applied the ignore file.
  docker run --rm --platform linux/amd64 \
    --volume "$PWD":/workdir \
    --workdir /workdir \
    "$image" \
    npx --yes "prettier@$version" \
      --config /workdir/scripts/config/prettierrc.yaml \
      --ignore-path /dev/null \
      --write \
      -- \
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
