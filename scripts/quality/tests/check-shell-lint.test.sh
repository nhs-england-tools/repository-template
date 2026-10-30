#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034,SC2317,SC2329

set -euo pipefail

# Test suite for the ShellCheck wrapper script. Tests use scratch repositories,
# real Git for file-listing and conflict-index cases, and GNU Make for target
# cases. GNU Make and Git are required. ShellCheck and Docker calls are
# stubbed, so neither tool nor a Docker daemon is needed. One test runs the
# real ShellCheck when it is installed and is skipped otherwise.
#
# Usage:
#   $ ./scripts/quality/tests/check-shell-lint.test.sh
#
# Options:
#   VERBOSE=true  # Show all the executed commands, default is 'false'

# ==============================================================================

readonly EXIT_STATUS_LABEL='exit status'

# Set up the suite fixtures and run every test.
function main() {

  cd "$(git rev-parse --show-toplevel)"
  source ./scripts/tests/test.lib.sh
  source ./scripts/quality/tests/quality-test.lib.sh
  QUALITY_FIXTURE_PATHS=(scripts/quality/check-shell-lint.sh scripts/quality/git-files.lib.sh scripts/quality/git-base.lib.sh scripts/docker/docker.lib.sh)
  QUALITY_FIXTURE_FORMAT='# %s\n'

  # The caller's options must not reach the script under test
  unset -v MISE_TOML check match_version file BRANCH_NAME GITHUB_BASE_REF QUALITY_PR_BASE FORCE_USE_DOCKER CONTAINER_CLI GNUMAKEFLAGS MAKEFILES

  SHELLCHECK_IMAGE=koalaman/shellcheck:v4.0.0@sha256:4444444444444444444444444444444444444444444444444444444444444444

  test-run-suite \
    test-check-shell-lint-defaults-to-all-tracked-scripts \
    test-check-shell-lint-empty-mode-defaults-to-all \
    test-check-shell-lint-selects-staged-shell-scripts \
    test-check-shell-lint-selects-working-tree-shell-scripts \
    test-check-shell-lint-selects-branch-shell-scripts \
    test-check-shell-lint-reports-a-missing-base \
    test-check-shell-lint-without-selected-files-does-not-run-shellcheck \
    test-check-shell-lint-scoped-mode-adds-callers-and-dependencies \
    test-check-shell-lint-scoped-mode-adds-only-relevant-context \
    test-check-shell-lint-scoped-mode-ignores-a-name-inside-a-longer-name \
    test-check-shell-lint-scoped-mode-lints-every-script-when-a-shellcheckrc-changes \
    test-check-shell-lint-scoped-mode-lints-every-script-when-mise-toml-changes \
    test-check-shell-lint-scoped-mode-falls-back-over-context \
    test-check-shell-lint-scoped-mode-lints-callers-of-a-deleted-script \
    test-check-shell-lint-scoped-mode-lints-callers-of-a-renamed-script \
    test-check-shell-lint-scoped-mode-skips-a-script-deleted-only-from-the-index \
    test-check-shell-lint-scoped-modes-skip-untracked-scripts \
    test-check-shell-lint-scoped-mode-checks-changed-make-comments \
    test-check-shell-lint-scoped-mode-checks-only-changed-script-comments \
    test-check-shell-lint-scoped-mode-includes-library-for-real-shellcheck \
    test-check-shell-lint-all-passes-awkward-names-intact \
    test-check-shell-lint-all-skips-deleted-untracked-and-ignored-files \
    test-check-shell-lint-all-fails-when-git-ls-files-fails \
    test-check-shell-lint-all-deduplicates-tracked-paths \
    test-check-shell-lint-all-groups-scripts-with-the-tracked-files-they-name \
    test-check-shell-lint-all-reports-findings-once-from-the-full-call \
    test-check-shell-lint-all-runs-the-full-call-when-grouping-fails \
    test-check-shell-lint-all-hides-name-scan-errors \
    test-check-shell-lint-all-without-scripts-does-not-call-shellcheck \
    test-check-shell-lint-all-propagates-shellcheck-failure-status-1 \
    test-check-shell-lint-all-propagates-shellcheck-failure-status-2 \
    test-check-shell-lint-all-ignores-hostile-git-pathspec-env \
    test-check-shell-lint-all-uses-parallel-docker-runs-when-forced \
    test-check-shell-lint-all-uses-parallel-docker-runs-with-awkward-names-when-forced \
    test-check-shell-lint-all-uses-docker-when-shellcheck-is-missing \
    test-check-shell-lint-all-stops-when-the-image-pull-fails \
    test-check-shell-lint-all-propagates-docker-failure-status \
    test-check-shell-lint-docker-target-is-removed \
    test-check-shell-lint-make-target-reports-success \
    test-check-shell-lint-make-target-uses-docker \
    test-check-shell-lint-make-target-fails-without-success-message \
    test-check-shell-lint-rejects-unknown-mode \
    test-check-shell-lint-pre-commit-and-ci-wiring \
    test-check-shell-lint-fails-a-comment-over-80-characters \
    test-check-shell-lint-make-target-forwards-check-mode \
    test-check-shell-lint-all-fails-a-comment-over-80-characters \
    test-check-shell-lint-accepts-long-code-urls-and-shebangs \
    test-check-shell-lint-all-fails-a-make-comment-over-80-characters \
    test-check-shell-lint-all-keeps-the-shellcheck-status-with-a-long-comment \
    test-check-shell-lint-all-checks-comments-in-docker-mode \
    test-check-shell-lint-all-reads-a-file-named-like-an-awk-assignment \
    test-check-shell-lint-counts-bytes-in-comments \
    test-check-shell-lint-all-skips-comments-of-paths-in-the-ignore-file \
    test-check-shell-lint-ignore-file-uses-git-ignore-rules \
    test-check-shell-lint-scoped-mode-skips-comments-of-paths-in-the-ignore-file \
    test-check-shell-lint-scoped-mode-checks-every-comment-when-the-ignore-file-changes

  return 0
}

# Build the fixture repository once, every test starts from a copy.
function test-suite-setup() {

  quality-build-fixture-base

  return 0
}

# ==============================================================================

