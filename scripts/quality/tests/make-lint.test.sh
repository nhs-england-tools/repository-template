#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034,SC2317,SC2329

set -euo pipefail

# Test suite for the check modes that 'make lint' passes to each check. Each
# test runs the real Makefile in a scratch repository, with the check scripts
# replaced by a recorder and 'gh' stubbed, so it needs none of the tools.
#
# Usage:
#   $ ./scripts/quality/tests/make-lint.test.sh
#
# Options:
#   VERBOSE=true  # Show all the executed commands, default is 'false'

# ==============================================================================

readonly EXIT_STATUS_LABEL='exit status'
readonly CHECKS=(check-file-format check-markdown-format check-markdown-links check-shell-lint check-workflow-security)

# Set up the suite fixtures and run every test.
function main() {

  cd "$(git rev-parse --show-toplevel)"
  source ./scripts/tests/test.lib.sh
  source ./scripts/quality/tests/quality-test.lib.sh
  QUALITY_FIXTURE_PATHS=(Makefile scripts/init.mk scripts/docker/docker.mk scripts/quality/git-base.lib.sh)
  QUALITY_FIXTURE_FORMAT='%s\n'

  # The caller's options must not reach the Makefile under test
  unset -v check BRANCH_NAME GITHUB_BASE_REF QUALITY_PR_BASE QUALITY_GH_TIMEOUT

  test-run-suite \
    test-make-lint-checks-every-tracked-file-by-default \
    test-make-lint-passes-a-check-mode-to-the-file-checks \
    test-make-lint-targets-run-their-check-directly \
    test-make-lint-shell-honours-a-file-mode

  return 0
}

# Build the fixture repository and the check recorder once, every test starts
# from a copy. The recorder runs once here, so macOS assesses the new
# executable here rather than in each test.
function test-suite-setup() {

  quality-build-fixture-base
  cat > "$SUITE_TMP/record-check.sh" <<'EOF'
#!/usr/bin/env bash
printf '%s check=%s pr=%s\n' "${0##*/}" "${check:-}" "${QUALITY_PR_BASE-unset}" >> "$CHECK_LOG"
EOF
  chmod +x "$SUITE_TMP/record-check.sh"
  CHECK_LOG=/dev/null "$SUITE_TMP/record-check.sh"

  return 0
}

# ==============================================================================

function test-make-lint-checks-every-tracked-file-by-default() {

  # Arrange
  make-lint-create-fixture-repo
  cd "$TEST_TMP/repo"
  # Act
  make-lint-run lint
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "check-file-format.sh check=all pr=unset
check-markdown-format.sh check=all pr=unset
check-markdown-links.sh check=all pr=unset
check-shell-lint.sh check=all pr=unset" "$(sed -n 1,4p "$TEST_TMP/checks.log")" "check modes"
  assert-equal 5 "$(awk 'END { print NR }' "$TEST_TMP/checks.log")" "number of checks run"
  assert-stub-not-called gh

  return 0
}

function test-make-lint-passes-a-check-mode-to-the-file-checks() {

  # Arrange
  make-lint-create-fixture-repo
  cd "$TEST_TMP/repo"
  # Act
  make-lint-run lint check=branch
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "check-file-format.sh check=branch pr=v2
check-markdown-format.sh check=branch pr=v2
check-markdown-links.sh check=branch pr=v2
check-shell-lint.sh check=all pr=v2" "$(sed -n 1,4p "$TEST_TMP/checks.log")" "check modes"
  assert-equal 1 "$(test-stub-calls gh | awk 'END { print NR }')" "number of GitHub CLI calls"

  return 0
}

function test-make-lint-targets-run-their-check-directly() {

  # Arrange
  local target
  make-lint-create-fixture-repo
  cd "$TEST_TMP/repo"
  # Act
  for target in lint-file-format lint-markdown-format lint-markdown-links lint-shell lint-workflow-security; do
    make-lint-run "$target"
    assert-equal 0 "$TEST_STATUS" "exit status of $target"
  done
  # Assert
  assert-equal "check-file-format.sh check=all pr=unset
check-markdown-format.sh check=all pr=unset
check-markdown-links.sh check=all pr=unset
check-shell-lint.sh check=all pr=unset
check-workflow-security.sh check= pr=unset" "$(cat "$TEST_TMP/checks.log")" "check run by each target"
  assert-equal 0 "$(make-lint-target-count 'lint-*')" "lint-* targets defined in the root Makefile"

  return 0
}

function test-make-lint-shell-honours-a-file-mode() {

  # Arrange
  make-lint-create-fixture-repo
  cd "$TEST_TMP/repo"
  # Act
  make-lint-run lint-shell check=file
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "check-shell-lint.sh check=file pr=unset" "$(cat "$TEST_TMP/checks.log")" "shell lint mode"

  return 0
}

# ==============================================================================

# Create the scratch repository with each check script replaced by a recorder
# that logs its name, its check mode and the shared pull request base, and with
# 'gh' stubbed to report an open pull request into v2.
function make-lint-create-fixture-repo() {

  local name
  # shellcheck disable=SC2119
  quality-create-fixture-repo
  test-isolate-path make
  test-stub gh 'printf "OPEN v2\n"'
  for name in "${CHECKS[@]}"; do
    ln -sf "$SUITE_TMP/record-check.sh" "$TEST_TMP/repo/scripts/quality/$name.sh"
  done

  return 0
}

# Run make in the current directory without the caller's make or mise setup.
# Arguments:
#   $@=[make targets and variables]
function make-lint-run() {

  test-capture env -u MAKEFLAGS -u MAKELEVEL -u GNUMAKEFLAGS -u MAKEFILES \
    CHECK_LOG="$TEST_TMP/checks.log" make MISE_SHIMS= "$@"

  return 0
}

# Print how many targets matching a glob the root Makefile itself defines.
# Arguments:
#   $1=[target name glob]
function make-lint-target-count() {

  local pattern="$1" line count=0
  while IFS= read -r line; do
    # shellcheck disable=SC2053
    [[ "${line%%:*}" == $pattern && "$line" =~ ^[a-z][a-z-]*: ]] && count=$((count + 1))
  done < "$TEST_TMP/repo/Makefile"
  printf '%s\n' "$count"

  return 0
}

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
