#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034,SC2317,SC2329

set -euo pipefail

# Test suite for the secret scanning script. Each test runs the script in a
# scratch repository with 'gitleaks' and 'docker' stubbed, so the suite needs
# neither tool nor a Docker daemon.
#
# Usage:
#   $ ./scripts/quality/tests/scan-secrets.test.sh
#
# Arguments (provided as environment variables):
#   VERBOSE=true  # Show all the executed commands, default is 'false'

# ==============================================================================

readonly EXIT_STATUS_LABEL='exit status'

function main() {

  cd "$(git rev-parse --show-toplevel)"
  source ./scripts/tests/test.lib.sh
  source ./scripts/quality/tests/quality-test.lib.sh
  QUALITY_FIXTURE_PATHS=(scripts/quality/scan-secrets.sh scripts/docker/docker.lib.sh scripts/config/gitleaks.toml scripts/config/.gitleaksignore)
  QUALITY_FIXTURE_FORMAT='%s\n'

  # The caller's options must not reach the script under test
  unset -v MISE_TOML match_version check BRANCH_NAME FORCE_USE_DOCKER

  GITLEAKS_IMAGE=ghcr.io/gitleaks/gitleaks:v1.0.0@sha256:1111111111111111111111111111111111111111111111111111111111111111
  # The gitleaks stub also records the git config it runs with
  # shellcheck disable=SC2016
  GITLEAKS_RECORD_ENV='printf "%s\n" "${GIT_CONFIG_GLOBAL:-} ${GIT_CONFIG_SYSTEM:-}" >> "$STUB_DIR/gitleaks.env"'

  test-run-suite \
    test-scan-secrets-defaults-to-whole-history \
    test-scan-secrets-builds-the-command-for-each-mode \
    test-scan-secrets-adds-baseline-and-omits-missing-ignore-file \
    test-scan-secrets-all-runs-three-checks-and-keeps-failure \
    test-scan-secrets-all-keeps-the-status-of-a-failing-first-check \
    test-scan-secrets-all-keeps-the-status-of-a-failing-last-check \
    test-scan-secrets-rejects-unknown-mode \
    test-scan-secrets-propagates-leaks \
    test-scan-secrets-isolates-git-config-natively \
    test-scan-secrets-uses-docker-when-forced \
    test-scan-secrets-uses-docker-with-a-baseline-file

  return 0
}

# ==============================================================================

function test-scan-secrets-defaults-to-whole-history() {

  # Arrange
  local r="$TEST_TMP/repo"
  quality-create-fixture-repo a.txt
  test-isolate-path
  test-stub gitleaks "$GITLEAKS_RECORD_ENV"
  cd "$r"
  # Act
  test-capture ./scripts/quality/scan-secrets.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "detect --source $r --verbose --redact $(gitleaks-tail)" "$(test-stub-calls gitleaks)" "the only gitleaks call"

  return 0
}

function test-scan-secrets-builds-the-command-for-each-mode() {

  # Arrange
  local r="$TEST_TMP/repo" statuses="" expected
  expected="$(
    expected-gitleaks-calls staged-changes working-tree-changes branch
    printf '%s\n' \
      "detect --source $r --verbose --redact --log-opts dev..HEAD $(gitleaks-tail)" \
      "detect --source $r --verbose --redact --log-opts -1 $(gitleaks-tail)"
  )"
  quality-create-fixture-repo a.txt
  test-isolate-path
  test-stub gitleaks "$GITLEAKS_RECORD_ENV"
  cd "$r"
  # Act
  test-capture env check=staged-changes ./scripts/quality/scan-secrets.sh
  statuses="$statuses$TEST_STATUS"
  test-capture env check=working-tree-changes ./scripts/quality/scan-secrets.sh
  statuses="$statuses$TEST_STATUS"
  test-capture env check=branch ./scripts/quality/scan-secrets.sh
  statuses="$statuses$TEST_STATUS"
  test-capture env check=branch BRANCH_NAME=dev ./scripts/quality/scan-secrets.sh
  statuses="$statuses$TEST_STATUS"
  test-capture env check=last-commit ./scripts/quality/scan-secrets.sh
  statuses="$statuses$TEST_STATUS"
  # Assert
  assert-equal 00000 "$statuses" "exit status of each mode"
  assert-equal "$expected" "$(test-stub-calls gitleaks)" "gitleaks calls in mode order"

  return 0
}

