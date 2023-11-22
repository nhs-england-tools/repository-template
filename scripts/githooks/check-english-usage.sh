#!/bin/bash

set -e

# Git hook to check prose style
#
# Usage:
#   $ check={all,staged-changes,working-tree-changes,branch} ./check-english-usage.sh
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
# ==============================================================================

image_version=v2.29.0@sha256:d4647754ea0d051d574bafe79edccaaa67f25a4c227b890a55dd83a117278590

# ==============================================================================

function main() {

  cd $(git rev-parse --show-toplevel)

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

  # We use /dev/null here to stop `vale` from complaining that it's
  # not been called correctly if the $filter happens to return an
  # empty list.  As long as there's a filename, even if it's one that
  # will be ignored, `vale` is happy.
  docker run --rm --platform linux/amd64 \
    --volume $PWD:/workdir \
    --workdir /workdir \
    jdkato/vale:$image_version \
      --config scripts/config/vale/vale.ini \
      $($filter) /dev/null
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
