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
# Options:
#   VERBOSE=true  # Show all the executed commands, default is 'false'

# ==============================================================================

readonly EXIT_STATUS_LABEL='exit status'
# A space, a glob character and a non-ASCII character in one path
readonly AWKWARD_REPO='dir with space [x] café/repo'

# Set up the suite fixtures and run every test.
function main() {

  cd "$(git rev-parse --show-toplevel)"
  source ./scripts/tests/test.lib.sh
  source ./scripts/quality/tests/quality-test.lib.sh
  QUALITY_FIXTURE_PATHS=(scripts/quality/scan-secrets.sh scripts/quality/git-base.lib.sh scripts/docker/docker.lib.sh scripts/config/gitleaks.toml scripts/config/.gitleaksignore)
  QUALITY_FIXTURE_FORMAT='%s\n'

  # The caller's options must not reach the script under test
  unset -v MISE_TOML match_version check BRANCH_NAME GITHUB_BASE_REF QUALITY_PR_BASE FORCE_USE_DOCKER

  GITLEAKS_IMAGE=ghcr.io/gitleaks/gitleaks:v1.0.0@sha256:1111111111111111111111111111111111111111111111111111111111111111
  # The gitleaks stub also records the git config it runs with
  # shellcheck disable=SC2016
  GITLEAKS_RECORD_ENV='printf "%s\n" "${GIT_CONFIG_GLOBAL:-} ${GIT_CONFIG_SYSTEM:-}" >> "$STUB_DIR/gitleaks.env"'

  test-run-suite \
    test-scan-secrets-defaults-to-whole-history \
    test-scan-secrets-builds-the-command-for-each-mode \
    test-scan-secrets-adds-baseline-and-omits-missing-ignore-file \
    test-scan-secrets-adds-baseline-at-an-awkward-path \
    test-scan-secrets-all-runs-three-checks-and-keeps-failure \
    test-scan-secrets-all-keeps-the-status-of-a-failing-first-check \
    test-scan-secrets-all-keeps-the-status-of-a-failing-last-check \
    test-scan-secrets-all-fails-when-branch-base-is-missing \
    test-scan-secrets-rejects-unknown-mode \
    test-scan-secrets-empty-mode-defaults-to-whole-history \
    test-scan-secrets-propagates-leaks \
    test-scan-secrets-isolates-git-config-natively \
    test-scan-secrets-uses-docker-when-forced \
    test-scan-secrets-uses-docker-at-an-awkward-path \
    test-scan-secrets-uses-docker-with-a-baseline-file \
    test-scan-secrets-stops-when-the-image-pull-fails

  return 0
}

# Build the fixture repository once, every test starts from a copy.
function test-suite-setup() {

  quality-build-fixture-base

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
  assert-equal "$(expected-gitleaks-call "$r" whole-history)" "$(test-stub-calls gitleaks)" "the only gitleaks call"

  return 0
}

function test-scan-secrets-builds-the-command-for-each-mode() {

  # Arrange
  local r="$TEST_TMP/$AWKWARD_REPO" statuses="" expected
  expected="$(
    expected-gitleaks-call "$r" staged-changes
    expected-gitleaks-call "$r" working-tree-changes
    expected-gitleaks-call "$r" branch origin/main..HEAD
    expected-gitleaks-call "$r" branch dev..HEAD
    expected-gitleaks-call "$r" branch origin/v2..HEAD
    expected-gitleaks-call "$r" last-commit
  )"
  create-awkward-fixture-repo a.txt
  test-isolate-path
  test-stub gitleaks "$GITLEAKS_RECORD_ENV"
  git -C "$r" update-ref refs/heads/dev refs/remotes/origin/main
  git -C "$r" update-ref refs/remotes/origin/v2 refs/remotes/origin/main
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
  test-capture env check=branch GITHUB_BASE_REF=v2 BRANCH_NAME=origin/main ./scripts/quality/scan-secrets.sh
  statuses="$statuses$TEST_STATUS"
  test-capture env check=last-commit ./scripts/quality/scan-secrets.sh
  statuses="$statuses$TEST_STATUS"
  # Assert
  assert-equal 000000 "$statuses" "exit status of each mode"
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

