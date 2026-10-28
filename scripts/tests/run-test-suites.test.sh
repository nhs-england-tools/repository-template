#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034,SC2317,SC2329

set -euo pipefail

# Test suite for the test suite runner. Each test builds a fixture tree of tiny
# plain bash suites in a scratch directory and runs the runner against it.
#
# Usage:
#   $ ./scripts/tests/run-test-suites.test.sh
#
# Arguments (provided as environment variables):
#   VERBOSE=true  # Show all the executed commands, default is 'false'

# ==============================================================================

readonly PASSING_SUITE_BODY='exit 0'
readonly EXIT_STATUS_LABEL='exit status'

function main() {

  cd "$(git rev-parse --show-toplevel)"
  source ./scripts/tests/test.lib.sh

  test-run-suite \
    test-runner-runs-every-suite-and-passes \
    test-runner-preserves-paths-and-filters-suites \
    test-runner-fails-when-any-suite-fails-and-still-runs-the-rest \
    test-runner-fails-when-no-suite-is-found \
    test-runner-fails-when-directory-is-missing \
    test-runner-fails-when-a-directory-cannot-be-searched \
    test-runner-runs-root-level-suites-with-a-relative-dir \
    test-runner-runs-suites-in-a-nested-repository \
    test-runner-runs-a-conflicted-suite-once \
    test-runner-runs-suites-in-parallel \
    test-runner-prints-output-in-discovery-order \
    test-runner-skips-git-ignored-suites \
    test-runner-skips-git-ignored-suites-under-a-relative-dir \
    test-runner-fails-a-suite-that-is-not-executable \
    test-runner-does-not-pass-its-variables-to-suites \
    test-runner-ends-suite-output-with-a-newline

  return 0
}

# ==============================================================================

function test-runner-runs-every-suite-and-passes() {

  # Arrange
  write-fixture a/tests/one.test.sh 'echo one-ran; exit 0'
  write-fixture b/tests/two.test.sh 'echo two-ran; exit 0'
  write-fixture b/tests/helper.sh 'exit 1'
  # Act
  run-runner
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDOUT" "one-ran"
  assert-contains "$TEST_STDOUT" "two-ran"
  assert-contains "$TEST_STDOUT" "Suites: 2, Passed: 2, Failed: 0"
  assert-not-contains "$TEST_STDOUT" "helper.sh"

  return 0
}

function test-runner-fails-when-any-suite-fails-and-still-runs-the-rest() {

  # Arrange
  write-fixture a.test.sh 'echo a-ran; exit 1'
  write-fixture b.test.sh 'echo b-ran; exit 0'
  # Act
  run-runner
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDOUT" "a-ran"
  assert-contains "$TEST_STDOUT" "b-ran"
  assert-contains "$TEST_STDOUT" "Suites: 2, Passed: 1, Failed: 1"
  assert-contains "$TEST_STDOUT" "Failed suites:"
  assert-contains "$TEST_STDOUT" "$TEST_TMP/tree/a.test.sh: exit code 1"

  return 0
}

function test-runner-fails-when-no-suite-is-found() {

  # Arrange
  git init -q "$TEST_TMP/tree"
  # Act
  run-runner
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "No test suites found under"

  return 0
}

function test-runner-preserves-paths-and-filters-suites() {

  # Arrange
  local newline_suite=$'line\nbreak.test.sh'
  write-fixture "$newline_suite" 'echo newline-ran'
  write-fixture 'café.test.sh' 'echo cafe-ran'
  git -C "$TEST_TMP/tree" add 'café.test.sh'
  write-fixture deleted.test.sh 'echo deleted-ran'
  git -C "$TEST_TMP/tree" add deleted.test.sh
  rm "$TEST_TMP/tree/deleted.test.sh"
  write-fixture 'space suite.test.sh' 'echo space-ran'
  write-fixture ignored.test.sh 'echo ignored-ran'
  printf 'ignored.test.sh\n' > "$TEST_TMP/tree/.gitignore"
  write-fixture z.test.sh 'echo z-ran'
  # Act
  run-runner
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDOUT" "newline-ran"
  assert-contains "$TEST_STDOUT" "cafe-ran"
  assert-contains "$TEST_STDOUT" "space-ran"
  assert-contains "$TEST_STDOUT" "z-ran"
  assert-not-contains "$TEST_STDOUT" "ignored-ran"
  assert-not-contains "$TEST_STDOUT" "deleted-ran"
  assert-contains "${TEST_STDOUT%%newline-ran*}" "cafe-ran" "café suite sorts before the newline suite"
  assert-contains "${TEST_STDOUT%%space-ran*}" "newline-ran" "newline suite sorts before the spaced suite"
  assert-contains "${TEST_STDOUT%%z-ran*}" "space-ran" "spaced suite sorts before z.test.sh"

  return 0
}

