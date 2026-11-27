#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034,SC2317,SC2329

set -euo pipefail

# Test suite for the pull request title check. Each test runs the script with a
# title, and sometimes a description, and checks its exit status, its
# diagnostic and the job summary it writes.
#
# Usage:
#   $ ./scripts/cicd/tests/check-pull-request-title.test.sh
#
# Options:
#   VERBOSE=true  # Show all the executed commands, default is 'false'

# ==============================================================================

source "$(dirname "${BASH_SOURCE[0]}")/../../tests/test.lib.sh"

readonly EXIT_STATUS_LABEL='exit status'
readonly CONVENTIONAL_COMMITS='Conventional Commits'
readonly GUIDE_LINK='docs/guides/template/Publish_releases.md#name-your-pull-request'
readonly SUGGESTION_LABEL='Suggested title:'

# Set up the suite and run every test.
function main() {

  cd "$(git rev-parse --show-toplevel)"

  # The caller's options must not reach the code under test
  unset -v GITHUB_ACTIONS GITHUB_STEP_SUMMARY PR_TITLE PR_BODY

  test-run-suite \
    test-title-check-accepts-conventional-titles \
    test-title-check-accepts-quotes-and-dollar-signs \
    test-title-check-rejects-non-conventional-titles \
    test-title-check-rejects-skip-marker-in-title \
    test-title-check-rejects-skip-marker-in-body \
    test-title-check-rejects-release-suppression \
    test-title-check-ignores-release-suppression-with-unicode-spaces \
    test-title-check-ignores-skip-trailer \
    test-title-check-accepts-non-directive-trailers \
    test-title-check-fails-without-title \
    test-title-check-writes-summary-on-failure \
    test-title-check-fails-when-summary-cannot-be-written

  return 0
}

# ==============================================================================

function test-title-check-rejects-release-suppression() {

  # Arrange
  local body
  for body in '[skip release]' '[release   skip]'; do
    # Act
    title-check-run PR_TITLE='fix: correct export' PR_BODY="$body"
    # Assert
    assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL for '$body'"
    assert-contains "$TEST_STDERR" 'skip' 'diagnostic'
  done
  # Act
  title-check-run PR_TITLE='fix: correct export [SKIP release]'
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL for title"

  return 0
}

function test-title-check-ignores-release-suppression-with-unicode-spaces() {

  # Act
  title-check-run PR_TITLE=$'fix: correct export [skip\xc2\xa0release]'
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"

  return 0
}

function test-title-check-ignores-skip-trailer() {

  # Act
  title-check-run PR_TITLE='fix: correct export' PR_BODY=$'Explanation\n\n\nskip-checks: true'
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"

  return 0
}

function test-title-check-accepts-non-directive-trailers() {

  # Arrange
  local body
  for body in 'skip-checks: false' $'Explanation\nskip-checks: true' \
    $'Explanation\n\n\nskip-checks: true\nOther: value'; do
    # Act
    title-check-run PR_TITLE='fix: correct export' PR_BODY="$body"
    # Assert
    assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL for '$body': $TEST_STDERR"
  done

  return 0
}

function test-title-check-accepts-conventional-titles() {

  # Arrange
  local title
  for title in 'feat: add x' 'fix(api)!: drop y' 'chore(deps): bump z from 1 to 2' 'revert: feat: add x'; do
    # Act
    title-check-run PR_TITLE="$title"
    # Assert
    assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL of '$title': $TEST_STDERR"
    assert-equal "" "$TEST_STDERR" "stderr of '$title'"
  done

  return 0
}

function test-title-check-accepts-quotes-and-dollar-signs() {

  # Arrange
  # The title must reach the script literally, without shell expansion
  # shellcheck disable=SC2016
  local title='fix: say "hello" to $HOME and `whoami` $(id)'
  # Act
  title-check-run PR_TITLE="$title"
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"

  return 0
}

