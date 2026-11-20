#!/usr/bin/env bash

set -euo pipefail

# Report errors, warnings and notices as GitHub Actions annotations in a
# workflow run, and as local 'ERROR:', 'WARNING:' and 'NOTICE:' lines elsewhere.
#
# Usage:
#   $ source ./scripts/cicd/github-actions.lib.sh
#
# Arguments (provided as environment variables):
#   GITHUB_ACTIONS=true  # Set by the runner, any other value means local
#   NO_COLOR=1           # Disable local terminal colours when non-empty
#
# Notes:
#   1) Diagnostics always go to stderr, so a caller's captured stdout stays
#      unchanged.
#   2) Only the message is escaped. The annotation takes no properties, such
#      as 'title=' or 'file=', so a caller that adds them must escape them.
#   3) Local labels use ANSI colours only on a terminal unless NO_COLOR is set
#      or TERM is 'dumb'. Redirected output remains plain.

# ==============================================================================

# Print an error, warning or notice to stderr, as an annotation in GitHub
# Actions.
# Arguments:
#   $1=[level, 'error', 'warning' or 'notice']
#   $2=[message]
function print-diagnostic() {

  local level label colour message
  local percent='%' cr=$'\r' lf=$'\n'
  if [[ $# -ne 2 ]]; then
    print-diagnostic error "print-diagnostic needs a level and a message"
    return 1
  fi
  level="$1"
  message="$2"
  case $level in
    error) label=ERROR; colour=31 ;;
    warning) label=WARNING; colour=33 ;;
    notice) label=NOTICE; colour=34 ;;
    *)
      print-diagnostic error "Diagnostic level '$level' is not 'error', 'warning' or 'notice'"
      return 1
      ;;
  esac

  if [[ "${GITHUB_ACTIONS:-}" == true ]]; then
    # Quoted patterns stay literal, and '%' must be escaped first
    message="${message//"$percent"/%25}"
    message="${message//"$cr"/%0D}"
    message="${message//"$lf"/%0A}"
    printf '::%s::%s\n' "$level" "$message" >&2
  elif [[ -t 2 && -z "${NO_COLOR:-}" && "${TERM:-}" != dumb ]]; then
    printf '\033[%sm%s:\033[0m %s\n' "$colour" "$label" "$message" >&2
  else
    printf '%s: %s\n' "$label" "$message" >&2
  fi

  return 0
}