function test-check-shell-lint-defaults-to-all-tracked-scripts() {

  # Arrange
  quality-create-fixture-repo scripts/x.sh
  test-isolate-path
  test-stub shellcheck
  cd "$TEST_TMP/repo"
  printf 'generated/\n' > .gitignore
  mkdir -p generated scripts/new
  printf '# generated\n' > generated/ignored.sh
  printf '# untracked\n' > scripts/new/untracked.sh
  # Act
  test-capture ./scripts/quality/check-shell-lint.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  check-shell-lint-assert-group-calls \
    "$(check-shell-lint-call-line -f quiet -- scripts/docker/docker.lib.sh scripts/quality/check-shell-lint.sh scripts/quality/git-base.lib.sh scripts/quality/git-files.lib.sh)" \
    "$(check-shell-lint-call-line -f quiet -- scripts/x.sh)"

  return 0
}

function test-check-shell-lint-empty-mode-defaults-to-all() {

  # Arrange
  quality-create-fixture-repo scripts/x.sh
  test-isolate-path
  test-stub shellcheck
  cd "$TEST_TMP/repo"
  printf '# untracked\n' > scripts/untracked.sh
  # Act
  test-capture env check= ./scripts/quality/check-shell-lint.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$(test-stub-calls shellcheck)" "scripts/x.sh" "empty mode lints tracked scripts"
  assert-not-contains "$(test-stub-calls shellcheck)" "scripts/untracked.sh" "empty mode skips untracked scripts"

  return 0
}

function test-check-shell-lint-selects-staged-shell-scripts() {

  # Arrange
  quality-create-fixture-repo scripts/x.sh scripts/unchanged.sh scripts/note.txt
  test-isolate-path
  test-stub shellcheck
  cd "$TEST_TMP/repo"
  printf '# staged change\n' > scripts/x.sh
  git add scripts/x.sh
  printf 'staged non-shell file\n' > scripts/note.txt
  git add scripts/note.txt
  printf '# unstaged change\n' > scripts/unchanged.sh
  # Act
  test-capture env check=staged-changes ./scripts/quality/check-shell-lint.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "$(check-shell-lint-call-line -f quiet -- scripts/x.sh)" "$(test-stub-calls shellcheck)" "staged shell script only"

  return 0
}

function test-check-shell-lint-selects-working-tree-shell-scripts() {

  # Arrange
  quality-create-fixture-repo scripts/x.sh scripts/unchanged.sh
  test-isolate-path
  test-stub shellcheck
  cd "$TEST_TMP/repo"
  printf '# working tree change\n' > scripts/x.sh
  # Act
  test-capture env check=working-tree-changes ./scripts/quality/check-shell-lint.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "$(check-shell-lint-call-line -f quiet -- scripts/x.sh)" "$(test-stub-calls shellcheck)" "working-tree shell script only"

  return 0
}

function test-check-shell-lint-selects-branch-shell-scripts() {

  # Arrange
  quality-create-fixture-repo scripts/x.sh scripts/unchanged.sh
  test-isolate-path
  test-stub shellcheck
  cd "$TEST_TMP/repo"
  git switch -q -c feature
  printf '# branch change\n' > scripts/x.sh
  git add scripts/x.sh
  git commit -q -m change
  # Act
  test-capture env check=branch BRANCH_NAME=main ./scripts/quality/check-shell-lint.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "$(check-shell-lint-call-line -f quiet -- scripts/x.sh)" "$(test-stub-calls shellcheck)" "branch shell script only"

  return 0
}

function test-check-shell-lint-reports-a-missing-base() {

  # Arrange
  quality-create-fixture-repo scripts/x.sh
  test-isolate-path
  test-stub shellcheck
  cd "$TEST_TMP/repo"
  git switch -q -c feature
  # Act
  test-capture env check=branch BRANCH_NAME=missing ./scripts/quality/check-shell-lint.sh
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "Branch to compare with not found: missing" "missing base diagnostic"
  assert-stub-not-called shellcheck

  return 0
}

function test-check-shell-lint-without-selected-files-does-not-run-shellcheck() {

  # Arrange
  quality-create-fixture-repo scripts/x.sh
  test-isolate-path
  test-stub shellcheck
  test-stub docker
  cd "$TEST_TMP/repo"
  # Act
  test-capture env check=working-tree-changes ./scripts/quality/check-shell-lint.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-stub-not-called shellcheck
  assert-stub-not-called docker

  return 0
}

function test-check-shell-lint-scoped-mode-adds-callers-and-dependencies() {

  # Arrange
  quality-create-fixture-repo scripts/library.sh scripts/helper.sh scripts/caller.sh scripts/outer.sh
  test-isolate-path
  test-stub shellcheck
  cd "$TEST_TMP/repo"
  printf 'source ./library.sh\n' > scripts/helper.sh
  printf 'source ./helper.sh\n' > scripts/caller.sh
  printf 'source ./caller.sh\n' > scripts/outer.sh
  printf '# changed library\n' > scripts/library.sh
  # Act
  test-capture env check=working-tree-changes ./scripts/quality/check-shell-lint.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "$(check-shell-lint-call-line -f quiet -- scripts/caller.sh scripts/helper.sh scripts/library.sh scripts/outer.sh)" \
    "$(test-stub-calls shellcheck)" "changed library callers and their dependencies"

  return 0
}

function test-check-shell-lint-scoped-mode-adds-only-relevant-context() {

  # Arrange
  quality-create-fixture-repo scripts/library.sh scripts/caller.sh scripts/solo.sh scripts/unrelated.sh
  test-isolate-path
  test-stub shellcheck
  cd "$TEST_TMP/repo"
  printf 'source ./library.sh\n' > scripts/caller.sh
  printf '# changed\n' > scripts/solo.sh
  # Act
  test-capture env check=working-tree-changes ./scripts/quality/check-shell-lint.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  check-shell-lint-assert-group-calls \
    "$(check-shell-lint-call-line -f quiet -- scripts/caller.sh scripts/library.sh)" \
    "$(check-shell-lint-call-line -f quiet -- scripts/solo.sh)"

  return 0
}

