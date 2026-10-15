#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034,SC2317,SC2329

set -euo pipefail

# Test suite for the ShellCheck wrapper script. Tests use scratch repositories,
# real Git for file-listing and conflict-index cases, and GNU Make for target
# cases. GNU Make and Git are required. ShellCheck and Docker calls are
# stubbed, so no ShellCheck binary or Docker daemon is needed.
#
# Usage:
#   $ ./scripts/quality/tests/check-shell-lint.test.sh
#
# Arguments (provided as environment variables):
#   VERBOSE=true  # Show all the executed commands, default is 'false'

# ==============================================================================

readonly EXIT_STATUS_LABEL='exit status'
readonly ONLY_SHELLCHECK_CALL_LABEL='the only shellcheck call'

function main() {

  cd "$(git rev-parse --show-toplevel)"
  source ./scripts/tests/test.lib.sh
  source ./scripts/quality/tests/quality-test.lib.sh
  QUALITY_FIXTURE_PATHS=(scripts/quality/check-shell-lint.sh scripts/docker/docker.lib.sh)
  QUALITY_FIXTURE_FORMAT='# %s\n'

  # The caller's options must not reach the script under test
  unset -v MISE_TOML check match_version file FORCE_USE_DOCKER CONTAINER_CLI GNUMAKEFLAGS MAKEFILES

  SHELLCHECK_IMAGE=koalaman/shellcheck:v4.0.0@sha256:4444444444444444444444444444444444444444444444444444444444444444

  test-run-suite \
    test-check-shell-lint-defaults-to-itself \
    test-check-shell-lint-makes-an-absolute-path-relative \
    test-check-shell-lint-propagates-shellcheck-failure \
    test-check-shell-lint-uses-docker-when-forced \
    test-check-shell-lint-uses-docker-when-shellcheck-is-missing \
    test-check-shell-lint-stops-when-the-image-pull-fails \
    test-check-shell-lint-all-passes-awkward-names-intact \
    test-check-shell-lint-all-skips-deleted-and-untracked-files \
    test-check-shell-lint-all-fails-when-git-ls-files-fails \
    test-check-shell-lint-all-deduplicates-tracked-paths \
    test-check-shell-lint-all-without-scripts-does-not-call-shellcheck \
    test-check-shell-lint-all-propagates-shellcheck-failure-status-1 \
    test-check-shell-lint-all-propagates-shellcheck-failure-status-2 \
    test-check-shell-lint-all-ignores-hostile-git-pathspec-env \
    test-check-shell-lint-all-uses-one-docker-run-when-forced \
    test-check-shell-lint-all-uses-one-docker-run-with-awkward-names-when-forced \
    test-check-shell-lint-all-uses-docker-when-shellcheck-is-missing \
    test-check-shell-lint-all-stops-when-the-image-pull-fails \
    test-check-shell-lint-all-propagates-docker-failure-status \
    test-check-shell-lint-docker-target-ignores-exported-mode \
    test-check-shell-lint-make-target-reports-success \
    test-check-shell-lint-make-target-uses-docker \
    test-check-shell-lint-make-target-fails-without-success-message \
    test-check-shell-lint-rejects-unknown-mode

  return 0
}

# Create a scratch repository with the Make modules used by target tests.
function check-shell-lint-create-make-fixture-repo() {

  quality-create-fixture-repo scripts/x.sh
  printf 'include scripts/init.mk\n' > "$TEST_TMP/repo/Makefile"
  cp "$TEST_REPO_ROOT/scripts/init.mk" "$TEST_TMP/repo/scripts/init.mk"
  cp "$TEST_REPO_ROOT/scripts/docker/docker.mk" "$TEST_TMP/repo/scripts/docker/docker.mk"
  git -C "$TEST_TMP/repo" add Makefile scripts/init.mk scripts/docker/docker.mk
  git -C "$TEST_TMP/repo" commit -q -m 'add make lint fixtures'

  return 0
}

# ==============================================================================

function test-check-shell-lint-defaults-to-itself() {

  # Arrange
  quality-create-fixture-repo scripts/x.sh
  test-isolate-path
  test-stub shellcheck
  cd "$TEST_TMP/repo"
  # Act
  test-capture ./scripts/quality/check-shell-lint.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "WARNING: 'file' variable not set, defaulting to itself" "$TEST_STDOUT" "stdout"
  assert-equal "scripts/quality/check-shell-lint.sh" "$(test-stub-calls shellcheck)" "$ONLY_SHELLCHECK_CALL_LABEL"

  return 0
}

