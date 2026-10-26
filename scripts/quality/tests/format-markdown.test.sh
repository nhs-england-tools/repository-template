#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034,SC2317,SC2329

set -euo pipefail

# Test suite for the Markdown formatter script. Each test runs the script
# in a scratch repository with 'prettier' and 'docker' stubbed, so the suite
# needs neither Prettier nor a Docker daemon.
#
# Usage:
#   $ ./scripts/quality/tests/format-markdown.test.sh
#
# Options:
#   VERBOSE=true  # Show all the executed commands, default is 'false'

# ==============================================================================

readonly EXIT_STATUS_LABEL='exit status'
readonly DOC_WITH_SPACE='docs/my doc.md'

# Set up the suite fixtures and run every test.
function main() {

  cd "$(git rev-parse --show-toplevel)"
  source ./scripts/tests/test.lib.sh
  source ./scripts/quality/tests/quality-test.lib.sh
  QUALITY_FIXTURE_PATHS=(scripts/quality/format-markdown.sh scripts/quality/git-files.lib.sh scripts/docker/docker.lib.sh scripts/config/prettierrc.yaml scripts/config/.prettierignore)
  QUALITY_FIXTURE_FORMAT='# %s\n'

  # The caller's options must not reach the script under test
  unset -v MISE_TOML match_version check BRANCH_NAME files FORCE_USE_DOCKER

  NODE_IMAGE=node:7.0.0-slim@sha256:7777777777777777777777777777777777777777777777777777777777777777
  PRETTIER_VERSION=8.0.0

  test-run-suite \
    test-format-markdown-does-nothing-without-markdown \
    test-format-markdown-rejects-unknown-mode \
    test-format-markdown-formats-existing-tracked-files \
    test-format-markdown-working-tree-and-staged-select-the-right-files \
    test-format-markdown-branch-uses-branch-name-and-skips-deleted-files \
    test-format-markdown-fails-when-the-base-branch-is-missing \
    test-format-markdown-propagates-git-file-list-failure \
    test-format-markdown-preserves-unusual-filenames \
    test-format-markdown-deduplicates-conflicted-index-paths \
    test-format-markdown-uses-docker-when-forced \
    test-format-markdown-uses-docker-when-prettier-is-missing \
    test-format-markdown-requires-an-exact-prettier-pin-in-docker \
    test-format-markdown-propagates-docker-run-failure \
    test-format-markdown-propagates-prettier-failure \
    test-format-markdown-stops-when-the-image-pull-fails

  return 0
}

# ==============================================================================

function test-format-markdown-does-nothing-without-markdown() {

  # Arrange
  quality-create-fixture-repo a.txt
  test-isolate-path
  test-stub prettier
  test-stub docker
  cd "$TEST_TMP/repo"
  # Act
  test-capture ./scripts/quality/format-markdown.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-stub-not-called prettier
  assert-stub-not-called docker

  return 0
}

function test-format-markdown-rejects-unknown-mode() {

  # Arrange
  quality-create-fixture-repo README.md
  test-isolate-path
  test-stub prettier
  cd "$TEST_TMP/repo"
  # Act
  test-capture env check=unknown ./scripts/quality/format-markdown.sh
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "Unrecognised check mode: unknown"
  assert-stub-not-called prettier

  return 0
}

function test-format-markdown-formats-existing-tracked-files() {

  # Arrange
  local r="$TEST_TMP/repo"
  quality-create-fixture-repo README.md "$DOC_WITH_SPACE" gone.md
  test-isolate-path
  test-stub prettier
  test-stub docker
  rm "$r/gone.md"
  cd "$r"
  # Act
  test-capture env check=all ./scripts/quality/format-markdown.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal \
    "--config $r/scripts/config/prettierrc.yaml --ignore-path $r/scripts/config/.prettierignore --write README.md docs/my\\ doc.md" \
    "$(test-stub-calls prettier)" "the only prettier call"
  assert-stub-not-called docker

  return 0
}

function test-format-markdown-working-tree-and-staged-select-the-right-files() {

  # Arrange
  local working_call staged_call
  quality-create-fixture-repo README.md "$DOC_WITH_SPACE"
  test-isolate-path
  test-stub prettier
  printf '%s\n' changed >> "$TEST_TMP/repo/README.md"
  printf '%s\n' changed >> "$TEST_TMP/repo/$DOC_WITH_SPACE"
  git -C "$TEST_TMP/repo" add "$DOC_WITH_SPACE"
  cd "$TEST_TMP/repo"
  # Act
  test-capture ./scripts/quality/format-markdown.sh
  working_call="$(test-stub-calls prettier | sed -n 1p)"
  test-capture env check=staged-changes ./scripts/quality/format-markdown.sh
  staged_call="$(test-stub-calls prettier | sed -n 2p)"
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$working_call" "README.md"
  assert-not-contains "$working_call" "docs/my\\ doc.md"
  assert-contains "$staged_call" "docs/my\\ doc.md"
  assert-not-contains "$staged_call" "README.md"

  return 0
}

