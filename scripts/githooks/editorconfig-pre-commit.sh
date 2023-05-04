#!/bin/bash

# Pre-commit git hook to check the EditorConfig rules complience over changed files
#
# Usage:
#   $ ./editorconfig-pre-commit.sh
#
# Exit codes:
#   0 - all files are formatted correctly
#   1 - files are not formatted correctly
#
# Notes:
#   Due to the file name escaping issue files are checked one by one.

# ==============================================================================

exit_code=0
image_digest=0f8f8dd4f393d29755bef2aef4391d37c34e358d676e9d66ce195359a9c72ef3 # 2.7.0
changed_files=$(git diff --name-only --diff-filter=ACMRT)

while read file; do
    docker run --rm --platform linux/amd64 \
        --volume=$PWD:/check \
        mstruebing/editorconfig-checker@sha256:$image_digest \
            ec \
                --exclude '.git/' \
                "$file"
    [ $? != 0 ] && exit_code=1 ||:
done < <(echo "$changed_files")
[ $? != 0 ] && exit_code=1 ||:

exit $exit_code
