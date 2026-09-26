#!/bin/bash

set -euo pipefail

# Command stub dispatcher used by test-stub in ./scripts/tests/test.lib.sh. Each
# stub is a symlink named after the command that points at this file, so a new
# stub does not pay the macOS first-run assessment of a new executable. It
# records the call's arguments in "<stub directory>/<name>.calls", then runs
# "<stub directory>/<name>.body" with the same arguments. It uses bash builtins
# only, because some tests run it with almost nothing on PATH. VERBOSE is not
# honoured, so a stub never adds a trace to the output under test. Do not run
# this file directly.
#
# Usage:
#   $ test-stub NAME [BODY]  # In a test that sources ./scripts/tests/test.lib.sh
#
# Exit codes:
#   0     - The body succeeded
#   2     - No body exists for this stub
#   other - The status the body exited or failed with

# ==============================================================================

function main() {

  # A symlink's own path is in $0, not the path of this file.
  local _stub_name="${0##*/}" _stub_dir="${0%/*}" _stub_line
  if [[ ! -f "$_stub_dir/$_stub_name.body" ]]; then
    echo "stub.sh: no body for $_stub_name, create stubs with test-stub" >&2
    exit 2
  fi
  if [[ $# -eq 0 ]]; then
    echo >> "$_stub_dir/$_stub_name.calls"
  else
    _stub_line="$(printf '%q ' "$@")"
    printf '%s\n' "${_stub_line% }" >> "$_stub_dir/$_stub_name.calls"
  fi
  # shellcheck source=/dev/null
  source "$_stub_dir/$_stub_name.body"

  return 0
}

# ==============================================================================

main "$@"

exit 0
