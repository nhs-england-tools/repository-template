#!/bin/bash
# shellcheck disable=SC1091,SC2016,SC2034,SC2317,SC2329

set -euo pipefail

# Test suite for the shared shell test harness. It uses the harness to test the
# harness. Behaviour of the suite runner is checked by writing small suites to
# a scratch directory and running them with the same interpreter as this suite.
#
# Usage:
#   $ ./scripts/tests/test.lib.test.sh
#
# Arguments (provided as environment variables):
#   VERBOSE=true  # Show all the executed commands, default is 'false'

# ==============================================================================

function main() {

  local -r FAILED_TEST_OUTPUT='t FAIL'
  local -r STDOUT_LABEL='stdout'
  local -r STDERR_LABEL='stderr'
  local -r EXIT_STATUS_LABEL='exit status'

  cd "$(git rev-parse --show-toplevel)"
  source ./scripts/tests/test.lib.sh

  test-run-suite \
    test-harness-fails-test-when-a-middle-command-fails \
    test-harness-fails-test-when-a-called-function-fails \
    test-harness-fails-test-when-a-command-substitution-fails \
    test-harness-reports-summary-and-passes \
    test-harness-fails-a-suite-with-no-tests \
    test-harness-isolates-variables-between-tests \
    test-harness-isolates-working-directory-between-tests \
    test-harness-removes-each-test-scratch-directory \
    test-harness-shows-output-of-failing-tests-only \
    test-harness-runs-teardown-after-a-failing-test \
    test-harness-reports-a-setup-failure \
    test-harness-does-not-pass-stdin-to-tests \
    test-harness-isolates-global-git-config \
    test-harness-isolates-git-in-suite-setup \
    test-harness-keeps-files-when-the-suite-scratch-directory-cannot-be-created \
    test-harness-keeps-files-when-a-test-scratch-directory-cannot-be-created \
    test-harness-fails-a-test-that-leaves-errexit-off \
    test-harness-fails-a-test-that-calls-exit-0 \
    test-harness-fails-a-test-that-reads-an-unset-variable \
    test-harness-keeps-the-status-of-a-test-that-exits-non-zero \
    test-harness-pins-the-locale \
    test-harness-ends-the-output-of-a-failing-test-with-a-newline \
    test-harness-exits-with-143-on-term \
    test-assert-equal-reports-expected-and-actual \
    test-assertions-pass-and-fail-correctly \
    test-assert-file-has-line-matches-whole-lines-only \
    test-assert-files-identical-compares-bytes \
    test-capture-separates-stdout-stderr-and-status-with-errexit \
    test-capture-hides-xtrace-and-verbose-from-the-command \
    test-stub-records-each-call-on-its-own-line \
    test-stub-is-a-link-to-the-dispatcher-with-a-plain-body-file \
    test-stub-replaces-the-body-when-called-again \
    test-stub-works-with-only-the-stub-directory-on-path \
    test-stub-dispatcher-refuses-a-link-without-a-body \
    test-assert-stub-called-matches-whole-lines-only \
    test-isolate-path-hides-unlisted-tools \
    test-isolate-path-keeps-listed-tools-and-rejects-missing-ones \
    test-isolate-path-links-the-executable-when-a-function-shadows-it \
    test-isolate-path-links-the-real-executable-behind-a-mise-shim \
    test-isolate-path-rejects-a-mise-shim-it-cannot-resolve \
    test-create-repo-copies-files-and-commits-on-main \
    test-create-repo-links-executables-and-copies-other-files

  return 0
}

# ==============================================================================
# Suite runner

function test-harness-fails-test-when-a-middle-command-fails() {

  # Arrange
  write-mini-suite 'function t() { false; true; }' t
  # Act
  test-capture "$BASH" "$TEST_TMP/mini.test.sh"
  # Assert
  assert-contains "$TEST_STDOUT" "$FAILED_TEST_OUTPUT"
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"

  return 0
}

function test-harness-fails-test-when-a-called-function-fails() {

  # Arrange
  write-mini-suite 'function h() { false; echo after; }
function t() { h; }' t
  # Act
  test-capture "$BASH" "$TEST_TMP/mini.test.sh"
  # Assert
  assert-contains "$TEST_STDOUT" "$FAILED_TEST_OUTPUT"
  assert-not-contains "$TEST_STDOUT" "after"

  return 0
}

