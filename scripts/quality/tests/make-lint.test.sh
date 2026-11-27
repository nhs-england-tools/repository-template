#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034,SC2317,SC2329

set -euo pipefail

# Test suite for the check modes that Make passes to quality scripts. Each test
# runs the real Makefile in a scratch repository, with scripts replaced by a
# recorder and 'gh' stubbed, so it needs none of the tools.
#
# Usage:
#   $ ./scripts/quality/tests/make-lint.test.sh
#
# Options:
#   VERBOSE=true  # Show all the executed commands, default is 'false'

# ==============================================================================

source "$(dirname "${BASH_SOURCE[0]}")/../../tests/test.lib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/quality-test.lib.sh"

readonly EXIT_STATUS_LABEL='exit status'
readonly CHECKS=(check-file-format check-markdown-format check-markdown-links check-shell-lint check-pipeline-contract check-security-readiness format-markdown)

# Set up the suite fixtures and run every test.
function main() {

  cd "$(git rev-parse --show-toplevel)"

  QUALITY_FIXTURE_PATHS=(Makefile scripts/init.mk scripts/docker/docker.mk scripts/quality/git-base.lib.sh scripts/cicd/github-actions.lib.sh)
  QUALITY_FIXTURE_FORMAT='%s\n'

  # The caller's options must not reach the Makefile under test
  unset -v check BRANCH_NAME GITHUB_BASE_REF QUALITY_PR_BASE QUALITY_GH_TIMEOUT FORCE_USE_DOCKER GITHUB_ACTIONS

  test-run-suite \
    test-make-lint-checks-every-tracked-file-by-default \
    test-make-lint-defaults-docker-and-supports-opt-out \
    test-make-lint-passes-a-check-mode-to-the-file-checks \
    test-make-lint-detects-the-fixture-default-branch \
    test-make-lint-targets-run-their-check-directly \
    test-make-lint-shell-honours-a-scoped-mode \
    test-make-lint-pipeline-contract-honours-a-scoped-mode \
    test-make-lint-security-readiness-honours-a-scoped-mode \
    test-make-format-defaults-to-all-and-passes-a-scoped-mode

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
if [[ -n "${DOCKER_LOG:-}" ]]; then
  printf '%s %s\n' "${0##*/}" "${FORCE_USE_DOCKER:-unset}" >> "$DOCKER_LOG"
fi
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
check-shell-lint.sh check=all pr=unset
check-pipeline-contract.sh check=all pr=unset
check-security-readiness.sh check=all pr=unset" "$(cat "$TEST_TMP/checks.log")" "check modes and execution order"
  assert-stub-not-called gh

  return 0
}

function test-make-lint-defaults-docker-and-supports-opt-out() {

  # Arrange
  local default_status default_settings
  make-lint-create-fixture-repo
  cd "$TEST_TMP/repo"
  # Act
  make-lint-run lint
  default_status="$TEST_STATUS"
  default_settings="$(cat "$TEST_TMP/docker.log")"
  : > "$TEST_TMP/docker.log"
  make-lint-run FORCE_USE_DOCKER=false lint
  # Assert
  assert-equal 0 "$default_status" "default Docker $EXIT_STATUS_LABEL"
  assert-equal 0 "$TEST_STATUS" "native opt-out $EXIT_STATUS_LABEL"
  assert-equal $'check-file-format.sh true\ncheck-markdown-format.sh true\ncheck-markdown-links.sh true\ncheck-shell-lint.sh true\ncheck-pipeline-contract.sh true\ncheck-security-readiness.sh true' \
    "$default_settings" "default container setting"
  assert-equal $'check-file-format.sh false\ncheck-markdown-format.sh false\ncheck-markdown-links.sh false\ncheck-shell-lint.sh false\ncheck-pipeline-contract.sh false\ncheck-security-readiness.sh false' \
    "$(cat "$TEST_TMP/docker.log")" "explicit opt-out setting"

  return 0
}

function test-make-lint-passes-a-check-mode-to-the-file-checks() {

  # Arrange
  make-lint-create-fixture-repo
  cd "$TEST_TMP/repo"
  local default_branch
  default_branch="$(git symbolic-ref --short refs/remotes/origin/HEAD)"
  default_branch="${default_branch#origin/}"
  # Act
  make-lint-run lint check=branch
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "check-file-format.sh check=branch pr=$default_branch
check-markdown-format.sh check=branch pr=$default_branch
check-markdown-links.sh check=branch pr=$default_branch
check-shell-lint.sh check=branch pr=$default_branch
check-pipeline-contract.sh check=branch pr=$default_branch
check-security-readiness.sh check=branch pr=$default_branch" "$(cat "$TEST_TMP/checks.log")" "check modes and execution order"
  assert-equal 1 "$(test-stub-calls gh | awk 'END { print NR }')" "number of GitHub CLI calls"

  return 0
}