function test-check-shell-lint-makes-an-absolute-path-relative() {

  # Arrange
  quality-create-fixture-repo scripts/x.sh
  test-isolate-path
  test-stub shellcheck
  cd "$TEST_TMP/repo"
  # Act
  test-capture env file="$TEST_TMP/repo/scripts/x.sh" ./scripts/quality/check-shell-lint.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "./scripts/x.sh" "$(test-stub-calls shellcheck)" "$ONLY_SHELLCHECK_CALL_LABEL"

  return 0
}

function test-check-shell-lint-propagates-shellcheck-failure() {

  # Arrange
  quality-create-fixture-repo scripts/x.sh
  test-isolate-path
  test-stub shellcheck 'exit 1'
  cd "$TEST_TMP/repo"
  # Act
  test-capture env file=scripts/x.sh ./scripts/quality/check-shell-lint.sh
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"

  return 0
}

function test-check-shell-lint-uses-docker-when-forced() {

  # Arrange
  quality-create-fixture-repo scripts/x.sh
  test-isolate-path
  test-stub shellcheck
  test-stub docker
  cd "$TEST_TMP/repo"
  # Act
  test-capture env FORCE_USE_DOCKER=true file=scripts/x.sh ./scripts/quality/check-shell-lint.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-stub-not-called shellcheck
  assert-stub-called docker \
    "run --rm --platform linux/amd64 --volume $TEST_TMP/repo:/workdir --workdir /workdir $SHELLCHECK_IMAGE /workdir/scripts/x.sh"
  quality-assert-one-docker-run

  return 0
}

function test-check-shell-lint-uses-docker-when-shellcheck-is-missing() {

  # Arrange
  quality-create-fixture-repo scripts/x.sh
  test-isolate-path
  test-stub docker
  cd "$TEST_TMP/repo"
  # Act
  test-capture env file=scripts/x.sh ./scripts/quality/check-shell-lint.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-stub-called docker \
    "run --rm --platform linux/amd64 --volume $TEST_TMP/repo:/workdir --workdir /workdir $SHELLCHECK_IMAGE /workdir/scripts/x.sh"
  quality-assert-one-docker-run

  return 0
}

function test-check-shell-lint-stops-when-the-image-pull-fails() {

  # Arrange
  quality-create-fixture-repo scripts/x.sh
  test-isolate-path
  test-stub shellcheck
  # shellcheck disable=SC2016
  test-stub docker 'if [[ "${1:-} ${2:-}" == "image inspect" ]]; then exit 1; fi; if [[ "${1:-}" == pull ]]; then echo "docker: pull access denied" >&2; exit 23; fi'
  cd "$TEST_TMP/repo"
  # Act
  test-capture env FORCE_USE_DOCKER=true file=scripts/x.sh ./scripts/quality/check-shell-lint.sh
  # Assert
  assert-equal 23 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "docker: pull access denied" "pull error on stderr"
  assert-equal "" "$(test-stub-calls docker | grep '^run ' || true)" "no docker run call"
  assert-stub-not-called shellcheck

  return 0
}

function test-check-shell-lint-all-passes-awkward-names-intact() {

  # Arrange
  quality-create-fixture-repo \
    "./-dash.sh" \
    "scripts/café.sh" \
    $'scripts/new\nline.sh' \
    "scripts/notes[draft].sh" \
    scripts/notesd.sh \
    "scripts/space name.sh"
  test-isolate-path
  test-stub shellcheck
  cd "$TEST_TMP/repo"
  # Act
  test-capture env check=all file=scripts/space\ name.sh ./scripts/quality/check-shell-lint.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  local -a expected_shellcheck_call=(
    --
    -dash.sh
    scripts/café.sh
    scripts/docker/docker.lib.sh
    $'scripts/new\nline.sh'
    "scripts/notes[draft].sh"
    scripts/notesd.sh
    scripts/quality/check-shell-lint.sh
    "scripts/space name.sh"
  )
  local expected_shellcheck_call_line
  expected_shellcheck_call_line="$(printf '%q ' "${expected_shellcheck_call[@]}")"
  expected_shellcheck_call_line="${expected_shellcheck_call_line% }"
  assert-equal "$expected_shellcheck_call_line" "$(test-stub-calls shellcheck)" "$ONLY_SHELLCHECK_CALL_LABEL"

  return 0
}