function test-harness-fails-test-when-a-command-substitution-fails() {

  # Arrange
  write-mini-suite 'function t() { local x; x="$(false)"; true; }' t
  # Act
  test-capture "$BASH" "$TEST_TMP/mini.test.sh"
  # Assert
  assert-contains "$TEST_STDOUT" "$FAILED_TEST_OUTPUT"

  return 0
}

function test-harness-reports-summary-and-passes() {

  # Arrange
  write-mini-suite 'function a() { return 0; }
function b() { return 0; }' a b
  # Act
  test-capture "$BASH" "$TEST_TMP/mini.test.sh"
  # Assert
  assert-contains "$TEST_STDOUT" "a PASS"
  assert-contains "$TEST_STDOUT" "b PASS"
  assert-contains "$TEST_STDOUT" "Total: 2, Passed: 2, Failed: 0"
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"

  return 0
}

function test-harness-fails-a-suite-with-no-tests() {

  # Arrange
  write-mini-suite 'true'
  # Act
  test-capture "$BASH" "$TEST_TMP/mini.test.sh"
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "ERROR: no tests to run" "$TEST_STDERR" "$STDERR_LABEL"
  assert-equal "" "$TEST_STDOUT" "$STDOUT_LABEL"

  return 0
}

function test-harness-isolates-variables-between-tests() {

  # Arrange
  write-mini-suite 'function a() { LEAK=1; }
function b() { assert-equal "" "${LEAK:-}"; }' a b
  # Act
  test-capture "$BASH" "$TEST_TMP/mini.test.sh"
  # Assert
  assert-contains "$TEST_STDOUT" "a PASS"
  assert-contains "$TEST_STDOUT" "b PASS"

  return 0
}

function test-harness-isolates-working-directory-between-tests() {

  # Arrange
  write-mini-suite 'START_DIR="$(pwd -P)"
function a() { cd /; }
function b() { assert-equal "$START_DIR" "$(pwd -P)"; }' a b
  cd "$TEST_TMP"
  # Act
  test-capture "$BASH" "$TEST_TMP/mini.test.sh"
  # Assert
  assert-contains "$TEST_STDOUT" "a PASS"
  assert-contains "$TEST_STDOUT" "b PASS"

  return 0
}

function test-harness-removes-each-test-scratch-directory() {

  # Arrange
  write-mini-suite 'function a() { printf "%s\n" "$TEST_TMP" > "$OUT/tmp-path"; }' a
  export OUT="$TEST_TMP"
  # Act
  test-capture "$BASH" "$TEST_TMP/mini.test.sh"
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-matches "$(cat "$TEST_TMP/tmp-path")" '^/.+' "recorded scratch directory"
  assert-file-not-exists "$(cat "$TEST_TMP/tmp-path")"

  return 0
}

function test-harness-shows-output-of-failing-tests-only() {

  # Arrange
  write-mini-suite 'function a() { echo diag-pass; }
function b() { echo diag-fail; false; }' a b
  unset VERBOSE
  # Act
  test-capture "$BASH" "$TEST_TMP/mini.test.sh"
  # Assert
  assert-contains "$TEST_STDOUT" "    diag-fail"
  assert-not-contains "$TEST_STDOUT" "diag-pass"

  return 0
}

function test-harness-runs-teardown-after-a-failing-test() {

  # Arrange
  write-mini-suite 'function test-suite-teardown() { touch "$OUT/torn-down"; }
function t() { false; }' t
  export OUT="$TEST_TMP"
  # Act
  test-capture "$BASH" "$TEST_TMP/mini.test.sh"
  # Assert
  assert-file-exists "$TEST_TMP/torn-down"
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"

  return 0
}

function test-harness-reports-a-setup-failure() {

  # Arrange
  write-mini-suite 'function test-suite-setup() { false; }
function test-suite-teardown() { touch "$OUT/torn-down"; }
function t() { return 0; }' t
  export OUT="$TEST_TMP"
  # Act
  test-capture "$BASH" "$TEST_TMP/mini.test.sh"
  # Assert
  assert-matches "$TEST_STATUS" '^[1-9][0-9]*$' "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "aborted"
  assert-file-exists "$TEST_TMP/torn-down"
  assert-not-contains "$TEST_STDOUT" "PASS"

  return 0
}

