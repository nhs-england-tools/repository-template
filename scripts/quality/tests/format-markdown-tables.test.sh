#!/bin/bash
# shellcheck disable=SC1091,SC2034,SC2317,SC2329

set -euo pipefail

# Test suite for the Markdown table formatter script. Each test runs the script
# in a scratch repository with 'npx' and 'docker' stubbed, so the suite needs
# neither Node.js nor a Docker daemon.
#
# Usage:
#   $ ./scripts/quality/tests/format-markdown-tables.test.sh
#
# Arguments (provided as environment variables):
#   VERBOSE=true  # Show all the executed commands, default is 'false'

# ==============================================================================

function main() {

  cd "$(git rev-parse --show-toplevel)"
  source ./scripts/tests/test.lib.sh
  source ./scripts/quality/tests/quality-test.lib.sh
  QUALITY_FIXTURE_PATHS=(scripts/quality/format-markdown-tables.sh scripts/docker/docker.lib.sh scripts/config/prettierrc.yaml scripts/config/.prettierignore)
  QUALITY_FIXTURE_FORMAT='# %s\n'

  # The caller's options must not reach the script under test
  unset -v MISE_TOML match_version files FORCE_USE_DOCKER

  NODE_IMAGE=node:7.0.0-slim@sha256:7777777777777777777777777777777777777777777777777777777777777777

  test-run-suite \
    test-format-markdown-tables-does-nothing-without-markdown \
    test-format-markdown-tables-formats-existing-tracked-files \
    test-format-markdown-tables-uses-docker-when-forced \
    test-format-markdown-tables-propagates-npx-failure

  return 0
}

# ==============================================================================

function test-format-markdown-tables-does-nothing-without-markdown() {

  # Arrange
  quality-create-fixture-repo a.txt
  test-isolate-path
  test-stub npx
  test-stub docker
  cd "$TEST_TMP/repo"
  # Act
  test-capture ./scripts/quality/format-markdown-tables.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "exit status"
  assert-stub-not-called npx
  assert-stub-not-called docker

  return 0
}

function test-format-markdown-tables-formats-existing-tracked-files() {

  # Arrange
  local r="$TEST_TMP/repo"
  quality-create-fixture-repo README.md "docs/my doc.md" gone.md
  test-isolate-path
  test-stub npx
  test-stub docker
  rm "$r/gone.md"
  cd "$r"
  # Act
  test-capture ./scripts/quality/format-markdown-tables.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "exit status"
  assert-equal \
    "--yes prettier@3 --config $r/scripts/config/prettierrc.yaml --ignore-path $r/scripts/config/.prettierignore --write README.md docs/my\\ doc.md" \
    "$(test-stub-calls npx)" "the only npx call"
  assert-stub-not-called docker

  return 0
}

function test-format-markdown-tables-uses-docker-when-forced() {

  # Arrange
  local options="--config /workdir/scripts/config/prettierrc.yaml --ignore-path /workdir/scripts/config/.prettierignore --write"
  quality-create-fixture-repo README.md "docs/my doc.md" gone.md
  test-isolate-path
  test-stub npx
  test-stub docker
  rm "$TEST_TMP/repo/gone.md"
  cd "$TEST_TMP/repo"
  # Act
  test-capture env FORCE_USE_DOCKER=true ./scripts/quality/format-markdown-tables.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "exit status"
  assert-stub-not-called npx
  assert-stub-called docker \
    "run --rm --platform linux/amd64 --volume $TEST_TMP/repo:/workdir --workdir /workdir $NODE_IMAGE npx --yes prettier@3 $options README.md docs/my\\ doc.md"
  quality-assert-one-docker-run

  return 0
}

function test-format-markdown-tables-propagates-npx-failure() {

  # Arrange
  local r="$TEST_TMP/repo"
  quality-create-fixture-repo README.md
  test-isolate-path
  test-stub npx 'exit 1'
  cd "$r"
  # Act
  test-capture ./scripts/quality/format-markdown-tables.sh
  # Assert
  assert-equal 1 "$TEST_STATUS" "exit status"
  assert-stub-called npx \
    "--yes prettier@3 --config $r/scripts/config/prettierrc.yaml --ignore-path $r/scripts/config/.prettierignore --write README.md"

  return 0
}

# ==============================================================================

function is-arg-true() {

  if [[ "$1" =~ ^(true|yes|y|on|1|TRUE|YES|Y|ON)$ ]]; then
    return 0
  else
    return 1
  fi
}

# ==============================================================================

is-arg-true "${VERBOSE:-false}" && set -x

main "$@"

exit 0
