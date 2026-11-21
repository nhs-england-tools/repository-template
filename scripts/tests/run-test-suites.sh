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
#   QUALITY_GATE_RESULT_FILE=path
#                 # Optional absolute private verdict path supplied by the hook
#   VERBOSE=true  # Show all the executed commands, default is 'false'
#
# Exit codes:
#   0 - Every test suite passed
#   1 - At least one test suite failed, no test suite was found, or Git could
#       not search the directory
#   77 - Verification is incomplete solely because prerequisites are unavailable
#   Other - Non-zero statuses from temporary-file creation or sorting

# ==============================================================================

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/../cicd/github-actions.lib.sh"

function main() {

  publish-result fail || return 1
  cd "$(git rev-parse --show-toplevel)" || return 1

  local dir=${dir:-scripts}
  local -a suites=()
  find-test-suites suites "$dir" || return "$?"
  if [[ ${#suites[@]} -eq 0 ]]; then
    print-diagnostic error "No test suites found under '$dir'. Verification did not run. Check discovery with: git -C '$dir' ls-files --cached --others --exclude-standard -- '*.test.sh'"
    return 1
  fi
  run-test-suites "${suites[@]}" || return "$?"
  publish-result pass || return 1

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
  tmp="$(mktemp -d)" || {
    print-diagnostic error "cannot create discovery scratch directory. Verification did not run. Diagnose with: mktemp -d"
    return 1
  }
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
  rm -rf "$tmp" || {
    print-diagnostic error "cannot remove discovery scratch directory '$tmp'. Inspect with: ls -ld '$tmp'"
    return 1
  }

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
    print-diagnostic error "cannot search $dir for test suites. Verification did not run. Diagnose with: git -C '$dir' ls-files --cached --others --exclude-standard -- '*.test.sh'"
    return 1
  fi
  # A conflicted path is listed once for each index stage
  LC_ALL=C sort -zu -o "$list" "$list" || {
    print-diagnostic error "cannot sort discovered suites in '$list'. Verification did not run. Diagnose with: sort --version"
    return 1
  }

  return 0
}

# Run test suites in parallel, then print each suite's output in the given
# order.
# Arguments:
#   $@=[test suite paths]
function run-test-suites() {

  local logs suite rc reason message i=0 failed=0 unavailable=0
  local -a pids=() paths=("$@") failures=()
  logs="$(mktemp -d)" || {
    print-diagnostic error "cannot create suite log directory. Verification did not run. Diagnose with: mktemp -d"
    return 1
  }
  # shellcheck disable=SC2064
  trap "rm -rf '$logs'" EXIT

  for suite in "${paths[@]}"; do
    # 'env' keeps the runner's own variables out of the suite and reports a
    # suite that cannot run as 126
    env -u dir -u suites -u QUALITY_GATE_RESULT_FILE "$suite" > "$logs/$i.log" 2>&1 < /dev/null &
    pids+=("$!")
    i=$((i + 1))
  done

  for i in "${!paths[@]}"; do
    set +e
    wait "${pids[$i]}"
    rc=$?
    set -e
    echo "== ${paths[$i]} =="
    cat "$logs/$i.log" || return 1
    if [[ -n "$(tail -c 1 "$logs/$i.log")" ]]; then
      echo
    fi
    if [[ $rc -ne 0 ]]; then
      reason="$(awk '/^(ERROR|FAILED|ASSERTION FAILED)/ { print; exit }' "$logs/$i.log" || true)"
      failures+=("${paths[$i]}: ${reason:-exit code $rc}")
      if [[ $rc -eq 77 ]]; then
        echo "UNAVAILABLE: ${paths[$i]} (exit code $rc)"
        unavailable=$((unavailable + 1))
      else
        echo "FAILED: ${paths[$i]} (exit code $rc)"
        failed=$((failed + 1))
        printf 'ERROR: suite %q exited with status %s. Verification failed. Diagnose with: VERBOSE=true %q\n' "${paths[$i]}" "$rc" "${paths[$i]}"
        if [[ "${GITHUB_ACTIONS:-}" == true ]]; then
          print-diagnostic error "Test suite failed: ${paths[$i]}: ${reason:-exit code $rc}"
        fi
        if [[ $rc -eq 126 || $rc -eq 127 ]]; then
          printf -v message 'cannot execute suite %q. Verification failed. Inspect its mode and interpreter with: ls -l %q' "${paths[$i]}" "${paths[$i]}"
          print-diagnostic error "$message"
        fi
      fi
    fi
  done

  printf 'Suites: %s, Passed: %s, Failed: %s' "${#paths[@]}" "$((${#paths[@]} - failed - unavailable))" "$failed"
  if [[ $unavailable -gt 0 ]]; then printf ', Unavailable: %s' "$unavailable"; fi
  printf '\n'
  rm -rf "$logs" || {
    print-diagnostic error "cannot remove suite logs '$logs'. Cleanup failed. Inspect with: ls -ld '$logs'"
    return 1
  }
  trap - EXIT
  if [[ $failed -gt 0 || $unavailable -gt 0 ]]; then
    if [[ $unavailable -gt 0 ]]; then
      echo "Suites requiring attention:"
    else
      echo "Failed suites:"
    fi
    for reason in "${failures[@]}"; do
      echo "  - $reason"
    done
    if [[ $failed -eq 0 ]]; then
      printf 'PREREQUISITE: %s suite(s) could not complete because prerequisites are unavailable. Verification remains unknown. Review the detailed diagnostics above and rerun: dir=%q bash scripts/tests/run-test-suites.sh\n' "$unavailable" "${dir:-scripts}"
      publish-result prerequisite || return 1
      return 77
    fi
    return 1
  fi

  return 0
}

# Write a private aggregate verdict when the hook supplies an absolute path.
# Arguments:
#   $1=[protocol value to write]
function publish-result() {

  local value="$1" file="${QUALITY_GATE_RESULT_FILE-}"
  [[ ${QUALITY_GATE_RESULT_FILE+x} ]] || return 0
  if [[ "$file" != /* ]]; then
    print-diagnostic error "QUALITY_GATE_RESULT_FILE must be an absolute path, got '$file'. No trustworthy verdict can be published. Check with: declare -p QUALITY_GATE_RESULT_FILE"
    return 1
  fi
  if ! printf '%s\n' "$value" > "$file"; then
    print-diagnostic error "cannot publish test-suite verdict to '$file'. Verification cannot be classified. Inspect the destination with: ls -ld '${file%/*}' '$file'"
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