function test-harness-does-not-pass-stdin-to-tests() {

  # Arrange
  write-mini-suite 'function t() { assert-equal "" "$(cat)"; }' t
  # Act
  test-capture "$BASH" -c 'printf "leaked\n" | "$BASH" "$1"' _ "$TEST_TMP/mini.test.sh"
  # Assert
  assert-contains "$TEST_STDOUT" "t PASS"

  return 0
}

function test-harness-isolates-global-git-config() {

  # Arrange
  write-mini-suite 'function t() {
  assert-equal /dev/null "$GIT_CONFIG_GLOBAL"
  assert-equal 1 "$GIT_CONFIG_NOSYSTEM"
}' t
  # Act
  test-capture env GIT_CONFIG_GLOBAL="$TEST_TMP/gitconfig" GIT_CONFIG_NOSYSTEM=0 \
    "$BASH" "$TEST_TMP/mini.test.sh"
  # Assert
  assert-contains "$TEST_STDOUT" "t PASS"

  return 0
}

function test-harness-isolates-git-in-suite-setup() {

  # Arrange
  write-mini-suite 'function test-suite-setup() {
  printf "%s\n" "$GIT_CONFIG_GLOBAL" "$GIT_CONFIG_NOSYSTEM" "$GIT_AUTHOR_NAME" \
    "${GIT_DIR:-unset}" "${GIT_INDEX_FILE:-unset}" > "$OUT/setup-env"
}
function t() { return 0; }' t
  export OUT="$TEST_TMP"
  # Act
  test-capture env GIT_CONFIG_GLOBAL="$TEST_TMP/gitconfig" GIT_CONFIG_NOSYSTEM=0 \
    GIT_AUTHOR_NAME=Host GIT_DIR="$TEST_TMP/host/.git" GIT_INDEX_FILE="$TEST_TMP/host/.git/index" \
    "$BASH" "$TEST_TMP/mini.test.sh"
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal $'/dev/null\n1\nTest\nunset\nunset' "$(cat "$TEST_TMP/setup-env")" "git environment seen by setup"

  return 0
}

function test-harness-keeps-files-when-the-suite-scratch-directory-cannot-be-created() {

  # Arrange
  write-mini-suite 'function t() { return 0; }' t
  test-stub mktemp 'exit 1'
  mkdir "$TEST_TMP/sentinel"
  touch "$TEST_TMP/sentinel/file"
  cd "$TEST_TMP/sentinel"
  # Act
  test-capture "$BASH" "$TEST_TMP/mini.test.sh"
  # Assert
  assert-matches "$TEST_STATUS" '^[1-9][0-9]*$' "$EXIT_STATUS_LABEL"
  assert-stub-called mktemp -d
  assert-file-exists "$TEST_TMP/sentinel"
  assert-file-exists "$TEST_TMP/sentinel/file"

  return 0
}

function test-harness-keeps-files-when-a-test-scratch-directory-cannot-be-created() {

  # Arrange
  # The setup replaces mktemp with a function that records its arguments and fails, for every test.
  write-mini-suite 'function test-suite-setup() {
  function mktemp() { printf "%s\n" "$*" >> "$OUT/mktemp-calls"; return 1; }
}
function t() { return 0; }' t
  export OUT="$TEST_TMP"
  mkdir "$TEST_TMP/sentinel"
  touch "$TEST_TMP/sentinel/file"
  cd "$TEST_TMP/sentinel"
  # Act
  test-capture "$BASH" "$TEST_TMP/mini.test.sh"
  # Assert
  assert-contains "$TEST_STDOUT" "$FAILED_TEST_OUTPUT"
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal -d "$(cat "$TEST_TMP/mktemp-calls")" "mktemp calls"
  assert-file-exists "$TEST_TMP/sentinel"
  assert-file-exists "$TEST_TMP/sentinel/file"

  return 0
}

function test-harness-fails-a-test-that-leaves-errexit-off() {

  # Arrange
  write-mini-suite 'function t() { set +e; assert-equal a b; return 0; }' t
  # Act
  test-capture "$BASH" "$TEST_TMP/mini.test.sh"
  # Assert
  assert-contains "$TEST_STDOUT" "$FAILED_TEST_OUTPUT"
  assert-contains "$TEST_STDOUT" "ERROR: test 't' left errexit off"
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"

  return 0
}