function test-scan-secrets-adds-baseline-at-an-awkward-path() {

  # Arrange
  local r="$TEST_TMP/$AWKWARD_REPO" expected
  create-awkward-fixture-repo a.txt
  printf '[]\n' > "$r/scripts/config/.gitleaks-baseline.json"
  test-isolate-path
  test-stub gitleaks "$GITLEAKS_RECORD_ENV"
  expected="$(quoted-call-line detect --source "$r" --verbose --redact --log-opts -1 \
    --baseline-path "$r/scripts/config/.gitleaks-baseline.json" \
    --config "$r/scripts/config/gitleaks.toml" \
    --gitleaks-ignore-path "$r/scripts/config/.gitleaksignore")"
  cd "$r"
  # Act
  test-capture env check=last-commit ./scripts/quality/scan-secrets.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "$expected" "$(test-stub-calls gitleaks)" "Gitleaks arguments with a baseline"

  return 0
}

function test-scan-secrets-all-runs-three-checks-and-keeps-failure() {

  # Arrange
  local expected
  expected="$(expected-gitleaks-calls "$TEST_TMP/repo" staged-changes working-tree-changes branch)"
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
  expected="$(expected-gitleaks-calls "$TEST_TMP/repo" staged-changes working-tree-changes branch)"
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
  expected="$(expected-gitleaks-calls "$TEST_TMP/repo" staged-changes working-tree-changes branch)"
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

function test-scan-secrets-all-fails-when-branch-base-is-missing() {

  # Arrange
  local r="$TEST_TMP/repo" calls
  quality-create-fixture-repo a.txt
  test-isolate-path
  test-stub gitleaks "$GITLEAKS_RECORD_ENV"
  git -C "$r" update-ref -d refs/remotes/origin/main
  cd "$r"
  # Act
  test-capture env check=all ./scripts/quality/scan-secrets.sh
  calls="$(test-stub-calls gitleaks)"
  # Assert
  assert-matches "$TEST_STATUS" '^[1-9][0-9]*$' "$EXIT_STATUS_LABEL"
  assert-equal 2 "$(printf '%s\n' "$calls" | awk 'NF { n++ } END { print n + 0 }')" "Gitleaks calls before branch-base failure"
  assert-contains "$TEST_STDERR" 'Branch to compare with not found: origin/main'

  return 0
}

function test-scan-secrets-rejects-unknown-mode() {

  # Arrange
  local mode
  local -a modes=(bogus ALL ' all')
  quality-create-fixture-repo a.txt
  test-isolate-path
  test-stub gitleaks
  test-stub docker
  cd "$TEST_TMP/repo"
  # Act
  for mode in "${modes[@]}"; do
    test-capture env "check=$mode" ./scripts/quality/scan-secrets.sh
    assert-equal 126 "$TEST_STATUS" "$EXIT_STATUS_LABEL for '$mode'"
    assert-equal "Unrecognised check mode: '$mode'. Use check=all, check=staged-changes, check=working-tree-changes, check=branch, check=whole-history, check=last-commit" "$TEST_STDERR" "stderr for '$mode'"
  done
  # Assert
  assert-stub-not-called gitleaks
  assert-stub-not-called docker

  return 0
}

function test-scan-secrets-empty-mode-defaults-to-whole-history() {

  # Arrange
  local r="$TEST_TMP/repo"
  quality-create-fixture-repo a.txt
  test-isolate-path
  test-stub gitleaks "$GITLEAKS_RECORD_ENV"
  cd "$r"
  # Act
  test-capture env check= ./scripts/quality/scan-secrets.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "$(expected-gitleaks-call "$r" whole-history)" "$(test-stub-calls gitleaks)" "gitleaks call for empty check mode"

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
    "run --rm --platform linux/amd64 --network none --volume $TEST_TMP/repo:/workdir:ro --workdir /workdir $GITLEAKS_IMAGE $options"
  quality-assert-one-docker-run

  return 0
}

function test-scan-secrets-uses-docker-at-an-awkward-path() {

  # Arrange
  local r="$TEST_TMP/$AWKWARD_REPO" expected
  create-awkward-fixture-repo a.txt
  test-isolate-path
  test-stub gitleaks
  test-stub docker
  expected="$(quoted-call-line run --rm --platform linux/amd64 --network none \
    --volume "$r:/workdir:ro" --workdir /workdir "$GITLEAKS_IMAGE")"
  expected="$expected $(expected-gitleaks-call /workdir branch)"
  cd "$r"
  # Act
  test-capture env FORCE_USE_DOCKER=true check=branch BRANCH_NAME=origin/main ./scripts/quality/scan-secrets.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-stub-called docker "$expected"
  quality-assert-one-docker-run

  return 0
}

function test-scan-secrets-stops-when-the-image-pull-fails() {

  # Arrange
  quality-create-fixture-repo a.txt
  test-isolate-path
  test-stub gitleaks
  # shellcheck disable=SC2016
  test-stub docker 'if [[ "${1:-} ${2:-}" == "image inspect" ]]; then exit 1; fi; if [[ "${1:-}" == pull ]]; then echo "docker: pull access denied" >&2; exit 23; fi'
  cd "$TEST_TMP/repo"
  # Act
  test-capture env FORCE_USE_DOCKER=true ./scripts/quality/scan-secrets.sh
  # Assert
  assert-equal 23 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "docker: pull access denied" "pull error on stderr"
  assert-equal "" "$(test-stub-calls docker | grep '^run ' || true)" "no docker run call"

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
    "run --rm --platform linux/amd64 --network none --volume $TEST_TMP/repo:/workdir:ro --workdir /workdir $GITLEAKS_IMAGE $options"
  quality-assert-one-docker-run

  return 0
}

# ==============================================================================

# Create a fixture repository at "$TEST_TMP/$AWKWARD_REPO".
# Arguments:
#   $@=[content files, as quality-create-fixture-repo accepts]
function create-awkward-fixture-repo() {

  local target="$TEST_TMP/$AWKWARD_REPO"
  quality-create-fixture-repo "$@" || return "$?"
  test-mkdir-parent "$target" || return "$?"
  mv "$TEST_TMP/repo" "$target" || return "$?"

  return 0
}

# Print the arguments as one line, quoted the way the stub records a call.
# Arguments:
#   $@=[call arguments]
function quoted-call-line() {

  local line
  printf -v line '%q ' "$@"
  printf '%s\n' "${line% }"

  return 0
}

# Print the expected native gitleaks call for each given check mode, one per
# line.
# Arguments:
#   $1=[project's top-level directory]
#   $@=[check modes, as expected-gitleaks-call accepts]
function expected-gitleaks-calls() {

  local r="$1" mode
  shift
  for mode in "$@"; do
    expected-gitleaks-call "$r" "$mode" || return "$?"
  done

  return 0
}

# Print the quoted arguments expected for one Gitleaks check.
# Arguments:
#   $1=[project's top-level directory]
#   $2=[check mode]
#   $3=[log range for branch mode, default is 'origin/main..HEAD']
function expected-gitleaks-call() {

  local r="$1" mode="$2" range="${3:-origin/main..HEAD}"
  local -a args=()
  case "$mode" in
    staged-changes) args=(protect --source "$r" --verbose --redact --staged) ;;
    working-tree-changes) args=(detect --no-git --source "$r" --verbose --redact) ;;
    branch) args=(detect --source "$r" --verbose --redact --log-opts "$range") ;;
    whole-history) args=(detect --source "$r" --verbose --redact) ;;
    last-commit) args=(detect --source "$r" --verbose --redact --log-opts -1) ;;
    *)
      echo "expected-gitleaks-call: unknown check mode '$mode'" >&2
      return 1
      ;;
  esac
  args+=(--config "$r/scripts/config/gitleaks.toml")
  args+=(--gitleaks-ignore-path "$r/scripts/config/.gitleaksignore")
  quoted-call-line "${args[@]}" || return "$?"

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
