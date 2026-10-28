#!/usr/bin/env bash

set -euo pipefail

# Validate GitHub Actions workflows and local actions against the repository's
# security baseline. A file that cannot be parsed or evaluated fails the check.
#
# Usage:
#   $ [options] ./scripts/quality/check-workflow-security.sh
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
#       is 'scripts/config/workflow-security.yaml'
#   VERBOSE=true
#       Show all the executed commands, default is 'false'
#
# Exit codes:
#   0 - All selected files meet the security baseline, or a scoped mode
#       selected no files
#   1 - A file violates the security baseline or cannot be checked, 'all'
#       mode finds no tracked workflow files, or the branch to compare with is
#       not found
#   126 - The check mode is not recognised
#
# Notes:
#   1) Check modes select existing files known to Git, as described in
#      './scripts/quality/git-files.lib.sh'. Untracked files are never checked.
#   2) A scoped mode that changes or deletes the allowlist, the rules in
#      check-workflow-security.jq or this script checks every workflow and
#      local action, since they apply to all of them.
#   3) Each rule is a 'rule_*' function in check-workflow-security.jq, with a
#      plain-language summary and an example of passing and failing YAML.
#   4) The check needs yq and jq from 'make config'. It has no Docker fallback.

# ==============================================================================

# Check the selected workflows and local actions against the security baseline.
function main() {

  cd "$(git rev-parse --show-toplevel)"

  local check_mode=${check:-all}
  local dir=${dir:-.github/workflows}
  local actions_dir=${actions_dir:-.github/actions}
  local allowlist=${allowlist:-scripts/config/workflow-security.yaml}
  local approved file tool failed=0
  local -a workflows=() actions=()

  for tool in yq jq; do
    command -v "$tool" > /dev/null 2>&1 || {
      echo "ERROR: $tool is required to validate workflow security, run 'make config'" >&2
      return 1
    }
  done
  dir="$(workflow-security-relative-path "$dir")"
  actions_dir="$(workflow-security-relative-path "$actions_dir")"
  allowlist="$(workflow-security-relative-path "$allowlist")"
  [[ -d "$dir" ]] || {
    echo "ERROR: workflow directory does not exist: $dir" >&2
    return 1
  }

  # shellcheck disable=SC1091
  source ./scripts/quality/git-files.lib.sh
  collect-workflow-security-files workflows actions "$check_mode" "$dir" "$actions_dir" "$allowlist" || return "$?"
  [[ "$check_mode" != all || ${#workflows[@]} -gt 0 ]] || {
    echo "ERROR: no tracked workflow files found under $dir" >&2
    return 1
  }
  approved="$(workflow-security-approved-writes "$allowlist")" || return 1

  for file in "${workflows[@]}"; do
    workflow-security-check "$file" workflow "${file#"$dir"/}" "$approved" || failed=1
  done
  for file in "${actions[@]}"; do
    workflow-security-check "$file" action "${file#"$actions_dir"/}" "[]" || failed=1
  done

  [[ $failed -eq 0 ]] || return 1

  return 0
}

# Print a path relative to the repository root, the current directory.
# Arguments:
#   $1=[path, relative or absolute]
function workflow-security-relative-path() {

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
function collect-workflow-security-files() {

  # shellcheck disable=SC2178
  local -n workflow_files="$1" action_files="$2" || return "$?"
  local check_mode="$3" dir="$4" actions_dir="$5" allowlist="$6" path
  local -a selected=() deleted=()
  # One call without a pathspec, so branch mode resolves its base only once
  quality-collect-git-files selected "$check_mode" '' deleted || return "$?"
  if [[ "$check_mode" != all ]]; then
    for path in "${selected[@]}" "${deleted[@]}"; do
      case $path in
        "$allowlist" | scripts/quality/check-workflow-security.jq | scripts/quality/check-workflow-security.sh) ;;
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
function workflow-security-approved-writes() {

  local allowlist="$1"

  if [[ ! -e "$allowlist" ]]; then
    echo "[]"
    return 0
  fi
  yq -o=json '.approved_write_permissions // []' "$allowlist" \
    | jq -c 'if type == "array" and all(.[]; type == "object") then . else error("invalid allowlist") end' || {
    echo "ERROR: approved_write_permissions in $allowlist must be a list of mappings" >&2
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
function workflow-security-check() {

  local file="$1" kind="$2" path="$3" approved="$4" json violations violation

  # yq reports the line and column of a YAML syntax error on stderr
  if ! json="$(yq -o=json 'explode(.)' "$file")" \
    || ! jq -e 'type == "object"' <<< "$json" > /dev/null 2>&1; then
    workflow-security-error "$file" "file is not a valid YAML mapping"
    return 1
  fi
  if ! violations="$(jq -r --arg kind "$kind" --arg path "$path" --argjson approved "$approved" \
    -f ./scripts/quality/check-workflow-security.jq <<< "$json")"; then
    workflow-security-error "$file" "file cannot be evaluated against the security baseline"
    return 1
  fi
  [[ -n "$violations" ]] || return 0

  while IFS= read -r violation; do
    workflow-security-error "$file" "$violation"
  done <<< "$violations"

  return 1
}

# Print a workflow security policy error.
# Arguments:
#   $1=[workflow or local action file]
#   $2=[policy failure]
function workflow-security-error() {

  local file="$1" message="$2"
  printf 'ERROR: %s: %s\n' "$file" "$message" >&2

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