function test-check-shell-lint-all-skips-deleted-and-untracked-files() {

  # Arrange
  quality-create-fixture-repo scripts/keep.sh a-deleted.sh zz-deleted.sh
  test-isolate-path
  test-stub shellcheck
  cd "$TEST_TMP/repo"
  rm a-deleted.sh zz-deleted.sh
  printf 'scripts/ignored.sh\n' > .gitignore
  printf '# ignored\n' > scripts/ignored.sh
  printf '# untracked\n' > scripts/untracked.sh
  # Act
  test-capture env check=all ./scripts/quality/check-shell-lint.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  local -a expected_shellcheck_call=(
    --
    scripts/docker/docker.lib.sh
    scripts/keep.sh
    scripts/quality/check-shell-lint.sh
  )
  local expected_shellcheck_call_line
  expected_shellcheck_call_line="$(printf '%q ' "${expected_shellcheck_call[@]}")"
  expected_shellcheck_call_line="${expected_shellcheck_call_line% }"
  assert-equal "$expected_shellcheck_call_line" "$(test-stub-calls shellcheck)" "$ONLY_SHELLCHECK_CALL_LABEL"

  return 0
}

function test-check-shell-lint-all-fails-when-git-ls-files-fails() {

  # Arrange
  quality-create-fixture-repo scripts/keep.sh
  test-isolate-path
  test-stub shellcheck
  test-stub docker
  # shellcheck disable=SC2016
  test-stub git 'if [[ "${1:-} ${2:-}" == "rev-parse --show-toplevel" ]]; then printf "%s\n" "$TEST_TMP/repo"; elif [[ "${1:-} ${2:-} ${3:-} ${4:-}" == "ls-files -z -- *.sh" ]]; then echo "git: ls-files failed" >&2; exit 23; else echo "unexpected git call: $*" >&2; exit 1; fi'
  cd "$TEST_TMP/repo"
  # Act
  test-capture env check=all ./scripts/quality/check-shell-lint.sh
  # Assert
  assert-equal 23 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "git: ls-files failed" "git failure on stderr"
  assert-stub-not-called shellcheck
  assert-stub-not-called docker

  return 0
}

function test-check-shell-lint-all-deduplicates-tracked-paths() {

  # Arrange
  quality-create-fixture-repo scripts/keep.sh
  test-isolate-path
  test-stub shellcheck
  local base_blob ours_blob theirs_blob null_oid
  base_blob="$(printf 'base\n' | git -C "$TEST_TMP/repo" hash-object -w --stdin)"
  ours_blob="$(printf 'ours\n' | git -C "$TEST_TMP/repo" hash-object -w --stdin)"
  theirs_blob="$(printf 'theirs\n' | git -C "$TEST_TMP/repo" hash-object -w --stdin)"
  null_oid="$(git -C "$TEST_TMP/repo" hash-object --stdin < /dev/null | sed 's/./0/g')"
  printf '0 %s\tscripts/keep.sh\n100644 %s 1\tscripts/keep.sh\n100644 %s 2\tscripts/keep.sh\n100644 %s 3\tscripts/keep.sh\n' \
    "$null_oid" "$base_blob" "$ours_blob" "$theirs_blob" |
    git -C "$TEST_TMP/repo" update-index --index-info
  assert-equal 3 "$(git -C "$TEST_TMP/repo" ls-files -u -- scripts/keep.sh | awk 'END { print NR }')" \
    "conflicted path has all three index stages"
  cd "$TEST_TMP/repo"
  # Act
  test-capture env check=all ./scripts/quality/check-shell-lint.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "-- scripts/docker/docker.lib.sh scripts/keep.sh scripts/quality/check-shell-lint.sh" \
    "$(test-stub-calls shellcheck)" "each tracked path is linted once"

  return 0
}