function test-check-shell-lint-scoped-mode-ignores-a-name-inside-a-longer-name() {

  # Arrange
  quality-create-fixture-repo scripts/core.sh scripts/caller.sh scripts/user.sh
  test-isolate-path
  test-stub shellcheck
  cd "$TEST_TMP/repo"
  printf 'source ./libcore.sh\nsource ./my-core.sh\nsource ./core.sh.bak\nsource ./core_sh/core.shx\n' > scripts/caller.sh
  printf '. "core.sh"\n' > scripts/user.sh
  git commit -q -am 'callers name longer names and the script itself'
  printf '# changed\n' > scripts/core.sh
  # Act
  test-capture env check=working-tree-changes ./scripts/quality/check-shell-lint.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "$(check-shell-lint-call-line -f quiet -- scripts/core.sh scripts/user.sh)" "$(test-stub-calls shellcheck)" \
    "only the script that names the changed one"

  return 0
}

function test-check-shell-lint-scoped-mode-lints-every-script-when-a-shellcheckrc-changes() {

  # Arrange
  quality-create-fixture-repo scripts/x.sh
  test-isolate-path
  test-stub shellcheck
  cd "$TEST_TMP/repo"
  printf 'disable=SC1091\n' > scripts/.shellcheckrc
  git add scripts/.shellcheckrc
  # Act
  test-capture env check=staged-changes ./scripts/quality/check-shell-lint.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  check-shell-lint-assert-group-calls \
    "$(check-shell-lint-call-line -f quiet -- scripts/docker/docker.lib.sh scripts/quality/check-shell-lint.sh scripts/quality/git-base.lib.sh scripts/quality/git-files.lib.sh)" \
    "$(check-shell-lint-call-line -f quiet -- scripts/x.sh)"

  return 0
}

function test-check-shell-lint-scoped-mode-lints-every-script-when-mise-toml-changes() {

  # Arrange
  quality-create-fixture-repo scripts/x.sh
  test-isolate-path
  test-stub shellcheck
  cd "$TEST_TMP/repo"
  printf '# %s\n' "$(printf 'a%.0s' {1..79})" > scripts/x.sh
  git commit -q -am 'existing long comment'
  printf '# changed\n' >> mise.toml
  # Act
  test-capture env check=working-tree-changes ./scripts/quality/check-shell-lint.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "" "$TEST_STDERR" "comments of unchanged scripts are not checked"
  check-shell-lint-assert-group-calls \
    "$(check-shell-lint-call-line -f quiet -- scripts/docker/docker.lib.sh scripts/quality/check-shell-lint.sh scripts/quality/git-base.lib.sh scripts/quality/git-files.lib.sh)" \
    "$(check-shell-lint-call-line -f quiet -- scripts/x.sh)"

  return 0
}

function test-check-shell-lint-scoped-mode-falls-back-over-context() {

  # Arrange
  quality-create-fixture-repo scripts/library.sh scripts/caller.sh scripts/solo.sh
  test-isolate-path
  # shellcheck disable=SC2016
  test-stub shellcheck 'if [[ "${1:-}" == "-f" ]]; then exit 1; fi; echo "scoped fallback report"; exit 7'
  cd "$TEST_TMP/repo"
  printf 'source ./library.sh\n' > scripts/caller.sh
  printf '# changed library\n' > scripts/library.sh
  # Act
  test-capture env check=working-tree-changes ./scripts/quality/check-shell-lint.sh
  # Assert
  assert-equal 7 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "scoped fallback report" "$TEST_STDOUT" "scoped full-call report"
  check-shell-lint-assert-full-call-last scripts/caller.sh scripts/library.sh

  return 0
}

function test-check-shell-lint-scoped-mode-lints-callers-of-a-deleted-script() {

  # Arrange
  quality-create-fixture-repo scripts/library.sh scripts/caller.sh scripts/solo.sh
  test-isolate-path
  test-stub shellcheck
  cd "$TEST_TMP/repo"
  printf 'source ./library.sh\n' > scripts/caller.sh
  git commit -q -am 'caller sources the library'
  git update-ref refs/remotes/origin/main HEAD
  git switch -q -c feature
  git rm -q scripts/library.sh
  git commit -q -m 'delete the library'
  # Act
  test-capture env check=branch ./scripts/quality/check-shell-lint.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "$(check-shell-lint-call-line -f quiet -- scripts/caller.sh)" "$(test-stub-calls shellcheck)" \
    "the caller of the deleted library"

  return 0
}

function test-check-shell-lint-scoped-mode-lints-callers-of-a-renamed-script() {

  # Arrange
  quality-create-fixture-repo scripts/library.sh scripts/caller.sh scripts/solo.sh
  test-isolate-path
  test-stub shellcheck
  cd "$TEST_TMP/repo"
  printf 'source ./library.sh\n' > scripts/caller.sh
  git commit -q -am 'caller sources the library'
  git mv scripts/library.sh scripts/renamed.sh
  # Act
  test-capture env check=staged-changes ./scripts/quality/check-shell-lint.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  check-shell-lint-assert-group-calls \
    "$(check-shell-lint-call-line -f quiet -- scripts/caller.sh)" \
    "$(check-shell-lint-call-line -f quiet -- scripts/renamed.sh)"

  return 0
}

function test-check-shell-lint-scoped-mode-skips-a-script-deleted-only-from-the-index() {

  # Arrange
  quality-create-fixture-repo scripts/library.sh scripts/caller.sh scripts/solo.sh
  test-isolate-path
  test-stub shellcheck
  cd "$TEST_TMP/repo"
  printf 'source ./library.sh\n' > scripts/caller.sh
  git commit -q -am 'caller sources the library'
  printf 'source ./solo.sh\n' > scripts/library.sh
  git rm -q --cached scripts/library.sh
  # Act
  test-capture env check=staged-changes ./scripts/quality/check-shell-lint.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "$(check-shell-lint-call-line -f quiet -- scripts/caller.sh)" "$(test-stub-calls shellcheck)" \
    "only the caller of the now untracked library"

  return 0
}

function test-check-shell-lint-scoped-modes-skip-untracked-scripts() {

  # Arrange
  local mode
  quality-create-fixture-repo scripts/x.sh
  test-isolate-path
  test-stub shellcheck
  cd "$TEST_TMP/repo"
  git switch -q -c feature
  printf '# untracked\n' > scripts/new.sh
  # Act
  for mode in staged-changes working-tree-changes branch; do
    test-capture env "check=$mode" ./scripts/quality/check-shell-lint.sh
    assert-equal 0 "$TEST_STATUS" "$mode $EXIT_STATUS_LABEL"
  done
  # Assert
  assert-stub-not-called shellcheck

  return 0
}

