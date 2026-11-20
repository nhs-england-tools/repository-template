#!/usr/bin/env bash

set -euo pipefail

# Decide whether a CI/CD run should notify the team and write the Microsoft
# Teams message as step outputs. A run with a failed or cancelled job reports
# the failed jobs and the commit. With STOP_THE_LINE=true, a failure asks the
# team to stop merging, and a passing run that ends a broken streak reports the
# recovery. With SUCCESS_TITLE set, a passing run reports its success. Run it
# as a step of './.github/workflows/notify-pipeline-status.yaml'.
#
# Usage:
#   $ [options] ./scripts/cicd/notify-pipeline-status.sh
#
# Options:
#   NEEDS='{...}'
#       Results of the jobs to report on, the JSON of 'toJSON(needs)', required
#   STOP_THE_LINE=true
#       Treat a failure as a broken trunk and report its recovery, default is
#       'false'
#   COMMIT_REF=ref
#       Commit or tag the run is about, default is the value of GITHUB_SHA
#   DETAILS='Label: value'
#       Extra facts to show in the message, one per line, default is none
#   SUCCESS_TITLE='PUBLISHED: Release 1.2.3'
#       Title of the message of a passing run, default is no message
#   SUCCESS_TEXT='Release 1.2.3 is published.'
#       Text of the message of a passing run, default is none
#   SUCCESS_LINK=https://...
#       Link of the message of a passing run, default is the run
#   WEBHOOK_CONFIGURED=true
#       Whether the Teams webhook secret is set, default is 'false'
#   VERBOSE=true
#       Show all the executed commands, default is 'false'
#
# Exit codes:
#   0 - The outputs are written, including when no notification is needed
#   1 - A GitHub Actions variable is not set or NEEDS is not a JSON object
#
# Notes:
#   1) It reads the default GitHub Actions variables, such as
#      GITHUB_REPOSITORY, GITHUB_RUN_ID and GITHUB_WORKFLOW_REF. It writes the
#      'status', 'title', 'colour', 'text', 'facts', 'link', 'link_title',
#      'commit' and 'webhook_configured' outputs to GITHUB_OUTPUT and the
#      message to GITHUB_STEP_SUMMARY. 'status' is 'none', 'failure',
#      'recovered' or 'success'.
#   2) With STOP_THE_LINE=true, only the newest finished run reports the state
#      of the branch, and a cancelled run is neither broken nor green.
#   3) The GitHub CLI needs GH_TOKEN with 'actions: read' and 'contents: read'.
#      When a lookup fails, the message has less detail and the script prints a
#      warning annotation, so the team is still told.
#   4) './scripts/cicd/notify-pipeline-status.jq' renders the message. It
#      removes Markdown and invisible characters from every value the pipeline
#      does not control.

# ==============================================================================

# A failed job can show as cancelled when it runs out of time
readonly NOTIFY_FAILED_JOB_CONCLUSIONS='["failure","cancelled","timed_out","startup_failure"]'
readonly NOTIFY_BROKEN_RUN_CONCLUSIONS='["failure","timed_out","startup_failure"]'