function test-check-shell-lint-all-without-scripts-does-not-call-shellcheck() {

  # Arrange
  quality-create-fixture-repo scripts/keep.sh
  test-isolate-path
  test-stub shellcheck
  test-stub docker
  # shellcheck disable=SC2016
  test-stub git 'if [[ "${1:-} ${2:-}" == "rev-parse --show-toplevel" ]]; then printf "%s\n" "$TEST_TMP/repo"; elif [[ "${1:-} ${2:-} ${3:-} ${4:-}" == "ls-files -z -- *.sh" ]]; then :; else echo "unexpected git call: $*" >&2; exit 1; fi'
  cd "$TEST_TMP/repo"
  # Act
  test-capture env check=all ./scripts/quality/check-shell-lint.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-stub-not-called shellcheck
  assert-stub-not-called docker

  return 0
}

function test-check-shell-lint-all-propagates-shellcheck-failure-status-1() {

  # Arrange
  quality-create-fixture-repo scripts/keep.sh scripts/upper.SH
  test-isolate-path
  test-stub shellcheck 'exit 1'
  cd "$TEST_TMP/repo"
  # Act
  test-capture env check=all ./scripts/quality/check-shell-lint.sh
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  local -a expected_shellcheck_call=(
    --
    scripts/docker/docker.lib.sh
    scripts/keep.sh
    scripts/quality/check-shell-lint.sh
  )
  local expected_shellcheck_call_line
  expected_shellcheck_call_line="$(printf '%q ' "${expected_shellcheck_call[@]}")"
  expected_shellcheck_call_line="${expected_shellcheck_call_line% }"
  assert-equal "$expected_shellcheck_call_line" "$(test-stub-calls shellcheck)" "$ONLY_SHELLCHECK_CALL_LABEL"

  return 0
}

function test-check-shell-lint-all-propagates-shellcheck-failure-status-2() {

  # Arrange
  quality-create-fixture-repo scripts/keep.sh
  test-isolate-path
  test-stub shellcheck 'exit 2'
  cd "$TEST_TMP/repo"
  # Act
  test-capture env check=all ./scripts/quality/check-shell-lint.sh
  # Assert
  assert-equal 2 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  local -a expected_shellcheck_call=(
    --
    scripts/docker/docker.lib.sh
    scripts/keep.sh
    scripts/quality/check-shell-lint.sh
  )
  local expected_shellcheck_call_line
  expected_shellcheck_call_line="$(printf '%q ' "${expected_shellcheck_call[@]}")"
  expected_shellcheck_call_line="${expected_shellcheck_call_line% }"
  assert-equal "$expected_shellcheck_call_line" "$(test-stub-calls shellcheck)" "$ONLY_SHELLCHECK_CALL_LABEL"

  return 0
}

function test-check-shell-lint-all-ignores-hostile-git-pathspec-env() {

  # Arrange
  quality-create-fixture-repo scripts/keep.sh scripts/upper.SH
  test-isolate-path
  test-stub shellcheck
  cd "$TEST_TMP/repo"
  # Act
  test-capture env check=all GIT_GLOB_PATHSPECS=1 GIT_NOGLOB_PATHSPECS=1 GIT_LITERAL_PATHSPECS=1 GIT_ICASE_PATHSPECS=1 ./scripts/quality/check-shell-lint.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  local -a expected_shellcheck_call=(
    --
    scripts/docker/docker.lib.sh
    scripts/keep.sh
    scripts/quality/check-shell-lint.sh
  )
  local expected_shellcheck_call_line
  expected_shellcheck_call_line="$(printf '%q ' "${expected_shellcheck_call[@]}")"
  expected_shellcheck_call_line="${expected_shellcheck_call_line% }"
  assert-equal "$expected_shellcheck_call_line" "$(test-stub-calls shellcheck)" "$ONLY_SHELLCHECK_CALL_LABEL"

  return 0
}

function test-check-shell-lint-all-uses-one-docker-run-when-forced() {

  # Arrange
  quality-create-fixture-repo scripts/keep.sh
  test-isolate-path
  test-stub shellcheck
  test-stub docker
  cd "$TEST_TMP/repo"
  # Act
  test-capture env FORCE_USE_DOCKER=true check=all ./scripts/quality/check-shell-lint.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-stub-not-called shellcheck
  local -a expected_docker_call=(
    run
    --rm
    --platform
    linux/amd64
    --volume
    "$TEST_TMP/repo:/workdir"
    --workdir
    /workdir
    "$SHELLCHECK_IMAGE"
    --
    /workdir/scripts/docker/docker.lib.sh
    /workdir/scripts/keep.sh
    /workdir/scripts/quality/check-shell-lint.sh
  )
  local expected_docker_call_line
  expected_docker_call_line="$(printf '%q ' "${expected_docker_call[@]}")"
  expected_docker_call_line="${expected_docker_call_line% }"
  assert-stub-called docker "$expected_docker_call_line"
  quality-assert-one-docker-run

  return 0
}