function test-format-markdown-branch-uses-branch-name-and-skips-deleted-files() {

  # Arrange
  quality-create-fixture-repo README.md gone.md untouched.md
  test-isolate-path
  test-stub prettier
  git -C "$TEST_TMP/repo" update-ref refs/heads/other HEAD
  printf '%s\n' changed >> "$TEST_TMP/repo/README.md"
  git -C "$TEST_TMP/repo" add README.md
  git -C "$TEST_TMP/repo" commit -q -m change
  printf '%s\n' changed >> "$TEST_TMP/repo/untouched.md"
  git -C "$TEST_TMP/repo" update-ref -d refs/remotes/origin/main
  rm "$TEST_TMP/repo/gone.md"
  cd "$TEST_TMP/repo"
  # Act
  test-capture env check=branch BRANCH_NAME=other ./scripts/quality/format-markdown.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains " $(test-stub-calls prettier) " " README.md "
  assert-contains " $(test-stub-calls prettier) " " untouched.md "
  assert-not-contains "$(test-stub-calls prettier)" "gone.md"

  return 0
}

function test-format-markdown-fails-when-the-base-branch-is-missing() {

  # Arrange
  quality-create-fixture-repo README.md
  test-isolate-path
  test-stub prettier
  git -C "$TEST_TMP/repo" update-ref -d refs/remotes/origin/main
  cd "$TEST_TMP/repo"
  # Act
  test-capture env check=branch ./scripts/quality/format-markdown.sh
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "Branch to compare with not found: origin/main"
  assert-stub-not-called prettier

  return 0
}

function test-format-markdown-propagates-git-file-list-failure() {

  # Arrange
  quality-create-fixture-repo README.md
  test-isolate-path
  test-stub prettier
  # shellcheck disable=SC2016
  test-stub git 'if [[ "${1:-} ${2:-}" == "rev-parse --show-toplevel" ]]; then printf "%s\n" "$TEST_TMP/repo"; elif [[ "${1:-} ${2:-} ${3:-} ${4:-}" == "ls-files -z -- *.md" ]]; then echo "git: ls-files failed" >&2; exit 23; else echo "unexpected git call: $*" >&2; exit 1; fi'
  cd "$TEST_TMP/repo"
  # Act
  test-capture env check=all ./scripts/quality/format-markdown.sh
  # Assert
  assert-equal 23 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "git: ls-files failed"
  assert-stub-not-called prettier

  return 0
}

function test-format-markdown-preserves-unusual-filenames() {

  # Arrange
  local glob_file='docs/strange[1]*.md'
  local glob_match='docs/strange1-other.md'
  local newline_file=$'docs/line\nbreak.md'
  quality-create-fixture-repo README.md "$glob_file" "$glob_match" "$newline_file"
  test-isolate-path
  test-stub prettier
  cd "$TEST_TMP/repo"
  # Act
  test-capture env check=all ./scripts/quality/format-markdown.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$(test-stub-calls prettier)" "$(printf '%q' "$glob_file")"
  assert-contains "$(test-stub-calls prettier)" "$(printf '%q' "$glob_match")"
  assert-contains "$(test-stub-calls prettier)" "$(printf '%q' "$newline_file")"

  return 0
}

function test-format-markdown-deduplicates-conflicted-index-paths() {

  # Arrange
  quality-create-fixture-repo README.md
  test-isolate-path
  test-stub prettier
  local base_blob ours_blob theirs_blob null_oid
  base_blob="$(printf 'base\n' | git -C "$TEST_TMP/repo" hash-object -w --stdin)"
  ours_blob="$(printf 'ours\n' | git -C "$TEST_TMP/repo" hash-object -w --stdin)"
  theirs_blob="$(printf 'theirs\n' | git -C "$TEST_TMP/repo" hash-object -w --stdin)"
  null_oid="$(git -C "$TEST_TMP/repo" hash-object --stdin < /dev/null | sed 's/./0/g')"
  printf '0 %s\tREADME.md\n100644 %s 1\tREADME.md\n100644 %s 2\tREADME.md\n100644 %s 3\tREADME.md\n' \
    "$null_oid" "$base_blob" "$ours_blob" "$theirs_blob" |
    git -C "$TEST_TMP/repo" update-index --index-info
  cd "$TEST_TMP/repo"
  # Act
  test-capture env check=all ./scripts/quality/format-markdown.sh
  # Assert
  assert-equal 1 "$(test-stub-calls prettier | awk '{ count += gsub(/README\.md/, "&") } END { print count + 0 }')" \
    "number of formatter arguments for conflicted path"

  return 0
}

