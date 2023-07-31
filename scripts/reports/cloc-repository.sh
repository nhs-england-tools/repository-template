#!/bin/bash

set -e

# Count lines of code of this repository.
#
# Usage:
#   $ ./cloc-repository.sh
#
# Options:
#   VERBOSE=true                        # Show all the executed commands, default is `false`
#   BUILD_DATETIME=%Y-%m-%dT%H:%M:%S%z  # Build datetime, default is `date -u +'%Y-%m-%dT%H:%M:%S%z'`

# ==============================================================================

# SEE: https://github.com/make-ops-tools/gocloc/pkgs/container/gocloc, use the `linux/amd64` os/arch
image_version=latest@sha256:6888e62e9ae693c4ebcfed9f1d86c70fd083868acb8815fe44b561b9a73b5032

# ==============================================================================

function main() {

  cd $(git rev-parse --show-toplevel)
  create-report
  enrich-report
}

function create-report() {

  docker run --rm --platform linux/amd64 \
    --volume $PWD:/workdir \
    ghcr.io/make-ops-tools/gocloc:$image_version \
      --output-type=json \
      . \
  > cloc-report.tmp.json
  if which jq > /dev/null && which column > /dev/null; then
    cat cloc-report.tmp.json | jq -r '["Language","files","blank","comment","code"],["--------"],(.languages[]|[.name,.files,.blank,.comment,.code]),["-----"],(.total|["TOTAL",.files,.blank,.comment,.code])|@tsv' | column -t
  fi
}

function enrich-report() {

  build_datetime=${BUILD_DATETIME:-$(date -u +'%Y-%m-%dT%H:%M:%S%z')}
  git_url=$(git config --get remote.origin.url)
  git_branch=$(git rev-parse --abbrev-ref HEAD)
  git_commit_hash=$(git rev-parse HEAD)
  git_tags=$(echo \"$(git tag | tr '\n' ',' | sed 's/,$//' | sed 's/,/","/g')\" | sed 's/""//g')
  pipeline_run_id=${GITHUB_RUN_ID:-0}
  pipeline_run_number=${GITHUB_RUN_NUMBER:-0}
  pipeline_run_attempt=${GITHUB_RUN_ATTEMPT:-0}

  docker run --rm --platform linux/amd64 \
    --volume $PWD:/repo \
    --workdir /repo \
    ghcr.io/make-ops-tools/jq:latest \
      '.creationInfo |= . + {"created":"'${build_datetime}'","repository":{"url":"'${git_url}'","branch":"'${git_branch}'","tags":['${git_tags}'],"commitHash":"'${git_commit_hash}'"},"pipeline":{"id":'${pipeline_run_id}',"number":'${pipeline_run_number}',"attempt":'${pipeline_run_attempt}'}}' \
      cloc-report.tmp.json \
        > cloc-report.json
  rm -f cloc-report.tmp.json
}

function is-arg-true() {

  if [[ "$1" =~ ^(true|yes|y|on|1|TRUE|YES|Y|ON)$ ]]; then
    return 0
  else
    return 1
  fi
}

# ==============================================================================

is-arg-true "$VERBOSE" && set -x

main $*

exit 0
