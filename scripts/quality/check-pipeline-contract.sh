#!/usr/bin/env bash

set -euo pipefail

# Validate GitHub Actions workflows against the repository's pipeline
# contract, the delivery rules every CI/CD pipeline must keep. A file that
# cannot be parsed or evaluated fails the check.
#
# Usage:
#   $ [options] ./scripts/quality/check-pipeline-contract.sh
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
#   VERBOSE=true
#       Show all the executed commands, default is 'false'
#
# Exit codes:
#   0 - All selected workflows meet the pipeline contract, or a scoped mode
#       selected no files
#   1 - A workflow breaks the contract or cannot be checked, 'all' mode finds
#       no tracked workflow files, or the branch to compare with is not found
#   126 - The check mode is not recognised
#
# Notes:
#   1) Check modes select existing files known to Git, as described in
#      './scripts/quality/git-files.lib.sh'. Untracked files are never checked.
#   2) A scoped mode that changes or deletes the rules in
#      check-pipeline-contract.jq or this script checks every workflow.
#   3) Each rule is a 'rule_*' function in check-pipeline-contract.jq, with a
#      plain-language summary and an example of passing and failing YAML.
#   4) The check needs yq and jq from 'make config'. It has no Docker fallback.

# ==============================================================================

# Check the selected workflows against the pipeline contract.
function main() {

  cd "$(git rev-parse --show-toplevel)"

  local check_mode=${check:-all}
  local dir=${dir:-.github/workflows}
  local file tool failed=0
  local -a workflows=()

  for tool in yq jq; do
    command -v "$tool" > /dev/null 2>&1 || {
      echo "ERROR: $tool is required to validate the pipeline contract, run 'make config'" >&2
      return 1
    }
  done
  dir="${dir%/}"
  dir="${dir#"$PWD"/}"
  dir="${dir#./}"
  [[ -d "$dir" ]] || {
    echo "ERROR: workflow directory does not exist: $dir" >&2
    return 1
  }

  # shellcheck disable=SC1091
  source ./scripts/quality/git-files.lib.sh
  collect-pipeline-contract-files workflows "$check_mode" "$dir" || return "$?"
  [[ "$check_mode" != all || ${#workflows[@]} -gt 0 ]] || {
    echo "ERROR: no tracked workflow files found under $dir" >&2
    return 1
  }

  for file in "${workflows[@]}"; do
    pipeline-contract-check "$file" "${file#"$dir"/}" || failed=1
  done

  [[ $failed -eq 0 ]] || return 1

  return 0
}

# Collect the workflow files that a check mode selects.
# Arguments:
#   $1=[name reference of the output workflow files]
#   $2=[check mode]
#   $3=[workflow directory]
function collect-pipeline-contract-files() {

  # shellcheck disable=SC2178
  local -n workflow_files="$1" || return "$?"
  local check_mode="$2" dir="$3" path
  local -a selected=() deleted=()
  # One call without a pathspec, so branch mode resolves its base only once
  quality-collect-git-files selected "$check_mode" '' deleted || return "$?"
  if [[ "$check_mode" != all ]]; then
    for path in "${selected[@]}" "${deleted[@]}"; do
      case $path in
        scripts/quality/check-pipeline-contract.jq | scripts/quality/check-pipeline-contract.sh) ;;
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
      *) ;;
    esac
  done

  return 0
}

# Check one workflow file and report every broken rule.
# Arguments:
#   $1=[file to check]
#   $2=[file path relative to the workflow directory, used for scoped rules]
function pipeline-contract-check() {

  local file="$1" path="$2" json violations violation

  # yq reports the line and column of a YAML syntax error on stderr
  if ! json="$(yq -o=json 'explode(.)' "$file")" \
    || ! jq -e 'type == "object"' <<< "$json" > /dev/null 2>&1; then
    pipeline-contract-error "$file" "file is not a valid YAML mapping"
    return 1
  fi
  if ! violations="$(jq -r --arg path "$path" \
    -f ./scripts/quality/check-pipeline-contract.jq <<< "$json")"; then
    pipeline-contract-error "$file" "file cannot be evaluated against the pipeline contract"
    return 1
  fi
  [[ -n "$violations" ]] || return 0

  while IFS= read -r violation; do
    pipeline-contract-error "$file" "$violation"
  done <<< "$violations"

  return 1
}

# Print a pipeline contract error.
# Arguments:
#   $1=[workflow file]
#   $2=[contract failure]
function pipeline-contract-error() {

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