function test-runner-fails-when-directory-is-missing() {

  # Arrange
  write-fixture existing.test.sh "$PASSING_SUITE_BODY"
  # Act
  run-runner "$TEST_TMP/tree/missing"
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "cannot search $TEST_TMP/tree/missing for test suites"
  assert-not-contains "$TEST_STDOUT" "Suites:" "no suites run after a Git discovery failure"

  return 0
}

function test-runner-fails-when-a-directory-cannot-be-searched() {

  # Arrange
  write-fixture a.test.sh "$PASSING_SUITE_BODY"
  write-fixture locked/b.test.sh "$PASSING_SUITE_BODY"
  git -C "$TEST_TMP/tree" add locked/b.test.sh
  chmod 000 "$TEST_TMP/tree/locked"
  # Act
  run-runner
  # Restore access so the harness can remove the scratch directory
  chmod 755 "$TEST_TMP/tree/locked"
  # Assert
  # Root can read any directory, so the fixture cannot fail discovery there
  if [[ $EUID -ne 0 ]]; then
    assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
    assert-contains "$TEST_STDERR" "ERROR: cannot search $TEST_TMP/tree for test suites"
    assert-not-contains "$TEST_STDOUT" "Suites:" "no suite runs after a failed discovery"
  fi

  return 0
}

function test-runner-runs-root-level-suites-with-a-relative-dir() {

  # Arrange
  write-fixture a.test.sh 'echo root-ran'
  # Act
  run-runner-in-tree dir=.
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDOUT" "== ./a.test.sh =="
  assert-contains "$TEST_STDOUT" "root-ran"

  return 0
}

function test-runner-runs-suites-in-a-nested-repository() {

  # Arrange
  write-fixture nested/a.test.sh 'echo nested-ran'
  git init -q "$TEST_TMP/tree/nested"
  # Act
  run-runner-in-tree dir=nested
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDOUT" "== nested/a.test.sh =="
  assert-contains "$TEST_STDOUT" "nested-ran"

  return 0
}

function test-runner-runs-a-conflicted-suite-once() {

  # Arrange
  local tree="$TEST_TMP/tree"
  write-fixture c.test.sh 'echo base'
  git -C "$tree" add c.test.sh
  git -C "$tree" commit -q -m base
  git -C "$tree" checkout -q -b other
  write-fixture c.test.sh 'echo other'
  git -C "$tree" commit -q -am other
  git -C "$tree" checkout -q -
  write-fixture c.test.sh 'echo first'
  git -C "$tree" commit -q -am first
  if git -C "$tree" merge -q other > /dev/null 2>&1; then
    echo "ERROR: the fixture merge did not conflict" >&2
    return 1
  fi
  write-fixture c.test.sh 'echo resolved-ran'
  # Act
  run-runner
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDOUT" "Suites: 1, Passed: 1, Failed: 0"

  return 0
}

function test-runner-runs-suites-in-parallel() {

  # Arrange
  local marker="$TEST_TMP/b-started"
  # Suite 'a' only passes if suite 'b' starts within 5 seconds, so a runner that runs them one after another fails
  write-fixture a.test.sh "i=0
while [[ \$i -lt 50 ]]; do
  [[ -e '$marker' ]] && exit 0
  sleep 0.1
  i=\$((i + 1))
done
exit 1"
  write-fixture b.test.sh "touch '$marker'"
  # Act
  run-runner
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDOUT" "Suites: 2, Passed: 2, Failed: 0"

  return 0
}

function test-runner-prints-output-in-discovery-order() {

  # Arrange
  write-fixture a.test.sh 'sleep 0.5; echo from-a'
  write-fixture b.test.sh 'echo from-b'
  # Act
  run-runner
  # Assert
  assert-contains "$TEST_STDOUT" "from-b"
  assert-contains "${TEST_STDOUT%%from-b*}" "from-a" "from-a appears before from-b"

  return 0
}

