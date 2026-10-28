#!/usr/bin/env bash

set -euo pipefail

# Scan the codebase and its Git history for hard-coded secrets. It runs
# gitleaks natively when installed, otherwise in a Docker container.
#
# Usage:
#   $ [options] ./scripts/quality/scan-secrets.sh
#
# Options:
#   check={all,staged-changes,working-tree-changes,branch,whole-history,
#          last-commit}
#                                       # Check mode, default is 'whole-history'
#   BRANCH_NAME=other-branch-than-main  # Branch to compare with, default is
#                                       # 'origin/main'
#   FORCE_USE_DOCKER=true               # Run in a Docker container, default is
#                                       # 'false'
#   VERBOSE=true                        # Show all the executed commands,
#                                       # default is 'false'
#
# Exit codes:
#   0 - No leaks present
#   1 - Leaks encountered
#   126 - The check mode is not recognised
#
# Check modes:
#   all                   # staged-changes, working-tree-changes and branch
#                         # together
#   staged-changes        # Changes staged for commit
#   working-tree-changes  # Working tree files, including untracked ones
#   branch                # Commits on this branch since BRANCH_NAME
#   whole-history         # Every commit on every branch
#   last-commit           # The most recent commit only

# ==============================================================================

# Run secret scanning in the requested check mode(s).
function main() {

  cd "$(git rev-parse --show-toplevel)"

  local check=${check:-whole-history}
  case $check in
    "all")
      # 'all' aggregates the three local-change checks. Every sub-check runs
      # and the overall result fails if any of them find a leak. The real
      # exit code is preserved instead of being collapsed, so a genuine
      # tool failure (e.g. an unrecognised mode or a Docker error) isn't
      # mistaken for "leaks found".
      local rc=0
      run-check staged-changes || rc=$?
      run-check working-tree-changes || rc=$?
      run-check branch || rc=$?
      return "$rc"
      ;;
    "staged-changes" | "working-tree-changes" | "branch" | "whole-history" | "last-commit")
      run-check "$check"
      ;;
    *)
      echo "Unrecognised check mode: '$check'. Use check=all, check=staged-changes, check=working-tree-changes, check=branch, check=whole-history, check=last-commit" >&2
      return 126
      ;;
  esac

  return 0
}

# Run a single secret-scanning check, natively or in Docker.
# Arguments:
#   $1=[check mode]
function run-check() {

  local check="$1"
  local dir
  local cmd
  local rc=0
  if command -v gitleaks > /dev/null 2>&1 && ! is-arg-true "${FORCE_USE_DOCKER:-false}"; then
    dir="$PWD"
    cmd="$(check="$check" dir="$dir" get-cmd-to-run)"
    cmd="$cmd" run-gitleaks-natively || rc=$?
  else
    dir="/workdir"
    cmd="$(check="$check" dir="$dir" get-cmd-to-run)"
    cmd="$cmd" run-gitleaks-in-docker || rc=$?
  fi

  return "$rc"
}

# Get the Gitleaks command and configuration to execute for the current check.
# Arguments (provided as environment variables):
#   check=[check mode]
#   dir=[project's top-level directory]
function get-cmd-to-run() {

  local cmd
  case $check in
    "staged-changes")
      cmd="protect --source $dir --verbose --redact --staged"
      ;;
    "working-tree-changes")
      # `protect` only diffs tracked files against the index, so untracked
      # files are invisible to it. `detect --no-git` scans the working
      # directory as plain files instead, which also picks up untracked
      # files.
      cmd="detect --no-git --source $dir --verbose --redact"
      ;;
    "branch")
      # Scan only the commits unique to this branch, i.e. those reachable from
      # HEAD but not from the base branch. This keeps the scan scoped to the
      # work in progress and does not fail on secrets that live only on
      # unrelated branches another developer may have pushed.
      cmd="detect --source $dir --verbose --redact --log-opts ${BRANCH_NAME:-origin/main}..HEAD"
      ;;
    "whole-history")
      # Scan every commit on every branch (Gitleaks' default `git log --all`
      # traversal). This is the most thorough mode and the default.
      cmd="detect --source $dir --verbose --redact"
      ;;
    "last-commit")
      cmd="detect --source $dir --verbose --redact --log-opts -1"
      ;;
    *)
      echo "Unrecognised check mode: '$check'. Use check=staged-changes, check=working-tree-changes, check=branch, check=whole-history, check=last-commit" >&2
      return 126
      ;;
  esac
  # Include base line file if it exists
  if [[ -f "$PWD/scripts/config/.gitleaks-baseline.json" ]]; then
    cmd="$cmd --baseline-path $dir/scripts/config/.gitleaks-baseline.json"
  fi
  # Include the config file
  cmd="$cmd --config $dir/scripts/config/gitleaks.toml"
  # Include ignore file if it exists
  if [[ -f "$PWD/scripts/config/.gitleaksignore" ]]; then
    cmd="$cmd --gitleaks-ignore-path $dir/scripts/config/.gitleaksignore"
  fi

  echo "$cmd"

  return 0
}

# Run Gitleaks natively.
# Arguments (provided as environment variables):
#   cmd=[command to run]
function run-gitleaks-natively() {

  # Isolate from the caller's global/system git config (e.g. a customised
  # `log.date` format breaks gitleaks' git-log parsing and silently drops the
  # commit hash from findings), so results match the Docker image's git
  # defaults regardless of the developer machine's configuration.
  local rc=0
  # shellcheck disable=SC2086
  GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null gitleaks $cmd || rc=$?

  return "$rc"
}

# Run Gitleaks in a Docker container.
# Arguments (provided as environment variables):
#   cmd=[command to run]
#   dir=[directory to mount as a volume]
function run-gitleaks-in-docker() {

  # shellcheck disable=SC1091
  source ./scripts/docker/docker.lib.sh

  local image
  image=$(name=ghcr.io/gitleaks/gitleaks docker-get-image-version-and-pull) || return "$?"
  local rc=0
  # shellcheck disable=SC2086
  docker run --rm --platform linux/amd64 \
    --network none \
    --volume "$PWD:$dir:ro" \
    --workdir "$dir" \
    "$image" \
      $cmd || rc=$?

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
