#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034,SC2317,SC2329

set -euo pipefail

# Test suite for the EditorConfig check script. Each test runs the script in a
# scratch repository with 'ec' and 'docker' stubbed, so the suite needs neither
# tool nor a Docker daemon.
#
# Usage:
#   $ ./scripts/quality/tests/check-file-format.test.sh
#
# Arguments (provided as environment variables):
#   VERBOSE=true  # Show all the executed commands, default is 'false'

# ==============================================================================

readonly A_TXT_ARGUMENT=' a.txt '
readonly EXIT_STATUS_LABEL='exit status'

function main() {

  cd "$(git rev-parse --show-toplevel)"
  source ./scripts/tests/test.lib.sh
  source ./scripts/quality/tests/quality-test.lib.sh
  QUALITY_FIXTURE_PATHS=(scripts/quality/check-file-format.sh scripts/docker/docker.lib.sh scripts/config/editorconfig-checker.json)
  QUALITY_FIXTURE_FORMAT='%s\n'

  # The caller's options must not reach the script under test
  unset -v MISE_TOML match_version check dry_run dry_run_opt filter BRANCH_NAME FORCE_USE_DOCKER

  EC_IMAGE=mstruebing/editorconfig-checker:v6.0.0@sha256:6666666666666666666666666666666666666666666666666666666666666666
  # The sh -c argument as recorded with %q, the double space comes from the empty dry_run_opt
  IFS= read -r EC_DOCKER_COMMAND << 'EOF'
ec\ -config\ /check/scripts/config/editorconfig-checker.json\ --exclude\ \'.git/\'\ \ \$\(git\ ls-files\)\ /dev/null
EOF

  test-run-suite \
    test-check-file-format-rejects-unknown-mode \
    test-check-file-format-all-checks-every-tracked-file \
    test-check-file-format-working-tree-changes-checks-modified-files-only \
    test-check-file-format-staged-changes-checks-staged-files-only \
    test-check-file-format-branch-checks-changes-since-branch \
    test-check-file-format-fails-when-the-base-branch-is-missing \
    test-check-file-format-dry-run-passes-flag \
    test-check-file-format-native-with-no-changes-checks-nothing \
    test-check-file-format-propagates-ec-failure \
    test-check-file-format-uses-docker-when-forced \
    test-check-file-format-uses-docker-when-ec-is-missing \
    test-check-file-format-stops-when-the-image-pull-fails

  return 0
}

# ==============================================================================

function test-check-file-format-rejects-unknown-mode() {

  # Arrange
  quality-create-fixture-repo a.txt
  test-isolate-path
  test-stub ec
  test-stub docker
  cd "$TEST_TMP/repo"
  # Act
  test-capture env check=bogus ./scripts/quality/check-file-format.sh
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "Unrecognised check mode: bogus"
  assert-stub-not-called ec
  assert-stub-not-called docker

  return 0
}

function test-check-file-format-all-checks-every-tracked-file() {

  # Arrange
  local prefix="-config $TEST_TMP/repo/scripts/config/editorconfig-checker.json --exclude .git/ " calls
  quality-create-fixture-repo a.txt b.txt
  test-isolate-path
  test-stub ec
  cd "$TEST_TMP/repo"
  # Act
  test-capture env check=all ./scripts/quality/check-file-format.sh
  # Assert
  calls="$(test-stub-calls ec)"
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal 1 "$(awk 'END { print NR }' <<< "$calls")" "number of ec calls"
  assert-equal "$prefix" "${calls:0:${#prefix}}" "start of the ec call"
  assert-contains "$calls " "$A_TXT_ARGUMENT"
  assert-contains "$calls " " b.txt "

  return 0
}

function test-check-file-format-working-tree-changes-checks-modified-files-only() {

  # Arrange
  quality-create-fixture-repo a.txt b.txt
  test-isolate-path
  test-stub ec
  echo changed >> "$TEST_TMP/repo/a.txt"
  cd "$TEST_TMP/repo"
  # Act
  test-capture env check=working-tree-changes ./scripts/quality/check-file-format.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$(test-stub-calls ec) " "$A_TXT_ARGUMENT"
  assert-not-contains "$(test-stub-calls ec)" "b.txt"

  return 0
}

