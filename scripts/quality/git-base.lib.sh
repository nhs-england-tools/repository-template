#!/usr/bin/env bash

set -euo pipefail

# Resolve the comparison base for branch-scoped quality checks. Source this file
# from the repository root.
#
# Usage:
#   $ source ./scripts/quality/git-base.lib.sh
#
# Arguments (provided as environment variables):
#   GITHUB_BASE_REF=branch  # Pull request base set by GitHub Actions. It wins
#                           # over every other source
#   BRANCH_NAME=ref         # Optional local base, used exactly as given
#   QUALITY_GH_TIMEOUT=n    # Seconds to wait for GitHub CLI, default is '5'
#   QUALITY_PR_BASE=branch  # Pull request base shared by the checks that
#                           # 'make lint check=branch' runs, set by
#                           # quality-export-pr-base. Empty when the branch
#                           # has no open pull request
#
# Exit codes:
#   0 - The base and its merge base with HEAD are resolved
#   1 - The base or the merge base cannot be resolved
#   Other - Non-zero statuses from Git
#
# Notes:
#   1) Without GITHUB_BASE_REF or BRANCH_NAME, the base of the branch's open
#      pull request is read with GitHub CLI. Without one, origin/HEAD and then
#      origin/main are used.
#   2) A branch name from GitHub resolves to its remote-tracking ref, or to the
#      local branch when it has not been fetched.

# ==============================================================================

# Resolve the base ref and its fork point with HEAD, and print both with their
# source on stderr.
# Arguments:
#   $1=[name of the variable to set to the base ref]
#   $2=[name of the variable to set to the merge base with HEAD]
function quality-resolve-base() {

  local base_ref_name="$1" fork_point_name="$2"
  local -n resolved_base_ref="$base_ref_name" resolved_fork_point="$fork_point_name"
  local pr_base base_source merge_base_commit commit_count

  if [[ -n "${GITHUB_BASE_REF:-}" ]]; then
    base_source='GITHUB_BASE_REF'
    quality-find-branch "$base_ref_name" "$GITHUB_BASE_REF" || return "$?"
  elif [[ -n "${BRANCH_NAME:-}" ]]; then
    base_source='BRANCH_NAME'
    if ! quality-verify-ref "$base_ref_name" "$BRANCH_NAME"; then
      echo "Branch to compare with not found: $BRANCH_NAME. Set BRANCH_NAME to an existing branch or commit." >&2
      return 1
    fi
  else
    if [[ -v QUALITY_PR_BASE ]]; then
      pr_base="$QUALITY_PR_BASE"
    else
      pr_base="$(quality-find-pr-base)" || return "$?"
    fi
    if [[ -n "$pr_base" ]]; then
      base_source='open pull request'
      quality-find-branch "$base_ref_name" "$pr_base" || return "$?"
    else
      quality-find-default-base "$base_ref_name" base_source || return "$?"
    fi
  fi

  if ! merge_base_commit="$(git merge-base "$resolved_base_ref" HEAD)"; then
    echo "No merge base found for '$resolved_base_ref' and HEAD. Fetch the base branch history or run 'git fetch --unshallow'." >&2
    return 1
  fi
  commit_count="$(git rev-list --count "$merge_base_commit..HEAD")" || return "$?"
  # shellcheck disable=SC2034
  resolved_fork_point="$merge_base_commit"
  printf 'Comparing with %s (%s, fork %s, %s commits)\n' \
    "$resolved_base_ref" "$base_source" "${merge_base_commit:0:7}" "$commit_count" >&2

  return 0
}

# Look up the pull request base once and export it as QUALITY_PR_BASE, so the
# checks that 'make lint check=branch' runs share one GitHub CLI call. Do
# nothing when GITHUB_BASE_REF or BRANCH_NAME gives the base.
function quality-export-pr-base() {

  local pr_base
  if [[ -n "${GITHUB_BASE_REF:-}" || -n "${BRANCH_NAME:-}" || -v QUALITY_PR_BASE ]]; then
    return 0
  fi
  pr_base="$(quality-find-pr-base)" || return "$?"
  export QUALITY_PR_BASE="$pr_base"

  return 0
}