function test-format-markdown-uses-docker-when-forced() {

  # Arrange
  local options="--config /workdir/scripts/config/prettierrc.yaml --ignore-path /workdir/scripts/config/.prettierignore --write"
  quality-create-fixture-repo README.md "$DOC_WITH_SPACE" gone.md
  test-isolate-path
  test-stub prettier
  test-stub docker
  rm "$TEST_TMP/repo/gone.md"
  cd "$TEST_TMP/repo"
  # Act
  test-capture env check=all FORCE_USE_DOCKER=true ./scripts/quality/format-markdown.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-stub-not-called prettier
  assert-stub-called docker \
    "run --rm --platform linux/amd64 --volume $TEST_TMP/repo:/workdir --workdir /workdir $NODE_IMAGE npx --yes prettier@$PRETTIER_VERSION $options README.md docs/my\\ doc.md"
  quality-assert-one-docker-run

  return 0
}

function test-format-markdown-uses-docker-when-prettier-is-missing() {

  # Arrange
  quality-create-fixture-repo README.md
  test-isolate-path
  test-stub docker
  cd "$TEST_TMP/repo"
  # Act
  test-capture env check=all ./scripts/quality/format-markdown.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$(test-stub-calls docker | grep '^run ')" " $NODE_IMAGE npx --yes prettier@$PRETTIER_VERSION "
  quality-assert-one-docker-run

  return 0
}

function test-format-markdown-requires-an-exact-prettier-pin-in-docker() {

  # Arrange
  local pin
  quality-create-fixture-repo README.md
  test-isolate-path
  test-stub docker
  cd "$TEST_TMP/repo"
  for pin in '' '"npm:prettier" = "3"'; do
    printf '[tools]\n%s\n\n[_.docker]\n"node" = "%s"\n' "$pin" "${NODE_IMAGE#node:}" > mise.toml
    # Act
    test-capture env check=all FORCE_USE_DOCKER=true ./scripts/quality/format-markdown.sh
    # Assert
    assert-equal 1 "$TEST_STATUS" "exit status for the pin '$pin'"
    assert-contains "$TEST_STDERR" "no exact 'npm:prettier' version in the [tools] table"
  done
  assert-stub-not-called docker

  return 0
}

function test-format-markdown-propagates-docker-run-failure() {

  # Arrange
  quality-create-fixture-repo README.md
  test-isolate-path
  test-stub prettier
  # shellcheck disable=SC2016
  test-stub docker 'if [[ "${1:-}" == run ]]; then exit 19; fi'
  cd "$TEST_TMP/repo"
  # Act
  test-capture env check=all FORCE_USE_DOCKER=true ./scripts/quality/format-markdown.sh
  # Assert
  assert-equal 19 "$TEST_STATUS" "$EXIT_STATUS_LABEL"

  return 0
}

function test-format-markdown-propagates-prettier-failure() {

  # Arrange
  local r="$TEST_TMP/repo"
  quality-create-fixture-repo README.md
  test-isolate-path
  test-stub prettier 'exit 1'
  cd "$r"
  # Act
  test-capture env check=all ./scripts/quality/format-markdown.sh
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-stub-called prettier \
    "--config $r/scripts/config/prettierrc.yaml --ignore-path $r/scripts/config/.prettierignore --write README.md"

  return 0
}

function test-format-markdown-stops-when-the-image-pull-fails() {

  # Arrange
  quality-create-fixture-repo README.md
  test-isolate-path
  test-stub prettier
  # shellcheck disable=SC2016
  test-stub docker 'if [[ "${1:-} ${2:-}" == "image inspect" ]]; then exit 1; fi; if [[ "${1:-}" == pull ]]; then echo "docker: pull access denied" >&2; exit 23; fi'
  cd "$TEST_TMP/repo"
  # Act
  test-capture env check=all FORCE_USE_DOCKER=true ./scripts/quality/format-markdown.sh
  # Assert
  assert-equal 23 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "docker: pull access denied" "pull error on stderr"
  assert-equal "" "$(test-stub-calls docker | grep '^run ' || true)" "no docker run call"

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
