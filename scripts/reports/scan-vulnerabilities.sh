#!/bin/bash

set -e

# Script to scan an SBOM file for CVEs (Common Vulnerabilities and Exposures).
#
# Usage:
#   $ ./scan-vulnerabilities.sh
#
# Options:
#   VERBOSE=true                        # Show all the executed commands, default is `false`
#   BUILD_DATETIME=%Y-%m-%dT%H:%M:%S%z  # Build datetime, default is `date -u +'%Y-%m-%dT%H:%M:%S%z'`

# ==============================================================================

# SEE: https://github.com/anchore/grype/pkgs/container/grype, use the `linux/amd64` os/arch
image_version=v0.64.2@sha256:f24e2282b5ff43a2a4df2280e9afcdac5a645df860b03db269049cbfb2cc25b4

# ==============================================================================

function main() {

  cd $(git rev-parse --show-toplevel)
  create-report
  enrich-report
}

function create-report() {

  docker run --rm --platform linux/amd64 \
    --volume $PWD:/scan \
    --volume /tmp/grype/db:/.cache/grype/db \
    ghcr.io/anchore/grype:$image_version \
      sbom:/scan/sbom-report.json \
      --config /scan/scripts/config/.grype.yaml \
      --output json \
      --file /scan/vulnerabilities-report.tmp.json
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
      vulnerabilities-report.tmp.json \
        > vulnerabilities-report.json
  rm -f vulnerabilities-report.tmp.json
}

function is_arg_true() {

  if [[ "$1" =~ ^(true|yes|y|on|1|TRUE|YES|Y|ON)$ ]]; then
    return 0
  else
    return 1
  fi
}

# ==============================================================================

is_arg_true "$VERBOSE" && set -x

main $*

exit 0
