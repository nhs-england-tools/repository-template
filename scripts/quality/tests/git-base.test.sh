#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034,SC2317,SC2329

set -euo pipefail

# Test suite for automatic quality-check base resolution. Each test uses a
# scratch Git repository and stubs GitHub CLI when needed.
#
# Usage:
#   $ ./scripts/quality/tests/git-base.test.sh
#
# Options:
#   VERBOSE=true  # Show all the executed commands, default is 'false'

# ==============================================================================

readonly EXIT_STATUS_LABEL='exit status'
readonly NONZERO_STATUS='^[1-9][0-9]*$'

# Run the base resolver tests.
function main() {

  cd "$(git rev-parse --show-toplevel)"
  source ./scripts/tests/test.lib.sh

  # The caller's options must not reach the code under test
  unset -v GITHUB_BASE_REF BRANCH_NAME QUALITY_PR_BASE QUALITY_GH_TIMEOUT

  test-run-suite \
    test-quality-resolve-base-prefers-github-base-ref \
    test-quality-resolve-base-prefers-the-remote-copy-of-a-github-base \
    test-quality-resolve-base-fails-when-the-github-base-is-missing \
    test-quality-resolve-base-uses-branch-name-as-given \
    test-quality-resolve-base-fails-when-branch-name-is-missing \
    test-quality-resolve-base-uses-the-open-pull-request-base \
    test-quality-resolve-base-fails-when-the-pull-request-base-is-not-fetched \
    test-quality-resolve-base-ignores-closed-and-merged-pull-requests \
    test-quality-resolve-base-falls-back-when-gh-prints-nothing \
    test-quality-resolve-base-falls-back-when-gh-fails \
    test-quality-resolve-base-falls-back-when-gh-is-unavailable \
    test-quality-resolve-base-stops-waiting-for-a-slow-gh \
    test-quality-resolve-base-reuses-a-shared-pull-request-base \
    test-quality-export-pr-base-calls-gh-once-for-several-checks \
    test-quality-export-pr-base-skips-gh-when-a-base-is-given \
    test-quality-resolve-base-uses-origin-head \
    test-quality-resolve-base-uses-main-when-origin-head-is-dangling \
    test-quality-resolve-base-uses-main-without-origin-head \
    test-quality-resolve-base-fails-without-a-merge-base

  return 0
}

# Create a repository with origin/main and origin/v2 at its first commit and
# the feature branch one commit ahead, checked out. Print the first commit.
function quality-test-create-repo() {

  local repo="$TEST_TMP/repo" base_commit
  mkdir -p "$repo"
  git -C "$repo" init -q --initial-branch=main
  git -C "$repo" config user.name fixture
  git -C "$repo" config user.email fixture@example.test
  printf 'base\n' > "$repo/a.txt"
  git -C "$repo" add a.txt
  git -C "$repo" commit -q -m base
  base_commit="$(git -C "$repo" rev-parse HEAD)"
  git -C "$repo" update-ref refs/remotes/origin/main "$base_commit"
  git -C "$repo" update-ref refs/remotes/origin/v2 "$base_commit"
  git -C "$repo" switch -q -c feature
  printf 'feature\n' >> "$repo/a.txt"
  git -C "$repo" commit -q -am feature

  printf '%s\n' "$base_commit"

  return 0
}

# Resolve the base in the current repository and print the ref and fork point.
function quality-test-resolve-base() {

  local base_ref fork_point
  source "$TEST_REPO_ROOT/scripts/quality/git-base.lib.sh"
  quality-resolve-base base_ref fork_point || return "$?"
  printf '%s %s\n' "$base_ref" "$fork_point"

  return 0
}

# Share one pull request lookup, as 'make lint check=branch' does, then resolve
# the base for two checks. Print both refs and the shared base, or 'unset'.
function quality-test-export-and-resolve-twice() {

  local first second fork_point
  source "$TEST_REPO_ROOT/scripts/quality/git-base.lib.sh"
  quality-export-pr-base || return "$?"
  quality-resolve-base first fork_point || return "$?"
  quality-resolve-base second fork_point || return "$?"
  printf '%s %s %s\n' "$first" "$second" "${QUALITY_PR_BASE-unset}"

  return 0
}

# ==============================================================================