# Write the pipeline status and, when the team should know, the message.
function main() {

  cd "$(git rev-parse --show-toplevel)"

  local needs="${NEEDS:-}" commit_ref="${COMMIT_REF:-}"
  local stop_the_line=false status=none name runs=null newer
  local failed_jobs='[]' broken_since=null commit message

  for name in GITHUB_REPOSITORY GITHUB_RUN_ID GITHUB_RUN_NUMBER GITHUB_RUN_ATTEMPT GITHUB_SHA \
    GITHUB_REF_NAME GITHUB_EVENT_NAME GITHUB_WORKFLOW GITHUB_WORKFLOW_REF GITHUB_ACTOR \
    GITHUB_SERVER_URL GITHUB_OUTPUT GITHUB_STEP_SUMMARY; do
    [[ -n "${!name:-}" ]] || {
      echo "ERROR: $name is not set, run this script in GitHub Actions" >&2
      return 1
    }
  done
  [[ "$GITHUB_RUN_NUMBER" =~ ^[0-9]+$ && "$GITHUB_RUN_ATTEMPT" =~ ^[0-9]+$ ]] || {
    echo "ERROR: GITHUB_RUN_NUMBER and GITHUB_RUN_ATTEMPT must be numbers" >&2
    return 1
  }
  jq -e 'type == "object"' <<< "$needs" > /dev/null 2>&1 || {
    echo "ERROR: NEEDS must be the JSON object of 'toJSON(needs)'" >&2
    return 1
  }
  if [[ -n "$commit_ref" ]] && ! [[ "$commit_ref" =~ ^[A-Za-z0-9][A-Za-z0-9._/+@-]*$ && "$commit_ref" != *..* ]]; then
    printf '::warning title=Unsafe commit ref::COMMIT_REF %q is not a safe commit or tag name, so the message shows the commit of the run\n' "$commit_ref"
    commit_ref=''
  fi
  commit_ref="${commit_ref:-$GITHUB_SHA}"
  is-arg-true "${STOP_THE_LINE:-false}" && stop_the_line=true

  if jq -e 'any(.[]; .result == "failure" or .result == "cancelled")' <<< "$needs" > /dev/null; then
    status=failure
  elif [[ -n "${SUCCESS_TITLE:-}" ]]; then
    status=success
  fi
  if [[ "$stop_the_line" == true ]]; then
    notify-previous-runs runs || return "$?"
    newer="$(
      jq -r --argjson number "$GITHUB_RUN_NUMBER" --argjson broken "$NOTIFY_BROKEN_RUN_CONCLUSIONS" '
        (. // [])
        | map(select(.number > $number and (.conclusion == "success" or (.conclusion as $c | $broken | index($c)))))
        | first | .number // empty' <<< "$runs"
    )" || return "$?"
    if [[ -n "$newer" ]]; then
      echo "status=none" >> "$GITHUB_OUTPUT"
      echo "Run $newer has already reported the state of $GITHUB_REF_NAME, so no notification is needed"
      return 0
    fi
    if [[ "$status" != failure ]]; then
      notify-broken-since broken_since "$runs" || return "$?"
      [[ "$broken_since" == null ]] || status=recovered
    fi
  fi
  if [[ "$status" == none ]]; then
    echo "status=none" >> "$GITHUB_OUTPUT"
    echo "No notification needed"
    return 0
  fi

  if [[ "$status" == failure ]]; then
    notify-failed-jobs failed_jobs "$needs" || return "$?"
  fi
  notify-commit commit "$commit_ref" || return "$?"
  message="$(
    jq -n -c -f ./scripts/cicd/notify-pipeline-status.jq \
      --arg status "$status" \
      --argjson stop_the_line "$stop_the_line" \
      --arg repository "$GITHUB_REPOSITORY" \
      --arg server_url "$GITHUB_SERVER_URL" \
      --arg run_id "$GITHUB_RUN_ID" \
      --arg workflow "$GITHUB_WORKFLOW" \
      --arg event "$GITHUB_EVENT_NAME" \
      --arg actor "$GITHUB_ACTOR" \
      --arg attempt "$GITHUB_RUN_ATTEMPT" \
      --argjson failed_jobs "$failed_jobs" \
      --argjson commit "$commit" \
      --argjson broken_since "$broken_since" \
      --arg details "${DETAILS:-}" \
      --arg success_title "${SUCCESS_TITLE:-}" \
      --arg success_text "${SUCCESS_TEXT:-}" \
      --arg success_link "${SUCCESS_LINK:-}"
  )" || return "$?"
  notify-write-outputs "$status" "$message" "$(jq -r .sha <<< "$commit")" || return "$?"

  return 0
}

# ==============================================================================

