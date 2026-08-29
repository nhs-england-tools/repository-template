#!/bin/bash

set -euo pipefail

# Pre-commit git hook to scan for secrets hard-coded in the codebase. This is a
# gitleaks command wrapper. It will run gitleaks natively if it is installed,
# otherwise it will run it in a Docker container.
#
# Usage:
#   $ [options] ./scan-secrets.sh
#
# Options:
#   check={all,staged-changes,working-tree-changes,branch,whole-history,last-commit}
#                                                     # Check mode, default is 'whole-history'
#   BRANCH_NAME=other-branch-than-main                # Branch to compare with, default is 'origin/main'
#   FORCE_USE_DOCKER=true                             # If set to true the command is run in a Docker container, default is 'false'
#   VERBOSE=true                                      # Show all the executed commands, default is 'false'
#
# Exit codes:
#   0 - No leaks present
#   1 - Leaks encountered
#   126 - Unrecognised check mode
#
# The `check` parameter controls what is scanned, so the scope can be limited
# to what is appropriate at the point the check is being applied:
#
#   check=all: staged-changes + working-tree-changes + branch (a full local check)
#   check=staged-changes: scan changes staged for commit
#   check=working-tree-changes: scan unstaged working tree changes
#   check=branch: scan commits made on this branch since $BRANCH_NAME
#   check=whole-history: scan every commit on every branch. This is the default.
#   check=last-commit: scan the most recent commit only

# ==============================================================================

# Run secret scanning in the requested check mode(s).
function main() {

  cd "$(git rev-parse --show-toplevel)"

  local check=${check:-whole-history}
  case $check in
    "all")
      # 'all' aggregates the three local-change checks. Every sub-check runs
      # and the overall result fails if any of them find a leak.
      local rc=0
      run-check staged-changes || rc=1
      run-check working-tree-changes || rc=1
      run-check branch || rc=1
      return "$rc"
      ;;
    "staged-changes" | "working-tree-changes" | "branch" | "whole-history" | "last-commit")
      run-check "$check"
      ;;
    *)
      echo "Unrecognised check mode: $check" >&2
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
    cmd="$(get-cmd-to-run)"
    cmd="$cmd" run-gitleaks-natively || rc=$?
  else
    dir="/workdir"
    cmd="$(get-cmd-to-run)"
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
      cmd="protect --source $dir --verbose --redact"
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
      echo "Unrecognised check mode: $check" >&2
      return 126
      ;;
  esac
  # Include base line file if it exists
  if [ -f "$PWD/scripts/config/.gitleaks-baseline.json" ]; then
    cmd="$cmd --baseline-path $dir/scripts/config/.gitleaks-baseline.json"
  fi
  # Include the config file
  cmd="$cmd --config $dir/scripts/config/gitleaks.toml"
  # Include ignore file if it exists
  if [ -f "$PWD/scripts/config/.gitleaksignore" ]; then
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

  # shellcheck disable=SC2155
  local image=$(name=ghcr.io/gitleaks/gitleaks docker-get-image-version-and-pull)
  local rc=0
  # shellcheck disable=SC2086
  docker run --rm --platform linux/amd64 \
    --volume "$PWD:$dir" \
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

  if [[ "$1" =~ ^(true|yes|y|on|1|TRUE|YES|Y|ON)$ ]]; then
    return 0
  else
    return 1
  fi
}

# ==============================================================================

is-arg-true "${VERBOSE:-false}" && set -x

main "$@"

exit 0
