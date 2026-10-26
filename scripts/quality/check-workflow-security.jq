# Security baseline rules for GitHub Actions workflows and local actions, run by
# scripts/quality/check-workflow-security.sh. The input is one YAML file
# converted to JSON.
#
# Usage:
#   yq -o=json 'explode(.)' .github/workflows/cicd-2-publish.yaml | jq -r -f scripts/quality/check-workflow-security.jq --arg kind workflow --arg path cicd-2-publish.yaml --argjson approved '[]'
#
# Arguments:
#   $kind      "workflow" or "action"
#   $path      file path relative to its scan directory
#   $approved  approved write permissions from scripts/config/workflow-security.yaml

# Helpers used by the rules below.

# Trigger names, whether 'on' is a string, a list or a mapping.
def triggers:
  .on
  | if type == "object" then keys[]
    elif type == "array" then .[] | strings
    elif type == "string" then .
    else empty
    end;

# Every step of every workflow job or composite action.
def steps:
  (.jobs | objects | .[] | objects | .steps | arrays | .[]),
  (.runs | objects | .steps | arrays | .[])
  | objects;

# Every value in workflow, job, container and service 'env' blocks.
def env_values:
  (.env),
  (.jobs | objects | .[] | objects | .env, (.container | objects | .env), (.services | objects | .[] | objects | .env))
  | if type == "object" then .[] else . end
  | strings;

# True when an expression reads a secret. A test such as "secrets.NAME != ''" only exposes true or false, so it is allowed.
def reads_secret:
  [scan("\\$\\{\\{[\\s\\S]*?\\}\\}")]
  | map(gsub("secrets\\.[A-Za-z_][A-Za-z0-9_-]*\\s*[!=]=\\s*(''|\"\")"; "")
      | gsub("(''|\"\")\\s*[!=]=\\s*secrets\\.[A-Za-z_][A-Za-z0-9_-]*"; ""))
  | any(test("(^|[^A-Za-z0-9_.-])secrets([^A-Za-z0-9_-]|$)"));

# True when the step or job uses the named action. GitHub matches owner and repository names in any case.
def uses_action($name): (.uses | strings | ascii_downcase | startswith($name + "@")) // false;

# True when the action input is set to false.
def input_is_false($input): (.with | if type == "object" then .[$input] else null end | tostring) == "false";

# True when the allowlist approves this write permission for this job in this workflow.
def is_approved($job; $permission):
  any($approved[]; .workflow == $path and .job == $job and .permission == $permission);

# These local quality actions use the repository's pinned tool images.
def is_dockerised_quality_action:
  $path | test("^(scan-secrets|check-file-format|check-markdown-format|check-markdown-links|check-shell-lint)/action\\.ya?ml$");

# Their shell steps must force the wrappers to use those Docker images.
def rule_dockerised_quality_actions_force_docker:
  if $kind != "action" or (is_dockerised_quality_action | not) then empty
  else
    [.runs.steps[]? | select(has("run"))] as $run_steps
    | if ($run_steps | length) > 0 and all($run_steps[]; .env.FORCE_USE_DOCKER | tostring == "true")
      then empty
      else "dockerised quality action must set FORCE_USE_DOCKER=true on every run step"
      end
  end;

# Rules. Each prints one message per violation and nothing when the file complies.

# The workflow gives its jobs no token permissions by default.
#   Good: permissions: {}
#   Bad:  permissions: { contents: read }
def rule_workflow_grants_no_permissions:
  if (.permissions | type) == "object" and (.permissions | length) == 0 then empty
  else "workflow permissions must be empty"
  end;

# Every job lists the token permissions it needs, each set to none, read or write.
#   Good: jobs.build.permissions: { contents: read }
#   Bad:  jobs.build with no permissions key
def rule_jobs_declare_permissions:
  if (.jobs | type) != "object" then "workflow jobs must be a mapping"
  else
    .jobs | to_entries[] | .key as $job | .value
    | if type != "object" then "job '\($job)' must be a mapping"
      elif has("permissions") | not then "job '\($job)' must declare permissions"
      elif (.permissions | type) != "object" then "job '\($job)' permissions must be a mapping"
      else .permissions | to_entries[] | select(.value | IN("none", "read", "write") | not)
        | "job '\($job)' permission '\(.key)' must be none, read, or write"
      end
  end;

# A job gets write access only when scripts/config/workflow-security.yaml approves it.
#   Good: jobs.publish.permissions.contents: write, listed in the allowlist
#   Bad:  jobs.build.permissions.packages: write, not listed
def rule_write_permissions_are_approved:
  .jobs | objects | to_entries[]
  | .key as $job
  | .value | objects | .permissions | objects | to_entries[]
  | select(.value == "write")
  | .key as $permission
  | select(is_approved($job; $permission) | not)
  | "write permission is not approved for job '\($job)': \($permission)";

