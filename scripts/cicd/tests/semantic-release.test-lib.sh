#!/usr/bin/env bash

set -euo pipefail

# Shared functions for the suites that run a real semantic-release against a
# local test remote. Source it after the test harness,
# scripts/tests/test.lib.sh, and call semantic-release-install from the
# suite's test-suite-setup.
#
# Usage:
#   $ source ./scripts/cicd/tests/semantic-release.test-lib.sh
#
# Arguments (provided as global variables, set by the caller):
#   RELEASE_ENV=(NAME=value ...)  # Variables semantic-release-run passes to
#                                 # the CLI through env, default is none

# ==============================================================================

readonly WORKFLOW_FILE=.github/workflows/cicd-2-publish.yaml

# Print a version pinned in the publish workflow, from the line that
# starts with the prefix or holds the package marker.
# Arguments:
#   $1=[line prefix after the indentation, or empty]
#   $2=[package marker before the version, or empty]
function workflow-pin() {

  local prefix="$1" marker="$2" version
  if [[ -n "$prefix" ]]; then
    version="$(sed -n "s/^ *$prefix\\([0-9][0-9.]*\\)\$/\\1/p" "$WORKFLOW_FILE")"
  else
    version="$(sed -n "s/^ *$marker\\([0-9][0-9.]*\\)\$/\\1/p" "$WORKFLOW_FILE")"
  fi
  if ! [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    print-diagnostic error "Cannot read the pin '$prefix$marker' from $WORKFLOW_FILE, so the pinned version is unknown. Keep it as an exact 'X.Y.Z' on its own line."
    return 1
  fi
  printf '%s\n' "$version"

  return 0
}

# Install the given package specs once into "$SUITE_TMP/npm", without running
# their install scripts. Return 77 when npm or node is missing or the install
# fails, for example without network access.
# Arguments:
#   $@=[npm package specs, each 'name@X.Y.Z']
function semantic-release-install() {

  if ! command -v npm > /dev/null || ! command -v node > /dev/null; then
    echo "PREREQUISITE: npm or node is not on PATH. Diagnose with: command -v npm node. The pinned plugins cannot run, so verification is unknown." >&2
    return 77
  fi
  mkdir -p "$SUITE_TMP/npm"
  if ! (cd "$SUITE_TMP/npm" && npm install --no-save --no-audit --no-fund --ignore-scripts \
    --loglevel=error "$@" > "$SUITE_TMP/npm.log" 2>&1); then
    sed 's/^/    /' "$SUITE_TMP/npm.log" >&2
    echo "PREREQUISITE: npm cannot install $*, for example without network access. Diagnose with: npm view $1 version. Verification is unknown." >&2
    return 77
  fi

  return 0
}

# Run the installed semantic-release outside CI mode against a test remote.
# GITHUB_ACTIONS, CI, GITHUB_TOKEN and GH_TOKEN are unset unless RELEASE_ENV
# sets them.
# Arguments:
#   $1=[repository path]
#   $2=[remote URL]
#   $@=[extra CLI arguments, for example '--dry-run']
function semantic-release-run() {

  local repo="$1" url="$2"
  shift 2
  cd "$repo"
  env -u GITHUB_ACTIONS -u CI -u GITHUB_TOKEN -u GH_TOKEN ${RELEASE_ENV[@]+"${RELEASE_ENV[@]}"} \
    node "$SUITE_TMP/npm/node_modules/semantic-release/bin/semantic-release.js" \
    --no-ci --repository-url "$url" "$@" || return "$?"

  return 0
}
