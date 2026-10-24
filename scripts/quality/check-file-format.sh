#!/usr/bin/env bash

set -euo pipefail

# Pre-commit git hook to check the EditorConfig rules compliance over changed
# files. It ensures all non-binary files across the codebase are formatted
# according to the style defined in the `.editorconfig` file. This is an
# `editorconfig-checker` command wrapper. It will run it natively if it is
# installed, otherwise it will run it in a Docker container.
#
# Usage:
#   $ [options] ./check-file-format.sh
#
# Options:
#   check={all,staged-changes,working-tree-changes,branch}  # Check mode, default is 'working-tree-changes'
#   dry_run=true                                            # Do not check, run dry run only, default is 'false'
#   BRANCH_NAME=other-branch-than-main                      # Branch to compare with, default is `origin/main`
#   FORCE_USE_DOCKER=true                                   # If set to true the command is run in a Docker container, default is 'false'
#   VERBOSE=true                                            # Show all the executed commands, default is `false`
#
# Exit codes:
#   0 - All files are formatted correctly
#   1 - Files are not formatted correctly
#
# The `check` parameter controls which files are checked, so you can
# limit the scope of the check according to what is appropriate at the
# point the check is being applied.
#
#   check=all: check all files in the repository
#   check=staged-changes: check only files staged for commit.
#   check=working-tree-changes: check modified, unstaged files. This is the default.
#   check=branch: check for all changes since branching from $BRANCH_NAME
#
# Note: All modes operate on files known to Git. Untracked files (never
# added with `git add`) are invisible to every mode, including `all`.
#
# Notes:
#   Please make sure to enable EditorConfig linting in your IDE. For the
#   Visual Studio Code editor it is `editorconfig.editorconfig` that is already
#   specified in the `./.vscode/extensions.json` file.

# ==============================================================================

function main() {

  cd "$(git rev-parse --show-toplevel)"

  # shellcheck disable=SC1091
  source ./scripts/quality/git-files.lib.sh
  local -a files=() dry_run_opt=()
  quality-collect-git-files files "${check:-working-tree-changes}" || return "$?"
  if is-arg-true "${dry_run:-false}"; then
    dry_run_opt=(--dry-run)
  fi

  # Pass /dev/null when no paths are selected so editorconfig-checker cannot
  # treat an empty argument list as a request to check all tracked files.
  if command -v editorconfig-checker > /dev/null 2>&1 && ! is-arg-true "${FORCE_USE_DOCKER:-false}"; then
    run-editorconfig-natively "${dry_run_opt[@]}" "${files[@]}" /dev/null || return "$?"
  else
    run-editorconfig-in-docker "${dry_run_opt[@]}" "${files[@]}" /dev/null || return "$?"
  fi

  return 0
}

# Run editorconfig natively.
# Arguments:
#   $@=[optional dry-run flag, paths to check and /dev/null backstop]
function run-editorconfig-natively() {

  editorconfig-checker \
    -config "$PWD/scripts/config/editorconfig-checker.json" \
    --exclude '.git/' "$@" || return "$?"

  return 0
}

# Run editorconfig in a Docker container.
# Arguments:
#   $@=[optional dry-run flag, paths to check and /dev/null backstop]
function run-editorconfig-in-docker() {

  # shellcheck disable=SC1091
  source ./scripts/docker/docker.lib.sh

  local image
  image=$(name=mstruebing/editorconfig-checker docker-get-image-version-and-pull) || return "$?"
  # Forward the variables that select the output format and colour natively
  docker run --rm --platform linux/amd64 \
    --env GITHUB_ACTIONS \
    --env NO_COLOR \
    --volume "$PWD":/check \
    "$image" \
      editorconfig-checker -config /check/scripts/config/editorconfig-checker.json --exclude '.git/' "$@" || return "$?"

  return 0
}

# ==============================================================================

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
