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
#   branch                # Files added or changed since the resolved branch
#                         # fork point, including staged and unstaged changes
#
# Notes:
#   1) Only paths that exist as regular files are returned. Untracked files are
#      never returned.
#   2) Checks read each returned path from the working tree, so in
#      'staged-changes' mode they also see unstaged edits to a staged file.
#      pre-commit stashes those edits before its hooks run.
#   3) 'quality-remove-ignored-paths' drops the paths that a check's ignore
#      file matches, with Git's ignore rules read from the repository root.

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
#   $3=[optional Git pathspec, empty for every path]
#   $4=[optional name reference of an array for the paths that the change set
#     deletes, including the old paths of renamed files, whether or not they
#     exist in the working tree]
function quality-collect-git-files() {

  local -n result="$1" || return "$?"
  local check_mode="$2" deleted_name="${4:-}"
  # shellcheck disable=SC2034
  local file status list_file rc=0 base_ref fork_point
  local -a pathspec=()
  local -A seen=()
  if [[ -n "$deleted_name" ]]; then
    local -n quality_deleted_paths="$deleted_name" || return "$?"
  fi
  if [[ -n "${3:-}" ]]; then
    pathspec=(-- "$3")
  fi
  list_file="$(mktemp)" || return "$?"

  # Renames are listed as a deletion and an addition, so both paths are seen
  case $check_mode in
    all)
      quality-git-paths ls-files -z "${pathspec[@]}" > "$list_file" || rc=$?
      ;;
    staged-changes)
      quality-git-paths diff --diff-filter=ACMRTD --no-renames --name-status -z --cached "${pathspec[@]}" > "$list_file" || rc=$?
      ;;
    working-tree-changes)
      quality-git-paths diff --diff-filter=ACMRTD --no-renames --name-status -z "${pathspec[@]}" > "$list_file" || rc=$?
      ;;
    branch)
      # Sourced only here, so the other modes work without the base resolver
      # shellcheck disable=SC1091
      if source ./scripts/quality/git-base.lib.sh && quality-resolve-base base_ref fork_point; then
        quality-git-paths diff --diff-filter=ACMRTD --no-renames --name-status -z "$fork_point" "${pathspec[@]}" > "$list_file" || rc=$?
      else
        rc=$?
      fi
      ;;
    *)
      echo "Unrecognised check mode: '$check_mode'. Use check=all, check=staged-changes, check=working-tree-changes, check=branch" >&2
      rc=126
      ;;
  esac
  if [[ $rc -ne 0 ]]; then
    rm -f "$list_file"
    return "$rc"
  fi

  status=''
  while IFS= read -r -d '' file; do
    # Diff modes print each status and path as two NUL-terminated fields
    if [[ "$check_mode" != all ]]; then
      status="$file"
      IFS= read -r -d '' file || break
    fi
    [[ -z "${seen[$file]:-}" ]] || continue
    seen["$file"]=1
    [[ "$file" == -* ]] && file="./$file"
    # A path deleted only from the index can still exist, untracked
    if [[ "$status" == D ]]; then
      [[ -z "$deleted_name" ]] || quality_deleted_paths+=("$file")
    elif [[ -f "$file" ]]; then
      result+=("$file")
    fi
  done < "$list_file"
  rm -f "$list_file"

  return 0
}

# Remove from an array the tracked paths that an ignore file matches. The file
# uses Git's ignore syntax, read from the repository root, unlike tools such as
# Prettier that read patterns relative to the ignore file. A missing file
# removes nothing. Paths keep the form they had, including a leading './'.
# Arguments:
#   $1=[name reference of the path array]
#   $2=[ignore file, relative to the repository root]
function quality-remove-ignored-paths() {

  local -n quality_filtered_paths="$1" || return "$?"
  local ignore_file="$2" path list_file rc=0
  local -a kept=()
  local -A ignored=()
  [[ -f "$ignore_file" && ${#quality_filtered_paths[@]} -gt 0 ]] || return 0
  list_file="$(mktemp)" || return "$?"
  quality-git-paths ls-files -z --cached --ignored \
    --exclude-from="$ignore_file" > "$list_file" || rc=$?
  if [[ $rc -eq 0 ]]; then
    while IFS= read -r -d '' path; do
      ignored["$path"]=1
    done < "$list_file"
  fi
  rm -f "$list_file"
  [[ $rc -eq 0 ]] || return "$rc"
  for path in "${quality_filtered_paths[@]}"; do
    [[ -n "${ignored["${path#./}"]:-}" ]] || kept+=("$path")
  done
  quality_filtered_paths=("${kept[@]}")

  return 0
}