function test-scan-secrets-adds-baseline-and-omits-missing-ignore-file() {

  # Arrange
  local r="$TEST_TMP/repo"
  local tail="--baseline-path $r/scripts/config/.gitleaks-baseline.json --config $r/scripts/config/gitleaks.toml"
  quality-create-fixture-repo a.txt
  test-isolate-path
  test-stub gitleaks "$GITLEAKS_RECORD_ENV"
  echo '[]' > "$r/scripts/config/.gitleaks-baseline.json"
  rm "$r/scripts/config/.gitleaksignore"
  cd "$r"
  # Act
  test-capture ./scripts/quality/scan-secrets.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "detect --source $r --verbose --redact $tail" "$(test-stub-calls gitleaks)" "the only gitleaks call"

  return 0
}

function test-scan-secrets-all-runs-three-checks-and-keeps-failure() {

  # Arrange
  local expected
  expected="$(expected-gitleaks-calls staged-changes working-tree-changes branch)"
  quality-create-fixture-repo a.txt
  test-isolate-path
  test-stub gitleaks 'if [[ " $* " == *" --no-git "* ]]; then exit 1; fi'
  cd "$TEST_TMP/repo"
  # Act
  test-capture env check=all ./scripts/quality/scan-secrets.sh
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "$expected" "$(test-stub-calls gitleaks)" "gitleaks calls in order"

  return 0
}

function test-scan-secrets-all-keeps-the-status-of-a-failing-first-check() {

  # Arrange
  local expected
  expected="$(expected-gitleaks-calls staged-changes working-tree-changes branch)"
  quality-create-fixture-repo a.txt
  test-isolate-path
  test-stub gitleaks 'if [[ " $* " == *" --staged "* ]]; then exit 3; fi'
  cd "$TEST_TMP/repo"
  # Act
  test-capture env check=all ./scripts/quality/scan-secrets.sh
  # Assert
  assert-equal 3 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "$expected" "$(test-stub-calls gitleaks)" "gitleaks calls in order"

  return 0
}

function test-scan-secrets-all-keeps-the-status-of-a-failing-last-check() {

  # Arrange
  local expected
  expected="$(expected-gitleaks-calls staged-changes working-tree-changes branch)"
  quality-create-fixture-repo a.txt
  test-isolate-path
  test-stub gitleaks 'if [[ " $* " == *" --log-opts "* ]]; then exit 5; fi'
  cd "$TEST_TMP/repo"
  # Act
  test-capture env check=all ./scripts/quality/scan-secrets.sh
  # Assert
  assert-equal 5 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "$expected" "$(test-stub-calls gitleaks)" "gitleaks calls in order"

  return 0
}

function test-scan-secrets-rejects-unknown-mode() {

  # Arrange
  quality-create-fixture-repo a.txt
  test-isolate-path
  test-stub gitleaks
  test-stub docker
  cd "$TEST_TMP/repo"
  # Act
  test-capture env check=bogus ./scripts/quality/scan-secrets.sh
  # Assert
  assert-equal 126 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "Unrecognised check mode: bogus" "$TEST_STDERR" "stderr"
  assert-stub-not-called gitleaks
  assert-stub-not-called docker

  return 0
}

function test-scan-secrets-propagates-leaks() {

  # Arrange
  quality-create-fixture-repo a.txt
  test-isolate-path
  test-stub gitleaks 'exit 1'
  cd "$TEST_TMP/repo"
  # Act
  test-capture ./scripts/quality/scan-secrets.sh
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"

  return 0
}

