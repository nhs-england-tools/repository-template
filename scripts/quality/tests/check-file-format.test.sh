#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034,SC2317,SC2329

set -euo pipefail

# Test suite for the EditorConfig check script. Each test runs the script in a
# scratch repository with 'editorconfig-checker' and 'docker' stubbed, so the
# suite needs neither tool nor a Docker daemon.
#
# Usage:
#   $ ./scripts/quality/tests/check-file-format.test.sh
#
# Options:
#   VERBOSE=true  # Show all the executed commands, default is 'false'

# ==============================================================================

readonly A_TXT_ARGUMENT=' a.txt '
readonly EXIT_STATUS_LABEL='exit status'
readonly EC=editorconfig-checker

# Set up the suite fixtures and run every test.
function main() {

  cd "$(git rev-parse --show-toplevel)"
  source ./scripts/tests/test.lib.sh
  source ./scripts/quality/tests/quality-test.lib.sh
  QUALITY_FIXTURE_PATHS=(scripts/quality/check-file-format.sh scripts/quality/git-files.lib.sh scripts/docker/docker.lib.sh scripts/config/editorconfig-checker.json)
  QUALITY_FIXTURE_FORMAT='%s\n'

  # The caller's options must not reach the script under test
  unset -v MISE_TOML match_version check dry_run BRANCH_NAME FORCE_USE_DOCKER

  EC_IMAGE=mstruebing/editorconfig-checker:6.0.0@sha256:6666666666666666666666666666666666666666666666666666666666666666
  test-run-suite \
    test-check-file-format-rejects-unknown-mode \
    test-check-file-format-all-checks-every-tracked-file \
    test-check-file-format-preserves-unusual-paths-in-native-and-docker \
    test-check-file-format-working-tree-changes-checks-modified-files-only \
    test-check-file-format-staged-changes-checks-staged-files-only \
    test-check-file-format-staged-rename-checks-new-path-once \
    test-check-file-format-branch-checks-changes-since-branch \
    test-check-file-format-fails-when-the-base-branch-is-missing \
    test-check-file-format-dry-run-passes-flag \
    test-check-file-format-skips-empty-selection \
    test-check-file-format-skips-deleted-files \
    test-check-file-format-propagates-checker-failure \
    test-check-file-format-uses-docker-when-forced \
    test-check-file-format-uses-docker-when-the-checker-is-missing \
    test-check-file-format-stops-when-the-image-pull-fails

  return 0
}

# Build the fixture repository once, every test starts from a copy.
function test-suite-setup() {

  quality-build-fixture-base

  return 0
}

# ==============================================================================

function test-check-file-format-rejects-unknown-mode() {

  # Arrange
  local mode
  local -a modes=(bogus ALL ' all')
  quality-create-fixture-repo a.txt
  test-isolate-path
  test-stub "$EC"
  test-stub docker
  cd "$TEST_TMP/repo"
  # Act
  for mode in "${modes[@]}"; do
    test-capture env "check=$mode" ./scripts/quality/check-file-format.sh
    assert-equal 126 "$TEST_STATUS" "$EXIT_STATUS_LABEL for '$mode'"
    assert-equal "Unrecognised check mode: '$mode'. Use check=all, check=staged-changes, check=working-tree-changes, check=branch" "$TEST_STDERR" "stderr for '$mode'"
  done
  # Assert
  assert-stub-not-called "$EC"
  assert-stub-not-called docker

  return 0
}

function test-check-file-format-all-checks-every-tracked-file() {

  # Arrange
  local prefix="-config $TEST_TMP/repo/scripts/config/editorconfig-checker.json -- " calls
  quality-create-fixture-repo a.txt b.txt
  test-isolate-path
  test-stub "$EC"
  cd "$TEST_TMP/repo"
  # Act
  test-capture env check=all ./scripts/quality/check-file-format.sh
  # Assert
  calls="$(test-stub-calls "$EC")"
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal 1 "$(awk 'END { print NR }' <<< "$calls")" "number of checker calls"
  assert-equal "$prefix" "${calls:0:${#prefix}}" "start of the checker call"
  assert-contains "$calls " "$A_TXT_ARGUMENT"
  assert-contains "$calls " " b.txt "

  return 0
}

function test-check-file-format-preserves-unusual-paths-in-native-and-docker() {

  # Arrange
  local newline_file=$'docs/line\nbreak.md' glob_file='docs/a[1]*.md'
  local space_file='docs/space name.md' non_ascii_file='docs/café.md' dash_file='-leading.md'
  quality-create-fixture-repo "$newline_file" "$glob_file" 'docs/a1-other.md' \
    "$space_file" "$non_ascii_file" "$dash_file"
  test-isolate-path
  test-stub "$EC"
  test-stub docker
  cd "$TEST_TMP/repo"
  # Act
  test-capture env check=all ./scripts/quality/check-file-format.sh
  local native_status="$TEST_STATUS"
  test-capture env check=all FORCE_USE_DOCKER=true ./scripts/quality/check-file-format.sh
  # Assert
  assert-equal 0 "$native_status" "native exit status"
  assert-equal 0 "$TEST_STATUS" "Docker exit status"
  local stub file
  for stub in "$EC" docker; do
    for file in "$newline_file" "$glob_file" "$space_file" "$non_ascii_file" "./$dash_file"; do
      assert-contains "$(test-stub-calls "$stub")" "$(printf '%q' "$file")" "$stub call has $file"
    done
  done

  return 0
}

