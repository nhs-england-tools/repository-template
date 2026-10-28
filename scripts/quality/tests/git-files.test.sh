#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2317,SC2329

set -euo pipefail

# Test suite for the shared Git path collector that the quality checks use.
# Each test uses a scratch Git repository and real Git.
#
# Usage:
#   $ ./scripts/quality/tests/git-files.test.sh
#
# Options:
#   VERBOSE=true  # Show all the executed commands, default is 'false'

# ==============================================================================

readonly EXIT_STATUS_LABEL='exit status'
readonly SELECTION_LABEL='selected and deleted paths'

# Run the collector tests.
function main() {

  cd "$(git rev-parse --show-toplevel)"
  source ./scripts/tests/test.lib.sh

  # The caller's options must not reach the code under test
  unset -v GITHUB_BASE_REF BRANCH_NAME QUALITY_PR_BASE

  test-run-suite \
    test-quality-collect-git-files-all-selects-existing-tracked-files \
    test-quality-collect-git-files-empty-pathspec-selects-every-path \
    test-quality-collect-git-files-keeps-awkward-names-intact \
    test-quality-collect-git-files-staged-changes-lists-a-rename-as-deleted-and-added \
    test-quality-collect-git-files-staged-changes-skips-a-file-deleted-only-from-the-index \
    test-quality-collect-git-files-working-tree-changes-lists-a-deleted-file \
    test-quality-collect-git-files-branch-lists-a-deleted-file \
    test-quality-collect-git-files-ignores-deletions-without-a-deleted-array \
    test-quality-collect-git-files-rejects-an-unknown-mode

  return 0
}

# Create "$TEST_TMP/repo" with the collector libraries and the given files,
# each containing its own name, committed on main with origin/main at it.
# Arguments:
#   $@=[content files to create, relative to the repository]
function git-files-test-create-repo() {

  local repo="$TEST_TMP/repo" file
  test-create-repo "$repo" scripts/quality/git-files.lib.sh scripts/quality/git-base.lib.sh
  for file in "$@"; do
    test-mkdir-parent "$repo/$file"
    printf '%s\n' "$file" > "$repo/$file"
  done
  git -C "$repo" add -A
  git -C "$repo" commit -q -m fixture
  git -C "$repo" update-ref refs/remotes/origin/main HEAD

  return 0
}

# Collect paths in the current repository and print each selected and deleted
# path on its own line, quoted with printf %q.
# Arguments:
#   $1=[check mode]
#   $2=[Git pathspec, empty for every path]
#   $3=[optional 'deleted' to also collect deleted paths]
function git-files-test-collect() {

  local -a selected=() deleted=()
  local path
  source ./scripts/quality/git-files.lib.sh
  if [[ "${3:-}" == deleted ]]; then
    quality-collect-git-files selected "$1" "$2" deleted || return "$?"
  else
    quality-collect-git-files selected "$1" "$2" || return "$?"
  fi
  for path in "${selected[@]}"; do
    printf 'selected %q\n' "$path"
  done
  for path in "${deleted[@]}"; do
    printf 'deleted %q\n' "$path"
  done

  return 0
}

# ==============================================================================

function test-quality-collect-git-files-all-selects-existing-tracked-files() {

  # Arrange
  git-files-test-create-repo docs/a.md docs/gone.md b.txt
  cd "$TEST_TMP/repo"
  printf 'generated/\n' > .gitignore
  mkdir -p generated
  printf 'ignored\n' > generated/ignored.md
  printf 'untracked\n' > docs/untracked.md
  rm docs/gone.md
  # Act
  test-capture git-files-test-collect all '*.md' deleted
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "selected docs/a.md" "$TEST_STDOUT" "$SELECTION_LABEL"

  return 0
}

function test-quality-collect-git-files-empty-pathspec-selects-every-path() {

  # Arrange
  git-files-test-create-repo a.md b.txt
  cd "$TEST_TMP/repo"
  printf 'changed\n' > a.md
  printf 'changed\n' > b.txt
  # Act
  test-capture git-files-test-collect working-tree-changes ''
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal $'selected a.md\nselected b.txt' "$TEST_STDOUT" "$SELECTION_LABEL"

  return 0
}