function test-check-shell-lint-scoped-mode-checks-changed-make-comments() {

  # Arrange
  local long_comment
  long_comment="# $(printf 'a%.0s' {1..79})"
  quality-create-fixture-repo scripts/changed.mk scripts/unchanged.mk
  test-isolate-path
  test-stub shellcheck
  cd "$TEST_TMP/repo"
  printf '%s\n' "$long_comment" > scripts/unchanged.mk
  git commit -q -am 'existing long comment'
  printf '%s\n' "$long_comment" > scripts/changed.mk
  git add scripts/changed.mk
  # Act
  test-capture env check=staged-changes ./scripts/quality/check-shell-lint.sh
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "scripts/changed.mk:1: comment is 81 characters, the limit is 80" "$TEST_STDERR" "only the changed Make file"
  assert-stub-not-called shellcheck

  return 0
}

function test-check-shell-lint-scoped-mode-checks-only-changed-script-comments() {

  # Arrange
  local long_comment
  long_comment="# $(printf 'a%.0s' {1..79})"
  quality-create-fixture-repo scripts/library.sh scripts/caller.sh
  test-isolate-path
  test-stub shellcheck
  cd "$TEST_TMP/repo"
  printf 'source ./library.sh\n%s\n' "$long_comment" > scripts/caller.sh
  git commit -q -am 'existing long comment in the caller'
  printf '%s\n' "$long_comment" > scripts/library.sh
  # Act
  test-capture env check=working-tree-changes ./scripts/quality/check-shell-lint.sh
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "scripts/library.sh:1: comment is 81 characters, the limit is 80" "$TEST_STDERR" "only the changed script"
  assert-equal "$(check-shell-lint-call-line -f quiet -- scripts/caller.sh scripts/library.sh)" "$(test-stub-calls shellcheck)" \
    "ShellCheck still sees the caller"

  return 0
}

function test-check-shell-lint-scoped-mode-includes-library-for-real-shellcheck() {

  # Arrange
  if ! (cd "$TEST_REPO_ROOT" && shellcheck --version) > /dev/null 2>&1; then
    echo "skipped: shellcheck is not installed"
    return 0
  fi
  quality-create-fixture-repo scripts/test-lib.sh scripts/check.sh
  test-isolate-path shellcheck
  cd "$TEST_TMP/repo"
  printf '#!/usr/bin/env bash\n# shellcheck disable=SC2034\nSHARED_VALUE=ready\n' > scripts/test-lib.sh
  printf 'true\n' > scripts/check.sh
  git add scripts/test-lib.sh scripts/check.sh
  git commit --amend -q --no-edit
  # shellcheck disable=SC2016
  printf '#!/usr/bin/env bash\nsource ./scripts/test-lib.sh\nprintf "%%s\\n" "$SHARED_VALUE"\n' > scripts/check.sh
  # Act and assert that ShellCheck reports the source was not followed alone.
  test-capture shellcheck -- scripts/check.sh
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL without following the source"
  assert-contains "$TEST_STDOUT$TEST_STDERR" "SC1091" "source was not followed without its library input"
  # Act: the wrapper includes the source library in its selected input set.
  test-capture env check=working-tree-changes ./scripts/quality/check-shell-lint.sh
  # Assert
  assert-equal "" "$TEST_STDOUT$TEST_STDERR" "no ShellCheck diagnostics with source context"
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL with source context"

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
  test-capture env check=all ./scripts/quality/check-shell-lint.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  check-shell-lint-assert-group-calls \
    "$(check-shell-lint-call-line -f quiet -- ./-dash.sh)" \
    "$(check-shell-lint-call-line -f quiet -- scripts/café.sh)" \
    "$(check-shell-lint-call-line -f quiet -- scripts/docker/docker.lib.sh scripts/quality/check-shell-lint.sh scripts/quality/git-base.lib.sh scripts/quality/git-files.lib.sh)" \
    "$(check-shell-lint-call-line -f quiet -- $'scripts/new\nline.sh')" \
    "$(check-shell-lint-call-line -f quiet -- "scripts/notes[draft].sh")" \
    "$(check-shell-lint-call-line -f quiet -- scripts/notesd.sh)" \
    "$(check-shell-lint-call-line -f quiet -- "scripts/space name.sh")"

  return 0
}

function test-check-shell-lint-all-skips-deleted-untracked-and-ignored-files() {

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
  check-shell-lint-assert-default-group-calls

  return 0
}

function test-check-shell-lint-all-fails-when-git-ls-files-fails() {

  # Arrange
  quality-create-fixture-repo scripts/keep.sh
  test-isolate-path
  test-stub shellcheck
  test-stub docker
  # shellcheck disable=SC2016
  test-stub git 'if [[ "${1:-} ${2:-}" == "rev-parse --show-toplevel" ]]; then printf "%s\n" "$TEST_TMP/repo"; elif [[ " $* " == *" ls-files "* ]]; then echo "git: ls-files failed" >&2; exit 23; else echo "unexpected git call: $*" >&2; exit 1; fi'
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
  check-shell-lint-assert-default-group-calls

  return 0
}

function test-check-shell-lint-all-groups-scripts-with-the-tracked-files-they-name() {

  # Arrange
  quality-create-fixture-repo scripts/app.sh scripts/base.sh scripts/mid.sh scripts/solo.sh
  test-isolate-path
  test-stub shellcheck
  cd "$TEST_TMP/repo"
  printf 'source ./scripts/mid.sh\n' > scripts/app.sh
  # shellcheck disable=SC2016
  printf 'source "$(dirname "$0")/base.sh"\n' > scripts/mid.sh
  printf 'source ./scripts/untracked.sh\n' > scripts/solo.sh
  printf '# untracked\n' > scripts/untracked.sh
  # Act
  test-capture env check=all ./scripts/quality/check-shell-lint.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  check-shell-lint-assert-group-calls \
    "$(check-shell-lint-call-line -f quiet -- scripts/app.sh scripts/base.sh scripts/mid.sh)" \
    "$(check-shell-lint-call-line -f quiet -- scripts/docker/docker.lib.sh scripts/quality/check-shell-lint.sh scripts/quality/git-base.lib.sh scripts/quality/git-files.lib.sh)" \
    "$(check-shell-lint-call-line -f quiet -- scripts/solo.sh)"

  return 0
}