function test-title-check-rejects-non-conventional-titles() {

  # Arrange
  local title
  for title in 'Feat: x' 'feat:x' 'feat: ' 'Bump x from 1 to 2' 'Revert "feat: x"' 'update readme' 'feature: x'; do
    # Act
    title-check-run PR_TITLE="$title"
    # Assert
    assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL of '$title'"
    assert-contains "$TEST_STDERR" "$CONVENTIONAL_COMMITS" "stderr of '$title'"
    assert-contains "$TEST_STDERR" "type(scope)!: description" "expected form for '$title'"
    assert-contains "$TEST_STDERR" "$GUIDE_LINK" "guide link for '$title'"
    assert-not-contains "$TEST_STDERR" "$SUGGESTION_LABEL" "no suggestion for '$title'"
    assert-equal 1 "$(grep -c '^ERROR: ' <<< "$TEST_STDERR")" "one error line for '$title'"
  done

  return 0
}

function test-title-check-rejects-skip-marker-in-title() {

  # Arrange
  local title
  for title in 'fix: x [skip ci]' 'fix: x [CI Skip]' 'fix: [no ci] x' 'fix: x [Skip Actions]' 'fix: x [actions skip]'; do
    # Act
    title-check-run PR_TITLE="$title"
    # Assert
    assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL of '$title'"
    assert-contains "$TEST_STDERR" "skip" "stderr of '$title'"
    assert-contains "$TEST_STDERR" "$GUIDE_LINK" "guide link for '$title'"
  done

  return 0
}

function test-title-check-rejects-skip-marker-in-body() {

  # Arrange
  local body=$'notes\n[skip actions]'
  # Act
  title-check-run PR_TITLE='fix: x' PR_BODY="$body"
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "[skip actions]" "stderr"
  assert-contains "$TEST_STDERR" "description" "stderr"

  return 0
}

function test-title-check-fails-without-title() {

  # Act
  title-check-run
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "PR_TITLE" "stderr"
  assert-contains "$TEST_STDERR" "$CONVENTIONAL_COMMITS" "rule"
  assert-contains "$TEST_STDERR" "type(scope)!: description" "expected form"
  assert-contains "$TEST_STDERR" "$GUIDE_LINK" "guide link"

  return 0
}

function test-title-check-writes-summary-on-failure() {

  # Arrange
  local summary="$TEST_TMP/summary"
  touch "$summary"
  # Act
  title-check-run PR_TITLE='Feat: x' GITHUB_STEP_SUMMARY="$summary"
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-not-contains "$TEST_STDERR" "'feat: x'" "no rewritten title in the diagnostic"
  assert-contains "$(cat "$summary")" "type(scope)!: description" "expected form in the summary"
  assert-contains "$(cat "$summary")" "$GUIDE_LINK" "guide link in the summary"
  assert-not-contains "$(cat "$summary")" "$SUGGESTION_LABEL" "no suggestion in the summary"
  assert-not-contains "$(cat "$summary")" "'feat: x'" "no rewritten title in the summary"

  # Act
  rm -f "$summary"
  title-check-run PR_TITLE='feat: x' GITHUB_STEP_SUMMARY="$summary"
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-file-not-exists "$summary"

  return 0
}

function test-title-check-fails-when-summary-cannot-be-written() {

  # Act
  title-check-run PR_TITLE='Feat: x' GITHUB_STEP_SUMMARY="$TEST_TMP/missing/summary"
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "job summary" "summary error"
  assert-contains "$(tail -n 1 <<< "$TEST_STDERR")" "$GUIDE_LINK" "guide link ends the summary error"
  assert-not-contains "$TEST_STDERR" "No such file" "no raw shell error"

  return 0
}

# ==============================================================================

# Run the script with only the given environment, so the caller's variables do
# not reach it.
# Arguments:
#   $@=[optional environment assignments]
function title-check-run() {

  test-capture env -i PATH="$PATH" LC_ALL=C "$@" ./scripts/cicd/check-pull-request-title.sh

  return 0
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
