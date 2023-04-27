#!/bin/bash

# Pre-commit git hook to run EditorConfig over changed files
#
# Usage:
#   $ ./editorconfig-pre-commit.sh
#
# Exit codes:
#   0 - all files are formatted correctly
#   1 - files are not formatted correctly

# ==============================================================================

image_digest=0f8f8dd4f393d29755bef2aef4391d37c34e358d676e9d66ce195359a9c72ef3 # 2.7.0

changed_files=$(git diff --name-only --diff-filter=ACMRT)
docker run --rm --platform linux/amd64 \
    --volume=$PWD:/check \
    mstruebing/editorconfig-checker@sha256:$image_digest \
        ec \
            --exclude '.git/' < <(echo "$changed_files")