function test-check-shell-lint-all-reports-findings-once-from-the-full-call() {

  # Arrange
  quality-create-fixture-repo scripts/bad.sh scripts/keep.sh
  test-isolate-path
  # shellcheck disable=SC2016
  test-stub shellcheck 'if [[ " $* " == *" scripts/bad.sh "* ]]; then echo "deliberate ShellCheck finding"; echo "deliberate ShellCheck error" >&2; exit 1; fi'
  cd "$TEST_TMP/repo"
  # Act
  test-capture env check=all ./scripts/quality/check-shell-lint.sh
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "deliberate ShellCheck finding" "$TEST_STDOUT" "stdout of the full call only"
  assert-equal "deliberate ShellCheck error" "$TEST_STDERR" "stderr of the full call only"
  check-shell-lint-assert-full-call-last \
    scripts/bad.sh scripts/docker/docker.lib.sh scripts/keep.sh scripts/quality/check-shell-lint.sh scripts/quality/git-base.lib.sh scripts/quality/git-files.lib.sh

  return 0
}

function test-check-shell-lint-all-runs-the-full-call-when-grouping-fails() {

  # Arrange
  quality-create-fixture-repo scripts/keep.sh
  test-isolate-path
  # shellcheck disable=SC2016
  test-stub shellcheck 'if [[ "${1:-}" == "-f" ]]; then exit 1; fi'
  cd "$TEST_TMP/repo"
  # Act
  test-capture env check=all ./scripts/quality/check-shell-lint.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  check-shell-lint-assert-full-call-last \
    scripts/docker/docker.lib.sh scripts/keep.sh scripts/quality/check-shell-lint.sh scripts/quality/git-base.lib.sh scripts/quality/git-files.lib.sh

  return 0
}

function test-check-shell-lint-all-hides-name-scan-errors() {

  # Arrange
  quality-create-fixture-repo scripts/keep.sh scripts/locked.sh
  test-isolate-path
  test-stub shellcheck
  cd "$TEST_TMP/repo"
  chmod 000 scripts/locked.sh
  # Act
  test-capture env check=all ./scripts/quality/check-shell-lint.sh
  # Assert
  chmod 644 scripts/locked.sh
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "" "$TEST_STDERR" "stderr"

  return 0
}

function test-check-shell-lint-all-without-scripts-does-not-call-shellcheck() {

  # Arrange
  quality-create-fixture-repo scripts/keep.sh
  test-isolate-path
  test-stub shellcheck
  test-stub docker
  # shellcheck disable=SC2016
  test-stub git 'if [[ "${1:-} ${2:-}" == "rev-parse --show-toplevel" ]]; then printf "%s\n" "$TEST_TMP/repo"; elif [[ " $* " == *" ls-files "* ]]; then :; else echo "unexpected git call: $*" >&2; exit 1; fi'
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
  check-shell-lint-assert-full-call-last \
    scripts/docker/docker.lib.sh scripts/keep.sh scripts/quality/check-shell-lint.sh scripts/quality/git-base.lib.sh scripts/quality/git-files.lib.sh

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
  check-shell-lint-assert-full-call-last \
    scripts/docker/docker.lib.sh scripts/keep.sh scripts/quality/check-shell-lint.sh scripts/quality/git-base.lib.sh scripts/quality/git-files.lib.sh

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
  check-shell-lint-assert-default-group-calls

  return 0
}

function test-check-shell-lint-all-uses-parallel-docker-runs-when-forced() {

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
  check-shell-lint-assert-docker-group-runs \
    "$(check-shell-lint-docker-run-line -f quiet -- /workdir/scripts/docker/docker.lib.sh /workdir/scripts/quality/check-shell-lint.sh /workdir/scripts/quality/git-base.lib.sh /workdir/scripts/quality/git-files.lib.sh)" \
    "$(check-shell-lint-docker-run-line -f quiet -- /workdir/scripts/keep.sh)"

  return 0
}

function test-check-shell-lint-all-uses-parallel-docker-runs-with-awkward-names-when-forced() {

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
  check-shell-lint-assert-docker-group-runs \
    "$(check-shell-lint-docker-run-line -f quiet -- /workdir/./-dash.sh)" \
    "$(check-shell-lint-docker-run-line -f quiet -- /workdir/scripts/café.sh)" \
    "$(check-shell-lint-docker-run-line -f quiet -- /workdir/scripts/docker/docker.lib.sh /workdir/scripts/quality/check-shell-lint.sh /workdir/scripts/quality/git-base.lib.sh /workdir/scripts/quality/git-files.lib.sh)" \
    "$(check-shell-lint-docker-run-line -f quiet -- $'/workdir/scripts/new\nline.sh')" \
    "$(check-shell-lint-docker-run-line -f quiet -- "/workdir/scripts/notes[draft].sh")" \
    "$(check-shell-lint-docker-run-line -f quiet -- /workdir/scripts/notesd.sh)" \
    "$(check-shell-lint-docker-run-line -f quiet -- "/workdir/scripts/space name.sh")"

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
  check-shell-lint-assert-docker-group-runs \
    "$(check-shell-lint-docker-run-line -f quiet -- /workdir/scripts/docker/docker.lib.sh /workdir/scripts/quality/check-shell-lint.sh /workdir/scripts/quality/git-base.lib.sh /workdir/scripts/quality/git-files.lib.sh)" \
    "$(check-shell-lint-docker-run-line -f quiet -- /workdir/scripts/keep.sh)"

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
  test-stub docker 'if [[ "${1:-}" == run ]]; then echo "deliberate ShellCheck finding"; echo "deliberate Docker error" >&2; exit 17; fi'
  cd "$TEST_TMP/repo"
  # Act
  test-capture env FORCE_USE_DOCKER=true check=all ./scripts/quality/check-shell-lint.sh
  # Assert
  assert-equal 17 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "deliberate ShellCheck finding" "$TEST_STDOUT" "stdout of the full run only"
  assert-equal "deliberate Docker error" "$TEST_STDERR" "stderr of the full run only"
  assert-stub-not-called shellcheck
  check-shell-lint-assert-docker-full-run-last \
    scripts/docker/docker.lib.sh scripts/keep.sh scripts/quality/check-shell-lint.sh scripts/quality/git-base.lib.sh scripts/quality/git-files.lib.sh

  return 0
}