function test-quality-collect-git-files-keeps-awkward-names-intact() {

  # Arrange
  local -a names=(-dash.md 'space name.md' 'notes[draft].md' café.md $'new\nline.md')
  local name expected=''
  git-files-test-create-repo "${names[@]}"
  cd "$TEST_TMP/repo"
  for name in "${names[@]}"; do
    printf 'changed\n' > "./$name"
  done
  # Act
  test-capture git-files-test-collect working-tree-changes '*.md' deleted
  # Assert
  for name in ./-dash.md café.md $'new\nline.md' 'notes[draft].md' 'space name.md'; do
    expected+="$(printf 'selected %q' "$name")"$'\n'
  done
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "${expected%$'\n'}" "$TEST_STDOUT" "$SELECTION_LABEL"

  return 0
}

function test-quality-collect-git-files-staged-changes-lists-a-rename-as-deleted-and-added() {

  # Arrange
  git-files-test-create-repo docs/old.md
  cd "$TEST_TMP/repo"
  git mv docs/old.md docs/new.md
  # Act
  test-capture git-files-test-collect staged-changes '*.md' deleted
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal $'selected docs/new.md\ndeleted docs/old.md' "$TEST_STDOUT" "$SELECTION_LABEL"

  return 0
}

function test-quality-collect-git-files-staged-changes-skips-a-file-deleted-only-from-the-index() {

  # Arrange
  git-files-test-create-repo docs/a.md docs/b.md
  cd "$TEST_TMP/repo"
  git rm -q --cached docs/a.md
  printf 'changed\n' > docs/b.md
  git add docs/b.md
  # Act
  test-capture git-files-test-collect staged-changes '*.md' deleted
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-file-exists docs/a.md
  assert-equal $'selected docs/b.md\ndeleted docs/a.md' "$TEST_STDOUT" "$SELECTION_LABEL"

  return 0
}

function test-quality-collect-git-files-working-tree-changes-lists-a-deleted-file() {

  # Arrange
  git-files-test-create-repo docs/a.md docs/b.md
  cd "$TEST_TMP/repo"
  rm docs/a.md
  printf 'changed\n' > docs/b.md
  # Act
  test-capture git-files-test-collect working-tree-changes '*.md' deleted
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal $'selected docs/b.md\ndeleted docs/a.md' "$TEST_STDOUT" "$SELECTION_LABEL"

  return 0
}

function test-quality-collect-git-files-branch-lists-a-deleted-file() {

  # Arrange
  git-files-test-create-repo docs/a.md docs/b.md docs/c.md
  cd "$TEST_TMP/repo"
  git switch -q -c feature
  git rm -q docs/a.md
  printf 'changed\n' > docs/b.md
  git commit -q -am change
  # Act
  BRANCH_NAME=main test-capture git-files-test-collect branch '*.md' deleted
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal $'selected docs/b.md\ndeleted docs/a.md' "$TEST_STDOUT" "$SELECTION_LABEL"

  return 0
}

function test-quality-collect-git-files-ignores-deletions-without-a-deleted-array() {

  # Arrange
  local mode
  git-files-test-create-repo docs/a.md docs/b.md
  cd "$TEST_TMP/repo"
  git rm -q --cached docs/a.md
  rm docs/b.md
  # Act and assert
  for mode in staged-changes working-tree-changes; do
    test-capture git-files-test-collect "$mode" '*.md'
    assert-equal 0 "$TEST_STATUS" "$mode $EXIT_STATUS_LABEL"
    assert-equal "" "$TEST_STDOUT" "$mode $SELECTION_LABEL"
  done

  return 0
}

function test-quality-collect-git-files-rejects-an-unknown-mode() {

  # Arrange
  git-files-test-create-repo a.md
  cd "$TEST_TMP/repo"
  # Act
  test-capture git-files-test-collect bogus ''
  # Assert
  assert-equal 126 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "Use check=all, check=staged-changes, check=working-tree-changes, check=branch" "accepted modes"
  assert-equal "" "$TEST_STDOUT" "$SELECTION_LABEL"

  return 0
}

# ==============================================================================

main "$@"
