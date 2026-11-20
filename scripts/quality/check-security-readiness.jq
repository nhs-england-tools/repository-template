# Offline security readiness governance rules, run by check-security-readiness.sh.
# Include this module and call yaml_diagnostics($kind; $path; $approved) on a
# parsed YAML mapping, or repository_diagnostics($kind; $content; $today) for
# raw repository file text. Workflow write approvals use security-readiness.yaml.

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
def is_approved($job; $permission; $approved; $path):
  any($approved[]; .workflow == $path and .job == $job and .permission == $permission);

# These local quality actions use the repository's pinned tool images.
def is_dockerised_quality_action($path):
  $path | test("^(scan-secrets|check-file-format|check-markdown-format|check-markdown-links|check-shell-lint)/action\\.ya?ml$");

# Their shell steps must use one consistent mode. False is an explicit opt-out
# and is reported as a warning by the shell checker.
def rule_dockerised_quality_actions_force_docker($kind; $path):
  if $kind != "action" or (is_dockerised_quality_action($path) | not) then empty
  else
    [.runs.steps[]? | select(has("run"))] as $run_steps
    | if ($run_steps | length) > 0 and all($run_steps[]; .env.FORCE_USE_DOCKER | tostring == "true")
      then empty
      elif ($run_steps | length) > 0 and all($run_steps[]; .env.FORCE_USE_DOCKER | tostring == "false")
      then "WARNING: FORCE_USE_DOCKER=false opts out of container isolation when native tools are available"
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

# A job gets write access only when scripts/config/security-readiness.yaml approves it.
#   Good: jobs.publish.permissions.contents: write, listed in the allowlist
#   Bad:  jobs.build.permissions.packages: write, not listed
def rule_write_permissions_are_approved($path; $approved):
  .jobs | objects | to_entries[]
  | .key as $job
  | .value | objects | .permissions | objects | to_entries[]
  | select(.value == "write")
  | .key as $permission
  | select(is_approved($job; $permission; $approved; $path) | not)
  | "write permission is not approved for job '\($job)': \($permission)";

# Every job that runs steps has a time limit, so a hung step cannot hold a runner
# for GitHub's 6 hour default.
#   Good: jobs.build: { timeout-minutes: 5, steps: [...] }
#   Bad:  jobs.build: { steps: [...] }, or timeout-minutes: 0
def rule_jobs_set_timeouts:
  .jobs | objects | to_entries[]
  | select(.value | objects | has("steps"))
  | select(.value["timeout-minutes"]
      | ((type == "number" and . > 0) or (type == "string" and test("^\\$\\{\\{[\\s\\S]*\\}\\}$")))
      | not)
  | "job '\(.key)' must set timeout-minutes to a positive number or an expression";

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

# A workflow that never runs for a pull request, a merge queue or a caller, such
# as publish or deploy, does not restore a mise cache that another run wrote.
# The action's cache input defaults to true, so it must be set to false. A
# workflow that can also be called, or that runs for pull requests, is not
# covered. Such a workflow must set cache: false on its own publish or deploy
# jobs.
#   Good: on: push with uses: jdx/mise-action@<sha> and cache: false
#   Bad:  on: workflow_dispatch with uses: jdx/mise-action@<sha> and no cache input
def rule_mise_cache_is_off_in_publish_and_deploy_workflows:
  if any(triggers; IN("pull_request", "merge_group", "workflow_call")) then empty
  else
    .. | objects
    | select(uses_action("jdx/mise-action"))
    | select(input_is_false("cache") | not)
    | "jdx/mise-action must set cache: false in a workflow that never runs for a pull request, a merge queue or a caller"
  end;

# Dockerised quality jobs use the digest-pinned image, not a runner-installed tool.
def rule_dockerised_quality_jobs_do_not_install_mise($path):
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

# Run scripts quote the GitHub Actions file they write to, as an unquoted path
# is split on spaces and expanded as a glob.
#   Good: run: echo "name=value" >> "$GITHUB_OUTPUT"
#   Bad:  run: echo "name=value" >> $GITHUB_OUTPUT, or | tee -a "$GITHUB_OUTPUT" $GITHUB_ENV
def rule_run_scripts_quote_github_files:
  "\\$\\{?(GITHUB_(?:OUTPUT|ENV|PATH|STEP_SUMMARY|STATE)\\b)" as $file
  | steps | .run | strings
  | [scan(">>?\\s*" + $file)[0],
      (scan("\\btee\\b([^|;&<>\\n]*)")[0] | scan("(?:^|\\s)" + $file)[0])]
  | unique[]
  | "run scripts must quote $\(.) where they write to it, as >> \"$\(.)\"";