# Set a variable to the JSON list of the run's failed jobs, [{name, url}]. Fall
# back to the IDs of the failed needs, without links, when the GitHub API does
# not return them.
# Arguments:
#   $1=[name of the variable to set]
#   $2=[results of the jobs, the JSON of 'toJSON(needs)']
# shellcheck disable=SC2034
function notify-failed-jobs() {

  local -n failed_jobs_out="$1" || return "$?"
  local needs="$2" response jobs=''
  if response="$(gh api --paginate "repos/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID/attempts/$GITHUB_RUN_ATTEMPT/jobs?per_page=100")"; then
    jobs="$(
      jq -c -s --argjson broken "$NOTIFY_FAILED_JOB_CONCLUSIONS" \
        '[.[].jobs[] | select(.conclusion as $c | $broken | index($c)) | {name, url: .html_url}]' \
        <<< "$response"
    )" || jobs=''
  fi
  if [[ -n "$jobs" && "$jobs" != '[]' ]]; then
    failed_jobs_out="$jobs"
    return 0
  fi

  echo "::warning title=Failed jobs not found::The GitHub API did not list the failed jobs, so the message shows their IDs"
  failed_jobs_out="$(
    jq -c '[to_entries[] | select(.value.result == "failure" or .value.result == "cancelled") | {name: .key, url: null}]' \
      <<< "$needs"
  )" || return "$?"

  return 0
}

# Set a variable to the finished runs of the workflow on this branch and event,
# newest first, [{conclusion, number, url, createdAt}], or to 'null' when the
# GitHub CLI cannot list them.
# Arguments:
#   $1=[name of the variable to set]
# shellcheck disable=SC2034
function notify-previous-runs() {

  local -n runs_out="$1" || return "$?"
  local workflow_file="${GITHUB_WORKFLOW_REF%%@*}" list
  workflow_file="${workflow_file##*/}"
  if list="$(
    gh run list --repo "$GITHUB_REPOSITORY" --workflow "$workflow_file" \
      --branch "$GITHUB_REF_NAME" --event "$GITHUB_EVENT_NAME" --status completed \
      --limit 20 --json conclusion,number,url,createdAt
  )" && jq -e 'type == "array"' <<< "$list" > /dev/null 2>&1; then
    runs_out="$list"
    return 0
  fi

  echo "::warning title=Previous runs not found::The GitHub CLI could not list the previous runs of $workflow_file"
  runs_out=null

  return 0
}

# Set a variable to the first broken run of the streak this run ends,
# {number, url, minutes}, or to 'null' when the last finished run before this
# one was green. The earlier attempt of a re-run counts as the run before, and
# a cancelled run is skipped.
# Arguments:
#   $1=[name of the variable to set]
#   $2=[finished runs from notify-previous-runs]
# shellcheck disable=SC2034
function notify-broken-since() {

  local -n broken_since_out="$1" || return "$?"
  local runs="$2" attempt='[]' previous=$((GITHUB_RUN_ATTEMPT - 1)) response now
  broken_since_out=null
  [[ "$runs" != null ]] || return 0
  if [[ "$previous" -gt 0 ]] &&
    { ! response="$(gh api "repos/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID/attempts/$previous")" ||
      ! attempt="$(jq -c '[{conclusion, number: .run_number, url: .html_url, createdAt: .created_at}]' <<< "$response")"; }; then
    echo "::warning title=Previous attempt not found::The GitHub API did not return attempt $previous of this run, so its result is not checked"
    attempt='[]'
  fi
  now="$(date -u +%s)" || return "$?"
  broken_since_out="$(
    jq -n -c --argjson attempt "$attempt" --argjson runs "$runs" --argjson number "$GITHUB_RUN_NUMBER" \
      --argjson broken "$NOTIFY_BROKEN_RUN_CONCLUSIONS" --argjson now "$now" '
      $attempt + ($runs | map(select(.number < $number)))
      | map(select(.conclusion == "success" or (.conclusion as $c | $broken | index($c))))
      | (map(.conclusion == "success") | index(true) // length) as $streak
      | if $streak == 0 then null
        else .[$streak - 1]
          | {number, url, minutes: (($now - (.createdAt | fromdateiso8601)) / 60 | floor)}
        end'
  )" || return "$?"

  return 0
}

