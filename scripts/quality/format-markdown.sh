#!/usr/bin/env bash

set -euo pipefail

# Format Markdown files with Prettier, including aligned tables. It runs
# Prettier natively via npx if Node.js is available, otherwise in Docker.
#
# Usage:
#   $ [options] ./format-markdown.sh
#
# Options:
#   check={all,staged-changes,working-tree-changes,branch}  # Check mode, default is 'working-tree-changes'
#   BRANCH_NAME=other-branch-than-main                      # Branch to compare with, default is `origin/main`
#   FORCE_USE_DOCKER=true   # If set to true the command is run in a Docker container, default is 'false'
#   VERBOSE=true            # Show all the executed commands, default is `false`
#
# Exit codes:
#   0 - All files formatted successfully
#   1 - Formatting failed

# The `check` parameter controls which files are formatted.
#
#   check=all: format all existing tracked Markdown files
#   check=staged-changes: format Markdown files staged for commit
#   check=working-tree-changes: format modified, unstaged Markdown files. This is the default.
#   check=branch: format all changes since branching from $BRANCH_NAME
#
# Untracked files are not included in any mode.

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

  if command -v npx > /dev/null 2>&1 && ! is-arg-true "${FORCE_USE_DOCKER:-false}"; then
    run-prettier-natively "${files[@]}" || return "$?"
  else
    run-prettier-in-docker "${files[@]}" || return "$?"
  fi

  return 0
}

# Run prettier natively via npx.
# Arguments:
#   $@=[Markdown file paths to format, relative to the project's top-level directory]
function run-prettier-natively() {

  local rc=0
  npx --yes prettier@3 \
    --config "$PWD/scripts/config/prettierrc.yaml" \
    --ignore-path "$PWD/scripts/config/.prettierignore" \
    --write \
    "$@" || rc=$?

  return "$rc"
}

# Run prettier in a Docker container.
# Arguments:
#   $@=[Markdown file paths to format, relative to the project's top-level directory]
function run-prettier-in-docker() {

  # shellcheck disable=SC1091
  source ./scripts/docker/docker.lib.sh

  local image
  image=$(name=node docker-get-image-version-and-pull) || return "$?"

  local rc=0
  docker run --rm --platform linux/amd64 \
    --volume "$PWD":/workdir \
    --workdir /workdir \
    "$image" \
    npx --yes prettier@3 \
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