function test-quality-resolve-base-prefers-github-base-ref() {

  # Arrange
  local base_commit
  base_commit="$(quality-test-create-repo)"
  test-isolate-path
  test-stub gh 'printf "OPEN main\n"'
  cd "$TEST_TMP/repo"
  # Act
  GITHUB_BASE_REF=v2 BRANCH_NAME=origin/main test-capture quality-test-resolve-base
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "origin/v2 $base_commit" "$TEST_STDOUT" "base ref and fork point"
  assert-contains "$TEST_STDERR" "Comparing with origin/v2 (GITHUB_BASE_REF, fork ${base_commit:0:7}"
  assert-stub-not-called gh

  return 0
}

function test-quality-resolve-base-prefers-the-remote-copy-of-a-github-base() {

  # Arrange
  local base_commit
  base_commit="$(quality-test-create-repo)"
  git -C "$TEST_TMP/repo" branch v2 feature
  test-isolate-path
  cd "$TEST_TMP/repo"
  # Act
  GITHUB_BASE_REF=v2 test-capture quality-test-resolve-base
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "origin/v2 $base_commit" "$TEST_STDOUT" "remote copy of the base"

  return 0
}

function test-quality-resolve-base-fails-when-the-github-base-is-missing() {

  # Arrange
  quality-test-create-repo > /dev/null
  test-isolate-path
  cd "$TEST_TMP/repo"
  # Act
  GITHUB_BASE_REF=missing BRANCH_NAME=origin/main test-capture quality-test-resolve-base
  # Assert
  assert-matches "$TEST_STATUS" "$NONZERO_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal '' "$TEST_STDOUT" "no fallback base"
  assert-contains "$TEST_STDERR" "Branch to compare with not found: missing. Fetch it with 'git fetch origin missing'."

  return 0
}

function test-quality-resolve-base-uses-branch-name-as-given() {

  # Arrange
  local head_commit branch_output branch_status
  quality-test-create-repo > /dev/null
  head_commit="$(git -C "$TEST_TMP/repo" rev-parse HEAD)"
  git -C "$TEST_TMP/repo" branch v2 feature
  git -C "$TEST_TMP/repo" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
  test-isolate-path
  test-stub gh 'printf "OPEN main\n"'
  cd "$TEST_TMP/repo"
  # Act
  BRANCH_NAME=v2 test-capture quality-test-resolve-base
  branch_output="$TEST_STDOUT"
  branch_status="$TEST_STATUS"
  BRANCH_NAME=HEAD test-capture quality-test-resolve-base
  # Assert
  assert-equal 0 "$branch_status" "exit status with a local branch"
  assert-equal "v2 $head_commit" "$branch_output" "local branch, not its remote copy"
  assert-equal 0 "$TEST_STATUS" "exit status with HEAD"
  assert-equal "HEAD $head_commit" "$TEST_STDOUT" "HEAD, not origin/HEAD"
  assert-stub-not-called gh

  return 0
}

function test-quality-resolve-base-fails-when-branch-name-is-missing() {

  # Arrange
  quality-test-create-repo > /dev/null
  test-isolate-path
  test-stub gh 'printf "OPEN v2\n"'
  cd "$TEST_TMP/repo"
  # Act
  BRANCH_NAME=missing test-capture quality-test-resolve-base
  # Assert
  assert-matches "$TEST_STATUS" "$NONZERO_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal '' "$TEST_STDOUT" "no fallback base"
  assert-contains "$TEST_STDERR" "Branch to compare with not found: missing. Set BRANCH_NAME to an existing branch or commit."
  assert-stub-not-called gh

  return 0
}

function test-quality-resolve-base-uses-the-open-pull-request-base() {

  # Arrange
  local base_commit expected_call
  base_commit="$(quality-test-create-repo)"
  expected_call="$(printf '%q ' pr view --json state,baseRefName --jq '.state + " " + .baseRefName')"
  test-isolate-path
  test-stub gh 'printf "OPEN v2\n"'
  cd "$TEST_TMP/repo"
  # Act
  test-capture quality-test-resolve-base
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "origin/v2 $base_commit" "$TEST_STDOUT" "base ref and fork point"
  assert-stub-called gh "${expected_call% }"
  assert-contains "$TEST_STDERR" "Comparing with origin/v2 (open pull request,"

  return 0
}

