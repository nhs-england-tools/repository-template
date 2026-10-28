#!/usr/bin/env bash

set -euo pipefail

# Validate GitHub Actions workflows and local actions against the repository's
# security baseline. A file that cannot be parsed or evaluated fails the check.
#
# Usage:
#   $ [options] ./scripts/quality/check-workflow-security.sh
#
# Options:
#   dir=path          # Directory of workflow files, default is
#                     # '.github/workflows'
#   actions_dir=path  # Directory of local actions, default is '.github/actions'
#   allowlist=path    # Approved write permissions, default is
#                     # 'scripts/config/workflow-security.yaml'
#   VERBOSE=true      # Show all the executed commands, default is 'false'
#
# Exit codes:
#   0 - All files meet the security baseline
#   1 - A file violates the security baseline or cannot be checked
#
# Notes:
#   1) Each rule is a 'rule_*' function in check-workflow-security.jq, with a
#      plain-language summary and an example of passing and failing YAML.
#   2) The check needs yq and jq from 'make config'. It has no Docker fallback.

# ==============================================================================

# Check every workflow and local action against the security baseline.
function main() {

  cd "$(git rev-parse --show-toplevel)"

  local dir=${dir:-.github/workflows}
  local actions_dir=${actions_dir:-.github/actions}
  local allowlist=${allowlist:-scripts/config/workflow-security.yaml}
  local approved file tool failed=0 checked=0

  for tool in yq jq; do
    command -v "$tool" > /dev/null 2>&1 || {
      echo "ERROR: $tool is required to validate workflow security, run 'make config'" >&2
      return 1
    }
  done
  dir="${dir%/}"
  actions_dir="${actions_dir%/}"
  [[ -d "$dir" ]] || {
    echo "ERROR: workflow directory does not exist: $dir" >&2
    return 1
  }
  approved="$(workflow-security-approved-writes "$allowlist")" || return 1

  while IFS= read -r -d '' file; do
    workflow-security-check "$file" workflow "${file#"$dir"/}" "$approved" || failed=1
    checked=$((checked + 1))
  done < <(find "$dir" -type f \( -name '*.yaml' -o -name '*.yml' \) -print0 | sort -z)
  [[ $checked -gt 0 ]] || {
    echo "ERROR: no workflow files found under $dir" >&2
    return 1
  }

  if [[ -d "$actions_dir" ]]; then
    while IFS= read -r -d '' file; do
      workflow-security-check "$file" action "${file#"$actions_dir"/}" "[]" || failed=1
    done < <(find "$actions_dir" -type f \( -name 'action.yaml' -o -name 'action.yml' \) -print0 | sort -z)
  fi

  [[ $failed -eq 0 ]] || return 1

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
