#!/usr/bin/env bash

set -euo pipefail

# Discover every shell test suite in the repository, run the suites in
# parallel and report each result in a stable order. A test suite is a file
# named '*.test.sh' that is tracked or untracked and not ignored, and a suite
# that is not executable fails. Paths remain NUL-safe throughout discovery and
# execution. Suites in submodules or nested repositories are found only when
# 'dir' points inside them. Loadout-managed directories, such as
# 'scripts/hooks', are git-ignored here, so their suites belong to the loadout
# repository.
#
# Usage:
#   $ [options] ./run-test-suites.sh
#
# Options:
#   dir=path      # Directory within a Git worktree, relative to the
#                 # repository's top-level directory or absolute, default is
#                 # 'scripts'
#   VERBOSE=true  # Show all the executed commands, default is 'false'
#
# Exit codes:
#   0 - Every test suite passed
#   1 - At least one test suite failed, no test suite was found, or Git could
#       not search the directory
#   Other - Non-zero statuses from temporary-file creation or sorting

# ==============================================================================

function main() {

  cd "$(git rev-parse --show-toplevel)"

  local dir=${dir:-scripts}
  local -a suites=()
  find-test-suites suites "$dir" || return "$?"
  if [[ ${#suites[@]} -eq 0 ]]; then
    echo "No test suites found under $dir" >&2
    return 1
  fi
  run-test-suites "${suites[@]}" || return "$?"

  return 0
}

# Collect the tracked and non-ignored untracked test suites under a directory,
# unique and sorted by byte order, as paths that start with the directory. Skip
# paths that no longer exist and fail if Git cannot search the whole directory.
# Arguments:
#   $1=[name reference of the output array]
#   $2=[directory to search]
function find-test-suites() {

  local -n result="$1" || return "$?"
  local dir="$2" base="${2%/}" tmp suite path rc=0
  tmp="$(mktemp -d)" || return "$?"
  if list-test-suites "$dir" "$tmp/list"; then
    while IFS= read -r -d '' suite; do
      path="$base/$suite"
      if [[ "$path" == -* ]]; then
        path="./$path"
      fi
      if [[ -f "$path" ]]; then
        result+=("$path")
      fi
    done < "$tmp/list" || rc=$?
  else
    rc=$?
  fi
  rm -rf "$tmp"

  return "$rc"
}

# Write the test suites Git lists under a directory to a file, NUL-delimited,
# unique and sorted by byte order, relative to the directory.
# Arguments:
#   $1=[directory to search]
#   $2=[file to write]
function list-test-suites() {

  local dir="$1" list="$2" err="$2.err" rc=0
  env -u GIT_GLOB_PATHSPECS -u GIT_NOGLOB_PATHSPECS \
    -u GIT_LITERAL_PATHSPECS -u GIT_ICASE_PATHSPECS \
    git -C "$dir" ls-files -z --cached --others --exclude-standard -- '*.test.sh' \
    > "$list" 2> "$err" || rc=$?
  # Git only warns about a directory it cannot read, so any message is a failure
  if [[ $rc -ne 0 || -s "$err" ]]; then
    cat "$err" >&2
    echo "ERROR: cannot search $dir for test suites" >&2
    return 1
  fi
  # A conflicted path is listed once for each index stage
  LC_ALL=C sort -zu -o "$list" "$list" || return "$?"

  return 0
}

# Run test suites in parallel, then print each suite's output in the given
# order.
# Arguments:
#   $@=[test suite paths]
function run-test-suites() {

  local logs suite rc reason i=0 failed=0
  local -a pids=() paths=("$@") failures=()
  logs="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '$logs'" EXIT

  for suite in "${paths[@]}"; do
    # 'env' keeps the runner's own variables out of the suite and reports a
    # suite that cannot run as 126
    env -u dir -u suites "$suite" > "$logs/$i.log" 2>&1 < /dev/null &
    pids+=("$!")
    i=$((i + 1))
  done

  for i in "${!paths[@]}"; do
    set +e
    wait "${pids[$i]}"
    rc=$?
    set -e
    echo "== ${paths[$i]} =="
    cat "$logs/$i.log"
    if [[ -n "$(tail -c 1 "$logs/$i.log")" ]]; then
      echo
    fi
    if [[ $rc -ne 0 ]]; then
      echo "FAILED: ${paths[$i]} (exit code $rc)"
      reason="$(awk '/^(ERROR|FAILED|ASSERTION FAILED)/ { print; exit }' "$logs/$i.log" || true)"
      failures+=("${paths[$i]}: ${reason:-exit code $rc}")
      failed=$((failed + 1))
    fi
  done

  echo "Suites: ${#paths[@]}, Passed: $((${#paths[@]} - failed)), Failed: $failed"
  if [[ $failed -ne 0 ]]; then
    echo "Failed suites:"
    for reason in "${failures[@]}"; do
      echo "  - $reason"
    done
    return 1
  fi

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
