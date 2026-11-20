# Pipeline contract rules for GitHub Actions workflows, run by
# scripts/quality/check-pipeline-contract.sh. The input is one workflow file
# converted to JSON.
#
# Usage:
#   yq -o=json 'explode(.)' .github/workflows/cicd-1-pull-request.yaml | jq -r -f scripts/quality/check-pipeline-contract.jq --arg path cicd-1-pull-request.yaml
#
# Arguments:
#   $path  file path relative to the workflow directory

# Rules. Each prints one message per violation and nothing when the file complies.

# A CI/CD pipeline tells the team when it breaks, so a failure stops the line.
#   Good: jobs.notify: { needs: [every other job], if: "${{ !cancelled() && ... }}",
#         uses: ./.github/workflows/notify-pipeline-status.yaml }
#   Bad:  no job calls the notification workflow
#   Bad:  jobs.notify.if: "success()", which skips the job when the pipeline fails
#   Bad:  jobs.notify.if: "always()", which also reports a run that a person cancelled
#   Bad:  jobs.notify.needs leaves out a job, whose failure is then not reported
def rule_cicd_workflows_notify_pipeline_status:
  if ($path | test("^cicd-") | not) then empty
  else
    (.jobs | objects) as $jobs
    | [$jobs | to_entries[] | select(.value | objects | .uses == "./.github/workflows/notify-pipeline-status.yaml")] as $notify
    | if $notify == [] then "workflow must call ./.github/workflows/notify-pipeline-status.yaml"
      else
        $notify[]
        | .key as $id
        | (if (.value.if // "" | tostring | test("^\\s*(\\$\\{\\{\\s*)?!cancelled\\(\\)\\s*(&&|\\}\\}\\s*$|$)")) then empty
          else "job \($id) must start its if: condition with !cancelled(), so it reports failures and stays cancellable"
          end),
          (([.value.needs // []] | flatten) as $needs
          | [$jobs | keys_unsorted[] | select(. != $id and (. as $job | $needs | index($job) | not))]
          | if . == [] then empty
            else "job \($id) must need every other job, missing: \(join(", "))"
            end)
      end
  end;

rule_cicd_workflows_notify_pipeline_status