function test-check-file-format-working-tree-changes-checks-modified-files-only() {

  # Arrange
  quality-create-fixture-repo a.txt b.txt
  test-isolate-path
  test-stub "$EC"
  echo changed >> "$TEST_TMP/repo/a.txt"
  cd "$TEST_TMP/repo"
  # Act
  test-capture env check=working-tree-changes ./scripts/quality/check-file-format.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$(test-stub-calls "$EC") " "$A_TXT_ARGUMENT"
  assert-not-contains "$(test-stub-calls "$EC")" "b.txt"

  return 0
}

function test-check-file-format-staged-changes-checks-staged-files-only() {

  # Arrange
  quality-create-fixture-repo a.txt b.txt
  test-isolate-path
  test-stub "$EC"
  echo changed >> "$TEST_TMP/repo/a.txt"
  echo changed >> "$TEST_TMP/repo/b.txt"
  git -C "$TEST_TMP/repo" add b.txt
  cd "$TEST_TMP/repo"
  # Act
  test-capture env check=staged-changes ./scripts/quality/check-file-format.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$(test-stub-calls "$EC") " " b.txt "
  assert-not-contains "$(test-stub-calls "$EC")" "a.txt"

  return 0
}

function test-check-file-format-staged-rename-checks-new-path-once() {

  # Arrange
  quality-create-fixture-repo old.txt
  test-isolate-path
  test-stub "$EC"
  git -C "$TEST_TMP/repo" mv old.txt new.txt
  cd "$TEST_TMP/repo"
  # Act
  test-capture env check=staged-changes ./scripts/quality/check-file-format.sh
  local calls
  calls="$(test-stub-calls "$EC")"
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal 1 "$(awk 'END { print NR }' <<< "$calls")" "number of checker calls"
  assert-contains "$calls " " new.txt "
  assert-not-contains "$calls" "old.txt"

  return 0
}

function test-check-file-format-branch-checks-changes-since-branch() {

  # Arrange
  local default_status default_call other_call
  quality-create-fixture-repo a.txt b.txt
  test-isolate-path
  test-stub "$EC"
  echo changed >> "$TEST_TMP/repo/a.txt"
  git -C "$TEST_TMP/repo" commit -q -am change
  git -C "$TEST_TMP/repo" update-ref refs/heads/other refs/remotes/origin/main
  cd "$TEST_TMP/repo"
  # Act
  test-capture env check=branch ./scripts/quality/check-file-format.sh
  default_status="$TEST_STATUS"
  default_call="$(test-stub-calls "$EC" | sed -n 1p)"
  # Arrange (second run)
  # Without origin/main the second run can only pass by comparing with BRANCH_NAME
  git update-ref -d refs/remotes/origin/main
  # Act (second run)
  test-capture env check=branch BRANCH_NAME=other ./scripts/quality/check-file-format.sh
  other_call="$(test-stub-calls "$EC" | sed -n 2p)"
  # Assert
  assert-equal 0 "$default_status" "exit status with the default branch"
  assert-contains "$default_call " "$A_TXT_ARGUMENT"
  assert-not-contains "$default_call" "b.txt"
  assert-equal 0 "$TEST_STATUS" "exit status with BRANCH_NAME"
  assert-contains "$other_call " "$A_TXT_ARGUMENT"
  assert-not-contains "$other_call" "b.txt"

  return 0
}

function test-check-file-format-fails-when-the-base-branch-is-missing() {

  # Arrange
  quality-create-fixture-repo a.txt
  test-isolate-path
  test-stub "$EC"
  git -C "$TEST_TMP/repo" update-ref -d refs/remotes/origin/main
  cd "$TEST_TMP/repo"
  # Act
  test-capture env check=branch ./scripts/quality/check-file-format.sh
  # Assert
  assert-matches "$TEST_STATUS" '^[1-9][0-9]*$' "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "Branch to compare with not found: origin/main"
  assert-stub-not-called "$EC"

  return 0
}

function test-check-file-format-dry-run-passes-flag() {

  # Arrange
  quality-create-fixture-repo a.txt
  test-isolate-path
  test-stub "$EC"
  test-stub docker
  cd "$TEST_TMP/repo"
  # Act
  test-capture env dry_run=true check=all ./scripts/quality/check-file-format.sh
  local native_status="$TEST_STATUS"
  test-capture env dry_run=true check=all FORCE_USE_DOCKER=true ./scripts/quality/check-file-format.sh
  # Assert
  assert-equal 0 "$native_status" "native exit status"
  assert-equal 0 "$TEST_STATUS" "Docker exit status"
  # The checker reads anything after '--' as a path, so the flag must come first
  assert-contains "$(test-stub-calls "$EC")" "editorconfig-checker.json --dry-run -- a.txt "
  assert-contains "$(test-stub-calls docker)" "editorconfig-checker.json --dry-run -- a.txt "

  return 0
}