function test-check-shell-lint-all-uses-one-docker-run-with-awkward-names-when-forced() {

  # Arrange
  quality-create-fixture-repo \
    "./-dash.sh" \
    "scripts/café.sh" \
    $'scripts/new\nline.sh' \
    "scripts/notes[draft].sh" \
    scripts/notesd.sh \
    "scripts/space name.sh"
  test-isolate-path
  test-stub shellcheck
  test-stub docker
  cd "$TEST_TMP/repo"
  # Act
  test-capture env FORCE_USE_DOCKER=true check=all ./scripts/quality/check-shell-lint.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-stub-not-called shellcheck
  local -a expected_docker_call=(
    run
    --rm
    --platform
    linux/amd64
    --volume
    "$TEST_TMP/repo:/workdir"
    --workdir
    /workdir
    "$SHELLCHECK_IMAGE"
    --
    /workdir/-dash.sh
    /workdir/scripts/café.sh
    /workdir/scripts/docker/docker.lib.sh
    $'/workdir/scripts/new\nline.sh'
    "/workdir/scripts/notes[draft].sh"
    /workdir/scripts/notesd.sh
    /workdir/scripts/quality/check-shell-lint.sh
    "/workdir/scripts/space name.sh"
  )
  local expected_docker_call_line
  expected_docker_call_line="$(printf '%q ' "${expected_docker_call[@]}")"
  expected_docker_call_line="${expected_docker_call_line% }"
  assert-stub-called docker "$expected_docker_call_line"
  quality-assert-one-docker-run

  return 0
}

function test-check-shell-lint-all-uses-docker-when-shellcheck-is-missing() {

  # Arrange
  quality-create-fixture-repo scripts/keep.sh
  test-isolate-path
  test-stub docker
  cd "$TEST_TMP/repo"
  # Act
  test-capture env check=all ./scripts/quality/check-shell-lint.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  local -a expected_docker_call=(
    run
    --rm
    --platform
    linux/amd64
    --volume
    "$TEST_TMP/repo:/workdir"
    --workdir
    /workdir
    "$SHELLCHECK_IMAGE"
    --
    /workdir/scripts/docker/docker.lib.sh
    /workdir/scripts/keep.sh
    /workdir/scripts/quality/check-shell-lint.sh
  )
  local expected_docker_call_line
  expected_docker_call_line="$(printf '%q ' "${expected_docker_call[@]}")"
  expected_docker_call_line="${expected_docker_call_line% }"
  assert-stub-called docker "$expected_docker_call_line"
  quality-assert-one-docker-run

  return 0
}

function test-check-shell-lint-all-stops-when-the-image-pull-fails() {

  # Arrange
  quality-create-fixture-repo scripts/keep.sh
  test-isolate-path
  test-stub shellcheck
  # shellcheck disable=SC2016
  test-stub docker 'if [[ "${1:-} ${2:-}" == "image inspect" ]]; then exit 1; fi; if [[ "${1:-}" == pull ]]; then echo "docker: pull access denied" >&2; exit 23; fi'
  cd "$TEST_TMP/repo"
  # Act
  test-capture env FORCE_USE_DOCKER=true check=all ./scripts/quality/check-shell-lint.sh
  # Assert
  assert-equal 23 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "docker: pull access denied" "pull error on stderr"
  assert-equal "" "$(test-stub-calls docker | grep '^run ' || true)" "no docker run call"
  assert-stub-not-called shellcheck

  return 0
}

function test-check-shell-lint-all-propagates-docker-failure-status() {

  # Arrange
  quality-create-fixture-repo scripts/keep.sh
  test-isolate-path
  test-stub shellcheck
  # shellcheck disable=SC2016
  test-stub docker 'if [[ "${1:-}" == run ]]; then exit 17; fi'
  cd "$TEST_TMP/repo"
  # Act
  test-capture env FORCE_USE_DOCKER=true check=all ./scripts/quality/check-shell-lint.sh
  # Assert
  assert-equal 17 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-stub-not-called shellcheck
  quality-assert-one-docker-run

  return 0
}