function test-check-shell-lint-docker-target-is-removed() {

  # Arrange
  check-shell-lint-create-make-fixture-repo
  test-isolate-path make
  cd "$TEST_TMP/repo"
  # Act
  test-capture env -u MAKEFLAGS -u MAKELEVEL -u GNUMAKEFLAGS -u MAKEFILES make MISE_SHIMS= docker-shellscript-lint
  # Assert
  assert-equal 2 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "No rule to make target 'docker-shellscript-lint'" "Docker-only lint target was removed"

  return 0
}

function test-check-shell-lint-make-target-reports-success() {

  # Arrange
  check-shell-lint-create-make-fixture-repo
  test-isolate-path make
  test-stub shellcheck
  cd "$TEST_TMP/repo"
  # Act
  test-capture env -u MAKEFLAGS -u MAKELEVEL -u GNUMAKEFLAGS -u MAKEFILES -u FORCE_USE_DOCKER make MISE_SHIMS= lint-shell
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDOUT" "shell lint: ok" "success message"
  check-shell-lint-assert-group-calls \
    "$(check-shell-lint-call-line -f quiet -- scripts/docker/docker.lib.sh scripts/quality/check-shell-lint.sh scripts/quality/git-base.lib.sh scripts/quality/git-files.lib.sh)" \
    "$(check-shell-lint-call-line -f quiet -- scripts/x.sh)"

  return 0
}

function test-check-shell-lint-make-target-forwards-check-mode() {

  # Arrange
  check-shell-lint-create-make-fixture-repo
  test-isolate-path make
  test-stub shellcheck
  cd "$TEST_TMP/repo"
  printf '# staged change\n' > scripts/x.sh
  git add scripts/x.sh
  # Act
  test-capture env -u MAKEFLAGS -u MAKELEVEL -u GNUMAKEFLAGS -u MAKEFILES -u FORCE_USE_DOCKER make MISE_SHIMS= lint-shell check=staged-changes
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "$(check-shell-lint-call-line -f quiet -- scripts/x.sh)" "$(test-stub-calls shellcheck)" "Make forwards staged-changes"

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
  test-capture env -u MAKEFLAGS -u MAKELEVEL -u GNUMAKEFLAGS -u MAKEFILES FORCE_USE_DOCKER=true make MISE_SHIMS= lint-shell
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDOUT" "shell lint: ok" "success message"
  assert-equal "image inspect koalaman/shellcheck:v4.0.0" "$(test-stub-calls docker | head -n 1)" "Make checks the image first"
  check-shell-lint-assert-docker-group-runs \
    "$(check-shell-lint-docker-run-line -f quiet -- /workdir/scripts/docker/docker.lib.sh /workdir/scripts/quality/check-shell-lint.sh /workdir/scripts/quality/git-base.lib.sh /workdir/scripts/quality/git-files.lib.sh)" \
    "$(check-shell-lint-docker-run-line -f quiet -- /workdir/scripts/x.sh)"
  assert-equal 3 "$(test-stub-calls docker | awk 'END { print NR }')" "number of docker calls"
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
  test-capture env -u MAKEFLAGS -u MAKELEVEL -u GNUMAKEFLAGS -u MAKEFILES -u FORCE_USE_DOCKER make MISE_SHIMS= lint-shell
  # Assert
  assert-equal 2 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "deliberate ShellCheck finding" "finding on stderr"
  assert-not-contains "$TEST_STDOUT" "shell lint: ok" "no success message"
  check-shell-lint-assert-full-call-last \
    scripts/docker/docker.lib.sh scripts/quality/check-shell-lint.sh scripts/quality/git-base.lib.sh scripts/quality/git-files.lib.sh scripts/x.sh

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
  assert-equal 126 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "check=all, check=staged-changes, check=working-tree-changes, check=branch" "unknown mode guidance on stderr"
  assert-stub-not-called shellcheck
  assert-stub-not-called docker

  return 0
}

function test-check-shell-lint-pre-commit-and-ci-wiring() {

  # Arrange
  local hook_ids lint_hook_ids shell_hook workflow_jobs jobs_with_needs pre_commit workflow
  local lint_jobs='^(scan-secrets|check-file-format|check-markdown-format|check-markdown-links|check-shell-lint|check-workflow-security)$'
  local lint_order='scan-secrets check-file-format check-markdown-format check-markdown-links check-shell-lint check-workflow-security '
  pre_commit="$TEST_REPO_ROOT/scripts/config/pre-commit.yaml"
  workflow="$TEST_REPO_ROOT/.github/workflows/stage-1-commit.yaml"
  hook_ids="$(sed -En 's/^[[:space:]]*-[[:space:]]+id:[[:space:]]*([^[:space:]]+).*/\1/p' "$pre_commit")"
  lint_hook_ids="$(printf '%s\n' "$hook_ids" | grep -E "$lint_jobs" || true)"
  shell_hook="$(awk '/^[[:space:]]*-[[:space:]]+id:/ { in_hook = ($NF == "check-shell-lint") } in_hook' "$pre_commit")"
  workflow_jobs="$(sed -En 's/^  ([a-z-]+):[[:space:]]*$/\1/p' "$workflow" | grep -E "$lint_jobs" || true)"
  jobs_with_needs="$(awk '/^  [a-z-]+:[[:space:]]*$/ { job = $1; sub(/:$/, "", job) } /^    needs:/ { print job }' "$workflow" | grep -E "$lint_jobs" || true)"
  # Assert
  assert-equal "$lint_order" "$(printf '%s\n' "$lint_hook_ids" | tr '\n' ' ')" "pre-commit lint hook order"
  assert-equal "test" "$(printf '%s\n' "$hook_ids" | tail -n 1)" "the test hook runs last"
  assert-equal "$lint_order" "$(printf '%s\n' "$workflow_jobs" | tr '\n' ' ')" "workflow lint job order"
  assert-contains "$shell_hook" "entry: make lint-shell check=all"$'\n' "pre-commit uses all mode like the other checks"
  assert-contains "$shell_hook" "pass_filenames: false" "pre-commit passes no file names"
  assert-contains "$(cat "$TEST_REPO_ROOT/.github/actions/check-shell-lint/action.yaml")" "make lint-shell check=all" "composite action uses all mode"
  assert-equal "" "$jobs_with_needs" "lint jobs run in parallel"

  return 0
}

