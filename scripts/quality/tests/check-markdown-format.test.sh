#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034,SC2317,SC2329

set -euo pipefail

# Test suite for the Markdown format check script. Each test runs the script
# in a scratch repository with 'markdownlint' and 'docker' stubbed, so the
# suite needs neither tool nor a Docker daemon. The frontmatter check runs the
# real python3.
#
# Usage:
#   $ ./scripts/quality/tests/check-markdown-format.test.sh
#
# Arguments (provided as environment variables):
#   VERBOSE=true  # Show all the executed commands, default is 'false'

# ==============================================================================

readonly MARKDOWN_HEADING='# Heading'
readonly EXIT_STATUS_LABEL='exit status'

function main() {

  cd "$(git rev-parse --show-toplevel)"
  source ./scripts/tests/test.lib.sh
  source ./scripts/quality/tests/quality-test.lib.sh
  QUALITY_FIXTURE_PATHS=(scripts/quality/check-markdown-format.sh scripts/docker/docker.lib.sh scripts/config/markdownlint.yaml scripts/config/.markdownlintignore)
  QUALITY_FIXTURE_FORMAT='# %s\n'

  # The caller's options must not reach the script under test
  unset -v MISE_TOML match_version check files BRANCH_NAME FORCE_USE_DOCKER

  MARKDOWNLINT_IMAGE=ghcr.io/igorshubovych/markdownlint-cli:v2.0.0@sha256:2222222222222222222222222222222222222222222222222222222222222222

  test-run-suite \
    test-check-markdown-format-rejects-unknown-mode \
    test-check-markdown-format-does-nothing-without-markdown-changes \
    test-check-markdown-format-all-passes-each-existing-file \
    test-check-markdown-format-working-tree-and-staged-select-the-right-files \
    test-check-markdown-format-branch-skips-deleted-files \
    test-check-markdown-format-fails-when-the-base-branch-is-missing \
    test-check-markdown-format-propagates-markdownlint-failure \
    test-check-markdown-format-uses-docker-when-forced \
    test-check-markdown-format-flags-missing-blank-line-after-frontmatter \
    test-check-markdown-format-accepts-valid-frontmatter-and-plain-files \
    test-check-markdown-format-warns-about-non-utf8-files \
    test-check-markdown-format-stops-when-the-image-pull-fails

  return 0
}

# ==============================================================================

function test-check-markdown-format-rejects-unknown-mode() {

  # Arrange
  quality-create-fixture-repo README.md
  test-isolate-path python3
  test-stub markdownlint
  test-stub docker
  cd "$TEST_TMP/repo"
  # Act
  test-capture env check=bogus ./scripts/quality/check-markdown-format.sh
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "Unrecognised check mode: bogus"
  assert-stub-not-called markdownlint
  assert-stub-not-called docker

  return 0
}

function test-check-markdown-format-does-nothing-without-markdown-changes() {

  # Arrange
  quality-create-fixture-repo README.md
  test-isolate-path python3
  test-stub markdownlint
  test-stub docker
  cd "$TEST_TMP/repo"
  # Act
  test-capture ./scripts/quality/check-markdown-format.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-stub-not-called markdownlint
  assert-stub-not-called docker

  return 0
}

function test-check-markdown-format-all-passes-each-existing-file() {

  # Arrange
  local options="--config $TEST_TMP/repo/scripts/config/markdownlint.yaml --ignore-path $TEST_TMP/repo/scripts/config/.markdownlintignore"
  quality-create-fixture-repo README.md "docs/my doc.md" gone.md
  test-isolate-path python3
  test-stub markdownlint
  rm "$TEST_TMP/repo/gone.md"
  cd "$TEST_TMP/repo"
  # Act
  test-capture env check=all ./scripts/quality/check-markdown-format.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "README.md docs/my\\ doc.md $options" "$(test-stub-calls markdownlint)" "the only markdownlint call"

  return 0
}

function test-check-markdown-format-working-tree-and-staged-select-the-right-files() {

  # Arrange
  local options="--config $TEST_TMP/repo/scripts/config/markdownlint.yaml --ignore-path $TEST_TMP/repo/scripts/config/.markdownlintignore"
  local working_tree_status
  quality-create-fixture-repo README.md "docs/my doc.md"
  test-isolate-path python3
  test-stub markdownlint
  echo changed >> "$TEST_TMP/repo/README.md"
  echo changed >> "$TEST_TMP/repo/docs/my doc.md"
  git -C "$TEST_TMP/repo" add "docs/my doc.md"
  cd "$TEST_TMP/repo"
  # Act
  test-capture env check=working-tree-changes ./scripts/quality/check-markdown-format.sh
  working_tree_status="$TEST_STATUS"
  test-capture env check=staged-changes ./scripts/quality/check-markdown-format.sh
  # Assert
  assert-equal 0 "$working_tree_status" "exit status of working-tree-changes"
  assert-equal 0 "$TEST_STATUS" "exit status of staged-changes"
  assert-equal "README.md $options" "$(test-stub-calls markdownlint | sed -n 1p)" "working-tree-changes call"
  assert-equal "docs/my\\ doc.md $options" "$(test-stub-calls markdownlint | sed -n 2p)" "staged-changes call"

  return 0
}

