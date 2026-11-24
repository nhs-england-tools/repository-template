#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034,SC2317,SC2329

set -euo pipefail

# Integration test suite for the commit analyser and the release notes
# generator with the repository '.releaserc'. The setup installs
# semantic-release and the conventionalcommits preset at the versions pinned
# in the publish workflow, from the npm registry. Each test commits on
# 'main' and runs a real semantic-release dry run against a local test remote.
# The workflow does not pin these two plugins. npm resolves them from the
# version ranges that semantic-release declares.
#
# Usage:
#   $ ./scripts/cicd/tests/release-breaking-notes.test.sh
#
# Options:
#   VERBOSE=true  # Show all the executed commands, default is 'false'
#
# Exit codes:
#   77 - npm is missing or cannot install the pinned packages, for example
#        without network access, so nothing is verified

# ==============================================================================

source "$(dirname "${BASH_SOURCE[0]}")/../../tests/test.lib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/semantic-release.test-lib.sh"

readonly BREAKING_NOTE='drop the legacy widget API'

# Set up the suite and run every test.
function main() {

  cd "$(git rev-parse --show-toplevel)"

  # The caller's options must not reach the code under test
  unset -v GITHUB_ACTIONS BASE_BRANCH

  test-run-suite \
    test-hidden-chore-with-plural-breaking-footer-releases-major \
    test-hidden-chore-without-footer-releases-nothing

  return 0
}

# Install the pinned packages once for every test.
function test-suite-setup() {

  local semantic preset
  semantic="$(workflow-pin 'SEMANTIC_RELEASE_VERSION: ' '')" || return 1
  preset="$(workflow-pin '' 'conventional-changelog-conventionalcommits@')" || return 1
  semantic-release-install "semantic-release@$semantic" \
    "conventional-changelog-conventionalcommits@$preset" || return "$?"

  return 0
}

# ==============================================================================

function test-hidden-chore-with-plural-breaking-footer-releases-major() {

  # Arrange
  local notes
  release-set-up
  # Act
  release-plan 'chore: tidy the widget module' "BREAKING CHANGES: $BREAKING_NOTE"
  # Assert
  assert-equal 0 "$TEST_STATUS" "exit status: $TEST_STDERR"
  assert-contains "$TEST_STDOUT" 'The next release version is 2.0.0' 'next version'
  notes="$(release-notes 2.0.0)"
  assert-contains "$notes" '### ⚠ BREAKING CHANGES' 'release notes'
  assert-contains "$notes" "* $BREAKING_NOTE" 'release notes'

  return 0
}

function test-hidden-chore-without-footer-releases-nothing() {

  # Arrange
  release-set-up
  # Act
  release-plan 'chore: tidy the widget module' ''
  # Assert
  assert-equal 0 "$TEST_STATUS" "exit status: $TEST_STDERR"
  assert-contains "$TEST_STDOUT" 'There are no relevant changes, so no new version is released' 'no release'

  return 0
}

# ==============================================================================

# Create a repository with the release 'v1.0.0' on 'main' and the repository
# '.releaserc'.
function release-set-up() {

  test-isolate-path jq node
  git init -q -b main "$TEST_TMP/repo"
  cp .releaserc "$TEST_TMP/repo/.releaserc"
  git -C "$TEST_TMP/repo" add .releaserc
  git -C "$TEST_TMP/repo" commit -q -m 'feat: first release'
  git -C "$TEST_TMP/repo" tag v1.0.0

  return 0
}

# Commit on 'main' and run the analyser and notes generator against a local
# test remote, without invoking publishing plugins or the GitHub API.
# Arguments:
#   $1=[commit subject]
#   $2=[commit body]
function release-plan() {

  local subject="$1" body="$2" repo="$TEST_TMP/repo"
  printf 'tidy\n' > "$repo/widget.txt"
  git -C "$repo" add widget.txt
  git -C "$repo" commit -q -m "$subject" -m "$body"
  git clone -q --bare "$repo" "$TEST_TMP/mirror.git"
  jq '.plugins |= map(select((if type == "array" then .[0] else . end) as $name |
    ["@semantic-release/commit-analyzer", "@semantic-release/release-notes-generator"] | index($name)))' \
    "$repo/.releaserc" > "$TEST_TMP/releaserc"
  mv "$TEST_TMP/releaserc" "$repo/.releaserc"
  test-capture semantic-release-run "$repo" "file://$TEST_TMP/mirror.git" --dry-run

  return 0
}

# Print the notes the last dry run generated for a version, without the
# analyser log before them, so only the notes generator output is checked.
# Arguments:
#   $1=[version]
function release-notes() {

  local version="$1"
  sed -n "/Release note for version $version:\$/,\$p" <<< "$TEST_STDOUT" | tail -n +2

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
