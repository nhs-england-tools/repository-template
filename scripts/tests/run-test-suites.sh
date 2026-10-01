#!/usr/bin/env bash

set -euo pipefail

# Discover every shell test suite in the repository, run the suites in
# parallel and report each result in a stable order. A test suite is a file
# named '*.test.sh' that git does not ignore, and a suite that is not
# executable fails. Loadout-managed directories, such as 'scripts/hooks', are
# git-ignored here, so their suites belong to the loadout repository.
#
# Usage:
#   $ [options] ./run-test-suites.sh
#
# Options:
#   dir=path      # Directory to search for test suites, relative to the repository's top-level directory or absolute, default is 'scripts'
#   VERBOSE=true  # Show all the executed commands, default is 'false'
#
# Exit codes:
#   0 - Every test suite passed
#   1 - At least one test suite failed, no test suite was found, or a directory could not be searched

# ==============================================================================

function main() {

  cd "$(git rev-parse --show-toplevel)"

  local dir=${dir:-scripts}
  local suites
  suites="$(dir="$dir" find-test-suites)"
  if [[ -z "$suites" ]]; then
    echo "No test suites found under $dir" >&2
    return 1
  fi
  suites="$suites" run-test-suites

  return 0
}

# Print the test suites under a directory, one per line, sorted, skipping the
# ones git ignores. Fail if any part of the directory cannot be searched.
# Arguments (provided as environment variables):
#   dir=[directory to search]
function find-test-suites() {

  local found suite
  if ! found="$(find "$dir" -type f -name '*.test.sh')"; then
    echo "ERROR: cannot search $dir for test suites" >&2
    return 1
  fi
  if [[ -z "$found" ]]; then
    return 0
  fi
  LC_ALL=C sort <<< "$found" | while IFS= read -r suite; do
    # Exit status 1 means not ignored and 128 means not in a git repository
    if ! git -C "$(dirname "$suite")" check-ignore -q -- "$(basename "$suite")" 2> /dev/null; then
      echo "$suite"
    fi
  done

  return 0
}

# Run test suites in parallel, then print each suite's output in the given order.
# Arguments (provided as environment variables):
#   suites=[newline-separated list of test suite paths]
function run-test-suites() {

  local logs suite rc reason i=0 failed=0
  local -a pids=() paths=() failures=()
  logs="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '$logs'" EXIT

  while IFS= read -r suite; do
    # 'env' keeps the runner's own variables out of the suite and reports a suite that cannot run as 126
    env -u dir -u suites "$suite" > "$logs/$i.log" 2>&1 < /dev/null &
    pids+=("$!")
    paths+=("$suite")
    i=$((i + 1))
  done <<< "$suites"

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