# Print the base branch of the current branch's open pull request, read with
# GitHub CLI within QUALITY_GH_TIMEOUT seconds. Print nothing, and say why on
# stderr, when there is none.
function quality-find-pr-base() {

  local seconds="${QUALITY_GH_TIMEOUT:-5}" output pid deadline response rc=0
  local open_pattern='^OPEN ([^[:space:]]+)$'
  [[ "$seconds" =~ ^[1-9][0-9]*$ ]] || seconds=5
  if ! command -v gh > /dev/null 2>&1; then
    echo 'GitHub CLI is unavailable, so the default branch is used.' >&2
    return 0
  fi

  output="$(mktemp)" || return "$?"
  gh pr view --json state,baseRefName --jq '.state + " " + .baseRefName' \
    > "$output" 2> /dev/null < /dev/null &
  pid=$!
  deadline=$(( ${EPOCHREALTIME/[.,]/} + seconds * 1000000 ))
  while kill -0 "$pid" 2> /dev/null; do
    if (( ${EPOCHREALTIME/[.,]/} >= deadline )); then
      # GitHub CLI may finish between the check and the signal
      kill "$pid" 2> /dev/null || true
      wait "$pid" 2> /dev/null || true
      rm -f "$output"
      echo "GitHub CLI did not answer within ${seconds}s, so the default branch is used." >&2
      return 0
    fi
    sleep 0.1
  done
  wait "$pid" || rc=$?
  response="$(< "$output")"
  rm -f "$output"
  if [[ $rc -ne 0 || ! "$response" =~ $open_pattern ]]; then
    echo 'GitHub CLI found no open pull request for this branch, so the default branch is used.' >&2
    return 0
  fi
  printf '%s\n' "${BASH_REMATCH[1]}"

  return 0
}

# Resolve a branch name from GitHub to its remote-tracking ref, or to the local
# branch when it has not been fetched.
# Arguments:
#   $1=[name of the variable to set to the ref]
#   $2=[branch name]
function quality-find-branch() {

  local base_ref_name="$1" branch="$2"
  if quality-verify-ref "$base_ref_name" "origin/$branch" \
    || quality-verify-ref "$base_ref_name" "$branch"; then
    return 0
  fi
  echo "Branch to compare with not found: $branch. Fetch it with 'git fetch origin $branch'." >&2

  return 1
}

# Resolve origin/HEAD, falling back to origin/main, as main is always the
# repository's default branch.
# Arguments:
#   $1=[name of the variable to set to the ref]
#   $2=[name of the variable to set to the source description]
function quality-find-default-base() {

  local base_ref_name="$1" source_name="$2" default_ref
  local -n resolved_source="$source_name"
  if default_ref="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD)" \
    && quality-verify-ref "$base_ref_name" "$default_ref"; then
    # shellcheck disable=SC2034
    resolved_source='origin/HEAD'
    return 0
  fi
  if quality-verify-ref "$base_ref_name" origin/main; then
    # shellcheck disable=SC2034
    resolved_source='origin/main fallback'
    return 0
  fi
  echo "Branch to compare with not found: origin/main. Fetch it with 'git fetch origin main', or set BRANCH_NAME." >&2

  return 1
}

# Set a variable to a ref when the ref names a commit.
# Arguments:
#   $1=[name of the variable to set]
#   $2=[ref]
function quality-verify-ref() {

  local verified_name="$1" ref="$2"
  local -n verified_ref="$verified_name"
  git rev-parse --verify --quiet --end-of-options "${ref}^{commit}" > /dev/null || return "$?"
  # shellcheck disable=SC2034
  verified_ref="$ref"

  return 0
}