function test-check-shell-lint-fails-a-comment-over-80-characters() {

  # Arrange
  quality-create-fixture-repo scripts/x.sh
  test-isolate-path
  test-stub shellcheck
  cd "$TEST_TMP/repo"
  printf '# %s\n' "$(printf 'a%.0s' {1..79})" > scripts/x.sh
  # Act
  test-capture env check=all ./scripts/quality/check-shell-lint.sh
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "scripts/x.sh:1: comment is 81 characters, the limit is 80" "finding on stderr"

  return 0
}

function test-check-shell-lint-all-fails-a-comment-over-80-characters() {

  # Arrange
  quality-create-fixture-repo scripts/x.sh
  test-isolate-path
  test-stub shellcheck
  cd "$TEST_TMP/repo"
  printf 'true\n  # %s\n' "$(printf 'a%.0s' {1..79})" > scripts/x.sh
  # Act
  test-capture env check=all ./scripts/quality/check-shell-lint.sh
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "scripts/x.sh:2: comment is 83 characters, the limit is 80" "finding on stderr"

  return 0
}

function test-check-shell-lint-accepts-long-code-urls-and-shebangs() {

  # Arrange
  quality-create-fixture-repo scripts/x.sh
  test-isolate-path
  test-stub shellcheck
  cd "$TEST_TMP/repo"
  local long
  long="$(printf 'a%.0s' {1..90})"
  printf '#!/usr/bin/env %s\n# https://example.com/%s\necho %s\n# %s\n' "$long" "$long" "$long" "$(printf 'a%.0s' {1..78})" > scripts/x.sh
  # Act
  test-capture env check=all ./scripts/quality/check-shell-lint.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "" "$TEST_STDERR" "stderr"

  return 0
}

function test-check-shell-lint-all-fails-a-make-comment-over-80-characters() {

  # Arrange
  quality-create-fixture-repo scripts/x.mk
  test-isolate-path
  test-stub shellcheck
  cd "$TEST_TMP/repo"
  printf 'all:\n\t# %s\n\techo %s\n' "$(printf 'a%.0s' {1..79})" "$(printf 'a%.0s' {1..90})" > scripts/x.mk
  # Act
  test-capture env check=all ./scripts/quality/check-shell-lint.sh
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "scripts/x.mk:2: comment is 82 characters, the limit is 80" "$TEST_STDERR" "stderr"
  check-shell-lint-assert-group-calls \
    "$(check-shell-lint-call-line -f quiet -- scripts/docker/docker.lib.sh scripts/quality/check-shell-lint.sh scripts/quality/git-base.lib.sh scripts/quality/git-files.lib.sh)"

  return 0
}

function test-check-shell-lint-all-keeps-the-shellcheck-status-with-a-long-comment() {

  # Arrange
  quality-create-fixture-repo scripts/x.sh
  test-isolate-path
  test-stub shellcheck 'exit 2'
  cd "$TEST_TMP/repo"
  printf '# %s\n' "$(printf 'a%.0s' {1..79})" > scripts/x.sh
  # Act
  test-capture env check=all ./scripts/quality/check-shell-lint.sh
  # Assert
  assert-equal 2 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "scripts/x.sh:1: comment is 81 characters, the limit is 80" "finding on stderr"

  return 0
}

function test-check-shell-lint-all-checks-comments-in-docker-mode() {

  # Arrange
  quality-create-fixture-repo scripts/x.sh
  test-isolate-path
  test-stub shellcheck
  test-stub docker
  cd "$TEST_TMP/repo"
  printf '# %s\n' "$(printf 'a%.0s' {1..79})" > scripts/x.sh
  # Act
  test-capture env FORCE_USE_DOCKER=true check=all ./scripts/quality/check-shell-lint.sh
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "scripts/x.sh:1: comment is 81 characters, the limit is 80" "$TEST_STDERR" "stderr"
  assert-stub-not-called shellcheck

  return 0
}

function test-check-shell-lint-all-reads-a-file-named-like-an-awk-assignment() {

  # Arrange
  quality-create-fixture-repo "scripts/x=y.sh"
  test-isolate-path
  test-stub shellcheck
  cd "$TEST_TMP/repo"
  printf '# %s\n' "$(printf 'a%.0s' {1..79})" > "scripts/x=y.sh"
  # Act
  test-capture env check=all ./scripts/quality/check-shell-lint.sh
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "scripts/x=y.sh:1: comment is 81 characters, the limit is 80" "$TEST_STDERR" "stderr"

  return 0
}

function test-check-shell-lint-counts-bytes-in-comments() {

  # Arrange
  quality-create-fixture-repo scripts/x.sh
  test-isolate-path
  test-stub shellcheck
  cd "$TEST_TMP/repo"
  printf '# %s\n' "$(printf '\303\251%.0s' {1..40})" > scripts/x.sh
  # Act
  test-capture env LC_ALL=en_US.UTF-8 check=all ./scripts/quality/check-shell-lint.sh
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "scripts/x.sh:1: comment is 82 characters, the limit is 80" "$TEST_STDERR" "stderr"

  return 0
}

function test-check-shell-lint-all-skips-comments-of-paths-in-the-ignore-file() {

  # Arrange
  quality-create-fixture-repo scripts/x.sh vendor/tool/y.sh
  test-isolate-path
  test-stub shellcheck
  cd "$TEST_TMP/repo"
  mkdir -p scripts/config
  printf '# %s\n' "$(printf 'a%.0s' {1..79})" > vendor/tool/y.sh
  printf '# Vendored scripts\r\n\r\nvendor/\r\n' > scripts/config/.commentlengthignore
  # Act
  test-capture env check=all ./scripts/quality/check-shell-lint.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "" "$TEST_STDERR" "stderr"
  assert-contains "$(test-stub-calls shellcheck)" "vendor/tool/y.sh" "ShellCheck still lints the ignored script"

  return 0
}

