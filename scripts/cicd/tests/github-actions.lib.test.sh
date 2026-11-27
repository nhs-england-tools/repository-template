#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034,SC2317,SC2329

set -euo pipefail

# Test suite for the diagnostic helper that prints errors, warnings and notices
# as GitHub Actions annotations or as plain local lines.
#
# Usage:
#   $ ./scripts/cicd/tests/github-actions.lib.test.sh
#
# Options:
#   VERBOSE=true  # Show all the executed commands, default is 'false'

# ==============================================================================

source "$(dirname "${BASH_SOURCE[0]}")/../../tests/test.lib.sh"

readonly EXIT_STATUS_LABEL='exit status'
readonly STDERR_LABEL='stderr'
readonly STDOUT_LABEL='stdout'

# Set up the suite and run every test.
function main() {

  cd "$(git rev-parse --show-toplevel)"

  # The caller's options must not reach the code under test
  unset -v GITHUB_ACTIONS

  test-run-suite \
    test-diagnostic-writes-a-github-error-to-stderr \
    test-diagnostic-writes-a-github-warning-to-stderr \
    test-diagnostic-writes-a-github-notice-to-stderr \
    test-diagnostic-writes-local-text-to-stderr \
    test-diagnostic-colours-only-local-terminal-labels \
    test-diagnostic-uses-local-text-unless-github-actions-is-true \
    test-diagnostic-escapes-the-message \
    test-diagnostic-cannot-inject-another-command \
    test-diagnostic-rejects-an-unknown-level \
    test-diagnostic-rejects-a-wrong-argument-count

  return 0
}

# ==============================================================================

function test-diagnostic-writes-a-github-error-to-stderr() {

  # Act
  diagnostic-run true error 'Build failed'
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-equal '::error::Build failed' "$TEST_STDERR" "$STDERR_LABEL"
  assert-equal "" "$TEST_STDOUT" "$STDOUT_LABEL"

  return 0
}

function test-diagnostic-writes-a-github-warning-to-stderr() {

  # Act
  diagnostic-run true warning 'Review due'
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-equal '::warning::Review due' "$TEST_STDERR" "$STDERR_LABEL"
  assert-equal "" "$TEST_STDOUT" "$STDOUT_LABEL"

  return 0
}

function test-diagnostic-writes-a-github-notice-to-stderr() {

  # Act
  diagnostic-run true notice 'Start Docker'
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-equal '::notice::Start Docker' "$TEST_STDERR" "$STDERR_LABEL"
  assert-equal "" "$TEST_STDOUT" "$STDOUT_LABEL"

  return 0
}

function test-diagnostic-writes-local-text-to-stderr() {

  # Act
  diagnostic-run '' error 'Build failed'
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-equal 'ERROR: Build failed' "$TEST_STDERR" "error stderr"
  assert-equal "" "$TEST_STDOUT" "error stdout"
  # Act
  diagnostic-run '' warning 'Review due'
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-equal 'WARNING: Review due' "$TEST_STDERR" "warning stderr"
  assert-equal "" "$TEST_STDOUT" "warning stdout"
  # Act
  diagnostic-run '' notice 'Start Docker'
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-equal 'NOTICE: Start Docker' "$TEST_STDERR" "notice stderr"
  assert-equal "" "$TEST_STDOUT" "notice stdout"

  return 0
}

function test-diagnostic-colours-only-local-terminal-labels() {

  # Arrange
  local level expected
  for level in error warning notice; do
    case "$level" in
      error) expected=$'\033[31mERROR:\033[0m Message' ;;
      warning) expected=$'\033[33mWARNING:\033[0m Message' ;;
      notice) expected=$'\033[34mNOTICE:\033[0m Message' ;;
      *) return 1 ;;
    esac
    # Act
    diagnostic-run-terminal "$level" colour
    # Assert
    assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL for $level: $TEST_STDERR"
    assert-equal "$expected" "$TEST_STDOUT" "terminal output for $level"
  done

  # Act
  diagnostic-run-terminal error no-colour
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL with NO_COLOR"
  assert-equal 'ERROR: Message' "$TEST_STDOUT" 'NO_COLOR output'
  # Act
  diagnostic-run-terminal warning dumb
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL with TERM=dumb"
  assert-equal 'WARNING: Message' "$TEST_STDOUT" 'dumb terminal output'
  # Act
  diagnostic-run-terminal notice github
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL in GitHub Actions"
  assert-equal '::notice::Message' "$TEST_STDOUT" 'GitHub annotation output'

  return 0
}

