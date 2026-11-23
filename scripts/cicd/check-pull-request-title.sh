#!/usr/bin/env bash

set -euo pipefail

# Check that a pull request title follows Conventional Commits, because the
# squash commit takes the title and semantic-release reads it to decide the
# next version. Also reject skip markers in the title and the description,
# because the squash commit would carry them to 'main' and stop the release
# workflow. A failure names the rule and how to fix it.
#
# Usage:
#   $ PR_TITLE='feat: add x' [options] \
#       ./scripts/cicd/check-pull-request-title.sh
#
# Options:
#   PR_TITLE='feat: add x'
#       Title of the pull request, required
#   PR_BODY='...'
#       Description of the pull request, default is none
#   GITHUB_STEP_SUMMARY=path
#       Job summary file that a failure also writes its guidance to, default is
#       none
#   VERBOSE=true
#       Show all the executed commands, default is 'false'
#
# Exit codes:
#   0 - The title is valid
#   1 - The title is not set or not valid, or a skip marker is present

# ==============================================================================

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/github-actions.lib.sh"

readonly TITLE_PATTERN='^(build|chore|ci|docs|feat|fix|perf|refactor|revert|style|test)(\([A-Za-z0-9._/-]+\))?!?: [^[:space:]]'
readonly TITLE_FORM="'type(scope)!: description', where type is build, chore, ci, docs, feat, fix, perf, refactor, revert, style or test, and the scope and '!' for a breaking change are optional"
readonly SKIP_MARKERS=('[skip ci]' '[ci skip]' '[no ci]' '[skip actions]' '[actions skip]')
readonly TITLE_GUIDE='See docs/guides/template/Publish_releases.md#name-your-pull-request'

# Check the title and the description, and report the first problem found.
function main() {

  local title="${PR_TITLE:-}" body="${PR_BODY:-}" message marker

  if [[ -z "$title" ]]; then
    message="PR_TITLE is not set, so there is no pull request title to check against Conventional Commits. Set it to a title of the form $TITLE_FORM, for example PR_TITLE='feat: add x'. $TITLE_GUIDE"
  elif ! [[ "$title" =~ $TITLE_PATTERN ]]; then
    message="The pull request title '$title' does not follow Conventional Commits, so the release cannot work out the next version from the squash commit. Rename it to the form $TITLE_FORM."
    message+=" $TITLE_GUIDE"
  elif marker="$(find-skip-marker "$title")"; then
    message="The pull request title contains the skip marker '$marker', so the squash commit can suppress the release or its workflow. Remove the marker from the title. $TITLE_GUIDE"
  elif marker="$(find-skip-marker "$body")"; then
    message="The pull request description contains the skip marker '$marker', so the squash commit can suppress the release or its workflow. Remove the marker from the description. $TITLE_GUIDE"
  else
    return 0
  fi

  print-diagnostic error "$message"
  write-summary "$message" || return "$?"

  return 1
}

# ==============================================================================

# Print the first skip marker the text contains, ignoring case, and fail when
# it contains none.
# Arguments:
#   $1=[text to search]
function find-skip-marker() {

  local text="${1,,}" marker
  local release_pattern='\[(skip[[:space:]]+release|release[[:space:]]+skip)\]'
  if [[ "$text" =~ $release_pattern ]]; then
    printf '%s\n' "${BASH_REMATCH[0]}"
    return 0
  fi
  for marker in "${SKIP_MARKERS[@]}"; do
    if [[ "$text" == *"$marker"* ]]; then
      printf '%s\n' "$marker"
      return 0
    fi
  done

  return 1
}

# Write the failure to the job summary when GITHUB_STEP_SUMMARY is set.
# Arguments:
#   $1=[failure message]
function write-summary() {

  local message="$1"
  [[ -n "${GITHUB_STEP_SUMMARY:-}" ]] || return 0
  # The group sends the shell's own redirection error to /dev/null
  if ! { printf '## Pull request title check failed\n\n%s\n' "$message" >> "$GITHUB_STEP_SUMMARY"; } 2> /dev/null; then
    print-diagnostic error "Cannot write the job summary to '$GITHUB_STEP_SUMMARY', so the guidance above shows only in the log. Check that its directory exists and can be written. $TITLE_GUIDE"
    return 1
  fi

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
