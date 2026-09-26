#!/bin/bash
# shellcheck disable=SC2034

set -euo pipefail

# Shared test harness for the repository's shell test suites. Each test runs in
# its own subshell with 'set -e' in force, so any failing command fails the
# test, not only the last one. A test that calls exit fails, even with status
# 0, since it never reached its end. Each test also gets its own scratch directory
# and a command stub directory first on PATH, and nothing a test changes leaks
# into the next test.
#
# Usage:
#   $ source ./scripts/tests/test.lib.sh
#   $ test-run-suite test-one test-two
#
# Arguments (provided as environment variables):
#   VERBOSE=true  # The suite traces its commands and the harness also prints the output of passing tests, default is 'false'
#
# Optional functions a suite can define:
#   test-suite-setup     # Runs once before the first test
#   test-suite-teardown  # Runs once on exit, even when a test or the setup fails
# Setup and teardown can use SUITE_TMP and have git isolated and LC_ALL=C like the tests.
# TEST_TMP, STUB_DIR and the helpers that need them are not available there.
#
# Variables available to tests:
#   TEST_REPO_ROOT   # Absolute path of this repository
#   TEST_BASE_TOOLS  # Tools test-isolate-path always keeps reachable
#   SUITE_TMP        # Scratch directory shared by the suite, removed on exit
#   TEST_TMP         # Scratch directory of the current test, removed after it
#   STUB_DIR         # Directory of command stubs, first on PATH
#   TEST_STDOUT, TEST_STDERR, TEST_STATUS  # Set by test-capture
# test-capture runs the command in a subshell, so its 'cd' and variable changes are discarded.

TEST_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
TEST_BASE_TOOLS=(awk basename bash cat chmod cmp cp cut date dirname env find git grep head ln mkdir mktemp mv rm sed sort tail tee touch tr uniq wc xargs)

# ==============================================================================
# Suite runner