function test-check-markdown-format-branch-skips-deleted-files() {

  # Arrange
  quality-create-fixture-repo README.md gone.md
  test-isolate-path python3
  test-stub markdownlint
  echo changed >> "$TEST_TMP/repo/README.md"
  git -C "$TEST_TMP/repo" commit -q -am change
  rm "$TEST_TMP/repo/gone.md"
  cd "$TEST_TMP/repo"
  # Act
  test-capture env check=branch ./scripts/quality/check-markdown-format.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains " $(test-stub-calls markdownlint) " " README.md "
  assert-not-contains "$(test-stub-calls markdownlint)" "gone.md"

  return 0
}

function test-check-markdown-format-fails-when-the-base-branch-is-missing() {

  # Arrange
  quality-create-fixture-repo README.md
  test-isolate-path python3
  test-stub markdownlint
  echo changed >> "$TEST_TMP/repo/README.md"
  git -C "$TEST_TMP/repo" update-ref -d refs/remotes/origin/main
  cd "$TEST_TMP/repo"
  # Act
  test-capture env check=branch ./scripts/quality/check-markdown-format.sh
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "Branch to compare with not found: origin/main"
  assert-stub-not-called markdownlint

  return 0
}

function test-check-markdown-format-propagates-markdownlint-failure() {

  # Arrange
  quality-create-fixture-repo README.md
  test-isolate-path python3
  test-stub markdownlint 'exit 1'
  cd "$TEST_TMP/repo"
  # Act
  test-capture env check=all ./scripts/quality/check-markdown-format.sh
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"

  return 0
}

function test-check-markdown-format-uses-docker-when-forced() {

  # Arrange
  quality-create-fixture-repo README.md
  test-isolate-path python3
  test-stub markdownlint
  test-stub docker
  cd "$TEST_TMP/repo"
  # Act
  test-capture env FORCE_USE_DOCKER=true check=all ./scripts/quality/check-markdown-format.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-stub-not-called markdownlint
  assert-stub-called docker \
    "run --rm --platform linux/amd64 --volume $TEST_TMP/repo:/workdir --workdir /workdir $MARKDOWNLINT_IMAGE README.md --config /workdir/scripts/config/markdownlint.yaml --ignore-path /workdir/scripts/config/.markdownlintignore"
  quality-assert-one-docker-run

  return 0
}

function test-check-markdown-format-flags-missing-blank-line-after-frontmatter() {

  # Arrange
  quality-create-fixture-repo README.md
  test-isolate-path python3
  test-stub markdownlint
  printf '%s\n' '---' 'title: x' '---' "$MARKDOWN_HEADING" > "$TEST_TMP/repo/README.md"
  cd "$TEST_TMP/repo"
  # Act
  test-capture env check=all ./scripts/quality/check-markdown-format.sh
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "README.md:4: missing blank line after YAML frontmatter"

  return 0
}

function test-check-markdown-format-accepts-valid-frontmatter-and-plain-files() {

  # Arrange
  quality-create-fixture-repo valid.md plain.md unterminated.md
  test-isolate-path python3
  test-stub markdownlint
  printf '%s\n' '---' 'title: x' '---' '' "$MARKDOWN_HEADING" > "$TEST_TMP/repo/valid.md"
  printf '%s\n' "$MARKDOWN_HEADING" '' 'Text' > "$TEST_TMP/repo/plain.md"
  printf '%s\n' '---' 'title: x' "$MARKDOWN_HEADING" > "$TEST_TMP/repo/unterminated.md"
  cd "$TEST_TMP/repo"
  # Act
  test-capture env check=all ./scripts/quality/check-markdown-format.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "" "$TEST_STDERR" "stderr"

  return 0
}

function test-check-markdown-format-warns-about-non-utf8-files() {

  # Arrange
  quality-create-fixture-repo latin1.md
  test-isolate-path python3
  test-stub markdownlint
  printf 'caf\xe9\n' > "$TEST_TMP/repo/latin1.md"
  git -C "$TEST_TMP/repo" commit -q -am latin1
  cd "$TEST_TMP/repo"
  # Act
  test-capture env check=all ./scripts/quality/check-markdown-format.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "latin1.md: skipped, not valid UTF-8"

  return 0
}

function test-check-markdown-format-stops-when-the-image-pull-fails() {

  # Arrange
  quality-create-fixture-repo README.md
  test-isolate-path python3
  test-stub markdownlint
  # shellcheck disable=SC2016
  test-stub docker 'if [[ "${1:-} ${2:-}" == "image inspect" ]]; then exit 1; fi; if [[ "${1:-}" == pull ]]; then echo "docker: pull access denied" >&2; exit 23; fi'
  cd "$TEST_TMP/repo"
  # Act
  test-capture env FORCE_USE_DOCKER=true check=all ./scripts/quality/check-markdown-format.sh
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