function test-make-lint-detects-the-fixture-default-branch() {

  # Arrange
  make-lint-create-fixture-repo
  cd "$TEST_TMP/repo"
  git update-ref refs/remotes/origin/fixture-default HEAD
  git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/fixture-default
  # Act
  make-lint-run lint check=branch
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-contains "$(cat "$TEST_TMP/checks.log")" 'check-security-readiness.sh check=branch pr=fixture-default' 'fixture default branch is shared with checks'
  assert-equal 1 "$(test-stub-calls gh | awk 'END { print NR }')" 'one pull request lookup'

  return 0
}

function test-make-lint-targets-run-their-check-directly() {

  # Arrange
  local target
  make-lint-create-fixture-repo
  cd "$TEST_TMP/repo"
  # Act
  for target in lint-file-format lint-markdown-format lint-markdown-links lint-shell lint-pipeline-contract lint-security-readiness; do
    make-lint-run "$target"
    assert-equal 0 "$TEST_STATUS" "exit status of $target"
  done
  # Assert
  assert-equal "check-file-format.sh check=all pr=unset
check-markdown-format.sh check=all pr=unset
check-markdown-links.sh check=all pr=unset
check-shell-lint.sh check=all pr=unset
check-pipeline-contract.sh check=all pr=unset
check-security-readiness.sh check=all pr=unset" "$(cat "$TEST_TMP/checks.log")" "check run by each target"
  assert-equal 0 "$(make-lint-target-count 'lint-*')" "lint-* targets defined in the root Makefile"
  assert-equal $'lint-pipeline-contract:\nlint-security-readiness:' "$(awk '/^lint-(pipeline-contract|security-readiness): check/ { print $1 }' scripts/init.mk)" 'Make target definition order'

  return 0
}

function test-make-lint-shell-honours-a-scoped-mode() {

  # Arrange
  make-lint-create-fixture-repo
  cd "$TEST_TMP/repo"
  # Act
  make-lint-run lint-shell check=staged-changes
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "check-shell-lint.sh check=staged-changes pr=unset" "$(cat "$TEST_TMP/checks.log")" "shell lint mode"

  return 0
}

function test-make-lint-security-readiness-honours-a-scoped-mode() {

  # Arrange
  make-lint-create-fixture-repo
  cd "$TEST_TMP/repo"
  # Act
  make-lint-run lint-security-readiness check=staged-changes
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "check-security-readiness.sh check=staged-changes pr=unset" "$(cat "$TEST_TMP/checks.log")" "security readiness mode"

  return 0
}

function test-make-lint-pipeline-contract-honours-a-scoped-mode() {

  # Arrange
  make-lint-create-fixture-repo
  cd "$TEST_TMP/repo"
  # Act
  make-lint-run lint-pipeline-contract check=staged-changes
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "check-pipeline-contract.sh check=staged-changes pr=unset" "$(cat "$TEST_TMP/checks.log")" "pipeline contract mode"

  return 0
}

function test-make-format-defaults-to-all-and-passes-a-scoped-mode() {

  # Arrange
  make-lint-create-fixture-repo
  cd "$TEST_TMP/repo"
  # Act
  make-lint-run format
  local default_status="$TEST_STATUS"
  make-lint-run format check=staged-changes
  # Assert
  assert-equal 0 "$default_status" "default $EXIT_STATUS_LABEL"
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL for staged-changes"
  assert-equal "format-markdown.sh check=all pr=unset
format-markdown.sh check=staged-changes pr=unset" "$(cat "$TEST_TMP/checks.log")" "format check modes"

  return 0
}

# ==============================================================================

# Create the scratch repository with each check script replaced by a recorder
# that logs its name, its check mode and the shared pull request base, and with
# 'gh' stubbed to report an open pull request into its own default branch.
function make-lint-create-fixture-repo() {

  local name default_branch
  # shellcheck disable=SC2119
  quality-create-fixture-repo
  default_branch="$(git -C "$TEST_TMP/repo" symbolic-ref --short HEAD)" || return "$?"
  git -C "$TEST_TMP/repo" update-ref "refs/remotes/origin/$default_branch" HEAD || return "$?"
  git -C "$TEST_TMP/repo" symbolic-ref refs/remotes/origin/HEAD "refs/remotes/origin/$default_branch" || return "$?"
  test-isolate-path make
  test-stub gh 'git symbolic-ref --short refs/remotes/origin/HEAD | sed "s,^origin/,OPEN ,"'
  for name in "${CHECKS[@]}"; do
    ln -sf "$SUITE_TMP/record-check.sh" "$TEST_TMP/repo/scripts/quality/$name.sh"
  done

  return 0
}

# Run make in the current directory without the caller's make or mise setup.
# Arguments:
#   $@=[make targets and variables]
function make-lint-run() {

  test-capture env -u MAKEFLAGS -u MAKELEVEL -u GNUMAKEFLAGS -u MAKEFILES -u FORCE_USE_DOCKER \
    CHECK_LOG="$TEST_TMP/checks.log" DOCKER_LOG="$TEST_TMP/docker.log" make MISE_SHIMS= "$@"

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