function test-check-shell-lint-docker-target-ignores-exported-mode() {

  # Arrange
  check-shell-lint-create-make-fixture-repo
  test-isolate-path make
  test-stub shellcheck
  cd "$TEST_TMP/repo"
  # Act
  test-capture env -u MAKEFLAGS -u MAKELEVEL -u GNUMAKEFLAGS -u MAKEFILES check=branch make MISE_SHIMS= docker-shellscript-lint
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "scripts/docker/docker.lib.sh" "$(test-stub-calls shellcheck)" "Docker lint stays in single-file mode"

  return 0
}

function test-check-shell-lint-make-target-reports-success() {

  # Arrange
  check-shell-lint-create-make-fixture-repo
  test-isolate-path make
  test-stub shellcheck
  cd "$TEST_TMP/repo"
  # Act
  test-capture env -u MAKEFLAGS -u MAKELEVEL -u GNUMAKEFLAGS -u MAKEFILES -u FORCE_USE_DOCKER make MISE_SHIMS= check-shell-lint
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDOUT" "shell lint: ok" "success message"
  assert-equal "-- scripts/docker/docker.lib.sh scripts/quality/check-shell-lint.sh scripts/x.sh" \
    "$(test-stub-calls shellcheck)" "Make invokes ShellCheck once over tracked scripts"

  return 0
}

function test-check-shell-lint-make-target-uses-docker() {

  # Arrange
  check-shell-lint-create-make-fixture-repo
  test-isolate-path make
  test-stub shellcheck
  test-stub docker
  cd "$TEST_TMP/repo"
  # Act
  test-capture env -u MAKEFLAGS -u MAKELEVEL -u GNUMAKEFLAGS -u MAKEFILES FORCE_USE_DOCKER=true make MISE_SHIMS= check-shell-lint
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDOUT" "shell lint: ok" "success message"
  local -a expected_docker_call=(
    run
    --rm
    --platform
    linux/amd64
    --volume
    "$TEST_TMP/repo:/workdir"
    --workdir
    /workdir
    "$SHELLCHECK_IMAGE"
    --
    /workdir/scripts/docker/docker.lib.sh
    /workdir/scripts/quality/check-shell-lint.sh
    /workdir/scripts/x.sh
  )
  local expected_docker_call_line expected_docker_calls
  expected_docker_call_line="$(printf '%q ' "${expected_docker_call[@]}")"
  expected_docker_call_line="${expected_docker_call_line% }"
  expected_docker_calls="$(printf 'image inspect koalaman/shellcheck:v4.0.0\n%s' "$expected_docker_call_line")"
  assert-equal "$expected_docker_calls" "$(test-stub-calls docker)" "Make uses one Docker run for tracked scripts"
  quality-assert-one-docker-run
  assert-stub-not-called shellcheck

  return 0
}

function test-check-shell-lint-make-target-fails-without-success-message() {

  # Arrange
  check-shell-lint-create-make-fixture-repo
  test-isolate-path make
  test-stub shellcheck 'echo "deliberate ShellCheck finding" >&2; exit 1'
  cd "$TEST_TMP/repo"
  # Act
  test-capture env -u MAKEFLAGS -u MAKELEVEL -u GNUMAKEFLAGS -u MAKEFILES -u FORCE_USE_DOCKER make MISE_SHIMS= check-shell-lint
  # Assert
  assert-equal 2 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "deliberate ShellCheck finding" "finding on stderr"
  assert-not-contains "$TEST_STDOUT" "shell lint: ok" "no success message"
  assert-equal "-- scripts/docker/docker.lib.sh scripts/quality/check-shell-lint.sh scripts/x.sh" \
    "$(test-stub-calls shellcheck)" "Make invokes ShellCheck once over tracked scripts"

  return 0
}

function test-check-shell-lint-rejects-unknown-mode() {

  # Arrange
  quality-create-fixture-repo scripts/keep.sh
  test-isolate-path
  test-stub shellcheck
  test-stub docker
  cd "$TEST_TMP/repo"
  # Act
  test-capture env check=bogus ./scripts/quality/check-shell-lint.sh
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "Use check=file or check=all" "unknown mode guidance on stderr"
  assert-stub-not-called shellcheck
  assert-stub-not-called docker

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
