#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034,SC2317,SC2329

set -euo pipefail

# Test suite for the automatic loading of '*.ext.mk' Make extensions. Each test
# copies the core Makefiles into a scratch directory, adds fixture extensions
# under 'scripts/' and runs make there.
#
# Usage:
#   $ ./scripts/tests/make-extensions.test.sh
#
# Arguments (provided as environment variables):
#   VERBOSE=true  # Show all the executed commands, default is 'false'

# ==============================================================================

readonly EXIT_STATUS_LABEL='exit status'

function main() {

  cd "$(git rev-parse --show-toplevel)"
  source ./scripts/tests/test.lib.sh

  test-run-suite \
    test-make-runs-without-extensions \
    test-make-loads-root-and-nested-extensions \
    test-make-loads-symlinked-extensions \
    test-make-lists-extension-targets-in-help \
    test-make-ignores-other-mk-files \
    test-make-loads-extensions-in-sorted-order \
    test-make-loads-core-files-once \
    test-make-fails-on-a-malformed-extension

  return 0
}

# ==============================================================================

function test-make-runs-without-extensions() {

  # Arrange
  copy-core
  # Act
  run-make help
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDOUT" "Usage:"

  return 0
}

function test-make-loads-root-and-nested-extensions() {

  # Arrange
  copy-core
  write-extension scripts/root.ext.mk root-ext
  write-extension scripts/a/b/c/deep.ext.mk deep-ext
  # Act
  run-make root-ext deep-ext
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDOUT" "root-ext-ran"
  assert-contains "$TEST_STDOUT" "deep-ext-ran"

  return 0
}

function test-make-loads-symlinked-extensions() {

  # Arrange
  copy-core
  write-extension shared/linked.mk linked-ext
  ln -s ../shared/linked.mk "$TEST_TMP/tree/scripts/linked.ext.mk"
  # Act
  run-make linked-ext
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDOUT" "linked-ext-ran"

  return 0
}

function test-make-lists-extension-targets-in-help() {

  # Arrange
  copy-core
  write-extension scripts/team/team.ext.mk team-ext
  # Act
  run-make help
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDOUT" "team-ext"

  return 0
}

function test-make-ignores-other-mk-files() {

  # Arrange
  copy-core
  write-extension scripts/team/team.lib.mk lib-target
  write-extension scripts/team/plain.mk plain-target
  # Act and assert
  local target
  for target in lib-target plain-target; do
    run-make "$target"
    assert-equal 2 "$TEST_STATUS" "$EXIT_STATUS_LABEL for $target"
    assert-contains "$TEST_STDERR" "No rule to make target '$target'"
  done

  return 0
}

function test-make-loads-extensions-in-sorted-order() {

  # Arrange
  copy-core
  mkdir -p "$TEST_TMP/tree/scripts/b" "$TEST_TMP/tree/scripts/a"
  echo 'ORDER += b' > "$TEST_TMP/tree/scripts/b/b.ext.mk"
  echo 'ORDER += a' > "$TEST_TMP/tree/scripts/a/a.ext.mk"
  # shellcheck disable=SC2016 # '$(ORDER)' is a Make reference, not a shell one
  printf 'ORDER += root\nprint-order:\n\t@echo "order=$(ORDER)"\n' > "$TEST_TMP/tree/scripts/z.ext.mk"
  # Act
  run-make print-order
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDOUT" "order=a b root"

  return 0
}

function test-make-loads-core-files-once() {

  # Arrange
  copy-core
  write-extension scripts/team/team.ext.mk team-ext
  # Act
  run-make help
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-not-contains "$TEST_STDERR" "overriding recipe"

  return 0
}

function test-make-fails-on-a-malformed-extension() {

  # Arrange
  copy-core
  mkdir -p "$TEST_TMP/tree/scripts/broken"
  echo 'this is not make syntax' > "$TEST_TMP/tree/scripts/broken/broken.ext.mk"
  # Act
  run-make help
  # Assert
  assert-equal 2 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "broken.ext.mk"

  return 0
}

# ==============================================================================
# Helpers

# Copy the core Makefiles into the scratch tree, without any local extension.
function copy-core() {

  mkdir -p "$TEST_TMP/tree/scripts/docker"
  cp "$TEST_REPO_ROOT/Makefile" "$TEST_TMP/tree/"
  cp "$TEST_REPO_ROOT/scripts/init.mk" "$TEST_TMP/tree/scripts/"
  cp "$TEST_REPO_ROOT/scripts/docker/docker.mk" "$TEST_TMP/tree/scripts/docker/"

  return 0
}

# Write an extension file that defines one documented target.
# Arguments:
#   $1=[path relative to the scratch tree]
#   $2=[target name]
function write-extension() {

  local file="$TEST_TMP/tree/$1" target="$2"
  mkdir -p "$(dirname "$file")"
  printf '%s: # Fixture target @Others\n\techo %s-ran\n' "$target" "$target" > "$file"

  return 0
}

# Run make in the scratch tree.
# Arguments:
#   $@=[make goals]
function run-make() {

  test-capture make --no-print-directory -C "$TEST_TMP/tree" "$@"

  return 0
}

# ==============================================================================

main "$@"