function test-harness-fails-a-test-that-calls-exit-0() {

  # Arrange
  write-mini-suite 'function t() { printf "%s\n" "$TEST_TMP" > "$OUT/tmp-path"; exit 0; }' t
  export OUT="$TEST_TMP"
  # Act
  test-capture "$BASH" "$TEST_TMP/mini.test.sh"
  # Assert
  assert-contains "$TEST_STDOUT" "$FAILED_TEST_OUTPUT"
  assert-contains "$TEST_STDOUT" "ERROR: test 't' exited before returning"
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-matches "$(cat "$TEST_TMP/tmp-path")" '^/.+' "recorded scratch directory"
  assert-file-not-exists "$(cat "$TEST_TMP/tmp-path")"

  return 0
}

function test-harness-fails-a-test-that-reads-an-unset-variable() {

  # Arrange
  # Bash 3.2 ends a nounset abort under an EXIT trap with the trap's status, 0 here.
  write-mini-suite 'function t() { printf "%s\n" "$TEST_TMP" > "$OUT/tmp-path"; echo "${NO_SUCH_VARIABLE_XYZ}"; }' t
  export OUT="$TEST_TMP"
  # Act
  test-capture "$BASH" "$TEST_TMP/mini.test.sh"
  # Assert
  assert-contains "$TEST_STDOUT" "$FAILED_TEST_OUTPUT"
  assert-contains "$TEST_STDOUT" "NO_SUCH_VARIABLE_XYZ: unbound variable"
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-matches "$(cat "$TEST_TMP/tmp-path")" '^/.+' "recorded scratch directory"
  assert-file-not-exists "$(cat "$TEST_TMP/tmp-path")"

  return 0
}

function test-harness-keeps-the-status-of-a-test-that-exits-non-zero() {

  # Arrange
  # Fixture test that exits with its own status instead of returning.
  function exits-3() { exit 3; }
  # Act
  test-capture _test-run-one exits-3
  # Assert
  assert-equal 3 "$TEST_STATUS" "status of the test's subshell"
  assert-equal "" "$TEST_STDERR" "$STDERR_LABEL"

  return 0
}

function test-harness-pins-the-locale() {

  # Arrange
  write-mini-suite 'function t() { assert-equal C "$LC_ALL" "LC_ALL seen by the test"; }' t
  # Act
  test-capture env LC_ALL=en_GB.UTF-8 "$BASH" "$TEST_TMP/mini.test.sh"
  # Assert
  assert-contains "$TEST_STDOUT" "t PASS"
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"

  return 0
}

function test-harness-ends-the-output-of-a-failing-test-with-a-newline() {

  # Arrange
  write-mini-suite 'function a() { printf no-newline; false; }
function b() { return 0; }' a b
  # Act
  test-capture "$BASH" "$TEST_TMP/mini.test.sh"
  # Assert
  assert-contains "$TEST_STDOUT" $'a FAIL\n    no-newline\nb PASS'

  return 0
}

function test-harness-exits-with-143-on-term() {

  # Arrange
  write-mini-suite 'function t() { kill -TERM $$; return 0; }' t
  # Act
  test-capture "$BASH" "$TEST_TMP/mini.test.sh"
  # Assert
  assert-equal 143 "$TEST_STATUS" "$EXIT_STATUS_LABEL"

  return 0
}

# ==============================================================================
# Assertions and helpers

function test-assert-equal-reports-expected-and-actual() {

  # Arrange
  local what="the value"
  # Act
  test-capture assert-equal one two "$what"
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "the value"
  assert-contains "$TEST_STDERR" "expected: [one]"
  assert-contains "$TEST_STDERR" "actual:   [two]"

  return 0
}

function test-assertions-pass-and-fail-correctly() {

  # Arrange
  touch "$TEST_TMP/present"
  # Act and assert
  test-capture assert-contains "abc" "b"
  assert-equal 0 "$TEST_STATUS" "assert-contains passing input"
  test-capture assert-contains "abc" "x"
  assert-equal 1 "$TEST_STATUS" "assert-contains failing input"
  test-capture assert-not-contains "abc" "x"
  assert-equal 0 "$TEST_STATUS" "assert-not-contains passing input"
  test-capture assert-not-contains "abc" "b"
  assert-equal 1 "$TEST_STATUS" "assert-not-contains failing input"
  test-capture assert-matches "v1.2" '^v[0-9]+\.[0-9]+$'
  assert-equal 0 "$TEST_STATUS" "assert-matches passing input"
  test-capture assert-matches "v1.2" '^x'
  assert-equal 1 "$TEST_STATUS" "assert-matches failing input"
  test-capture assert-file-exists "$TEST_TMP/present"
  assert-equal 0 "$TEST_STATUS" "assert-file-exists passing input"
  test-capture assert-file-exists "$TEST_TMP/absent"
  assert-equal 1 "$TEST_STATUS" "assert-file-exists failing input"
  test-capture assert-file-not-exists "$TEST_TMP/absent"
  assert-equal 0 "$TEST_STATUS" "assert-file-not-exists passing input"
  test-capture assert-file-not-exists "$TEST_TMP/present"
  assert-equal 1 "$TEST_STATUS" "assert-file-not-exists failing input"

  return 0
}