function test-quality-resolve-base-fails-when-the-pull-request-base-is-not-fetched() {

  # Arrange
  quality-test-create-repo > /dev/null
  test-isolate-path
  test-stub gh 'printf "OPEN v3\n"'
  cd "$TEST_TMP/repo"
  # Act
  test-capture quality-test-resolve-base
  # Assert
  assert-matches "$TEST_STATUS" "$NONZERO_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal '' "$TEST_STDOUT" "no fallback base"
  assert-contains "$TEST_STDERR" "Branch to compare with not found: v3. Fetch it with 'git fetch origin v3'."

  return 0
}

function test-quality-resolve-base-ignores-closed-and-merged-pull-requests() {

  # Arrange
  local base_commit merged_output merged_stderr
  base_commit="$(quality-test-create-repo)"
  test-isolate-path
  test-stub gh 'printf "MERGED v2\n"'
  cd "$TEST_TMP/repo"
  # Act
  test-capture quality-test-resolve-base
  merged_output="$TEST_STDOUT"
  merged_stderr="$TEST_STDERR"
  test-stub gh 'printf "CLOSED v2\n"'
  test-capture quality-test-resolve-base
  # Assert
  assert-equal "origin/main $base_commit" "$merged_output" "base with a merged pull request"
  assert-contains "$merged_stderr" "GitHub CLI found no open pull request for this branch"
  assert-equal "origin/main $base_commit" "$TEST_STDOUT" "base with a closed pull request"

  return 0
}

function test-quality-resolve-base-falls-back-when-gh-prints-nothing() {

  # Arrange
  local base_commit
  base_commit="$(quality-test-create-repo)"
  test-isolate-path
  test-stub gh 'exit 0'
  cd "$TEST_TMP/repo"
  # Act
  test-capture quality-test-resolve-base
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "origin/main $base_commit" "$TEST_STDOUT" "default base"
  assert-contains "$TEST_STDERR" "GitHub CLI found no open pull request for this branch"

  return 0
}

function test-quality-resolve-base-falls-back-when-gh-fails() {

  # Arrange
  local base_commit
  base_commit="$(quality-test-create-repo)"
  test-isolate-path
  test-stub gh 'echo "no pull requests found" >&2; exit 1'
  cd "$TEST_TMP/repo"
  # Act
  test-capture quality-test-resolve-base
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "origin/main $base_commit" "$TEST_STDOUT" "default base"
  assert-contains "$TEST_STDERR" "GitHub CLI found no open pull request for this branch"
  assert-not-contains "$TEST_STDERR" "no pull requests found"

  return 0
}

function test-quality-resolve-base-falls-back-when-gh-is-unavailable() {

  # Arrange
  local base_commit
  base_commit="$(quality-test-create-repo)"
  test-isolate-path
  cd "$TEST_TMP/repo"
  # Act
  test-capture quality-test-resolve-base
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "origin/main $base_commit" "$TEST_STDOUT" "default base"
  assert-contains "$TEST_STDERR" "GitHub CLI is unavailable, so the default branch is used."

  return 0
}

