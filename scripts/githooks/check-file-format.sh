#!/bin/bash

set +e

# Pre-commit git hook to check the EditorConfig rules compliance over changed
# files. It ensures all non-binary files across the codebase are formatted
# according to the style defined in the `.editorconfig` file.
#
# Usage:
#   $ check={all,staged-changes,working-tree-changes,branch} [dry_run=true] ./check-file-format.sh
#
# Options:
#   BRANCH_NAME=other-branch-than-main  # Branch to compare with, default is `origin/main`
#   VERBOSE=true                        # Show all the executed commands, default is `false`
#
# Exit codes:
#   0 - All files are formatted correctly
#   1 - Files are not formatted correctly
#
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
# If the `dry_run` parameter is set to a truthy value, the list of
# files that ec would check is output, with no check done.
#
# Notes:
#   Please, make sure to enable EditorConfig linting in your IDE. For the
#   Visual Studio Code editor it is `editorconfig.editorconfig` that is already
#   specified in the `./.vscode/extensions.json` file.

# ==============================================================================

# SEE: https://hub.docker.com/r/mstruebing/editorconfig-checker/tags, use the `linux/amd64` os/arch
image_version=2.7.1@sha256:dd3ca9ea50ef4518efe9be018d669ef9cf937f6bb5cfe2ef84ff2a620b5ddc24

# ==============================================================================


function main() {

  cd $(git rev-parse --show-toplevel)

  is-arg-true "$dry_run" && dry_run_opt="--dry-run"

  check=${check:-working-tree-changes}
  case $check in
    "all")
      filter="git ls-files"
      ;;
    "staged-changes")
      filter="git diff --diff-filter=ACMRT --name-only --cached"
      ;;
    "working-tree-changes")
      filter="git diff --diff-filter=ACMRT --name-only"
      ;;
    "branch")
      filter="git diff --diff-filter=ACMRT --name-only ${BRANCH_NAME:-origin/main}"
      ;;
    *)
      echo "Unrecognised check mode: $check" >&2 && exit 1
      ;;
  esac


  # We use /dev/null here as a backstop in case there are no files in the state
  # we choose.  If the filter comes back empty, adding `/dev/null` onto it has
  # the effect of preventing `ec` from treating "no files" as "all the files".
  docker run --rm --platform linux/amd64 \
    --volume=$PWD:/check \
    mstruebing/editorconfig-checker:$image_version \
      sh -c "ec --exclude '.git/' $dry_run_opt \$($filter) /dev/null"
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