function test-runner-skips-git-ignored-suites() {

  # Arrange
  git init -q "$TEST_TMP/tree"
  echo 'ignored/' > "$TEST_TMP/tree/.gitignore"
  write-fixture ignored/tests/bad.test.sh 'exit 1'
  write-fixture kept.test.sh "$PASSING_SUITE_BODY"
  # Act
  run-runner
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDOUT" "Suites: 1, Passed: 1, Failed: 0"
  assert-not-contains "$TEST_STDOUT" "bad.test.sh"

  return 0
}

function test-runner-skips-git-ignored-suites-under-a-relative-dir() {

  # Arrange
  git init -q "$TEST_TMP/tree"
  echo '/scripts/a/tests/bad.test.sh' > "$TEST_TMP/tree/.gitignore"
  write-fixture scripts/a/tests/bad.test.sh 'exit 1'
  write-fixture scripts/b/tests/kept.test.sh "$PASSING_SUITE_BODY"
  # Act
  run-runner-in-tree
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDOUT" "Suites: 1, Passed: 1, Failed: 0"
  assert-not-contains "$TEST_STDOUT" "bad.test.sh"

  return 0
}

function test-runner-fails-a-suite-that-is-not-executable() {

  # Arrange
  write-fixture a.test.sh "$PASSING_SUITE_BODY"
  chmod -x "$TEST_TMP/tree/a.test.sh"
  write-fixture b.test.sh "$PASSING_SUITE_BODY"
  # Act
  run-runner
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDOUT" "FAILED: $TEST_TMP/tree/a.test.sh (exit code 126)"
  assert-contains "$TEST_STDOUT" "Suites: 2, Passed: 1, Failed: 1"
  assert-contains "$TEST_STDOUT" "$TEST_TMP/tree/a.test.sh: exit code 126"

  return 0
}

function test-runner-does-not-pass-its-variables-to-suites() {

  # Arrange
  local default_stdout
  git init -q "$TEST_TMP/tree"
  write-fixture scripts/leak.test.sh "echo \"leak: \${dir-unset} \${suites-unset}\""
  # Act
  run-runner-in-tree
  default_stdout="$TEST_STDOUT"
  run-runner-in-tree dir="$TEST_TMP/tree/scripts"
  # Assert
  assert-contains "$default_stdout" "leak: unset unset" "no variables leak with the default dir"
  assert-contains "$TEST_STDOUT" "leak: unset unset" "no variables leak with the dir option set"

  return 0
}

function test-runner-ends-suite-output-with-a-newline() {

  # Arrange
  write-fixture a.test.sh "printf 'a-no-newline'; exit 1"
  write-fixture b.test.sh "printf 'b-no-newline'"
  # Act
  run-runner
  # Assert
  assert-contains "$TEST_STDOUT" $'a-no-newline\nFAILED: ' "failed result on its own line"
  assert-contains "$TEST_STDOUT" $'b-no-newline\nSuites: 2' "summary on its own line"
  assert-contains "$TEST_STDOUT" $'Failed suites:\n  - ' "failed suite summary on its own line"

  return 0
}

# ==============================================================================
# Helpers

# Write an executable plain bash script into the fixture tree "$TEST_TMP/tree",
# a git repository so the runner can discover its suites.
# Arguments:
#   $1=[path of the script, relative to the fixture tree]
#   $2=[bash code the script runs]
function write-fixture() {

  local file="$TEST_TMP/tree/$1"
  if [[ ! -d "$TEST_TMP/tree/.git" ]]; then
    git init -q "$TEST_TMP/tree"
  fi
  mkdir -p "$(dirname "$file")"
  printf '#!/usr/bin/env bash\n%s\n' "$2" > "$file"
  chmod +x "$file"

  return 0
}

# Run the runner against the fixture tree, capturing its output and exit status.
function run-runner() {

  local target_dir=${1:-$TEST_TMP/tree}
  test-capture env dir="$target_dir" "$TEST_REPO_ROOT/scripts/tests/run-test-suites.sh"

  return 0
}

# Run the runner with the fixture tree as its current directory, so a fixture
# git repository there is its top level, capturing its output and exit status.
# Arguments:
#   $@=[variable assignments for the runner, such as 'dir=path', optional]
function run-runner-in-tree() {

  test-capture _run-runner-from-tree "$@"

  return 0
}

# Change to the fixture tree and run the runner there without an inherited 'dir'.
# Arguments:
#   $@=[variable assignments for the runner, optional]
function _run-runner-from-tree() {

  cd "$TEST_TMP/tree"
  env -u dir "$@" "$TEST_REPO_ROOT/scripts/tests/run-test-suites.sh"

  return $?
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
