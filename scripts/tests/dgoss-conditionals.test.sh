#!/bin/bash

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

script="scripts/docker/dgoss.sh"

# SonarCloud flags single-bracket conditional tests in POSIX sh as a
# reliability issue. Conditional expressions in this script must use the
# bash [[ ... ]] form so globbing and word splitting cannot change the test.
if grep -nE '(^|[^[:alnum:]_\[])\[ [^]]*\]' "$script"; then
  echo "dgoss.sh uses single-bracket conditional tests" >&2
  exit 1
fi