function test-assert-file-has-line-matches-whole-lines-only() {

  # Arrange
  printf '%s\n' 'one two' three > "$TEST_TMP/file"
  # Act and assert
  test-capture assert-file-has-line "$TEST_TMP/file" three
  assert-equal 0 "$TEST_STATUS" "whole line"
  test-capture assert-file-has-line "$TEST_TMP/file" one
  assert-equal 1 "$TEST_STATUS" "partial line"
  assert-contains "$TEST_STDERR" "    one two" "actual content in the message"

  return 0
}

function test-assert-files-identical-compares-bytes() {

  # Arrange
  printf 'a\n' > "$TEST_TMP/expected"
  printf 'a\n' > "$TEST_TMP/same"
  printf 'a\n\n' > "$TEST_TMP/extra-newline"
  # Act and assert
  test-capture assert-files-identical "$TEST_TMP/expected" "$TEST_TMP/same"
  assert-equal 0 "$TEST_STATUS" "identical files"
  test-capture assert-files-identical "$TEST_TMP/expected" "$TEST_TMP/extra-newline"
  assert-equal 1 "$TEST_STATUS" "files that differ by a trailing newline"
  assert-contains "$TEST_STDERR" "ASSERTION FAILED" "failure message"

  return 0
}

function test-capture-separates-stdout-stderr-and-status-with-errexit() {

  # Arrange
  # Fixture that fails in the middle, so 'after' must never be printed.
  function f() { echo out; echo err >&2; false; echo after; }
  # Act
  test-capture f
  # Assert
  assert-equal out "$TEST_STDOUT" "$STDOUT_LABEL"
  assert-equal err "$TEST_STDERR" "$STDERR_LABEL"
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"

  return 0
}

function test-capture-hides-xtrace-and-verbose-from-the-command() {

  # Arrange
  # Fixture that writes nothing to stderr.
  function g() { local value="$1"; : "$value"; return 0; }
  export VERBOSE=true
  # Act
  set -x
  test-capture g needle-xyz
  { set +x; } 2> /dev/null
  local traced_stderr="$TEST_STDERR"
  test-capture "$BASH" -c 'printf "%s\n" "${VERBOSE:-unset}"'
  # Assert
  assert-equal "" "$traced_stderr" "stderr of a function run under xtrace"
  assert-equal unset "$TEST_STDOUT" "VERBOSE seen by a child process"

  return 0
}

function test-stub-records-each-call-on-its-own-line() {

  # Arrange
  test-stub tool 'echo stubbed; exit 3'
  # Act
  test-capture tool "a b" c
  local stdout="$TEST_STDOUT" status="$TEST_STATUS"
  test-capture tool
  # Assert
  assert-equal $'a\\ b c\n\nend' "$(test-stub-calls tool; echo end)" "recorded calls"
  assert-equal stubbed "$stdout" "stdout of the first call"
  assert-equal 3 "$status" "exit status of the first call"

  return 0
}

function test-stub-is-a-link-to-the-dispatcher-with-a-plain-body-file() {

  # Arrange
  local linked=false plain=false
  # Act
  test-stub tool 'echo stubbed'
  # Assert
  if [[ -L "$STUB_DIR/tool" && "$STUB_DIR/tool" -ef "$TEST_REPO_ROOT/scripts/tests/stub.sh" ]]; then
    linked=true
  fi
  if [[ -f "$STUB_DIR/tool.body" && ! -x "$STUB_DIR/tool.body" ]]; then
    plain=true
  fi
  assert-equal true "$linked" "stub is a link to scripts/tests/stub.sh"
  assert-equal true "$plain" "body is a non-executable file"

  return 0
}

function test-stub-replaces-the-body-when-called-again() {

  # Arrange
  test-stub tool 'echo first'
  test-stub tool 'echo second; exit 5'
  # Act
  test-capture tool x
  # Assert
  assert-equal second "$TEST_STDOUT" "$STDOUT_LABEL"
  assert-equal 5 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal x "$(test-stub-calls tool)" "recorded calls"

  return 0
}

