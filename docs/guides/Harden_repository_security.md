# Harden repository security

- [Harden repository security](#harden-repository-security)
  - [Overview](#overview)
  - [Trust boundaries](#trust-boundaries)
  - [GitHub Actions](#github-actions)
    - [Workflow security check](#workflow-security-check)
    - [Fix a failing check](#fix-a-failing-check)
    - [Publish and deploy](#publish-and-deploy)
  - [Secrets](#secrets)
  - [Dependencies and images](#dependencies-and-images)
  - [Tool containers](#tool-containers)
    - [Use the containers on a workstation](#use-the-containers-on-a-workstation)
  - [Making a security-sensitive change](#making-a-security-sensitive-change)
  - [Testing](#testing)
  - [Limits and responsibilities](#limits-and-responsibilities)

## Overview

This template runs repository code, third-party tools and GitHub Actions on
developer machines and CI runners. Treat pull request content, workflow inputs,
downloaded tools and container images as potential paths to the repository,
secrets and CI credentials. Apply least privilege at each boundary rather than
assuming that a linter, a container or a Git hook makes code safe.

The template provides toolchain, workflow and quality-check defaults, not an
application security policy. Teams that add services must assess their own
authentication, data handling, network exposure and deployment controls.

## Trust boundaries

- **Workflow input to a CI script:** A branch name, pull request title or
  dispatch input becomes code when a workflow expression inserts it into a
  script. The workflow security check rejects `${{` in `run` scripts and
  `actions/github-script` scripts, so values reach them through step `env`.
- **Third-party code to CI credentials:** An action or tool can use anything its
  job can reach. Actions are pinned by commit SHA, each job gets only the
  `GITHUB_TOKEN` permissions it declares, and checkout and mise do not leave the
  token for later steps.
- **Local tools to the working tree:** A linter that runs natively has the
  user's access to files and the network. In Docker, the linters run with no
  network and a read-only checkout.
- **Repository history to downstream users:** A committed credential remains
  available after it is deleted. Secret scanning checks every commit, and an
  exposed credential must be rotated.

## GitHub Actions

Every [workflow](../../.github/workflows/) sets `permissions: {}`, so each job
starts with no `GITHUB_TOKEN` permissions and declares the ones it needs. Most
jobs need only `contents: read`. The `metadata` job of the pull request workflow
also reads pull requests to find one for the branch. The `publish` job holds the
only write permission, `contents: write`, which `gh release create` needs. It
does not check out the repository, so no repository code runs with that token.

### Workflow security check

[check-workflow-security.sh](../../scripts/quality/check-workflow-security.sh)
checks every workflow file and every local `action.yaml` or `action.yml` under
[.github/actions](../../.github/actions). It converts each file to JSON with
`yq`, applies the rules in
[check-workflow-security.jq](../../scripts/quality/check-workflow-security.jq)
with `jq`, and fails when a file breaks a rule or cannot be parsed. The rules
require:

- `permissions: {}` at workflow level and a permissions mapping on every job. A
  job may hold a write permission only when
  [workflow-security.yaml](../../scripts/config/workflow-security.yaml) approves
  it for that workflow and job.
- No `pull_request_target` or `workflow_run` trigger, and no `secrets: inherit`
  on a reusable workflow call. Pass only the named secrets that are needed.
- Secrets only in step environments, not in workflow, job, container or service
  environments. Those environments may still hold an expression that only tests
  whether a secret is set, such as `${{ secrets.NAME != '' }}`.
- Remote actions pinned to a full 40-character commit SHA, and container actions
  pinned to a SHA-256 digest. Local actions may use `./` paths.
- `persist-credentials: false` on `actions/checkout` and
  `persist_github_token: false` on `jdx/mise-action`.
- No `${{` expressions in `run` scripts or `actions/github-script` scripts.
- `FORCE_USE_DOCKER=true` on the five container-based quality actions, and no
  `jdx/mise-action` step in their commit-stage jobs. See
  [Tool containers](#tool-containers).

Each rule in the jq file has a short description and an example of passing and
failing YAML. The check runs in `make lint`, as a pre-commit hook and in the
commit-stage CI job. `make test` also runs it against this repository. It has no
container fallback and needs the `yq` and `jq` that `make config` installs. To
change a rule, update its tests and explain the risk in review. Do not bypass
the check.

An entry in `workflow-security.yaml` names a workflow file, a job and a
permission. It records a reviewed approval and grants nothing, so the job must
still declare the permission.

### Fix a failing check

Each error names the file and the rule it breaks. The usual fixes are:

| Error contains                              | Fix                                                                                                   |
| ------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| `workflow permissions must be empty`        | Set `permissions: {}` at the top of the workflow and grant permissions per job.                       |
| `must declare permissions`                  | Add a `permissions` mapping to the job, usually `contents: read`, or `{}` when it needs none.         |
| `write permission is not approved`          | Remove the grant, or review it and add an entry to `workflow-security.yaml`.                          |
| `must not be interpolated`                  | Move each `${{ }}` value into step `env` and read it as `"$NAME"` or `process.env.NAME`.              |
| `secret values must not be set`             | Move the secret into the `env` of the step that uses it.                                              |
| `must set persist-credentials: false`       | Add `persist-credentials: false` under the checkout step's `with`.                                    |
| `action ref is not a full 40-character SHA` | Pin the release commit SHA with a version comment, see [Update Dependencies](Update_Dependencies.md). |
| `file is not a valid YAML mapping`          | Fix the YAML error that `yq` prints above the message.                                                |

### Publish and deploy

[cicd-2-publish.yaml](../../.github/workflows/cicd-2-publish.yaml) runs
`gh release create` with `--repo "$GITHUB_REPOSITORY"`, so the publish job needs
no checkout. [cicd-3-deploy.yaml](../../.github/workflows/cicd-3-deploy.yaml)
requires a `tag` input with no default. It rejects `latest`, checks the value
with `git check-ref-format` and checks out `refs/tags/<tag>` instead of the
default branch. A valid ref name does not prove that the tag exists or that it
cannot move. Protect release tags and restrict who can run the deploy workflow
in the repository settings.

The build, publish, deploy and acceptance steps are template placeholders.
Implement and review them before relying on them.

## Secrets

[scan-secrets.sh](../../scripts/quality/scan-secrets.sh) runs Gitleaks with
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

## Dependencies and images

[mise.toml](../../mise.toml) pins every native tool to an exact version and
every helper image to a tag and SHA-256 digest in its `[_.docker]` table. Its
settings make mise record checksums and supported provenance in `mise.lock`,
install only locked versions and re-check provenance on install. When mise
resolves an update, it skips releases that are less than seven days old. These
controls show which bytes were installed. They do not prove that a release or
its dependencies are benign, so review release notes and lock changes before you
upgrade. Follow [Update Dependencies](Update_Dependencies.md) for the cooldown,
approval and digest-refresh steps.

[Dependabot](../../.github/dependabot.yaml) proposes Docker, GitHub Actions, npm
and uv updates after a seven-day cooldown. It does not read `mise.toml`, so tool
and image pins are refreshed by hand.

[docker.lib.sh](../../scripts/docker/docker.lib.sh) stops with an error when a
helper image has no valid digest pin, instead of falling back to `latest`. It
pulls the pinned digest when the image is missing locally, and the wrappers run
the image by that digest.

[format-markdown.sh](../../scripts/quality/format-markdown.sh) runs the Prettier
version pinned as `npm:prettier` in `[tools]`. Natively it runs the copy that
`make config` installs from the lockfile. In Docker it runs
`npx --yes prettier@<version>` in the pinned `node` image, which downloads that
exact version from npm at run time without checking it against `mise.lock`.

## Tool containers

Apart from the workflow security check, each check runs its tool natively when
the tool is installed. Otherwise, or when `FORCE_USE_DOCKER=true`, it runs the
tool's pinned image. The Gitleaks, EditorConfig Checker, markdownlint, Lychee,
ShellCheck and Hadolint containers run with `--network none` and mount the
checkout read-only. A compromised dependency in one of these images cannot send
data over the network or change the working tree. Lychee also has
`offline = true` in [lychee.toml](../../scripts/config/lychee.toml), so it
checks local links only, natively or in Docker.

This containment has limits:

- Docker pulls the image on the host, with network access, before the container
  starts.
- A container can read the whole checkout, including untracked and ignored files
  such as `.env`, and print what it reads.
- The Prettier container keeps network access and a writable mount, because
  `npx` downloads Prettier and Prettier rewrites files.
- The wrapper scripts, the frontmatter step of the Markdown format check and the
  workflow security check run natively.
- A native tool runs with the full access of the developer or the CI runner.

In the commit-stage workflow, the `scan-secrets`, `check-file-format`,
`check-markdown-format`, `check-markdown-links` and `check-shell-lint` actions
set `FORCE_USE_DOCKER=true`, and their jobs do not install tools with mise. The
workflow security check enforces both. These jobs have only `contents: read`, do
not keep checkout credentials and pass no secrets or tokens into the containers.
The workflow security job runs natively with the `yq` and `jq` that mise
installs.

### Use the containers on a workstation

For the same isolation on your machine, add `export FORCE_USE_DOCKER=true` to
your shell profile. The checks then use their pinned containers in `make lint`,
in the Git hooks and when run on their own, even when `make config` has
installed the native tools. The workflow security check still runs natively. A
Git hook started by an editor sees the variable only if the editor inherits your
shell environment. Docker must be running. The images are `linux/amd64`, so
Apple silicon runs them under emulation.

The table shows the median of three runs of each `make` target over the whole
repository, on an Apple silicon workstation with the images already pulled.

| Check, mode                  | Native | Docker | Added  |
| ---------------------------- | ------ | ------ | ------ |
| Secret scan, `whole-history` | 0.51 s | 0.98 s | 0.47 s |
| File format, `all`           | 0.10 s | 0.45 s | 0.35 s |
| Markdown format, `all`       | 0.38 s | 1.40 s | 1.02 s |
| Markdown links, `all`        | 0.08 s | 0.49 s | 0.41 s |
| Shell lint, `all`            | 2.09 s | 3.33 s | 1.24 s |

In total, the checks took 3.16 s natively and 6.65 s in Docker. ShellCheck
takes the most time in both modes, though it runs in parallel, one container
for each group of related scripts in Docker. A first image pull adds time, and
x64 CI runners have no emulation cost.

## Making a security-sensitive change

1. Identify who controls each input, dependency, token, file and network path.
   Include CI jobs and native runs, not only Docker runs.
2. Grant the smallest job permissions and keep secrets in step `env`. For a
   necessary write permission, review the job and add its approval to
   [workflow-security.yaml](../../scripts/config/workflow-security.yaml).
3. Pin external actions and images. Follow the cooldown and integrity checks in
   [Update Dependencies](Update_Dependencies.md). Do not fetch executable
   dependencies at run time unless the risk is reviewed.
4. Add a failing test for the policy or wrapper behaviour you are changing, make
   the change and rerun the test. Keep local and CI paths aligned.
5. Run the checks in [Testing](#testing) and review the diff, including new
   files, generated output and the GitHub settings that cannot be tested here.

## Testing

Review and trust `mise.toml`, then run `make config` as the
[README](../../README.md) describes. From the repository root, run:

```shell
make check-workflow-security
make scan-secrets
make scan-secrets check=all
make lint
make test
```

`make lint` does not scan for secrets, so run `make scan-secrets` as well.
`make test` includes
[check-workflow-security.test.sh](../../scripts/quality/tests/check-workflow-security.test.sh),
which you can also run on its own. To exercise the containers, prefix a check
with `FORCE_USE_DOCKER=true`.

The file format, Markdown and shell lint checks select only files known to Git.
`make lint` skips a new file until you stage it or run
`git add --intent-to-add <file>`. The workflow security check reads its
directories directly, so it includes new files. Git hooks run only where
`make config` installed them, and `git commit --no-verify` skips them.
[Run Git hooks on commit](Run_Git_hooks_on_commit.md) describes the hooks.

## Limits and responsibilities

The workflow security check enforces specific YAML rules. It does not audit
shell code, action behaviour, repository settings or external integrations.
Secret scanning matches patterns and cannot prove that a repository holds no
secrets. A digest fixes image content but does not make its publisher or code
trustworthy. `--network none` and the read-only mount constrain only the tool
containers, not native programs, CI runners or image pulls.

CI is the shared backstop only when branch protection or a ruleset requires its
checks. [CODEOWNERS](../../.github/CODEOWNERS) names an owner for every file,
including the workflows and `workflow-security.yaml`, but GitHub enforces that
review only when a rule requires code owner review. Each adopting team must
configure branch and tag protection, required status checks, deployment
environments and permissions, and must review its own application dependencies.
Report vulnerabilities through the route in
[SECURITY.md](../../.github/SECURITY.md).
