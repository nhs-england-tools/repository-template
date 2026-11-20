#!/usr/bin/env bash

set -euo pipefail

# Check offline security readiness for workflows, local actions, ownership,
# review dates, security policy, contribution guidance and approved licences.
# Governance owns the rules. Uncheckable files fail the check.
#
# Usage:
#   $ [options] ./scripts/quality/check-security-readiness.sh
#
# Options:
#   check={all,staged-changes,working-tree-changes,branch}
#       Check mode, default is 'all'
#   BRANCH_NAME=base-branch
#       Local base for branch mode, chosen automatically when unset, as
#       './scripts/quality/git-base.lib.sh' describes
#   dir=path
#       Directory of workflow files, relative to the repository root, default
#       is '.github/workflows'
#   actions_dir=path
#       Directory of local actions, relative to the repository root, default
#       is '.github/actions'
#   allowlist=path
#       Approved write permissions, relative to the repository root, default
#       is 'scripts/config/security-readiness.yaml'
#   VERBOSE=true
#       Show all the executed commands, default is 'false'
#
# Exit codes:
#   0 - All selected files and repository-wide checks pass, possibly with
#       non-fatal review-date or template-adoption warnings
#   1 - A file violates the security baseline or cannot be checked, 'all'
#       mode finds no tracked workflow files, or the branch to compare with is
#       not found
#   126 - The check mode is not recognised
#
# Notes:
#   1) Check modes select workflows and actions known to Git, as described in
#      './scripts/quality/git-files.lib.sh'. Untracked files are never checked.
#   2) A scoped mode that changes or deletes the allowlist, the rules in
#      check-security-readiness.jq or this script checks every workflow and
#      local action, since they apply to all of them.
#   3) Each rule is a 'rule_*' function in check-security-readiness.jq, with a
#      plain-language summary and an example of passing and failing YAML.
#   4) The check needs yq and jq from 'make config'. It has no Docker fallback.
#   5) Every mode checks the tracked '.github/CODEOWNERS' using today's UTC
#      date. Its single '# Review-by: YYYY-MM-DD' must be no more than one
#      calendar year ahead. Warn from one month before due and fail the day
#      after due. Month-end shifts clamp to the last valid day.
#   6) Repository files are always checked, even in unchanged scoped runs.
#      Approved licences are hardcoded governance policy. Keep this checker
#      aligned with security readiness on the engineering dashboard.

# ==============================================================================

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/../cicd/github-actions.lib.sh"
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/git-files.lib.sh"

SECURITY_READINESS_DOCKER_OPT_OUT=0

