#!/bin/bash

set -euo pipefail

# Verify that the GNU-compatible tools this repository's own scripts rely on
# are the ones actually resolved on PATH, on any OS. Most Linux systems pass
# natively, but Debian and Ubuntu ship mawk as awk, so they need the gawk
# package. On macOS it catches the classic "brew install'd but the gnubin
# directory isn't on PATH" gap, since Homebrew installs GNU formulae under a
# 'g'-prefixed name (gsed, ggrep, ...) unless gnubin is added to PATH. See
# scripts/toolchain/install-gnu-macos.sh to fix a failing check on macOS.
#
# Usage:
#   $ ./verify-gnu.sh
#
# Options:
#   VERBOSE=true  # Show all the executed commands, default is 'false'
#
# Exit codes:
#   0 - Every checked tool resolves to its GNU implementation
#   1 - At least one tool is missing or resolves to a non-GNU implementation

TOOLS=(awk date diff find grep sed)

# ==============================================================================

function main() {

  local tool failed=0

  for tool in "${TOOLS[@]}"; do
    check-tool "${tool}" || failed=$((failed + 1))
  done

  if [[ ${failed} -gt 0 ]]; then
    echo
    echo "${failed} tool(s) are not resolving to their GNU implementation."
    if [[ "$(uname -s)" == "Darwin" ]]; then
      echo "Run: make toolchain-install-gnu-macos, then add the printed PATH line to your shell profile."
    else
      echo "Install the missing GNU packages with your system package manager, for example: sudo apt-get install gawk"
    fi
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
