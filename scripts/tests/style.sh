#!/bin/bash

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"


# This file is for you! Edit it to call your prose style checker.
# It's preconfigured to use `vale`, the same as the github action,
# except that here it only checks unstaged files first, and only if
# those files are OK does it then go on to check staged files.  This
# is to give you fast feedback on the changes you've most recently
# made.

check=working-tree-changes ./scripts/githooks/check-english-usage.sh && \
  check=staged-changes ./scripts/githooks/check-english-usage.sh
