# Harden repository security 🔒

- [Harden repository security 🔒](#harden-repository-security-)
  - [Overview 🧭](#overview-)
  - [Trust boundaries 🧱](#trust-boundaries-)
  - [GitHub Actions 🤖](#github-actions-)
    - [Publish and deploy](#publish-and-deploy)
  - [Security readiness](#security-readiness)
    - [Run the check](#run-the-check)
    - [Workflow and action rules](#workflow-and-action-rules)
    - [CODEOWNERS review date](#codeowners-review-date)
    - [Fix a failing check](#fix-a-failing-check)
    - [Repository file rules](#repository-file-rules)
    - [Engineering dashboard checks](#engineering-dashboard-checks)
  - [Secrets 🔐](#secrets-)
  - [Dependencies and images 📦](#dependencies-and-images-)
  - [Tool containers 🐳](#tool-containers-)
    - [Use the containers on a workstation](#use-the-containers-on-a-workstation)
  - [Making a security-sensitive change 🚦](#making-a-security-sensitive-change-)
  - [Testing 🧪](#testing-)
  - [Limits and responsibilities 📏](#limits-and-responsibilities-)

## Overview 🧭

This template runs repository code, third-party tools and GitHub Actions on
developer machines and CI runners. Treat pull request content, workflow inputs,
downloaded tools and container images as potential paths to the repository,
secrets and CI credentials. Apply least privilege at each boundary rather than
assuming that a linter, a container or a Git hook makes code safe.

The template provides toolchain, workflow and quality-check defaults, not an
application security policy. Teams that add services must assess their own
authentication, data handling, network exposure and deployment controls.

## Trust boundaries 🧱

- **Workflow input to a CI script:** A branch name, pull request title or
  dispatch input becomes code when a workflow expression inserts it into a
  script. The security readiness check rejects `${{` in `run` scripts and
  `actions/github-script` scripts, so values reach them through step `env`.
- **Third-party code to CI credentials:** An action or tool can use anything its
  job can reach. Actions are pinned by commit SHA, each job gets only the
  `GITHUB_TOKEN` permissions it declares, and checkout and mise do not leave the
  token for later steps.
- **Local tools to the working tree:** Container-capable quality tools use
  pinned Docker images by default, locally and in CI. Most lint containers have
  no network and a read-only checkout, reducing host access. Native tools have
  the user's or runner's access to files and the network, so opting out is not
  recommended.
- **Repository history to downstream users:** A committed credential remains
  available after it is deleted. Secret scanning checks every commit, and an
  exposed credential must be rotated.

## GitHub Actions 🤖

Every [workflow](../../../.github/workflows/) sets `permissions: {}`, so each
job starts with no `GITHUB_TOKEN` permissions and declares the ones it needs.
Most jobs need only `contents: read`.

The `🏷️ Check pull request title` job has only `contents: read`.
[security-readiness.yaml](../../../scripts/config/security-readiness.yaml)
approves no job-level `GITHUB_TOKEN` write grants.

### Publish and deploy

[cicd-2-publish.yaml](../../../.github/workflows/cicd-2-publish.yaml) releases
with a short-lived token of the release GitHub App, not with `GITHUB_TOKEN`.
Every publish job declares only read permissions. The App token is created only
in the plan and release jobs, which run on pushes to `main` and never run pull
request code. The plan job uses it for an authenticated dry run on every push.
The App
bypasses the rulesets on `main` and `v*` tags so it can create the GitHub-signed
release commit through the API and push tags. The App key remains a shared
organisation secret for now. See [Publish releases](Publish_releases.md#release-app)
for its permissions.

[cicd-3-deploy.yaml](../../../.github/workflows/cicd-3-deploy.yaml) requires a
`tag` input with no default. It rejects `latest`, checks the value with
`git check-ref-format` and checks out `refs/tags/<tag>` instead of the default
branch. A valid ref name does not prove that the tag exists or that it cannot
move. Add a ruleset on `v*` tags that restricts creations, updates and
deletions, with only the release App in its bypass list. Restrict who can run
the deploy workflow in the repository settings. Only one deployment runs at a
time, and a running deployment is never cancelled. At most one more waits behind
it. When another deployment starts, GitHub cancels the one that is waiting and
queues the new one.

The build, publish, deploy and acceptance steps are template placeholders.
Implement and review them before relying on them.

## Security readiness

The engineering dashboard reports security readiness across repositories. The
template implements the checks that can run quickly against tracked files
without credentials. Passing locally does not prove that all security readiness
checks on the engineering dashboard pass.

### Run the check

Run the combined target to see warnings immediately:

```shell
make lint-security-readiness
```

The target runs after `lint-pipeline-contract` in `make lint`. Its Make
definition and pre-commit hook also follow the pipeline contract check. The
commit-stage CI job declares `needs: check-pipeline-contract`, so it starts only
after that job passes. The pre-commit hook always runs and shows output even
when passing. Warnings do not block commits or CI, and CI emits warning
annotations. `make test` exercises the rules but hides successful checker
output.

The check needs the existing `yq`, `jq` and `date` tools. It has no Docker
fallback and makes no network requests. Use `make config` to install the
repository toolchain.

### Workflow and action rules

[check-security-readiness.sh](../../../scripts/quality/check-security-readiness.sh)
checks tracked workflow files and tracked local `action.yaml` or `action.yml`
under [.github/actions](../../../.github/actions). Like the other checks,
`check=staged-changes`, `check=working-tree-changes` or `check=branch` limits
the workflow and action selection to changed files. Repository-wide checks still
run every time. Untracked files never satisfy a check. A change or deletion of
the write-approval file, rules or script checks all workflows and actions. It
converts each file to JSON with `yq`, applies the rules in
[check-security-readiness.jq](../../../scripts/quality/check-security-readiness.jq)
with `jq`, and fails when a file breaks a rule or cannot be parsed. The rules
require:

- `permissions: {}` at workflow level and a permissions mapping on every job. A
  job may hold a write permission only when
  [security-readiness.yaml](../../../scripts/config/security-readiness.yaml)
  approves it for that workflow and job.
- No `pull_request_target` or `workflow_run` trigger, and no `secrets: inherit`
  on a reusable workflow call. Pass only the named secrets that are needed.
- Secrets only in step environments, not in workflow, job, container or service
  environments. Those environments may still hold an expression that only tests
  whether a secret is set, such as `${{ secrets.NAME != '' }}`.
- Remote actions pinned to a full 40-character commit SHA, and container actions
  pinned to a SHA-256 digest. Local actions may use `./` paths.
- `persist-credentials: false` on `actions/checkout` and
  `persist_github_token: false` on `jdx/mise-action`.
- `cache: false` on `jdx/mise-action` in publish and deploy workflows, so they
  install tools fresh instead of restoring a cache that another run wrote. The
  action caches by default. The check treats a workflow as publish or deploy
  when it has no `pull_request`, `merge_group` or `workflow_call` trigger. It
  cannot spot publish or deploy jobs inside other workflows, so set
  `cache: false` on those jobs yourself. The stage workflows keep their cache,
  so pull requests still start quickly.
- `timeout-minutes` set to a positive number or a `${{ }}` expression on every
  job that runs steps, so a hung step cannot hold a runner for GitHub's 6 hour
  default. A job that calls a reusable workflow has no steps and is exempt.
- No `${{` expressions in `run` scripts or `actions/github-script` scripts.
- Quoted paths where a `run` script writes to a GitHub Actions file, as in
  `>> "$GITHUB_OUTPUT"` or `tee -a "$GITHUB_OUTPUT"`. The check covers
  `GITHUB_OUTPUT`, `GITHUB_ENV`, `GITHUB_PATH`, `GITHUB_STEP_SUMMARY` and
  `GITHUB_STATE`. Nothing runs ShellCheck on `run` scripts, so keep them short
  and move logic into a script under `scripts/`.
- The five container-based quality actions default to
  `FORCE_USE_DOCKER=true`. A consistent `false` setting warns without failing.
  Missing or mixed settings fail. Their jobs cannot use `jdx/mise-action`. A
  native opt-out needs the tools already installed on the runner. See
  [Tool containers](#tool-containers-).

The workflow rules in the jq module include passing and failing examples. To
change a rule, update its tests and explain the risk in review. Do not bypass
the governance checks.

### CODEOWNERS review date

The repository baseline includes the tracked
[CODEOWNERS](../../../.github/CODEOWNERS) and its review date. Every check mode
validates it, even when no workflows or actions have changed. It must contain
exactly one `# Review-by: YYYY-MM-DD` header with a valid date. Missing files,
duplicate headers and invalid dates fail.

The check compares dates using UTC and calendar months or years, not fixed
numbers of days. Month-end shifts use the last valid day of the destination
month.

| Review date condition                                   | Result                 |
| ------------------------------------------------------- | ---------------------- |
| More than one calendar year ahead                       | Fail                   |
| Before one calendar month before due                    | Pass without a warning |
| From one calendar month before due through the due date | Warn without failing   |
| After the due date                                      | Fail                   |

For `# Review-by: 2027-01-01`, warnings start on 1 December 2026 and failures
start on 2 January 2027. The due date itself still passes. This expiry boundary
matches the security readiness check on the engineering dashboard. Warnings
appear on stderr and as GitHub Actions annotations in CI. To resolve a warning
or failure, review the ownership team and update the date. Do not extend the
date without reviewing ownership.

An entry in
[security-readiness.yaml](../../../scripts/config/security-readiness.yaml) names
a workflow file, a job and a permission. It records a reviewed approval and
grants nothing, so the job must still declare the permission.

### Fix a failing check

Each error names the file and the rule it breaks. The usual fixes are:

| Error contains                              | Fix                                                                                                   |
| ------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| `workflow permissions must be empty`        | Set `permissions: {}` at the top of the workflow and grant permissions per job.                       |
| `must declare permissions`                  | Add a `permissions` mapping to the job, usually `contents: read`, or `{}` when it needs none.         |
| `write permission is not approved`          | Remove the grant, or review it and add an entry to `security-readiness.yaml`.                         |
| `must not be interpolated`                  | Move each `${{ }}` value into step `env` and read it as `"$NAME"` or `process.env.NAME`.              |
| `secret values must not be set`             | Move the secret into the `env` of the step that uses it.                                              |
| `must set persist-credentials: false`       | Add `persist-credentials: false` under the checkout step's `with`.                                    |
| `must set cache: false`                     | Add `cache: false` under the mise step's `with`.                                                      |
| `must set timeout-minutes`                  | Add `timeout-minutes` to the job, set to its expected run time with a small margin.                   |
| `must quote`                                | Quote the variable named in the error, as in `>> "$GITHUB_ENV"`.                                      |
| `action ref is not a full 40-character SHA` | Pin the release commit SHA with a version comment, see [Update Dependencies](Update_Dependencies.md). |
| `file is not a valid YAML mapping`          | Fix the YAML error that `yq` prints above the message.                                                |

### Repository file rules

[check-security-readiness.sh](../../../scripts/quality/check-security-readiness.sh)
checks the complete baseline in every supported `check=...` mode, even when no
files changed. It reads working-tree content from tracked files, not just the
staged versions. Its rules are:

- **Ownership:** [.github/CODEOWNERS](../../../.github/CODEOWNERS) must contain
  an effective `*` rule with at least one team owner. The check validates the
  file but cannot confirm that its teams or people exist.
- **Security policy:** A tracked, non-empty `SECURITY.md` must include
  `reporting a vulnerability`, `cybersecurity@nhs.net`, `ncsc` and
  `general security enquiries`, ignoring case. These are the policy markers used
  by security readiness on the engineering dashboard.
- **Contribution guide:** A tracked `CONTRIBUTING.md` must not be empty.
- **Adoption TODOs:** `TODO:` markers in the tracked root `Makefile` and
  `README.md`, and the selected `CODE_OF_CONDUCT.md`, `CONTRIBUTING.md` and
  `SECURITY.md`, warn without failing. Resolve TODOs before adopting the
  template for a project.
- **Licence:** A tracked root licence file must match MIT, Apache-2.0,
  BSD-2-Clause or BSD-3-Clause. The complete text is compared with the
  governance-approved references hardcoded in
  [check-security-readiness.jq](../../../scripts/quality/check-security-readiness.jq).
  The reference texts come from SPDX license-list-data v3.26.0. Standard
  Markdown titles, standard copyright-only notices and whitespace may differ.
  Copyright notices must have year and holder fields without additional
  sentences or restrictions. Copyright-prefixed text containing extra terms is
  not ignored. Modified, additional or truncated terms fail. This conservative
  comparison is narrower than SPDX's full equivalence rules. Equivalent variants
  may need governance-approved checker updates. It is not a legal assessment or
  permission to change the project's licence.

Governance defines the security readiness rules and approved licences. They are
hardcoded in the checker, not configured by downstream teams. When governance
changes the security readiness checks reported on the engineering dashboard,
update this checker and its tests to match. Do not introduce a repository
allowlist or override to bypass the governance policy.

Required files must be readable regular files, not symlinks. Missing files,
invalid rules and evaluation failures block the check. The checker uses the
existing `jq` tool and performs no network requests. Date validation remains in
the security readiness check described above.

### Engineering dashboard checks

These are the 17 security readiness checks. The online checks remain on the
engineering dashboard and are not local or CI API calls in this template.

| Security readiness check                | Local feedback or engineering dashboard requirement                                                                                                        |
| --------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| CODEOWNERS present                      | Security readiness requires the tracked file.                                                                                                              |
| CODEOWNERS review date valid            | Security readiness fails after the UTC due date. It also warns one month before due and limits future dates to one year.                                   |
| Ownership teams non-secret              | Offline syntax validation cannot prove this. The engineering dashboard checks team visibility through GitHub.                                              |
| At least two maintainers                | The engineering dashboard counts distinct members across ownership teams. Offline checks cannot prove membership or activity.                              |
| Actions pinned                          | Security readiness validates commit SHAs and container digests. The engineering dashboard uses its action-pinning scan result.                             |
| Dependabot PRs not stale                | The engineering dashboard checks that open Dependabot PRs are younger than 14 days.                                                                        |
| Contribution guide present              | Offline readiness requires the tracked guide to be non-empty.                                                                                              |
| Security policy present                 | Offline readiness requires the tracked policy.                                                                                                             |
| Security policy aligned                 | Offline readiness checks the four required policy markers.                                                                                                 |
| SonarCloud quality gate passed          | The engineering dashboard reads the project's SonarCloud quality-gate status. Local file checks cannot establish it.                                       |
| Issue response time met                 | The engineering dashboard checks that open issues receive a first response within seven days.                                                              |
| Vulnerability response time met         | The engineering dashboard checks vulnerability data. Critical alerts fail at five days old and high alerts at ten days old.                                |
| Approved licence present                | Offline readiness compares approved licence text. The engineering dashboard checks GitHub's recognised SPDX identifier against the same four approved IDs. |
| Secret scanning enabled                 | The engineering dashboard checks the GitHub setting for public repositories. Local secret scanning is a separate control.                                  |
| Push protection enabled                 | The engineering dashboard checks the GitHub setting for public repositories.                                                                               |
| Security advisories available           | The engineering dashboard checks availability through GitHub for public repositories.                                                                      |
| Private vulnerability reporting enabled | The engineering dashboard checks the GitHub setting for public repositories.                                                                               |

Do not infer that settings are enabled from a local pass. Investigate failures
through the engineering dashboard and the responsible repository or organisation
settings.

## Secrets 🔐

[scan-secrets.sh](../../../scripts/quality/scan-secrets.sh) runs Gitleaks with
redacted output. The pre-commit hook and the commit-stage CI job use
`check=whole-history`, which scans every commit on every ref but not uncommitted
files. `check=all` scans staged changes, working-tree files including untracked
ones, and the commits on the current branch. See [Scan secrets](Scan_secrets.md)
for the modes, configuration, ignore fingerprints and how to remove a leaked
secret.

Do not put credentials in source, workflow definitions, build arguments,
command-line flags or logs. Give a secret only to the step that needs it. The
workflow policy limits where a secret is placed, but it cannot stop an action
from logging, forwarding or misusing it. If a credential is exposed, revoke or
rotate it first, then assess history, logs and downstream copies. Add an ignore
rule only for a reviewed false positive, never to accept a real credential.

## Dependencies and images 📦

[mise.toml](../../../mise.toml) pins every native tool to an exact version and
every helper image to a tag and SHA-256 digest in its `[_.docker]` table. Its
settings make mise record checksums and supported provenance in `mise.lock`,
install only locked versions and re-check provenance on install. When mise
resolves an update, it skips releases that are less than seven days old. These
controls show which bytes were installed. They do not prove that a release or
its dependencies are benign, so review release notes and lock changes before you
upgrade. Follow [Update Dependencies](Update_Dependencies.md) for the cooldown,
approval and digest-refresh steps.

[Dependabot](../../../.github/dependabot.yaml) proposes Docker, GitHub Actions,
npm and uv updates after a seven-day cooldown. It does not read `mise.toml`, so
tool and image pins are refreshed by hand.

The [publish workflow](../../../.github/workflows/cicd-2-publish.yaml) pins
semantic-release and its plugins to exact versions, but the semantic-release
action installs them with npm at run time. Their transitive dependencies resolve
afresh on every run, with no lockfile, integrity check or cooldown, and they run
with the release App token. Dependabot cannot update these pins.

[docker.lib.sh](../../../scripts/docker/docker.lib.sh) stops with an error when
a helper image has no valid digest pin, instead of falling back to `latest`. It
pulls the pinned digest when the image is missing locally, and the wrappers run
the image by that digest.

[format-markdown.sh](../../../scripts/quality/format-markdown.sh) runs the
Prettier version pinned as `npm:prettier` in `[tools]`. Natively it runs the
copy that `make config` installs from the lockfile. In Docker it runs
`npx --yes prettier@<version>` in the pinned `node` image, which downloads that
exact version from npm at run time without checking it against `mise.lock`.

## Tool containers 🐳

Container-capable checks use their pinned Docker images by default, even when a
native tool is installed. See
[Use native tools or Docker](Run_and_configure_quality_checks.md#use-native-tools-or-docker-)
for configuration and the checks that always run natively.

The Gitleaks, EditorConfig Checker, markdownlint, Lychee, ShellCheck and
Hadolint containers run with `--network none` and mount the checkout read-only.
A compromised dependency in one of these images cannot send data over the
network or change the working tree. Lychee also has
`offline = true` in [lychee.toml](../../../scripts/config/lychee.toml), so it
checks local links only, natively or in Docker.

This containment has limits:

- Docker pulls the image on the host, with network access, before the container
  starts.
- A container can read the whole checkout, including untracked and ignored files
  such as `.env`, and print what it reads.
- The Prettier container keeps network access and a writable mount, because
  `npx` downloads Prettier and Prettier rewrites files.
- The wrapper scripts, the Markdown frontmatter step, and the pipeline-contract
  and security-readiness checks run natively.
- A native tool runs with the full access of the developer or the CI runner.

In the commit-stage workflow, the `scan-secrets`, `check-file-format`,
`check-markdown-format`, `check-markdown-links` and `check-shell-lint` actions
set `FORCE_USE_DOCKER=true` by default, and their jobs do not install tools with
mise. Security readiness allows a consistent false opt-out with one warning,
and rejects missing or mixed settings. Make-driven checks also default to
containers. These jobs have only `contents: read`, do not keep checkout
credentials and pass no secrets or tokens into the containers. The
pipeline-contract and security-readiness jobs run natively with the `yq` and
`jq` that mise installs.

### Use the containers on a workstation

Git hooks started by an editor see shell settings only when the editor inherits
that environment. The default platform is `linux/amd64`, so Apple silicon runs
those images under emulation. See
[Platform architecture](Build_Docker_images.md#platform-architecture).

## Making a security-sensitive change 🚦

1. Identify who controls each input, dependency, token, file and network path.
   Include CI jobs and native runs, not only Docker runs.
2. Grant the smallest job permissions and keep secrets in step `env`. For a
   necessary write permission, review the job and add its approval to
   [security-readiness.yaml](../../../scripts/config/security-readiness.yaml).
3. Pin external actions and images. Follow the cooldown and integrity checks in
   [Update Dependencies](Update_Dependencies.md). Do not fetch executable
   dependencies at run time unless the risk is reviewed.
4. Add a failing test for the policy or wrapper behaviour you are changing, make
   the change and rerun the test. Keep local and CI paths aligned.
5. Run the checks in [Testing](#testing-) and review the diff, including new
   files, generated output and the GitHub settings that cannot be tested here.

## Testing 🧪

Review and trust `mise.toml`, then run `make config` as the
[README](../../../README.md) describes. From the repository root, run:

```shell
make scan-secrets
make scan-secrets check=all
make lint
make test
```

`make lint` does not scan for secrets, so run `make scan-secrets` as well.
`make test` includes
[check-security-readiness.test.sh](../../../scripts/quality/tests/check-security-readiness.test.sh),
which you can also run on its own.

The file format, Markdown, shell lint and security readiness checks select only
files known to Git. `make lint` skips a new file until you stage it or run
`git add --intent-to-add <file>`. See
[Choose which files to check](Run_and_configure_quality_checks.md#choose-which-files-to-check-)
for the tracked-file scopes. Git hooks run only where `make config` installed
them, and `git commit --no-verify` skips them.
[Run Git hooks on commit](Run_Git_hooks_on_commit.md) describes the hooks.

## Limits and responsibilities 📏

The security readiness check enforces workflow and action YAML rules and the
repository-file governance baseline. It does not audit shell code, action
behaviour, repository settings or external integrations. Secret scanning matches
patterns and cannot prove that a repository holds no secrets. A digest fixes
image content but does not make its publisher or code trustworthy.
`--network none` and the read-only mount constrain only the tool containers, not
native programs, CI runners or image pulls.

CI is the shared backstop only when branch protection or a ruleset requires its
checks. [CODEOWNERS](../../../.github/CODEOWNERS) names an owner for every file,
including the workflows and `security-readiness.yaml`, but GitHub enforces that
review only when a rule requires code owner review. Each adopting team must
configure branch and tag protection, required status checks, deployment
environments and permissions, and must review its own application dependencies.
Report vulnerabilities through the route in
[SECURITY.md](../../../.github/SECURITY.md).