# Set a variable to the commit the run is about, {sha, url, subject}. Fall back
# to the ref without a link or subject when the GitHub API does not return it.
# Arguments:
#   $1=[name of the variable to set]
#   $2=[commit SHA or tag name]
# shellcheck disable=SC2034
function notify-commit() {

  local -n commit_out="$1" || return "$?"
  local ref="$2" response
  if response="$(gh api "repos/$GITHUB_REPOSITORY/commits/$ref")" &&
    commit_out="$(jq -c '{sha, url: .html_url, subject: (.commit.message | split("\n")[0])}' <<< "$response")"; then
    return 0
  fi

  echo "::warning title=Commit not found::The GitHub API did not return commit $ref, so the message shows the ref only"
  commit_out="$(jq -n -c \
    --arg ref "$ref" \
    --arg url "$GITHUB_SERVER_URL/$GITHUB_REPOSITORY/commit/$ref" \
    '{sha: $ref, url: $url, subject: ""}')" || return "$?"

  return 0
}

# Write the status, message and commit to GITHUB_OUTPUT, the message to the
# step summary and the log, and warn when the webhook secret is not set.
# Arguments:
#   $1=[status, 'failure', 'recovered' or 'success']
#   $2=[message, the JSON from notify-pipeline-status.jq]
#   $3=[commit SHA or ref the message is about]
function notify-write-outputs() {

  local status="$1" message="$2" commit="$3" title colour text facts link link_title summary webhook=false
  local delimiter="NOTIFY_PIPELINE_STATUS_${SRANDOM}${SRANDOM}"
  title="$(jq -r .title <<< "$message")" || return "$?"
  colour="$(jq -r .colour <<< "$message")" || return "$?"
  text="$(jq -r .text <<< "$message")" || return "$?"
  facts="$(jq -r .facts <<< "$message")" || return "$?"
  link="$(jq -r .link <<< "$message")" || return "$?"
  link_title="$(jq -r .link_title <<< "$message")" || return "$?"
  summary="$(jq -r .summary <<< "$message")" || return "$?"
  is-arg-true "${WEBHOOK_CONFIGURED:-false}" && webhook=true

  {
    printf 'status=%s\n' "$status"
    printf 'title=%s\n' "$title"
    printf 'colour=%s\n' "$colour"
    printf 'text<<%s\n%s\n%s\n' "$delimiter" "$text" "$delimiter"
    printf 'facts<<%s\n%s\n%s\n' "$delimiter" "$facts" "$delimiter"
    printf 'link=%s\n' "$link"
    printf 'link_title=%s\n' "$link_title"
    printf 'commit=%s\n' "$commit"
    printf 'webhook_configured=%s\n' "$webhook"
  } >> "$GITHUB_OUTPUT"
  printf '%s\n' "$summary" >> "$GITHUB_STEP_SUMMARY"
  printf '%s\n\n%s\n\n%s\n' "$title" "$text" "$facts"
  if [[ "$webhook" == false ]]; then
    echo "::warning title=Team not notified::Set the TEAMS_NOTIFICATION_WEBHOOK_URL secret to send pipeline notifications to Microsoft Teams"
  fi

  return 0
}

# ==============================================================================

# Check whether the supplied argument represents a true boolean value.
# Arguments:
#   $1=[value to evaluate]
function is-arg-true() {

  local value="$1"
  if [[ "$value" =~ ^(true|yes|y|on|1|TRUE|YES|Y|ON)$ ]]; then
    return 0
  else
    return 1
  fi
}

# ==============================================================================

is-arg-true "${VERBOSE:-false}" && set -x

main "$@"

exit 0