# Check the repository baseline, selected workflows and local actions.
function main() {

  cd "$(git rev-parse --show-toplevel)"

  local check_mode=${check:-all}
  local dir=${dir:-.github/workflows}
  local actions_dir=${actions_dir:-.github/actions}
  local allowlist=${allowlist:-scripts/config/security-readiness.yaml}
  local approved file tool failed=0
  local -a workflows=() actions=()

  SECURITY_READINESS_DOCKER_OPT_OUT=0
  is-arg-true "${FORCE_USE_DOCKER:-true}" || SECURITY_READINESS_DOCKER_OPT_OUT=1

  for tool in yq jq date; do
    command -v "$tool" > /dev/null 2>&1 || {
      print-diagnostic error "$tool is required to validate security readiness, run 'make config'"
      return 1
    }
  done
  dir="$(security-readiness-relative-path "$dir")"
  actions_dir="$(security-readiness-relative-path "$actions_dir")"
  allowlist="$(security-readiness-relative-path "$allowlist")"
  [[ -d "$dir" ]] || {
    print-diagnostic error "workflow directory does not exist: $dir"
    return 1
  }

  collect-security-readiness-files workflows actions "$check_mode" "$dir" "$actions_dir" "$allowlist" || return "$?"
  [[ "$check_mode" != all || ${#workflows[@]} -gt 0 ]] || {
    print-diagnostic error "no tracked workflow files found under $dir"
    failed=1
  }
  approved="$(security-readiness-approved-writes "$allowlist")" || {
    approved='[]'
    failed=1
  }

  security-readiness-check-repository || failed=1
  for file in "${workflows[@]}"; do
    security-readiness-check "$file" workflow "${file#"$dir"/}" "$approved" || failed=1
  done
  for file in "${actions[@]}"; do
    security-readiness-check "$file" action "${file#"$actions_dir"/}" "[]" || failed=1
  done

  if [[ $SECURITY_READINESS_DOCKER_OPT_OUT -eq 1 ]]; then
    print-diagnostic warning "FORCE_USE_DOCKER=false opts out of container isolation when native tools are available. Set FORCE_USE_DOCKER=true for the recommended, more secure setup."
  fi

  [[ $failed -eq 0 ]] || return 1

  return 0
}

# Print a path relative to the repository root, the current directory.
# Arguments:
#   $1=[path, relative or absolute]
function security-readiness-relative-path() {

  local path="${1%/}"
  path="${path#"$PWD"/}"
  printf '%s\n' "${path#./}"

  return 0
}

# Collect the workflow and local action files that a check mode selects.
# Arguments:
#   $1=[name reference of the output workflow files]
#   $2=[name reference of the output local action files]
#   $3=[check mode]
#   $4=[workflow directory]
#   $5=[local actions directory]
#   $6=[allowlist file]
function collect-security-readiness-files() {

  # shellcheck disable=SC2178
  local -n workflow_files="$1" action_files="$2" || return "$?"
  local check_mode="$3" dir="$4" actions_dir="$5" allowlist="$6" path
  local -a selected=() deleted=()
  # One call without a pathspec, so branch mode resolves its base only once
  quality-collect-git-files selected "$check_mode" '' deleted || return "$?"
  if [[ "$check_mode" != all ]]; then
    for path in "${selected[@]}" "${deleted[@]}"; do
      case $path in
        "$allowlist" | scripts/quality/check-security-readiness.jq | scripts/quality/check-security-readiness.sh) ;;
        *) continue ;;
      esac
      selected=()
      quality-collect-git-files selected all '' || return "$?"
      break
    done
  fi
  for path in "${selected[@]}"; do
    case $path in
      "$dir"/*.yaml|"$dir"/*.yml) workflow_files+=("$path") ;;
      "$actions_dir"/action.yaml|"$actions_dir"/action.yml|"$actions_dir"/*/action.yaml|"$actions_dir"/*/action.yml)
        action_files+=("$path")
        ;;
      *) ;;
    esac
  done

  return 0
}

# Print the approved write permissions as a compact JSON array.
# Arguments:
#   $1=[allowlist file, a missing file approves no write permissions]
function security-readiness-approved-writes() {

  local allowlist="$1"

  if [[ ! -e "$allowlist" ]]; then
    echo "[]"
    return 0
  fi
  yq -o=json '.approved_write_permissions // []' "$allowlist" \
    | jq -c 'if type == "array" and all(.[]; type == "object") then . else error("invalid allowlist") end' || {
    print-diagnostic error "approved_write_permissions in $allowlist must be a list of mappings"
    return 1
  }

  return 0
}

# Check one workflow or local action file and report every violated rule.
# Arguments:
#   $1=[file to check]
#   $2=[kind of file, either 'workflow' or 'action']
#   $3=[file path relative to its scan directory, used for scoped rules]
#   $4=[approved write permissions as a JSON array]
function security-readiness-check() {

  local file="$1" kind="$2" path="$3" approved="$4" json violations violation failed=0

  # yq reports the line and column of a YAML syntax error on stderr
  if ! json="$(yq -o=json 'explode(.)' "$file")" \
    || ! jq -e 'type == "object"' <<< "$json" > /dev/null 2>&1; then
    security-readiness-error "$file" "file is not a valid YAML mapping"
    return 1
  fi
  if ! violations="$(jq -r -L scripts/quality --arg kind "$kind" --arg path "$path" --argjson approved "$approved" \
    'include "check-security-readiness"; yaml_diagnostics($kind; $path; $approved)' <<< "$json")"; then
    security-readiness-error "$file" "file cannot be evaluated against the security baseline"
    return 1
  fi
  [[ -n "$violations" ]] || return 0

  while IFS= read -r violation; do
    if [[ "$violation" == WARNING:* ]]; then
      SECURITY_READINESS_DOCKER_OPT_OUT=1
    else
      security-readiness-error "$file" "$violation"
      failed=1
    fi
  done <<< "$violations"

  return "$failed"
}

# Print a security readiness policy error.
# Arguments:
#   $1=[workflow or local action file]
#   $2=[policy failure]
function security-readiness-error() {

  local file="$1" message="$2"
  print-diagnostic error "$file: $message"

  return 0
}

# Check baseline files and warn about unfinished template adoption.
function security-readiness-check-repository() {

  local kind file today failed=0
  if ! today="$(date -u +%F)"; then
    security-readiness-error .github/CODEOWNERS "cannot determine today's UTC date"
    return 1
  fi

  for kind in codeowners security contributing licence makefile readme conduct; do
    case "$kind" in
      codeowners) file="$(security-readiness-find-file .github/CODEOWNERS)" ;;
      security) file="$(security-readiness-find-file SECURITY.md .github/SECURITY.md docs/SECURITY.md)" ;;
      contributing) file="$(security-readiness-find-file CONTRIBUTING.md .github/CONTRIBUTING.md docs/CONTRIBUTING.md)" ;;
      licence) file="$(security-readiness-find-file LICENCE.md LICENCE LICENSE LICENSE.md LICENSE.txt LICENCE.txt COPYING)" ;;
      makefile) file=Makefile ;;
      readme) file=README.md ;;
      conduct) file="$(security-readiness-find-file CODE_OF_CONDUCT.md .github/CODE_OF_CONDUCT.md docs/CODE_OF_CONDUCT.md)" ;;
      *) return 1 ;;
    esac
    case "$kind" in
      makefile | readme | conduct)
        git ls-files --error-unmatch -- "$file" > /dev/null 2>&1 || continue
        ;;
      *) ;;
    esac
    if [[ -z "$file" || ! -f "$file" || ! -r "$file" || -L "$file" ]] \
      || ! git ls-files --error-unmatch -- "$file" > /dev/null 2>&1; then
      print-diagnostic error "${file:-$kind}: a tracked, readable, regular $kind file is required"
      failed=1
      continue
    fi
    security-readiness-check-file "$kind" "$file" "$today" || failed=1
  done

  return "$failed"
}

# Print the first tracked candidate, preserving precedence for missing files.
# Arguments:
#   $@=[candidate paths in precedence order]
function security-readiness-find-file() {

  local file default="$1"
  for file in "$@"; do
    if git ls-files --error-unmatch -- "$file" > /dev/null 2>&1; then
      printf '%s\n' "$file"
      return 0
    fi
  done
  printf '%s\n' "$default"

  return 0
}

# Evaluate one file and print local diagnostics and CI annotations.
# Arguments:
#   $1=[kind of baseline file]
#   $2=[tracked file path]
#   $3=[today's UTC date]
function security-readiness-check-file() {

  local kind="$1" file="$2" today="$3" diagnostics level message failed=0

  if ! diagnostics="$(jq -nr -L scripts/quality --arg kind "$kind" --rawfile content "$file" --arg today "$today" \
    'include "check-security-readiness"; repository_diagnostics($kind; $content; $today)')"; then
    print-diagnostic error "$file: security readiness cannot be evaluated"
    return 1
  fi
  [[ -n "$diagnostics" ]] || return 0
  while IFS=$'\t' read -r level message; do
    if [[ "$level" == WARNING ]]; then
      print-diagnostic warning "$file: $message"
    else
      print-diagnostic error "$file: $message"
      failed=1
    fi
  done <<< "$diagnostics"

  return "$failed"
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