function test-quality-resolve-base-stops-waiting-for-a-slow-gh() {

  # Arrange
  local base_commit start_us elapsed_us
  base_commit="$(quality-test-create-repo)"
  test-isolate-path
  test-stub gh 'sleep 5; printf "OPEN v2\n"'
  cd "$TEST_TMP/repo"
  # Act
  # Strip the locale's decimal separator to get whole microseconds
  start_us="${EPOCHREALTIME//[!0-9]/}"
  QUALITY_GH_TIMEOUT=1 test-capture quality-test-resolve-base
  elapsed_us=$((${EPOCHREALTIME//[!0-9]/} - start_us))
  # Assert
  assert-equal 0 "$((elapsed_us >= 5000000))" "waited less than the slow GitHub CLI call"
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "origin/main $base_commit" "$TEST_STDOUT" "default base"
  assert-contains "$TEST_STDERR" "GitHub CLI did not answer within 1s, so the default branch is used."

  return 0
}

function test-quality-resolve-base-reuses-a-shared-pull-request-base() {

  # Arrange
  local base_commit shared_output shared_status
  base_commit="$(quality-test-create-repo)"
  test-isolate-path
  test-stub gh 'printf "OPEN main\n"'
  cd "$TEST_TMP/repo"
  # Act
  QUALITY_PR_BASE=v2 test-capture quality-test-resolve-base
  shared_output="$TEST_STDOUT"
  shared_status="$TEST_STATUS"
  QUALITY_PR_BASE='' test-capture quality-test-resolve-base
  # Assert
  assert-equal 0 "$shared_status" "exit status with a shared base"
  assert-equal "origin/v2 $base_commit" "$shared_output" "shared pull request base"
  assert-equal 0 "$TEST_STATUS" "exit status with no shared base"
  assert-equal "origin/main $base_commit" "$TEST_STDOUT" "default base"
  assert-stub-not-called gh

  return 0
}

function test-quality-export-pr-base-calls-gh-once-for-several-checks() {

  # Arrange
  quality-test-create-repo > /dev/null
  test-isolate-path
  test-stub gh 'printf "OPEN v2\n"'
  cd "$TEST_TMP/repo"
  # Act
  test-capture quality-test-export-and-resolve-twice
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "origin/v2 origin/v2 v2" "$TEST_STDOUT" "both bases and the shared base"
  assert-equal 1 "$(test-stub-calls gh | awk 'END { print NR }')" "number of GitHub CLI calls"

  return 0
}

function test-quality-export-pr-base-skips-gh-when-a-base-is-given() {

  # Arrange
  local github_output
  quality-test-create-repo > /dev/null
  test-isolate-path
  test-stub gh 'printf "OPEN main\n"'
  cd "$TEST_TMP/repo"
  # Act
  GITHUB_BASE_REF=v2 test-capture quality-test-export-and-resolve-twice
  github_output="$TEST_STDOUT"
  BRANCH_NAME=origin/v2 test-capture quality-test-export-and-resolve-twice
  # Assert
  assert-equal "origin/v2 origin/v2 unset" "$github_output" "bases with GITHUB_BASE_REF"
  assert-equal "origin/v2 origin/v2 unset" "$TEST_STDOUT" "bases with BRANCH_NAME"
  assert-stub-not-called gh

  return 0
}

function test-quality-resolve-base-uses-origin-head() {

  # Arrange
  local base_commit
  base_commit="$(quality-test-create-repo)"
  git -C "$TEST_TMP/repo" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/v2
  test-isolate-path
  cd "$TEST_TMP/repo"
  # Act
  test-capture quality-test-resolve-base
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "origin/v2 $base_commit" "$TEST_STDOUT" "origin/HEAD target"
  assert-contains "$TEST_STDERR" "Comparing with origin/v2 (origin/HEAD,"

  return 0
}

function test-quality-resolve-base-uses-main-when-origin-head-is-dangling() {

  # Arrange
  local base_commit
  base_commit="$(quality-test-create-repo)"
  git -C "$TEST_TMP/repo" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/gone
  test-isolate-path
  cd "$TEST_TMP/repo"
  # Act
  test-capture quality-test-resolve-base
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "origin/main $base_commit" "$TEST_STDOUT" "main fallback"
  assert-contains "$TEST_STDERR" "Comparing with origin/main (origin/main fallback,"

  return 0
}

function test-quality-resolve-base-uses-main-without-origin-head() {

  # Arrange
  local base_commit
  base_commit="$(quality-test-create-repo)"
  test-isolate-path
  cd "$TEST_TMP/repo"
  # Act
  test-capture quality-test-resolve-base
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "origin/main $base_commit" "$TEST_STDOUT" "main fallback"

  return 0
}

function test-quality-resolve-base-fails-without-a-merge-base() {

  # Arrange
  local repo="$TEST_TMP/repo"
  quality-test-create-repo > /dev/null
  git -C "$repo" switch -q --orphan unrelated
  printf 'unrelated\n' > "$repo/b.txt"
  git -C "$repo" add b.txt
  git -C "$repo" commit -q -m unrelated
  git -C "$repo" update-ref refs/remotes/origin/unrelated HEAD
  git -C "$repo" switch -q feature
  test-isolate-path
  cd "$repo"
  # Act
  GITHUB_BASE_REF=unrelated test-capture quality-test-resolve-base
  # Assert
  assert-matches "$TEST_STATUS" "$NONZERO_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal '' "$TEST_STDOUT" "no base without a merge base"
  assert-contains "$TEST_STDERR" "No merge base found for 'origin/unrelated' and HEAD"

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