# Run the given tests, print a PASS or FAIL line for each and a summary. Fail
# without running anything when no test is given.
# Arguments:
#   $@=[names of the test functions to run, in order]
function test-run-suite() {

  local test rc log failed=0

  if [[ $# -eq 0 ]]; then
    echo "ERROR: no tests to run" >&2
    return 1
  fi
  if ! _TEST_SUITE_TMP="$(_test-mktemp-dir)"; then
    echo "ERROR: cannot create the suite scratch directory" >&2
    return 1
  fi
  SUITE_TMP="$_TEST_SUITE_TMP"
  trap '_test-suite-exit' EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  _test-isolate-git
  export LC_ALL=C
  if declare -F test-suite-setup > /dev/null; then
    test-suite-setup
  fi

  log="$SUITE_TMP/.test.log"
  for test in "$@"; do
    set +e
    _test-run-one "$test" > "$log" 2>&1 < /dev/null
    rc=$?
    set -e
    if [[ $rc -eq 0 ]]; then
      echo "$test PASS"
      if [[ "${VERBOSE:-false}" =~ ^(true|yes|y|on|1|TRUE|YES|Y|ON)$ ]]; then
        _test-indent "$log"
      fi
    else
      echo "$test FAIL"
      _test-indent "$log"
      failed=$((failed + 1))
    fi
  done

  echo "Total: $#, Passed: $(($# - failed)), Failed: $failed"
  _TEST_SUITE_COMPLETED=true
  [[ $failed -eq 0 ]] || return 1

  return 0
}

# Run one test in an isolated subshell with errexit, nounset and pipefail on.
# Arguments:
#   $1=[name of the test function]
function _test-run-one() {

  local test="$1"
  ( _test-run-isolated "$test" )

  return $?
}

# Give the current test its scratch directory and stub directory, then run it.
# Must be called inside the test's own subshell.
# Arguments:
#   $1=[name of the test function]
function _test-run-isolated() {

  set -euo pipefail
  local test="$1"
  _TEST_NAME="$test"
  _TEST_RETURNED=""
  _TEST_TMP="$(_test-mktemp-dir)"
  trap '_test-isolated-exit' EXIT
  TEST_TMP="$_TEST_TMP"
  STUB_DIR="$TEST_TMP/.stubs"
  mkdir "$STUB_DIR"
  PATH="$STUB_DIR:$PATH"
  export TEST_TMP STUB_DIR PATH
  "$test"
  _TEST_RETURNED=true
  if [[ $- != *e* ]]; then
    echo "ERROR: test '$test' left errexit off" >&2
    return 1
  fi

  return 0
}

# Fail a test whose subshell exits with status 0 before the test returned, then
# remove the test's scratch directory and keep the exit status.
function _test-isolated-exit() {

  local rc=$?
  if [[ $rc -eq 0 && -z "${_TEST_RETURNED:-}" ]]; then
    echo "ERROR: test '${_TEST_NAME:-}' exited before returning" >&2
    rc=1
  fi
  _test-remove-dir "${_TEST_TMP:-}"
  exit "$rc"
}

# Point git at an empty global config and a fixed identity, and drop the
# variables that could point it at another repository, such as a git hook's GIT_DIR.
function _test-isolate-git() {

  local vars var
  vars="$(git rev-parse --local-env-vars)"
  while IFS= read -r var; do
    unset -v "$var"
  done <<< "$vars"
  GIT_CONFIG_GLOBAL=/dev/null
  GIT_CONFIG_NOSYSTEM=1
  GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.com
  GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.com
  export GIT_CONFIG_GLOBAL GIT_CONFIG_NOSYSTEM \
    GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL

  return 0
}

# Run the suite teardown, remove the suite scratch directory and keep the exit status.
function _test-suite-exit() {

  local rc=$?
  set +e
  if declare -F test-suite-teardown > /dev/null; then
    test-suite-teardown || { echo "ERROR: test-suite-teardown failed" >&2; rc=1; }
  fi
  _test-remove-dir "${_TEST_SUITE_TMP:-}"
  if [[ -z "${_TEST_SUITE_COMPLETED:-}" ]]; then
    echo "ERROR: the test suite aborted before running all its tests, see the output above" >&2
    [[ $rc -ne 0 ]] || rc=1
  fi
  exit "$rc"
}

# Print the physical path of a new temporary directory, or fail without output.
function _test-mktemp-dir() {

  local dir
  if ! dir="$(mktemp -d)" || [[ -z "$dir" || ! -d "$dir" ]]; then
    return 1
  fi
  (cd "$dir" && pwd -P)

  return $?
}

# Remove a scratch directory created by the harness, doing nothing for an empty
# value or a path that is not a directory.
# Arguments:
#   $1=[directory to remove]
function _test-remove-dir() {

  if [[ -n "$1" && -d "$1" ]]; then
    rm -rf "$1"
  fi

  return 0
}

# Print a file with every line indented by four spaces and newline-terminated.
# Arguments:
#   $1=[file to print]
function _test-indent() {

  awk '{ print "    " $0 }' "$1"

  return 0
}

# ==============================================================================
# Helpers

# Run a command with errexit on, xtrace off, VERBOSE unset and stdin from
# /dev/null, capturing its stdout (trailing newlines removed), stderr and exit status.
# Arguments:
#   $@=[command and arguments, a function is allowed]
function test-capture() {

  set +e
  TEST_STDOUT="$(
    set -e
    { set +x; } 2> /dev/null
    unset VERBOSE
    "$@" 2> "$TEST_TMP/.stderr" < /dev/null
  )"
  TEST_STATUS=$?
  set -e
  TEST_STDERR="$(cat "$TEST_TMP/.stderr")"

  return 0
}

# Create a command stub, first on PATH, that records each call as one line of
# "$STUB_DIR/<name>.calls": the arguments quoted with printf %q and separated
# by single spaces, or an empty line for a call without arguments. The stub is
# a symlink to scripts/tests/stub.sh, which runs "$STUB_DIR/<name>.body".
# "$STUB_DIR/<name>" links to the tracked dispatcher, so never write to it, change a body with another test-stub call.
# Calling it again for the same name replaces the body.
# Arguments:
#   $1=[command name]
#   $2=[bash code the stub runs after recording, with the call's arguments in "$@", default is 'exit 0']
function test-stub() {

  local name="$1" body="${2:-exit 0}"
  printf '%s\n' "$body" > "$STUB_DIR/$name.body"
  ln -sf "$TEST_REPO_ROOT/scripts/tests/stub.sh" "$STUB_DIR/$name"

  return 0
}

# Print the recorded calls of a stub, one per line, or nothing if it was never called.
# Arguments:
#   $1=[command name]
function test-stub-calls() {

  if [[ -f "$STUB_DIR/$1.calls" ]]; then
    cat "$STUB_DIR/$1.calls"
  fi

  return 0
}

# Replace PATH with the stub directory plus symlinks to the base tools and the
# given tools, so the command under test cannot see anything else installed on
# the host. Call it before creating stubs. Calling it again in the same test is harmless.
# A tool found in a mise shims directory is linked to the real executable, as
# 'mise which' resolves it from this repository, because a shim's behaviour
# depends on the mise config of the directory it runs in.
# Arguments:
#   $@=[extra tools to keep reachable, in addition to TEST_BASE_TOOLS]
# shellcheck disable=SC2120
function test-isolate-path() {

  local bin="$TEST_TMP/.bin" tool path
  mkdir -p "$bin"
  for tool in "${TEST_BASE_TOOLS[@]}" "$@"; do
    path="$(type -P "$tool")" || { echo "test-isolate-path: '$tool' is not on PATH" >&2; return 1; }
    if [[ "$path" == */mise/shims/* ]]; then
      path="$(cd "$TEST_REPO_ROOT" && mise which "$tool")" ||
        { echo "test-isolate-path: cannot resolve the mise shim of '$tool'" >&2; return 1; }
    fi
    # On a repeated call the tool already resolves to its link, which must not point to itself.
    [[ "$path" == "$bin/$tool" ]] || ln -sf "$path" "$bin/$tool"
  done
  PATH="$STUB_DIR:$bin"
  export PATH

  return 0
}

# Create a git repository on branch 'main' containing the given files from
# this repository, with one commit. Executable files are symlinked, not copied,
# because macOS assesses every new executable on its first run. Linked
# executables are the real repository files, so tests must never write to them
# or change their mode or timestamps (chmod, touch and redirections all follow links).
# Arguments:
#   $1=[directory to create]
#   $@=[paths to include, relative to this repository's top-level directory]
function test-create-repo() {

  local dir="$1" path
  shift
  git init -q -b main "$dir"
  for path in "$@"; do
    mkdir -p "$dir/$(dirname "$path")"
    if [[ -f "$TEST_REPO_ROOT/$path" && -x "$TEST_REPO_ROOT/$path" ]]; then
      ln -s "$TEST_REPO_ROOT/$path" "$dir/$path"
    else
      cp -p "$TEST_REPO_ROOT/$path" "$dir/$path"
    fi
  done
  git -C "$dir" add -A
  git -C "$dir" commit -q --allow-empty -m "initial"

  return 0
}

# ==============================================================================
# Assertions

# Fail unless the two values are equal.
# Arguments:
#   $1=[expected value]
#   $2=[actual value]
#   $3=[description of the value, default is 'values are equal']
function assert-equal() {

  local expected="$1" actual="$2" what="${3:-values are equal}"
  if [[ "$expected" != "$actual" ]]; then
    {
      echo "ASSERTION FAILED: $what"
      echo "  expected: [$expected]"
      echo "  actual:   [$actual]"
    } >&2
    return 1
  fi

  return 0
}

# Fail unless the haystack contains the needle as a fixed string.
# Arguments:
#   $1=[text to search]
#   $2=[fixed string to find]
#   $3=[description of the check, default is 'text contains the string']
function assert-contains() {

  local haystack="$1" needle="$2" what="${3:-text contains the string}"
  if [[ "$haystack" != *"$needle"* ]]; then
    {
      echo "ASSERTION FAILED: $what"
      echo "  expected to contain: [$needle]"
      echo "  actual:              [$haystack]"
    } >&2
    return 1
  fi

  return 0
}

# Fail if the haystack contains the needle as a fixed string.
# Arguments:
#   $1=[text to search]
#   $2=[fixed string that must not appear]
#   $3=[description of the check, default is 'text does not contain the string']
function assert-not-contains() {

  local haystack="$1" needle="$2" what="${3:-text does not contain the string}"
  if [[ "$haystack" == *"$needle"* ]]; then
    {
      echo "ASSERTION FAILED: $what"
      echo "  expected not to contain: [$needle]"
      echo "  actual:                  [$haystack]"
    } >&2
    return 1
  fi

  return 0
}

# Fail unless the value matches the extended regular expression.
# Arguments:
#   $1=[value to match]
#   $2=[extended regular expression]
#   $3=[description of the check, default is 'value matches the pattern']
function assert-matches() {

  local value="$1" ere="$2" what="${3:-value matches the pattern}"
  if ! [[ "$value" =~ $ere ]]; then
    {
      echo "ASSERTION FAILED: $what"
      echo "  expected to match: [$ere]"
      echo "  actual:            [$value]"
    } >&2
    return 1
  fi

  return 0
}

# Fail unless the path exists.
# Arguments:
#   $1=[path to check]
function assert-file-exists() {

  if [[ ! -e "$1" ]]; then
    echo "ASSERTION FAILED: file exists: [$1]" >&2
    return 1
  fi

  return 0
}

# Fail if the path exists.
# Arguments:
#   $1=[path to check]
function assert-file-not-exists() {

  if [[ -e "$1" ]]; then
    echo "ASSERTION FAILED: file does not exist: [$1]" >&2
    return 1
  fi

  return 0
}

# Fail unless the file has a line equal to the given line.
# Arguments:
#   $1=[file to search]
#   $2=[expected line]
function assert-file-has-line() {

  local file="$1" line="$2"
  if ! grep -Fxq -- "$line" "$file"; then
    {
      echo "ASSERTION FAILED: [$file] has the line: [$line]"
      echo "  actual content:"
      sed 's/^/    /' "$file"
    } >&2
    return 1
  fi

  return 0
}

# Fail unless the two files have byte-identical content.
# Arguments:
#   $1=[file with the expected content]
#   $2=[file with the actual content]
function assert-files-identical() {

  local expected="$1" actual="$2"
  if ! cmp -s "$expected" "$actual"; then
    {
      echo "ASSERTION FAILED: [$actual] is byte-identical to [$expected]"
      echo "  expected content:"
      sed 's/^/    /' "$expected"
      echo "  actual content:"
      sed 's/^/    /' "$actual"
    } >&2
    return 1
  fi

  return 0
}

# Fail unless a stub recorded a call whose whole arguments line equals the given line.
# Arguments:
#   $1=[command name]
#   $2=[expected arguments line, as recorded by test-stub]
function assert-stub-called() {

  local name="$1" line="$2"
  if [[ ! -f "$STUB_DIR/$name.calls" ]] || ! grep -Fxq -- "$line" "$STUB_DIR/$name.calls"; then
    {
      echo "ASSERTION FAILED: stub '$name' called with: [$line]"
      echo "  recorded calls:"
      test-stub-calls "$name" | sed 's/^/    /'
    } >&2
    return 1
  fi

  return 0
}

# Fail if a stub recorded any call.
# Arguments:
#   $1=[command name]
function assert-stub-not-called() {

  local name="$1"
  if [[ -s "$STUB_DIR/$name.calls" ]]; then
    {
      echo "ASSERTION FAILED: stub '$name' not called"
      echo "  recorded calls:"
      sed 's/^/    /' "$STUB_DIR/$name.calls"
    } >&2
    return 1
  fi

  return 0
}
