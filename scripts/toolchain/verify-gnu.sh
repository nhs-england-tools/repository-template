#!/usr/bin/env bash

set -euo pipefail

# Verify that the GNU-compatible tools this repository's own scripts rely on
# are the ones actually resolved on PATH, on any OS. Most Linux systems pass
# natively, but Debian and Ubuntu ship mawk as awk, so they need the gawk
# package. On macOS it catches the classic "brew install'd but the gnubin
# directory isn't on PATH" gap, since Homebrew installs GNU formulae under a
# 'g'-prefixed name (gsed, ggrep, ...) unless gnubin is added to PATH. See
# scripts/toolchain/install-gnu-macos.sh to fix a failing check on macOS.
# It also reports, but never installs, GNU make 3.82 or later and the CLI
# version of a Docker or Podman container runtime on PATH, since
# scripts/docker/docker.mk needs both prerequisites.
# It also enforces Bash 5.2 or later on PATH, since the repository's scripts
# use associative arrays and other features the macOS-shipped Bash 3.2 lacks.
#
# Usage:
#   $ ./verify-gnu.sh
#
# Options:
#   VERBOSE=true  # Show all the executed commands, default is 'false'
#
# Exit codes:
#   0 - Every checked tool resolves to its required GNU implementation or
#       GNU-style behaviour, make and bash are new enough, and a container
#       runtime reports its version
#   1 - At least one tool is missing, too old, or resolves to an incompatible
#       implementation

TOOLS=(awk date diff find grep sed)
MIN_MAKE_VERSION="3.82"
MIN_BASH_VERSION="5.2"

# ==============================================================================

function main() {

  local tool failed=0

  check-bash || failed=$((failed + 1))

  for tool in "${TOOLS[@]}"; do
    if [[ "${tool}" == "date" ]]; then
      check-date || failed=$((failed + 1))
    else
      check-tool "${tool}" || failed=$((failed + 1))
    fi
  done

  check-make || failed=$((failed + 1))
  check-container-runtime || failed=$((failed + 1))

  if [[ ${failed} -gt 0 ]]; then
    echo
    echo "${failed} tool(s) are not resolving to their required GNU-compatible implementation or version."
    if [[ "$(uname -s)" == "Darwin" ]]; then
      echo "Run: make toolchain-install-gnu-macos, then add the printed PATH line to your shell profile."
    else
      echo "Install the missing GNU packages with your system package manager, for example: sudo apt-get install gawk"
    fi
    echo "Neither make, bash, nor a container runtime is installed by this script, install or upgrade them yourself."
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

# Check that date supports the GNU-style behaviour this repository uses.
function check-date() {

  local path version formatted epoch

  path="$(command -v date 2> /dev/null || true)"
  if [[ -z "${path}" ]]; then
    echo "MISSING  date: not found on PATH"
    return 1
  fi

  version="$(date --version 2>&1 | head -n 1 || true)"
  if [[ -z "${version}" ]]; then
    version="$(date 2>&1 | head -n 1 || true)"
  fi
  [[ -n "${version}" ]] || version="unknown version"

  formatted="$(date --date='2026-09-27T07:08:09+0000' -u +'%Y%m%d%H%M%S' 2> /dev/null || true)"
  epoch="$(date --date='1970-01-01T00:00:01+0000' -u +'%s' 2> /dev/null || true)"
  if [[ "${formatted}" == "20260927070809" && "${epoch}" == "1" ]]; then
    echo "OK       date: GNU-style date (${version}) (${path})"
    return 0
  else
    echo "INCOMPAT date: ${version} (${path}), missing GNU-style --date support"
    return 1
  fi
}

# Check that Bash is on PATH, identifies as GNU, and is at least MIN_BASH_VERSION.
function check-bash() {

  local path version

  path="$(command -v bash 2> /dev/null || true)"
  if [[ -z "${path}" ]]; then
    echo "MISSING  bash: not found on PATH"
    return 1
  fi

  version="$(bash --version 2>&1 | head -n 1 || true)"
  if [[ "${version}" != *"GNU bash"* ]]; then
    echo "NOT GNU  bash: ${version} (${path})"
    return 1
  fi

  version="${version#*version }"
  version="${version%%[^0-9.]*}"
  if version-ge "${version}" "${MIN_BASH_VERSION}"; then
    echo "OK       bash: GNU bash ${version} (${path})"
    return 0
  else
    echo "TOO OLD  bash: GNU bash ${version} (${path}), need ${MIN_BASH_VERSION} or later"
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

# Check that Docker or Podman is on PATH and report its CLI version.
# Prefer Docker, but try Podman if Docker cannot report a version.
function check-container-runtime() {

  local runtime path version found=false

  for runtime in docker podman; do
    path="$(command -v "${runtime}" 2> /dev/null || true)"
    [[ -n "${path}" ]] || continue
    found=true

    if ! version="$("${runtime}" --version 2>&1)"; then
      echo "UNAVAILABLE ${runtime}: failed to report version (${path})"
      continue
    fi
    version="${version%%$'\n'*}"
    if [[ -z "${version//[[:space:]]/}" ]]; then
      echo "UNAVAILABLE ${runtime}: no version reported (${path})"
      continue
    fi

    echo "OK       ${runtime}: ${version} (${path})"
    return 0
  done

  if [[ "${found}" == false ]]; then
    echo "MISSING  docker/podman: neither found on PATH"
  fi
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

  local value="$1"
  if [[ "$value" =~ ^(true|yes|y|on|1|TRUE|YES|Y|ON)$ ]]; then
    return 0
  else
    return 1
  fi
}

# ==============================================================================

# Let the test suite source the functions without running main
[[ "${BASH_SOURCE[0]}" == "$0" ]] || return 0

is-arg-true "${VERBOSE:-false}" && set -x

main "$@"

exit 0