function test-scan-secrets-isolates-git-config-natively() {

  # Arrange
  local caller_config="$TEST_TMP/caller.gitconfig"
  quality-create-fixture-repo a.txt
  test-isolate-path
  test-stub gitleaks "$GITLEAKS_RECORD_ENV"
  printf '[log]\n\tdate = relative\n' > "$caller_config"
  cd "$TEST_TMP/repo"
  # Act
  # A caller config, not the harness's /dev/null, shows that the script sets it
  test-capture env GIT_CONFIG_GLOBAL="$caller_config" GIT_CONFIG_SYSTEM="$caller_config" ./scripts/quality/scan-secrets.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "/dev/null /dev/null" "$(cat "$STUB_DIR/gitleaks.env")" "GIT_CONFIG_GLOBAL and GIT_CONFIG_SYSTEM seen by gitleaks"

  return 0
}

function test-scan-secrets-uses-docker-when-forced() {

  # Arrange
  local options="detect --source /workdir --verbose --redact --config /workdir/scripts/config/gitleaks.toml --gitleaks-ignore-path /workdir/scripts/config/.gitleaksignore"
  quality-create-fixture-repo a.txt
  test-isolate-path
  test-stub gitleaks
  test-stub docker
  cd "$TEST_TMP/repo"
  # Act
  test-capture env FORCE_USE_DOCKER=true ./scripts/quality/scan-secrets.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-stub-not-called gitleaks
  assert-stub-called docker \
    "run --rm --platform linux/amd64 --volume $TEST_TMP/repo:/workdir --workdir /workdir $GITLEAKS_IMAGE $options"
  quality-assert-one-docker-run

  return 0
}

function test-scan-secrets-uses-docker-with-a-baseline-file() {

  # Arrange
  local options="detect --source /workdir --verbose --redact --baseline-path /workdir/scripts/config/.gitleaks-baseline.json --config /workdir/scripts/config/gitleaks.toml --gitleaks-ignore-path /workdir/scripts/config/.gitleaksignore"
  quality-create-fixture-repo a.txt
  test-isolate-path
  test-stub gitleaks
  test-stub docker
  echo '[]' > "$TEST_TMP/repo/scripts/config/.gitleaks-baseline.json"
  cd "$TEST_TMP/repo"
  # Act
  test-capture env FORCE_USE_DOCKER=true ./scripts/quality/scan-secrets.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-stub-not-called gitleaks
  assert-stub-called docker \
    "run --rm --platform linux/amd64 --volume $TEST_TMP/repo:/workdir --workdir /workdir $GITLEAKS_IMAGE $options"
  quality-assert-one-docker-run

  return 0
}

# ==============================================================================

# Print the options every native gitleaks call ends with in "$TEST_TMP/repo",
# when the ignore file exists and no baseline file does.
function gitleaks-tail() {

  local r="$TEST_TMP/repo"
  echo "--config $r/scripts/config/gitleaks.toml --gitleaks-ignore-path $r/scripts/config/.gitleaksignore"

  return 0
}

# Print the expected native gitleaks call in "$TEST_TMP/repo" for each given
# check mode, one per line.
# Arguments:
#   $@=[check modes, each 'staged-changes', 'working-tree-changes' or 'branch']
function expected-gitleaks-calls() {

  local r="$TEST_TMP/repo" mode
  for mode in "$@"; do
    case "$mode" in
      staged-changes) echo "protect --source $r --verbose --redact --staged $(gitleaks-tail)" ;;
      working-tree-changes) echo "detect --no-git --source $r --verbose --redact $(gitleaks-tail)" ;;
      branch) echo "detect --source $r --verbose --redact --log-opts origin/main..HEAD $(gitleaks-tail)" ;;
      *)
        echo "expected-gitleaks-calls: unknown check mode '$mode'" >&2
        return 1
        ;;
    esac
  done

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