function test-stub-works-with-only-the-stub-directory-on-path() {

  # Arrange
  local saved_path="$PATH" rc=0
  test-stub tool 'echo "body $#"; exit 4'
  # Act
  PATH="$STUB_DIR"
  tool "a b" > "$TEST_TMP/out" 2> "$TEST_TMP/err" || rc=$?
  PATH="$saved_path"
  # Assert
  assert-equal 4 "$rc" "$EXIT_STATUS_LABEL"
  assert-equal "body 1" "$(cat "$TEST_TMP/out")" "$STDOUT_LABEL"
  assert-equal "" "$(cat "$TEST_TMP/err")" "$STDERR_LABEL"
  assert-equal 'a\ b' "$(test-stub-calls tool)" "recorded calls"

  return 0
}

function test-stub-dispatcher-refuses-a-link-without-a-body() {

  # Arrange
  mkdir "$TEST_TMP/links"
  ln -s "$TEST_REPO_ROOT/scripts/tests/stub.sh" "$TEST_TMP/links/orphan"
  # Act
  test-capture "$TEST_TMP/links/orphan" a
  # Assert
  assert-equal 2 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "stub.sh: no body for orphan, create stubs with test-stub" "$TEST_STDERR" "$STDERR_LABEL"
  assert-file-not-exists "$TEST_TMP/links/orphan.calls"

  return 0
}

function test-assert-stub-called-matches-whole-lines-only() {

  # Arrange
  test-stub tool
  # Act
  tool pull image:1
  # Assert
  test-capture assert-stub-called tool "pull image:1"
  assert-equal 0 "$TEST_STATUS" "whole line"
  test-capture assert-stub-called tool "pull"
  assert-equal 1 "$TEST_STATUS" "partial line"
  test-capture assert-stub-not-called other
  assert-equal 0 "$TEST_STATUS" "never called stub"
  test-capture assert-stub-not-called tool
  assert-equal 1 "$TEST_STATUS" "called stub"

  return 0
}

function test-isolate-path-hides-unlisted-tools() {

  # Arrange
  create-fake-tool
  PATH="$TEST_TMP/fake:$PATH"
  command -v fake-tool > /dev/null
  # Act
  test-isolate-path
  # Assert
  test-capture command -v fake-tool
  assert-equal 1 "$TEST_STATUS" "fake-tool lookup status"
  test-capture command -v git
  assert-equal 0 "$TEST_STATUS" "git lookup status"
  local tool
  for tool in cmp tee touch xargs; do
    test-capture command -v "$tool"
    assert-equal 0 "$TEST_STATUS" "$tool lookup status"
  done

  return 0
}

function test-isolate-path-keeps-listed-tools-and-rejects-missing-ones() {

  # Arrange
  create-fake-tool
  PATH="$TEST_TMP/fake:$PATH"
  # Act
  test-isolate-path fake-tool
  local found_status=0
  command -v fake-tool > /dev/null || found_status=$?
  test-capture test-isolate-path no-such-tool-xyz
  # Assert
  assert-equal 0 "$found_status" "fake-tool lookup status"
  assert-equal 1 "$TEST_STATUS" "missing tool status"
  assert-contains "$TEST_STDERR" "no-such-tool-xyz"

  return 0
}

function test-isolate-path-links-the-executable-when-a-function-shadows-it() {

  # Arrange
  create-fake-tool
  PATH="$TEST_TMP/fake:$PATH"
  # Fixture function that shadows the executable of the same name.
  function fake-tool() { return 1; }
  # Act
  test-isolate-path fake-tool
  # Assert
  test-capture env fake-tool
  assert-equal 0 "$TEST_STATUS" "fake-tool run through PATH"

  return 0
}

function test-isolate-path-links-the-real-executable-behind-a-mise-shim() {

  # Arrange
  local linked=false
  create-fake-mise-shim
  PATH="$TEST_TMP/mise/shims:$TEST_TMP/mise-bin:$PATH"
  # Act
  test-isolate-path fake-tool
  # Assert
  if [[ "$TEST_TMP/.bin/fake-tool" -ef "$TEST_TMP/real/fake-tool" ]]; then
    linked=true
  fi
  assert-equal true "$linked" "fake-tool is a link to the real executable"
  assert-equal "$TEST_REPO_ROOT" "$(cat "$TEST_TMP/mise-cwd")" "directory mise which ran in"
  test-capture env fake-tool
  assert-equal 0 "$TEST_STATUS" "fake-tool run through PATH"

  return 0
}

