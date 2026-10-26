#!/usr/bin/env bash

set -euo pipefail

# Check that files follow the EditorConfig rules defined in '.editorconfig'. It
# runs editorconfig-checker natively when installed, otherwise in a Docker
# container.
#
# Usage:
#   $ [options] ./scripts/quality/check-file-format.sh
#
# Options:
#   check={all,staged-changes,working-tree-changes,branch}  # Check mode, default is 'working-tree-changes'
#   dry_run=true                                            # List the files to check without checking them, default is 'false'
#   BRANCH_NAME=other-branch-than-main                      # Branch to compare with, default is 'origin/main'
#   FORCE_USE_DOCKER=true                                   # If set to true the command is run in a Docker container, default is 'false'
#   VERBOSE=true                                            # Show all the executed commands, default is 'false'
#
# Exit codes:
#   0 - All files are formatted correctly
#   1 - Files are not formatted correctly, or the check mode is not recognised
#
# Notes:
#   1) Check modes select existing files known to Git, as described in
#      './scripts/quality/git-files.lib.sh'. Untracked files are never checked.
#   2) Enable EditorConfig in your IDE. For Visual Studio Code, the
#      'editorconfig.editorconfig' extension is listed in
#      './.vscode/extensions.json'.

# ==============================================================================

# Check file format in native or Docker mode.
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

# Run editorconfig-checker natively.
# Arguments:
#   $@=[optional dry-run flag, paths to check and /dev/null backstop]
function run-editorconfig-natively() {

  editorconfig-checker \
    -config "$PWD/scripts/config/editorconfig-checker.json" \
    --exclude '.git/' "$@" || return "$?"

  return 0
}

# Run editorconfig-checker in a Docker container.
# Arguments:
#   $@=[optional dry-run flag, paths to check and /dev/null backstop]
function run-editorconfig-in-docker() {

  # shellcheck disable=SC1091
  source ./scripts/docker/docker.lib.sh

  local image
  image=$(name=mstruebing/editorconfig-checker docker-get-image-version-and-pull) || return "$?"
  # Forward the variables that select the output format and colour natively
  docker run --rm --platform linux/amd64 \
    --network none \
    --env GITHUB_ACTIONS \
    --env NO_COLOR \
    --volume "$PWD":/check:ro \
    "$image" \
      editorconfig-checker -config /check/scripts/config/editorconfig-checker.json --exclude '.git/' "$@" || return "$?"

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