function test-check-shell-lint-ignore-file-uses-git-ignore-rules() {

  # Arrange
  quality-create-fixture-repo scripts/x.sh vendor/a.sh vendor/b.sh lib/vendor/c.sh
  test-isolate-path
  test-stub shellcheck
  cd "$TEST_TMP/repo"
  mkdir -p scripts/config
  printf '# %s\n' "$(printf 'a%.0s' {1..79})" | tee vendor/a.sh vendor/b.sh > lib/vendor/c.sh
  printf '/vendor/*.sh\n!vendor/b.sh\n' > scripts/config/.commentlengthignore
  # Act
  test-capture env check=all ./scripts/quality/check-shell-lint.sh
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal $'lib/vendor/c.sh:1: comment is 81 characters, the limit is 80\nvendor/b.sh:1: comment is 81 characters, the limit is 80' \
    "$TEST_STDERR" "only the files the entries do not match"

  return 0
}

function test-check-shell-lint-scoped-mode-skips-comments-of-paths-in-the-ignore-file() {

  # Arrange
  quality-create-fixture-repo scripts/x.sh vendor/tool/y.sh scripts/vendor.mk
  test-isolate-path
  test-stub shellcheck
  cd "$TEST_TMP/repo"
  mkdir -p scripts/config
  printf 'vendor/\nscripts/vendor.mk\n' > scripts/config/.commentlengthignore
  git add scripts/config/.commentlengthignore
  git commit -q -m 'ignore vendored files'
  printf '# %s\n' "$(printf 'a%.0s' {1..79})" | tee vendor/tool/y.sh > scripts/vendor.mk
  git add vendor/tool/y.sh scripts/vendor.mk
  # Act
  test-capture env check=staged-changes ./scripts/quality/check-shell-lint.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "" "$TEST_STDERR" "stderr"
  assert-contains "$(test-stub-calls shellcheck)" "vendor/tool/y.sh" "ShellCheck still lints the changed script"

  return 0
}

function test-check-shell-lint-scoped-mode-checks-every-comment-when-the-ignore-file-changes() {

  # Arrange
  quality-create-fixture-repo scripts/x.sh vendor/tool/y.sh scripts/vendor.mk
  test-isolate-path
  test-stub shellcheck
  cd "$TEST_TMP/repo"
  mkdir -p scripts/config
  printf 'vendor/\nscripts/vendor.mk\n' > scripts/config/.commentlengthignore
  printf '# %s\n' "$(printf 'a%.0s' {1..79})" | tee vendor/tool/y.sh > scripts/vendor.mk
  git add -A
  git commit -q -m 'vendored files with long comments'
  printf 'vendor/\n' > scripts/config/.commentlengthignore
  git add scripts/config/.commentlengthignore
  # Act
  test-capture env check=staged-changes ./scripts/quality/check-shell-lint.sh
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "scripts/vendor.mk:1: comment is 81 characters, the limit is 80" "$TEST_STDERR" "the file the ignore list no longer matches"

  return 0
}

# ==============================================================================

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

# Print the arguments as one line, quoted the way the stub records a call.
# Arguments:
#   $@=[call arguments]
function check-shell-lint-call-line() {

  local line
  line="$(printf '%q ' "$@")"
  printf '%s\n' "${line% }"

  return 0
}

# Fail unless the shellcheck stub recorded exactly the given calls, in any
# order.
# Arguments:
#   $@=[expected call lines]
function check-shell-lint-assert-group-calls() {

  assert-equal "$(printf '%s\n' "$@" | LC_ALL=C sort)" "$(test-stub-calls shellcheck | LC_ALL=C sort)" \
    "parallel ShellCheck group calls"

  return 0
}

# Fail unless the shellcheck stub recorded the group calls of the fixture with
# scripts/keep.sh only.
function check-shell-lint-assert-default-group-calls() {

  check-shell-lint-assert-group-calls \
    "$(check-shell-lint-call-line -f quiet -- scripts/docker/docker.lib.sh scripts/quality/check-shell-lint.sh scripts/quality/git-base.lib.sh scripts/quality/git-files.lib.sh)" \
    "$(check-shell-lint-call-line -f quiet -- scripts/keep.sh)"

  return 0
}

# Fail unless the last shellcheck call is the only full call, over the given
# files.
# Arguments:
#   $@=[tracked shell-script paths in the expected order]
function check-shell-lint-assert-full-call-last() {

  local expected
  expected="$(check-shell-lint-call-line -- "$@")"
  assert-equal "$expected" "$(test-stub-calls shellcheck | tail -n 1)" "the last shellcheck call"
  assert-equal 1 "$(test-stub-calls shellcheck | grep -c '^-- ' || true)" "number of full shellcheck calls"

  return 0
}

# Print the docker run call line of the ShellCheck image with the given
# ShellCheck arguments.
# Arguments:
#   $@=[ShellCheck arguments]
function check-shell-lint-docker-run-line() {

  check-shell-lint-call-line run --rm --platform linux/amd64 --network none \
    --volume "$TEST_TMP/repo:/workdir:ro" --workdir /workdir "$SHELLCHECK_IMAGE" "$@"

  return 0
}

# Fail unless the docker stub recorded exactly the given run calls, in any
# order.
# Arguments:
#   $@=[expected run call lines]
function check-shell-lint-assert-docker-group-runs() {

  assert-equal "$(printf '%s\n' "$@" | LC_ALL=C sort)" "$(test-stub-calls docker | grep '^run ' | LC_ALL=C sort)" \
    "parallel ShellCheck group docker runs"

  return 0
}

# Fail unless the last docker call is the only full ShellCheck run, over the
# given files.
# Arguments:
#   $@=[tracked shell-script paths in the expected order]
function check-shell-lint-assert-docker-full-run-last() {

  local -a paths=()
  local path
  for path in "$@"; do
    paths+=("/workdir/$path")
  done
  assert-equal "$(check-shell-lint-docker-run-line -- "${paths[@]}")" "$(test-stub-calls docker | tail -n 1)" "the last docker call"
  assert-equal 1 "$(test-stub-calls docker | grep '^run ' | grep -vc ' -f quiet ' || true)" "number of full docker runs"

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
