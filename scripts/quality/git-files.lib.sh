#!/usr/bin/env bash

set -euo pipefail

# Collect existing Git paths for a quality check. Source this file from the
# repository root.
#
# Usage:
#   $ source ./scripts/quality/git-files.lib.sh
#
# Check modes:
#   all                   # Every tracked file
#   staged-changes        # Files added or changed in the index
#   working-tree-changes  # Files changed in the working tree but not yet staged
#   branch                # Files added or changed since BRANCH_NAME, default 'origin/main', including uncommitted changes
#
# Notes:
#   1) Only paths that exist as regular files are returned. Untracked files are
#      never returned.

# ==============================================================================

# Run Git without caller pathspec overrides. The collector requests NUL output.
# Arguments:
#   $@=[Git subcommand and arguments]
function quality-git-paths() {

  env -u GIT_GLOB_PATHSPECS -u GIT_NOGLOB_PATHSPECS \
    -u GIT_LITERAL_PATHSPECS -u GIT_ICASE_PATHSPECS git "$@"

  return $?
}

# Collect unique, existing paths selected by the requested check mode.
# Arguments:
#   $1=[name reference of output array]
#   $2=[check mode]
#   $3=[optional Git pathspec]
function quality-collect-git-files() {

  local -n result="$1" || return "$?"
  local check_mode="$2" base_branch=${BRANCH_NAME:-origin/main}
  local file list_file rc
  local -a pathspec=()
  local -A seen=()
  if [[ $# -ge 3 ]]; then
    pathspec=(-- "$3")
  fi
  list_file="$(mktemp)" || return "$?"

  case $check_mode in
    all)
      if quality-git-paths ls-files -z "${pathspec[@]}" > "$list_file"; then :; else
        rc=$?
        rm -f "$list_file"
        return "$rc"
      fi
      ;;
    staged-changes)
      if quality-git-paths diff --diff-filter=ACMRT --name-only -z --cached "${pathspec[@]}" > "$list_file"; then :; else
        rc=$?
        rm -f "$list_file"
        return "$rc"
      fi
      ;;
    working-tree-changes)
      if quality-git-paths diff --diff-filter=ACMRT --name-only -z "${pathspec[@]}" > "$list_file"; then :; else
        rc=$?
        rm -f "$list_file"
        return "$rc"
      fi
      ;;
    branch)
      if ! git rev-parse --verify --quiet "${base_branch}^{commit}" > /dev/null; then
        echo "Branch to compare with not found: $base_branch" >&2
        rm -f "$list_file"
        return 1
      fi
      if quality-git-paths diff --diff-filter=ACMRT --name-only -z "$base_branch" "${pathspec[@]}" > "$list_file"; then :; else
        rc=$?
        rm -f "$list_file"
        return "$rc"
      fi
      if quality-git-paths diff --diff-filter=ACMRT --name-only -z "${pathspec[@]}" >> "$list_file"; then :; else
        rc=$?
        rm -f "$list_file"
        return "$rc"
      fi
      ;;
    *)
      echo "Unrecognised check mode: $check_mode" >&2
      rm -f "$list_file"
      return 1
      ;;
  esac

  while IFS= read -r -d '' file; do
    if [[ -f "$file" && -z "${seen[$file]:-}" ]]; then
      if [[ "$file" == -* ]]; then
        result+=("./$file")
      else
        result+=("$file")
      fi
      seen["$file"]=1
    fi
  done < "$list_file"
  rm -f "$list_file"

  return 0
}