function test-isolate-path-rejects-a-mise-shim-it-cannot-resolve() {

  # Arrange
  create-fake-mise-shim
  rm "$TEST_TMP/real/fake-tool"
  PATH="$TEST_TMP/mise/shims:$TEST_TMP/mise-bin:$PATH"
  # Act
  test-capture test-isolate-path fake-tool
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "test-isolate-path: cannot resolve the mise shim of 'fake-tool'"

  return 0
}

function test-create-repo-copies-files-and-commits-on-main() {

  # Arrange
  local repo="$TEST_TMP/repo"
  # Act
  test-create-repo "$repo" scripts/tests/test.lib.sh
  # Assert
  assert-file-exists "$repo/scripts/tests/test.lib.sh"
  assert-equal main "$(git -C "$repo" symbolic-ref --short HEAD)" "branch"
  assert-equal "" "$(git -C "$repo" status --porcelain)" "git status"
  assert-equal 1 "$(git -C "$repo" rev-list --count HEAD)" "commit count"

  return 0
}

function test-create-repo-links-executables-and-copies-other-files() {

  # Arrange
  local repo="$TEST_TMP/repo" exe=scripts/tests/run-test-suites.sh lib=scripts/tests/test.lib.sh
  local linked=false copied=false
  # Act
  test-create-repo "$repo" "$exe" "$lib"
  # Assert
  if [[ -L "$repo/$exe" && "$repo/$exe" -ef "$TEST_REPO_ROOT/$exe" ]]; then
    linked=true
  fi
  if [[ -f "$repo/$lib" && ! -L "$repo/$lib" ]]; then
    copied=true
  fi
  assert-equal true "$linked" "executable is a link to the repository file"
  assert-equal true "$copied" "non-executable file is a real file"
  assert-equal "$(printf '%s\n' "120000 $exe" "100644 $lib")" \
    "$(git -C "$repo" ls-tree -r HEAD | awk '{ print $1, $4 }')" "committed modes and paths"
  assert-equal "" "$(git -C "$repo" status --porcelain)" "git status"

  return 0
}

# ==============================================================================
# Helpers

# Write a mini test suite that uses the harness and runs the given tests.
# Arguments:
#   $1=[bash code defining the mini suite's functions]
#   $@=[names of the tests to run]
function write-mini-suite() {

  local body="$1"
  shift
  {
    echo '#!/bin/bash'
    echo 'set -euo pipefail'
    echo "source '$TEST_REPO_ROOT/scripts/tests/test.lib.sh'"
    printf '%s\n' "$body"
    echo "test-run-suite $*"
  } > "$TEST_TMP/mini.test.sh"

  return 0
}

# Create an executable "$TEST_TMP/fake/fake-tool" that is not installed anywhere else.
function create-fake-tool() {

  mkdir -p "$TEST_TMP/fake"
  printf '#!/bin/bash\nexit 0\n' > "$TEST_TMP/fake/fake-tool"
  chmod +x "$TEST_TMP/fake/fake-tool"

  return 0
}

# Create "$TEST_TMP/mise/shims/fake-tool", a shim that exits 1, the real
# "$TEST_TMP/real/fake-tool" that exits 0, and a fake "$TEST_TMP/mise-bin/mise"
# whose 'which' prints the real one if it exists and records its working directory.
function create-fake-mise-shim() {

  mkdir -p "$TEST_TMP/mise/shims" "$TEST_TMP/real" "$TEST_TMP/mise-bin"
  printf '#!/bin/bash\nexit 1\n' > "$TEST_TMP/mise/shims/fake-tool"
  printf '#!/bin/bash\nexit 0\n' > "$TEST_TMP/real/fake-tool"
  cat > "$TEST_TMP/mise-bin/mise" << EOF
#!/bin/bash
pwd -P > '$TEST_TMP/mise-cwd'
[[ "\$*" == "which fake-tool" && -x '$TEST_TMP/real/fake-tool' ]] || exit 1
echo '$TEST_TMP/real/fake-tool'
EOF
  chmod +x "$TEST_TMP/mise/shims/fake-tool" "$TEST_TMP/real/fake-tool" "$TEST_TMP/mise-bin/mise"

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