# github-script code reads values from env, so untrusted text cannot become JavaScript.
#   Good: env.TITLE: ${{ github.event.issue.title }} with script: core.info(process.env.TITLE)
#   Bad:  script: core.info("${{ github.event.issue.title }}")
def rule_github_scripts_have_no_expressions:
  steps | select(uses_action("actions/github-script"))
  | .with | objects | .script | strings | select(contains("${{"))
  | "expressions must not be interpolated into actions/github-script scripts, pass values through step env";

# Number of days in a Gregorian calendar month, including leap centuries.
def calendar_month_days($year; $month):
  if $month == 2 then
    if $year % 4 == 0 and ($year % 100 != 0 or $year % 400 == 0) then 29 else 28 end
  elif $month | IN(4, 6, 9, 11) then 30
  else 31 end;

# Parse a strict ISO date into [year, month, day], without normalising invalid days.
def calendar_date:
  (capture("^(?<year>[0-9]{4})-(?<month>[0-9]{2})-(?<day>[0-9]{2})$") // error("invalid ISO date format"))
  | [.year, .month, .day] | map(tonumber)
  | if .[0] >= 1 and .[1] >= 1 and .[1] <= 12 and .[2] >= 1
      and .[2] <= calendar_month_days(.[0]; .[1])
    then . else error("invalid calendar date") end;

# Shift whole calendar months and clamp the day to the destination month.
def calendar_shift($months):
  . as $date
  | ($date[0] * 12 + $date[1] - 1 + $months) as $total
  | ($total / 12 | floor) as $year
  | ($total % 12 + 1) as $month
  | [$year, $month, ([$date[2], calendar_month_days($year; $month)] | min)];

def calendar_format:
  [("0000" + (.[0] | tostring))[-4:], ("00" + (.[1] | tostring))[-2:], ("00" + (.[2] | tostring))[-2:]]
  | join("-");

# CODEOWNERS review is mandatory, with one month of warning and no overdue grace.
#   Good: # Review-by: 2027-01-01, checked on 2026-11-14
#   Bad:  # Review-by: 2027-01-01, checked on 2027-01-02
def rule_codeowners_review_date($today; $content):
  ($today | calendar_date) as $today
  | ($content | split("\n") | map(select(test("^\\s*#\\s*Review-by\\b")))) as $headers
  | if ($headers | length) != 1 then
      ["ERROR", "exactly one '# Review-by: YYYY-MM-DD' header is required"]
    else
      ((try ($headers[0] | capture("^\\s*#\\s*Review-by:[ \\t]*(?<date>[0-9]{4}-[0-9]{2}-[0-9]{2})[ \\t\\r]*$") | .date | calendar_date) catch null) // null) as $due
      | if $due == null then ["ERROR", "Review-by must be a valid date in YYYY-MM-DD format"]
        elif $due > ($today | calendar_shift(12)) then ["ERROR", "Review-by is more than one calendar year ahead, review ownership and set an earlier date"]
        elif $today > $due then ["ERROR", "Review-by \($due | calendar_format) is overdue, review ownership and update the date"]
        elif $today >= ($due | calendar_shift(-1)) then
          ["WARNING", "Review-by \($due | calendar_format) is approaching or due today, review ownership and update the date by \($due | calendar_format)"]
        else empty end
    end
  | @tsv;


# Diagnostics contain constant text and line numbers, never untrusted tokens.

def diagnostic($level; $message): {level: $level, message: $message};

# Approved licences are governance policy, not downstream configuration.
# Keep this policy aligned with security readiness on the engineering dashboard.
# Reference: https://github.com/spdx/license-list-data/tree/v3.26.0/json/details
def approved_licences:
  [
    {
      "id": "MIT",
      "text": "MIT License\n\nCopyright (c) <year> <copyright holders>\n\nPermission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the \"Software\"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:\n\nThe above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.\n\nTHE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.\n"
    },
    {
      "id": "BSD-2-Clause",
      "text": "Copyright (c) <year> <owner>\n\nRedistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:\n\n1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.\n\n2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.\n\nTHIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS \"AS IS\" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.\n"
    },
    {
      "id": "BSD-3-Clause",
      "text": "Copyright (c) <year> <owner>.\n\nRedistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:\n\n1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.\n\n2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.\n\n3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.\n\nTHIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS \"AS IS\" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.\n"
    },
    {
      "id": "Apache-2.0",
      "text": "Apache License\nVersion 2.0, January 2004\nhttp://www.apache.org/licenses/\n\nTERMS AND CONDITIONS FOR USE, REPRODUCTION, AND DISTRIBUTION\n\n1. Definitions.\n\n\"License\" shall mean the terms and conditions for use, reproduction, and distribution as defined by Sections 1 through 9 of this document.\n\n\"Licensor\" shall mean the copyright owner or entity authorized by the copyright owner that is granting the License.\n\n\"Legal Entity\" shall mean the union of the acting entity and all other entities that control, are controlled by, or are under common control with that entity. For the purposes of this definition, \"control\" means (i) the power, direct or indirect, to cause the direction or management of such entity, whether by contract or otherwise, or (ii) ownership of fifty percent (50%) or more of the outstanding shares, or (iii) beneficial ownership of such entity.\n\n\"You\" (or \"Your\") shall mean an individual or Legal Entity exercising permissions granted by this License.\n\n\"Source\" form shall mean the preferred form for making modifications, including but not limited to software source code, documentation source, and configuration files.\n\n\"Object\" form shall mean any form resulting from mechanical transformation or translation of a Source form, including but not limited to compiled object code, generated documentation, and conversions to other media types.\n\n\"Work\" shall mean the work of authorship, whether in Source or Object form, made available under the License, as indicated by a copyright notice that is included in or attached to the work (an example is provided in the Appendix below).\n\n\"Derivative Works\" shall mean any work, whether in Source or Object form, that is based on (or derived from) the Work and for which the editorial revisions, annotations, elaborations, or other modifications represent, as a whole, an original work of authorship. For the purposes of this License, Derivative Works shall not include works that remain separable from, or merely link (or bind by name) to the interfaces of, the Work and Derivative Works thereof.\n\n\"Contribution\" shall mean any work of authorship, including the original version of the Work and any modifications or additions to that Work or Derivative Works thereof, that is intentionally submitted to Licensor for inclusion in the Work by the copyright owner or by an individual or Legal Entity authorized to submit on behalf of the copyright owner. For the purposes of this definition, \"submitted\" means any form of electronic, verbal, or written communication sent to the Licensor or its representatives, including but not limited to communication on electronic mailing lists, source code control systems, and issue tracking systems that are managed by, or on behalf of, the Licensor for the purpose of discussing and improving the Work, but excluding communication that is conspicuously marked or otherwise designated in writing by the copyright owner as \"Not a Contribution.\"\n\n\"Contributor\" shall mean Licensor and any individual or Legal Entity on behalf of whom a Contribution has been received by Licensor and subsequently incorporated within the Work.\n\n2. Grant of Copyright License. Subject to the terms and conditions of this License, each Contributor hereby grants to You a perpetual, worldwide, non-exclusive, no-charge, royalty-free, irrevocable copyright license to reproduce, prepare Derivative Works of, publicly display, publicly perform, sublicense, and distribute the Work and such Derivative Works in Source or Object form.\n\n3. Grant of Patent License. Subject to the terms and conditions of this License, each Contributor hereby grants to You a perpetual, worldwide, non-exclusive, no-charge, royalty-free, irrevocable (except as stated in this section) patent license to make, have made, use, offer to sell, sell, import, and otherwise transfer the Work, where such license applies only to those patent claims licensable by such Contributor that are necessarily infringed by their Contribution(s) alone or by combination of their Contribution(s) with the Work to which such Contribution(s) was submitted. If You institute patent litigation against any entity (including a cross-claim or counterclaim in a lawsuit) alleging that the Work or a Contribution incorporated within the Work constitutes direct or contributory patent infringement, then any patent licenses granted to You under this License for that Work shall terminate as of the date such litigation is filed.\n\n4. Redistribution. You may reproduce and distribute copies of the Work or Derivative Works thereof in any medium, with or without modifications, and in Source or Object form, provided that You meet the following conditions:\n\n(a) You must give any other recipients of the Work or Derivative Works a copy of this License; and\n\n(b) You must cause any modified files to carry prominent notices stating that You changed the files; and\n\n(c) You must retain, in the Source form of any Derivative Works that You distribute, all copyright, patent, trademark, and attribution notices from the Source form of the Work, excluding those notices that do not pertain to any part of the Derivative Works; and\n\n(d) If the Work includes a \"NOTICE\" text file as part of its distribution, then any Derivative Works that You distribute must include a readable copy of the attribution notices contained within such NOTICE file, excluding those notices that do not pertain to any part of the Derivative Works, in at least one of the following places: within a NOTICE text file distributed as part of the Derivative Works; within the Source form or documentation, if provided along with the Derivative Works; or, within a display generated by the Derivative Works, if and wherever such third-party notices normally appear. The contents of the NOTICE file are for informational purposes only and do not modify the License. You may add Your own attribution notices within Derivative Works that You distribute, alongside or as an addendum to the NOTICE text from the Work, provided that such additional attribution notices cannot be construed as modifying the License.\n\nYou may add Your own copyright statement to Your modifications and may provide additional or different license terms and conditions for use, reproduction, or distribution of Your modifications, or for any such Derivative Works as a whole, provided Your use, reproduction, and distribution of the Work otherwise complies with the conditions stated in this License.\n\n5. Submission of Contributions. Unless You explicitly state otherwise, any Contribution intentionally submitted for inclusion in the Work by You to the Licensor shall be under the terms and conditions of this License, without any additional terms or conditions. Notwithstanding the above, nothing herein shall supersede or modify the terms of any separate license agreement you may have executed with Licensor regarding such Contributions.\n\n6. Trademarks. This License does not grant permission to use the trade names, trademarks, service marks, or product names of the Licensor, except as required for reasonable and customary use in describing the origin of the Work and reproducing the content of the NOTICE file.\n\n7. Disclaimer of Warranty. Unless required by applicable law or agreed to in writing, Licensor provides the Work (and each Contributor provides its Contributions) on an \"AS IS\" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied, including, without limitation, any warranties or conditions of TITLE, NON-INFRINGEMENT, MERCHANTABILITY, or FITNESS FOR A PARTICULAR PURPOSE. You are solely responsible for determining the appropriateness of using or redistributing the Work and assume any risks associated with Your exercise of permissions under this License.\n\n8. Limitation of Liability. In no event and under no legal theory, whether in tort (including negligence), contract, or otherwise, unless required by applicable law (such as deliberate and grossly negligent acts) or agreed to in writing, shall any Contributor be liable to You for damages, including any direct, indirect, special, incidental, or consequential damages of any character arising as a result of this License or out of the use or inability to use the Work (including but not limited to damages for loss of goodwill, work stoppage, computer failure or malfunction, or any and all other commercial damages or losses), even if such Contributor has been advised of the possibility of such damages.\n\n9. Accepting Warranty or Additional Liability. While redistributing the Work or Derivative Works thereof, You may choose to offer, and charge a fee for, acceptance of support, warranty, indemnity, or other liability obligations and/or rights consistent with this License. However, in accepting such obligations, You may act only on Your own behalf and on Your sole responsibility, not on behalf of any other Contributor, and only if You agree to indemnify, defend, and hold each Contributor harmless for any liability incurred by, or claims asserted against, such Contributor by reason of your accepting any such warranty or additional liability.\n\nEND OF TERMS AND CONDITIONS\n\nAPPENDIX: How to apply the Apache License to your work.\n\nTo apply the Apache License to your work, attach the following boilerplate notice, with the fields enclosed by brackets \"[]\" replaced with your own identifying information. (Don't include the brackets!) The text should be enclosed in the appropriate comment syntax for the file format. We also recommend that a file or class name and description of purpose be included on the same \"printed page\" as the copyright notice for easier identification within third-party archives.\n\nCopyright [yyyy] [name of copyright owner]\n\nLicensed under the Apache License, Version 2.0 (the \"License\");\nyou may not use this file except in compliance with the License.\nYou may obtain a copy of the License at\n\nhttp://www.apache.org/licenses/LICENSE-2.0\n\nUnless required by applicable law or agreed to in writing, software\ndistributed under the License is distributed on an \"AS IS\" BASIS,\nWITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.\nSee the License for the specific language governing permissions and\nlimitations under the License.\n"
    }
  ];

def is_login: length <= 39 and test("^[A-Za-z0-9]+(?:-[A-Za-z0-9]+)*$");

def is_team:
  split("/") as $parts
  | if ($parts | length) != 2 or ($parts[0] | startswith("@") | not) then false
    else ($parts[0][1:] | is_login)
      and ($parts[1] | length <= 100 and test("^[A-Za-z0-9](?:[A-Za-z0-9_.-]*[A-Za-z0-9])?$"))
    end;

def is_owner:
  (is_team or (startswith("@") and (.[1:] | is_login))
    or test("^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"))
  and (test("(^|[/@])(changeme|your-org|your-team|organisation|organization)(/|$)"; "i") | not);

# Preserve escaped spaces in patterns, and ignore whole-line and inline comments.
def ownership_rules:
  split("\n") | to_entries
  | map(select(.value | test("^\\s*(#|$)") | not)
      | (.key + 1) as $line
      | .value as $raw
      | ($raw | split("#")[0] | [match("(?:\\\\.|[^\\s])+"; "g") | .string]) as $tokens
      | {line: $line, raw_pattern: ($raw | [match("(?:\\\\.|[^\\s])+"; "g") | .string][0]), pattern: $tokens[0], owners: $tokens[1:]});

# GitHub ignores negation, character ranges and escaped initial '#' patterns.
def rule_ownership:
  ownership_rules as $rules
  | [
      $rules[]
      | if (.pattern | startswith("!") or test("[\\[\\]]")) or (.raw_pattern | test("\\\\#")) then
          diagnostic("ERROR"; "unsupported CODEOWNERS pattern on line \(.line)")
        else empty end,
        (if all(.owners[]; is_owner) then empty
          else diagnostic("ERROR"; "invalid owner or template placeholder on line \(.line)") end)
    ]
    + ([$rules[] | select(.pattern | IN("*", "**", "/**"))] | last
      | if any($rules[]; .pattern == "*") and . != null and any(.owners[]; is_team and is_owner) then []
          else [diagnostic("ERROR"; "the effective '*' catch-all must name a team owner")] end);

def rule_security_policy:
  ascii_downcase as $lower
  | [
      ["reporting a vulnerability", "cybersecurity@nhs.net", "ncsc", "general security enquiries"][] as $marker
      | if $lower | contains($marker) then empty
        else diagnostic("ERROR"; "required security policy content is missing: \($marker)") end
    ];

def rule_adoption_todos:
  if test("TODO:"; "i") then
    [diagnostic("WARNING"; "template adoption placeholders remain, resolve TODOs before adopting")]
  else [] end;

# Recognise copyright-only notice lines, not warranty clauses or extra terms.
def copyright_notice:
  test("^[ \\t]*Copyright[ \\t]+(?:\\(c\\)[ \\t]+)?(?:[0-9]{4}(?:-[0-9]{4})?|<year>|\\[yyyy\\])[ \\t]+(?:<copyright holders>|<owner>|\\[name of copyright owner\\]|[A-Za-z0-9][A-Za-z0-9 ,&'()/_-]*)\\.?[ \\t]*$"; "i");

# Only standard titles, copyright-only notices and whitespace may differ.
def normalise_licence:
  gsub("\r"; "")
  | sub("^\\s*#[ \\t]*"; "")
  | sub("^\\s*MIT Licen[sc]e[ \\t]*\\n"; ""; "i")
  | sub("^\\s*BSD[ -][23]-Clause(?: \"[^\"]+\")? Licen[sc]e[ \\t]*\\n"; ""; "i")
  | split("\n")
  | map(select(copyright_notice | not))
  | join("\n")
  | gsub("\\s+"; " ") | sub("^ "; "") | sub(" $"; "");

def rule_licence:
  normalise_licence as $actual
  | if any(approved_licences[]; (.text | normalise_licence) == $actual) then []
    else [diagnostic("ERROR"; "file does not match approved licence text: MIT, Apache-2.0, BSD-2-Clause or BSD-3-Clause")]
  end;

def repository_diagnostics($kind; $content; $today):
  ($content
    | (if $kind == "codeowners" then rule_ownership
      elif $kind == "security" then rule_security_policy
      elif $kind == "contributing" then
        if test("\\S") then [] else [diagnostic("ERROR"; "CONTRIBUTING.md must not be empty")] end
      elif $kind == "licence" then rule_licence
      elif $kind | IN("makefile", "readme", "conduct") then []
      else error("unknown readiness file kind") end),
      (if $kind | IN("security", "contributing", "makefile", "readme", "conduct") then rule_adoption_todos else [] end)
    | .[] | [.level, .message] | @tsv),
  (if $kind == "codeowners" then rule_codeowners_review_date($today; $content) else empty end);

def yaml_diagnostics($kind; $path; $approved):
  (if $kind == "workflow" then
    rule_workflow_grants_no_permissions,
    rule_jobs_declare_permissions,
    rule_write_permissions_are_approved($path; $approved),
    rule_jobs_set_timeouts,
    rule_secrets_are_not_inherited,
    rule_no_privileged_triggers,
    rule_secrets_are_step_scoped,
    rule_mise_cache_is_off_in_publish_and_deploy_workflows
  elif $kind == "action" then empty
  else error("unknown YAML security readiness kind") end),
  rule_actions_are_pinned,
  rule_checkout_does_not_keep_token,
  rule_mise_does_not_keep_token,
  rule_dockerised_quality_actions_force_docker($kind; $path),
  rule_dockerised_quality_jobs_do_not_install_mise($path),
  rule_run_scripts_have_no_expressions,
  rule_run_scripts_quote_github_files,
  rule_github_scripts_have_no_expressions;
