#!/usr/bin/env bash

set -euo pipefail

# Shared fixture functions for the quality check test suites, also used by the
# Dockerfile linter suite in scripts/docker/tests. Source it after the test
# harness, scripts/tests/test.lib.sh.
#
# Usage:
#   $ source ./scripts/quality/tests/quality-test.lib.sh
#
# Arguments (provided as global variables, set once by the suite):
#   QUALITY_FIXTURE_PATHS=(...)      # Paths of this repository to put in each scratch repository, the script under test and its libraries and config files
#   QUALITY_FIXTURE_FORMAT='# %s\n'  # printf format of each content file, given its name

# ==============================================================================

# Create the scratch repository "$TEST_TMP/repo" with QUALITY_FIXTURE_PATHS and
# the fixture mise.toml, add the given files, each containing its own name in
# QUALITY_FIXTURE_FORMAT, and commit them on main with origin/main pointing at that commit.
# Arguments:
#   $@=[content files to create, relative to the repository]
function quality-create-fixture-repo() {

  local repo="$TEST_TMP/repo" file
  test-create-repo "$repo" "${QUALITY_FIXTURE_PATHS[@]}"
  cp "$TEST_REPO_ROOT/scripts/quality/tests/mise.toml.test" "$repo/mise.toml"
  for file in "$@"; do
    mkdir -p "$repo/$(dirname "$file")"
    # shellcheck disable=SC2059
    printf "$QUALITY_FIXTURE_FORMAT" "$file" > "$repo/$file"
  done
  git -C "$repo" add -A
  git -C "$repo" commit -q -m fixture
  git -C "$repo" update-ref refs/remotes/origin/main HEAD

  return 0
}

# Fail unless the docker stub recorded exactly one 'run' call.
function quality-assert-one-docker-run() {

  assert-equal 1 "$(test-stub-calls docker | awk '/^run / { n++ } END { print n + 0 }')" "number of docker run calls"

  return 0
}