function test-check-file-format-staged-changes-checks-staged-files-only() {

  # Arrange
  quality-create-fixture-repo a.txt b.txt
  test-isolate-path
  test-stub ec
  echo changed >> "$TEST_TMP/repo/a.txt"
  echo changed >> "$TEST_TMP/repo/b.txt"
  git -C "$TEST_TMP/repo" add b.txt
  cd "$TEST_TMP/repo"
  # Act
  test-capture env check=staged-changes ./scripts/quality/check-file-format.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$(test-stub-calls ec) " " b.txt "
  assert-not-contains "$(test-stub-calls ec)" "a.txt"

  return 0
}

function test-check-file-format-branch-checks-changes-since-branch() {

  # Arrange
  local default_status default_call other_call
  quality-create-fixture-repo a.txt b.txt
  test-isolate-path
  test-stub ec
  echo changed >> "$TEST_TMP/repo/a.txt"
  git -C "$TEST_TMP/repo" commit -q -am change
  git -C "$TEST_TMP/repo" update-ref refs/heads/other refs/remotes/origin/main
  cd "$TEST_TMP/repo"
  # Act
  test-capture env check=branch ./scripts/quality/check-file-format.sh
  default_status="$TEST_STATUS"
  default_call="$(test-stub-calls ec | sed -n 1p)"
  # Arrange (second run)
  # Without origin/main the second run can only pass by comparing with BRANCH_NAME
  git update-ref -d refs/remotes/origin/main
  # Act (second run)
  test-capture env check=branch BRANCH_NAME=other ./scripts/quality/check-file-format.sh
  other_call="$(test-stub-calls ec | sed -n 2p)"
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
  test-stub ec
  git -C "$TEST_TMP/repo" update-ref -d refs/remotes/origin/main
  cd "$TEST_TMP/repo"
  # Act
  test-capture env check=branch ./scripts/quality/check-file-format.sh
  # Assert
  assert-matches "$TEST_STATUS" '^[1-9][0-9]*$' "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "fatal: ambiguous argument 'origin/main': unknown revision"
  assert-stub-not-called ec

  return 0
}

function test-check-file-format-dry-run-passes-flag() {

  # Arrange
  quality-create-fixture-repo a.txt
  test-isolate-path
  test-stub ec
  cd "$TEST_TMP/repo"
  # Act
  test-capture env dry_run=true check=all ./scripts/quality/check-file-format.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$(test-stub-calls ec) " " --dry-run "

  return 0
}

function test-check-file-format-native-with-no-changes-checks-nothing() {

  # Arrange
  quality-create-fixture-repo a.txt
  test-isolate-path
  test-stub ec
  cd "$TEST_TMP/repo"
  # Act
  test-capture ./scripts/quality/check-file-format.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "-config $TEST_TMP/repo/scripts/config/editorconfig-checker.json --exclude .git/ /dev/null" \
    "$(test-stub-calls ec)" "the only ec call"

  return 0
}

function test-check-file-format-propagates-ec-failure() {

  # Arrange
  quality-create-fixture-repo a.txt
  test-isolate-path
  test-stub ec 'exit 1'
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
  test-stub ec
  test-stub docker
  cd "$TEST_TMP/repo"
  # Act
  test-capture env FORCE_USE_DOCKER=true check=all ./scripts/quality/check-file-format.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-stub-not-called ec
  assert-stub-called docker \
    "run --rm --platform linux/amd64 --volume $TEST_TMP/repo:/check $EC_IMAGE sh -c $EC_DOCKER_COMMAND"
  quality-assert-one-docker-run

  return 0
}

function test-check-file-format-uses-docker-when-ec-is-missing() {

  # Arrange
  quality-create-fixture-repo a.txt
  test-isolate-path
  test-stub docker
  cd "$TEST_TMP/repo"
  # Act
  test-capture env check=all ./scripts/quality/check-file-format.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-stub-called docker \
    "run --rm --platform linux/amd64 --volume $TEST_TMP/repo:/check $EC_IMAGE sh -c $EC_DOCKER_COMMAND"
  quality-assert-one-docker-run

  return 0
}

function test-check-file-format-stops-when-the-image-pull-fails() {

  # Arrange
  quality-create-fixture-repo a.txt
  test-isolate-path
  test-stub ec
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