function test-diagnostic-uses-local-text-unless-github-actions-is-true() {

  # Arrange
  local value
  for value in false TRUE 1; do
    # Act
    diagnostic-run "$value" error 'a%b'
    # Assert
    assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL for $value: $TEST_STDERR"
    assert-equal 'ERROR: a%b' "$TEST_STDERR" "stderr for $value"
  done

  return 0
}

function test-diagnostic-escapes-the-message() {

  # Act
  diagnostic-run true error $'50% & 100%25\rdone\nnext'
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-equal '::error::50%25 & 100%2525%0Ddone%0Anext' "$TEST_STDERR" "$STDERR_LABEL"

  return 0
}

function test-diagnostic-cannot-inject-another-command() {

  # Act
  diagnostic-run true warning $'x\n::error::y'
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-equal '::warning::x%0A::error::y' "$TEST_STDERR" "$STDERR_LABEL"
  assert-not-contains "$TEST_STDERR" $'\n' "second line"

  return 0
}

function test-diagnostic-rejects-an-unknown-level() {

  # Act
  diagnostic-run true debug 'Hello'
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL in GitHub Actions"
  assert-equal "::error::Diagnostic level 'debug' is not 'error', 'warning' or 'notice'" "$TEST_STDERR" "annotation"
  assert-equal "" "$TEST_STDOUT" "$STDOUT_LABEL"
  # Act
  diagnostic-run '' debug 'Hello'
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL locally"
  assert-equal "ERROR: Diagnostic level 'debug' is not 'error', 'warning' or 'notice'" "$TEST_STDERR" "local text"

  return 0
}

function test-diagnostic-rejects-a-wrong-argument-count() {

  # Act
  diagnostic-run true error
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL with one argument"
  assert-equal '::error::print-diagnostic needs a level and a message' "$TEST_STDERR" "annotation with one argument"
  # Act
  diagnostic-run '' error 'a' 'b'
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL with three arguments"
  assert-equal 'ERROR: print-diagnostic needs a level and a message' "$TEST_STDERR" "local text with three arguments"
  assert-equal "" "$TEST_STDOUT" "$STDOUT_LABEL"

  return 0
}

# ==============================================================================

# Capture diagnostic output sent to a pseudo-terminal.
# Arguments:
#   $1=[diagnostic level]
#   $2=[colour, no-colour, dumb or github]
function diagnostic-run-terminal() {

  local level="$1" mode="$2"
  # shellcheck disable=SC2016
  test-capture python3 -c '
import os, pty, select, subprocess, sys, termios
level, mode = sys.argv[1:]
environment = os.environ.copy()
environment.pop("NO_COLOR", None)
environment.pop("GITHUB_ACTIONS", None)
environment["TERM"] = "dumb" if mode == "dumb" else "xterm-256color"
if mode == "no-colour":
  environment["NO_COLOR"] = "1"
if mode == "github":
  environment["GITHUB_ACTIONS"] = "true"
master, slave = pty.openpty()
attributes = termios.tcgetattr(slave)
attributes[1] &= ~termios.OPOST
termios.tcsetattr(slave, termios.TCSANOW, attributes)
process = subprocess.Popen(
  ["bash", "-c", "source ./scripts/cicd/github-actions.lib.sh; print-diagnostic \"$1\" Message", "diagnostic", level],
  stdout=subprocess.PIPE, stderr=slave, env=environment,
)
output = b""
try:
  while b"\n" not in output:
    ready, _, _ = select.select([master], [], [], 30)
    if not ready:
      raise TimeoutError("diagnostic did not write to the terminal")
    chunk = os.read(master, 4096)
    if not chunk:
      raise RuntimeError("terminal closed before the diagnostic was written")
    output += chunk
finally:
  os.close(slave)
  os.close(master)
stdout, _ = process.communicate()
if stdout:
  sys.stderr.write("unexpected diagnostic stdout")
  sys.exit(1)
sys.stdout.buffer.write(output)
sys.exit(process.returncode)
' "$level" "$mode"

  return 0
}

# Source the diagnostic helper and capture one call of it.
# Arguments:
#   $1=[value of GITHUB_ACTIONS, empty to leave it unset]
#   $@=[arguments of 'print-diagnostic', after the first]
function diagnostic-run() {

  test-capture diagnostic-call "$@"

  return 0
}

# Run the diagnostic helper in the subshell of 'test-capture'.
# Arguments:
#   $1=[value of GITHUB_ACTIONS, empty to leave it unset]
#   $@=[arguments of 'print-diagnostic', after the first]
function diagnostic-call() {

  local github_actions="$1"
  shift
  [[ -z "$github_actions" ]] || export GITHUB_ACTIONS="$github_actions"
  source ./scripts/cicd/github-actions.lib.sh
  print-diagnostic "$@"

  return $?
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
