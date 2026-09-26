#!/bin/bash

set -euo pipefail

# Verify that the GNU-compatible tools this repository's own scripts rely on
# are the ones actually resolved on PATH, on any OS. Most Linux systems pass
# natively, but Debian and Ubuntu ship mawk as awk, so they need the gawk
# package. On macOS it catches the classic "brew install'd but the gnubin
# directory isn't on PATH" gap, since Homebrew installs GNU formulae under a
# 'g'-prefixed name (gsed, ggrep, ...) unless gnubin is added to PATH. See
# scripts/toolchain/install-gnu-macos.sh to fix a failing check on macOS.
# It also reports, but never installs, GNU make 3.82 or later and a Docker or
# Podman container runtime on PATH, since scripts/docker/docker.mk needs both.
#
# Usage:
#   $ ./verify-gnu.sh
#
# Options:
#   VERBOSE=true  # Show all the executed commands, default is 'false'
#
# Exit codes:
#   0 - Every checked tool resolves to its GNU implementation, make is 3.82 or
#       later, and a container runtime is on PATH
#   1 - At least one tool is missing, too old, or resolves to a non-GNU
#       implementation

TOOLS=(awk date diff find grep sed)
MIN_MAKE_VERSION="3.82"

# ==============================================================================

function main() {

  local tool failed=0

  for tool in "${TOOLS[@]}"; do
    check-tool "${tool}" || failed=$((failed + 1))
  done

  check-make || failed=$((failed + 1))
  check-container-runtime || failed=$((failed + 1))

  if [[ ${failed} -gt 0 ]]; then
    echo
    echo "${failed} tool(s) are not resolving to their required GNU implementation or version."
    if [[ "$(uname -s)" == "Darwin" ]]; then
      echo "Run: make toolchain-install-gnu-macos, then add the printed PATH line to your shell profile."
    else
      echo "Install the missing GNU packages with your system package manager, for example: sudo apt-get install gawk"
    fi
    echo "Neither make nor a container runtime is installed by this script, install them yourself."
    return 1
  fi

  echo "All GNU tools verified."

  return 0
}

# Check that the given tool's --version output identifies it as GNU.
# Arguments:
#   $1=[tool name, e.g. 'sed']
function check-tool() {

  local tool="$1" path version expect

  case "${tool}" in
    date) expect="GNU coreutils" ;;
    diff) expect="GNU diffutils" ;;
    find) expect="GNU findutils" ;;
    awk) expect="GNU Awk" ;;
    grep) expect="GNU grep" ;;
    sed) expect="GNU sed" ;;
    *) expect="GNU" ;;
  esac

  path="$(command -v "${tool}" 2> /dev/null || true)"
  if [[ -z "${path}" ]]; then
    echo "MISSING  ${tool}: not found on PATH"
    return 1
  fi

  # BSD tools either reject --version or print something without the expected
  # string in it, so a substring match is enough. stderr is folded in since
  # some BSD tools print their rejection there instead of stdout. macOS's own
  # grep prints "grep (BSD grep, GNU compatible)", which would false-positive
  # on a bare "GNU" match, hence the tool-specific expected string above.
  # BSD tools exit non-zero on --version, which is an expected outcome here.
  version="$("${tool}" --version 2>&1 | head -n 1 || true)"
  if [[ "${version}" == *"${expect}"* ]]; then
    echo "OK       ${tool}: ${version} (${path})"
    return 0
  else
    echo "NOT GNU  ${tool}: ${version} (${path})"
    return 1
  fi
}

# Check that GNU make is on PATH and is at least MIN_MAKE_VERSION.
function check-make() {

  local path version

  path="$(command -v make 2> /dev/null || true)"
  if [[ -z "${path}" ]]; then
    echo "MISSING  make: not found on PATH"
    return 1
  fi

  version="$(make --version 2>&1 | head -n 1 || true)"
  if [[ "${version}" != *"GNU Make"* ]]; then
    echo "NOT GNU  make: ${version} (${path})"
    return 1
  fi

  version="${version##*GNU Make }"
  if version-ge "${version}" "${MIN_MAKE_VERSION}"; then
    echo "OK       make: GNU Make ${version} (${path})"
    return 0
  else
    echo "TOO OLD  make: GNU Make ${version} (${path}), need ${MIN_MAKE_VERSION} or later"
    return 1
  fi
}

# Check that a container runtime, Docker or Podman, is on PATH.
function check-container-runtime() {

  local path

  path="$(command -v docker 2> /dev/null || true)"
  if [[ -n "${path}" ]]; then
    echo "OK       docker: ${path}"
    return 0
  fi

  path="$(command -v podman 2> /dev/null || true)"
  if [[ -n "${path}" ]]; then
    echo "OK       podman: ${path}"
    return 0
  fi

  echo "MISSING  docker/podman: neither found on PATH"
  return 1
}

# Compare two dotted version strings numerically, ignoring any trailing
# non-numeric suffix on each component, for example '3.82.1-rc1'.
# Arguments:
#   $1=[version to check, e.g. '4.4.1']
#   $2=[minimum required version, e.g. '3.82']
function version-ge() {

  local -a left right
  local i max

  IFS='.' read -r -a left <<< "${1%%[^0-9.]*}"
  IFS='.' read -r -a right <<< "${2%%[^0-9.]*}"

  max=${#left[@]}
  [[ ${#right[@]} -gt ${max} ]] && max=${#right[@]}

  for ((i = 0; i < max; i++)); do
    local l=${left[i]:-0} r=${right[i]:-0}
    if ((10#${l:-0} > 10#${r:-0})); then
      return 0
    elif ((10#${l:-0} < 10#${r:-0})); then
      return 1
    fi
  done

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