function test-check-file-format-skips-empty-selection() {

  # Arrange
  quality-create-fixture-repo a.txt
  test-isolate-path
  test-stub "$EC"
  test-stub docker
  cd "$TEST_TMP/repo"
  # Act
  test-capture ./scripts/quality/check-file-format.sh
  local default_status="$TEST_STATUS" default_output="$TEST_STDOUT"
  test-capture env check= ./scripts/quality/check-file-format.sh
  local empty_status="$TEST_STATUS" empty_output="$TEST_STDOUT"
  test-capture env dry_run=true ./scripts/quality/check-file-format.sh
  local dry_run_status="$TEST_STATUS" dry_run_output="$TEST_STDOUT"
  test-capture env FORCE_USE_DOCKER=true ./scripts/quality/check-file-format.sh
  # Assert
  assert-equal 0 "$default_status" "default exit status"
  assert-equal 0 "$empty_status" "empty check mode exit status"
  assert-equal 0 "$dry_run_status" "dry-run exit status"
  assert-equal 0 "$TEST_STATUS" "Docker exit status"
  assert-contains "$default_output" "No files to check"
  assert-contains "$empty_output" "No files to check"
  assert-contains "$dry_run_output" "No files to check"
  assert-contains "$TEST_STDOUT" "No files to check"
  assert-stub-not-called "$EC"
  assert-stub-not-called docker

  return 0
}

function test-check-file-format-skips-deleted-files() {

  # Arrange
  quality-create-fixture-repo a.txt b.txt
  test-isolate-path
  test-stub "$EC"
  cd "$TEST_TMP/repo"
  rm a.txt
  # Act
  test-capture env check=all ./scripts/quality/check-file-format.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$(test-stub-calls "$EC") " " b.txt "
  assert-not-contains "$(test-stub-calls "$EC")" "a.txt"

  return 0
}

function test-check-file-format-propagates-checker-failure() {

  # Arrange
  quality-create-fixture-repo a.txt
  test-isolate-path
  test-stub "$EC" 'exit 1'
  cd "$TEST_TMP/repo"
  # Act
  test-capture env check=all ./scripts/quality/check-file-format.sh
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"

  return 0
}

function test-check-file-format-uses-docker-when-forced() {

  # Arrange
  quality-create-fixture-repo a.txt
  test-isolate-path
  test-stub "$EC"
  test-stub docker
  cd "$TEST_TMP/repo"
  # Act
  test-capture env FORCE_USE_DOCKER=true check=all ./scripts/quality/check-file-format.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-stub-not-called "$EC"
  assert-stub-called docker "$(expected-docker-run)"
  quality-assert-one-docker-run

  return 0
}

function test-check-file-format-uses-docker-when-the-checker-is-missing() {

  # Arrange
  quality-create-fixture-repo a.txt
  test-isolate-path
  # A leftover pre-v4 'ec' binary must not count as the checker
  test-stub ec
  test-stub docker
  cd "$TEST_TMP/repo"
  # Act
  test-capture env check=all ./scripts/quality/check-file-format.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-stub-not-called ec
  assert-stub-called docker "$(expected-docker-run)"
  quality-assert-one-docker-run

  return 0
}

function test-check-file-format-stops-when-the-image-pull-fails() {

  # Arrange
  quality-create-fixture-repo a.txt
  test-isolate-path
  test-stub "$EC"
  # shellcheck disable=SC2016
  test-stub docker 'if [[ "${1:-} ${2:-}" == "image inspect" ]]; then exit 1; fi; if [[ "${1:-}" == pull ]]; then echo "docker: pull access denied" >&2; exit 23; fi'
  cd "$TEST_TMP/repo"
  # Act
  test-capture env FORCE_USE_DOCKER=true check=all ./scripts/quality/check-file-format.sh
  # Assert
  assert-equal 23 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "docker: pull access denied" "pull error on stderr"
  assert-equal "" "$(test-stub-calls docker | grep '^run ' || true)" "no docker run call"

  return 0
}

# ==============================================================================

# Print the Docker arguments expected when the fixture checks every tracked file.
function expected-docker-run() {

  echo "run --rm --platform linux/amd64 --network none --env GITHUB_ACTIONS --env NO_COLOR --volume $TEST_TMP/repo:/check:ro --workdir /check $EC_IMAGE $EC -config /check/scripts/config/editorconfig-checker.json -- a.txt mise.toml scripts/config/editorconfig-checker.json scripts/docker/docker.lib.sh scripts/quality/check-file-format.sh scripts/quality/git-files.lib.sh"

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