# A called workflow receives only the secrets passed to it by name.
#   Good: jobs.test.secrets.SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
#   Bad:  jobs.test.secrets: inherit
def rule_secrets_are_not_inherited:
  .jobs | objects | to_entries[]
  | select(.value | objects | .secrets == "inherit")
  | "secrets: inherit is prohibited for job '\(.key)', pass named secrets explicitly";

# No trigger gives code from a fork access to secrets or a write token.
#   Good: on: pull_request
#   Bad:  on: pull_request_target
#   Bad:  on: [push, workflow_run]
def rule_no_privileged_triggers:
  if any(triggers; . == "pull_request_target" or . == "workflow_run")
  then "privileged triggers pull_request_target and workflow_run are prohibited"
  else empty
  end;

# A secret is given only to the step that needs it, not to a whole job or workflow.
#   Good: jobs.build.steps[0].env.TOKEN: ${{ secrets.TOKEN }}
#   Good: jobs.build.env.HAS_TOKEN: ${{ secrets.TOKEN != '' }}
#   Bad:  jobs.build.env.TOKEN: ${{ secrets.TOKEN }}
def rule_secrets_are_step_scoped:
  if any(env_values; reads_secret)
  then "secret values must not be set in workflow, job, container, or service environment"
  else empty
  end;

# Remote actions are pinned to a commit SHA or image digest, so the code cannot change after review.
#   Good: uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1
#   Good: uses: ./.github/actions/scan-secrets
#   Bad:  uses: actions/checkout@v7
def rule_actions_are_pinned:
  .. | objects | select(has("uses")) | .uses
  | if type != "string" then "action reference must be a string"
    elif startswith("./") then empty
    elif startswith("docker://") then
      if test("@sha256:[0-9a-fA-F]{64}$") then empty else "container action is not pinned by digest: \(.)" end
    elif test("^[^@]+@[0-9a-fA-F]{40}$") then empty
    else "action ref is not a full 40-character SHA: \(.)"
    end;

# Checkout does not keep the job token where later steps can read it.
#   Good: uses: actions/checkout@<sha> with persist-credentials: false
#   Bad:  uses: actions/checkout@<sha> with no persist-credentials input
def rule_checkout_does_not_keep_token:
  .. | objects
  | select(uses_action("actions/checkout"))
  | select(input_is_false("persist-credentials") | not)
  | "actions/checkout must set persist-credentials: false";

# mise does not keep the GitHub token where later steps can read it.
#   Good: uses: jdx/mise-action@<sha> with persist_github_token: false
#   Bad:  uses: jdx/mise-action@<sha> with no persist_github_token input
def rule_mise_does_not_keep_token:
  .. | objects
  | select(uses_action("jdx/mise-action"))
  | select(input_is_false("persist_github_token") | not)
  | "jdx/mise-action must set persist_github_token: false";

# Dockerised quality jobs use the digest-pinned image, not a runner-installed tool.
def rule_dockerised_quality_jobs_do_not_install_mise:
  if $path != "stage-1-commit.yaml" then empty
  else
    ["scan-secrets", "check-file-format", "check-markdown-format", "check-markdown-links", "check-shell-lint"][] as $job
    | .jobs[$job] as $job_config
    | if ($job_config | type) == "object" and any($job_config.steps[]?; uses_action("jdx/mise-action"))
      then "job '\($job)' must use its pinned Docker image instead of jdx/mise-action"
      else empty
      end
  end;

# Run scripts read values from env, so untrusted text cannot become shell code.
#   Good: env.TITLE: ${{ github.event.pull_request.title }} with run: echo "$TITLE"
#   Bad:  run: echo "${{ github.event.pull_request.title }}"
def rule_run_scripts_have_no_expressions:
  steps | .run | strings | select(contains("${{"))
  | if test("\\$\\{\\{[^}]*secrets") then "secrets must not be interpolated into run scripts"
    else "expressions must not be interpolated into run scripts, pass values through step env"
    end;

# github-script code reads values from env, so untrusted text cannot become JavaScript.
#   Good: env.TITLE: ${{ github.event.issue.title }} with script: core.info(process.env.TITLE)
#   Bad:  script: core.info("${{ github.event.issue.title }}")
def rule_github_scripts_have_no_expressions:
  steps | select(uses_action("actions/github-script"))
  | .with | objects | .script | strings | select(contains("${{"))
  | "expressions must not be interpolated into actions/github-script scripts, pass values through step env";

# Workflow-only rules first, then rules for both workflows and local actions.
if $kind == "workflow" then
  rule_workflow_grants_no_permissions,
  rule_jobs_declare_permissions,
  rule_write_permissions_are_approved,
  rule_secrets_are_not_inherited,
  rule_no_privileged_triggers,
  rule_secrets_are_step_scoped
else empty end,
rule_actions_are_pinned,
rule_checkout_does_not_keep_token,
rule_mise_does_not_keep_token,
rule_dockerised_quality_actions_force_docker,
rule_dockerised_quality_jobs_do_not_install_mise,
rule_run_scripts_have_no_expressions,
rule_github_scripts_have_no_expressions
