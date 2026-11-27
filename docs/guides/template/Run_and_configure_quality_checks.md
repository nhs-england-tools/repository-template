# Run and configure quality checks ✅

- [Run and configure quality checks ✅](#run-and-configure-quality-checks-)
  - [Overview 🧭](#overview-)
  - [Why the checks are built in 🧠](#why-the-checks-are-built-in-)
    - [Feedback, constraint and guidance](#feedback-constraint-and-guidance)
    - [Built for agentic development](#built-for-agentic-development)
    - [One check, every stage](#one-check-every-stage)
  - [Prerequisites 📋](#prerequisites-)
  - [Choose a command 🧭](#choose-a-command-)
  - [Choose which files to check 📂](#choose-which-files-to-check-)
  - [Configure rules and exclusions 🔧](#configure-rules-and-exclusions-)
  - [Use native tools or Docker 🐳](#use-native-tools-or-docker-)
  - [Add project checks ➕](#add-project-checks-)

## Overview 🧭

This guide explains how to run, scope, configure and extend the repository's
quality checks, and why they are there. It assumes you know Make and the tools
themselves, such as ShellCheck and markdownlint. The interesting part is not any
single linter. It is how the checks work together to keep quality high when much
of the code is written by AI agents.

Read [Why the checks are built in](#why-the-checks-are-built-in-) first for the
reasoning. The sections after it are task-focused. They show how to run a check,
choose its files, tune its rules, choose how it runs and add your own.

## Why the checks are built in 🧠

### Feedback, constraint and guidance

A quality check does three jobs at once.

**Feedback.** A check answers "is this change right?" in seconds, on your
machine, the same way every time. Each finding names a file and the rule it
breaks. You, or an agent, can act on it without waiting for a reviewer.

**Constraint.** A check encodes a decision the team has already made, such as
the file format, shell safety, failure notifications in every pipeline or the
security baseline. A change that breaks the decision fails, whoever wrote it.
Reviewers can then spend their attention on design and intent rather than style.

**Guidance.** A good finding says why, not only what. The pipeline-contract
check, for example, reports:

```text
ERROR: .github/workflows/cicd-1-pull-request.yaml: job notify must start its if: condition with !cancelled(), so it reports failures and stays cancellable
```

The message carries the reason for the rule. Whoever reads it learns the
convention as well as the fix, and gets the next change right first time. The
rule files go further. Each pipeline-contract and security-readiness rule
documents its intent with passing and failing examples.

### Built for agentic development

This repository is designed for development with AI agents. An agent writes code
quickly and sounds confident, but it does not remember last week's review
comments. It works from what is in its context: the instructions, the code and
the output of the commands it runs. It can also report that it has finished
while `make lint` still fails.

Checks are the most dependable way to hand an agent the team's standards.
Written guidance can be skimmed or forgotten. A failing check gives a definite
answer, and its output lands in the agent's context exactly where it is needed.

The repository closes the loop with a Stop hook. When a GitHub Copilot agent
tries to finish a turn that changed files, the hook runs `make lint` and
`make test`. If either fails, it sends a short report back and the agent carries
on, up to three times per turn. A gate that cannot run for a reason outside the
code, such as a stopped Docker daemon, is reported to you instead, because the
agent cannot fix it.
[Run the quality gate when the agent stops](Run_quality_gate_on_agent_stop.md)
covers the hook in detail.

Several design choices follow from that loop. Keep them when you adapt the
checks:

- **Deterministic.** Tools are pinned to exact versions, and the link check runs
  offline. An agent cannot tell a flaky failure from a real one, so a flaky
  check wastes turns and teaches everyone to ignore it.
- **Read-only.** The lint targets never rewrite files. Formatting is a separate,
  explicit step. A check can then never slip a change into the diff you are
  reviewing.
- **Fast and scoped.** `make lint` stops at the first failure, and the `check=`
  modes narrow a run to the files that changed. The hook skips every gate when a
  turn changed nothing. Quick feedback keeps the fix-and-rerun loop tight, for
  people and agents alike.
- **Isolated.** Most checks run in pinned containers, with no network and a
  read-only view of the repository. Checks run unattended on every agent turn,
  so it matters what a tool can reach.
- **Plain output.** Findings use `ERROR:` and `WARNING:` prefixes locally, and
  become annotations in GitHub Actions. The same message reads well in a
  terminal, in an agent's context and on a pull request.

An agent can still work around a check, for example by loosening a rule or
excluding a file. The hook guards its own configuration. It reads the gate list
from the commit at the start of the turn, so a change made during the turn
cannot switch a gate off for that turn, and it flags the change for review. Rule
and exclusion files, such as `markdownlint.yaml`, have no such guard. Review
changes to them as carefully as code. See
[Configure rules and exclusions](#configure-rules-and-exclusions-).

### One check, every stage

The same Make targets run at four points, from your terminal to the pipeline:

| Where           | When it runs                                                | What it runs                                                                                          |
| --------------- | ----------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| On demand       | When you run it                                             | `make lint`, one `make lint-*` target or `make check`, with any `check=` mode                         |
| Agent Stop hook | When a Copilot agent finishes a turn that changed files     | The gates in `quality-gates.yaml`, which are `make lint` and `make test` by default                   |
| Git pre-commit  | On every commit, once `make config` has installed the hooks | Each lint check, `make scan-secrets` and `make test`                                                  |
| CI/CD pipeline  | On every push and pull request                              | Each lint check and the secret scan in the commit stage, then `make typecheck test` in the test stage |

Every stage calls the same target with the same pinned tools, so a finding means
the same thing everywhere. Each stage also catches what the one before it
missed. The Stop hook catches most findings inside the agent's turn. Pre-commit
catches changes made without an agent. The pipeline is the shared backstop, and
runs whatever happened locally.

## Prerequisites 📋

Run commands from the repository root after completing the
[quick start](../../../README.md#quick-start-). The scripts need GNU Bash 5.2 or
later and GNU userland tools. Run `make toolchain-verify-gnu` to check `PATH`.

## Choose a command 🧭

Start with the template's lint checks, then format Markdown if needed:

```shell
make lint
make format check=working-tree-changes
git diff
make lint
```

`make lint` runs the included checks and stops at the first failure. That keeps
the loop short: fix one finding, then run again. Run an individual target to
work on a particular finding:

| Included check                 | Behaviour                                                                            |
| ------------------------------ | ------------------------------------------------------------------------------------ |
| `make lint-file-format`        | Checks encoding, line endings, indentation and whitespace against EditorConfig.      |
| `make lint-markdown-format`    | Runs markdownlint and checks for a blank line after YAML frontmatter.                |
| `make lint-markdown-links`     | Checks local Markdown links with Lychee.                                             |
| `make lint-shell`              | Runs ShellCheck and checks comment length in shell and Make include files.           |
| `make lint-pipeline-contract`  | Checks that each CI/CD workflow keeps the delivery rules, such as notification.      |
| `make lint-security-readiness` | Checks workflows, local actions and the repository-wide security readiness baseline. |

Adapt the root lifecycle targets for your project. `make format` currently
formats Markdown, and `make typecheck` is a placeholder. Treat `make test` as
the quick-feedback target for development, not necessarily the project's full
test suite. It currently runs the template's
[Bash suites](Write_and_run_Bash_tests.md). Add fast project and system tests,
such as unit tests, to it. Keep slower integration and end-to-end tests in
separate targets. Speed matters here, because the Stop hook runs `make test`
within a time budget at the end of every agent turn that changes files.
`make check` runs `format`, `lint`, `typecheck` and `test`, in that order.

The lint targets validate files without rewriting them. `make format` and
`make check` can change files. Neither stages the results. Review `git diff`
after formatting, especially if a selected file has both staged and unstaged
changes. Prettier does not fix every markdownlint or EditorConfig finding.

Secret scanning is a separate target, `make scan-secrets`. Its default is
`check=whole-history`, and its scopes differ from the file checks below. See
[Scan secrets](Scan_secrets.md).

## Choose which files to check 📂

Scope trades coverage for speed. A scoped run gives fast feedback on the files
you are working on. `check=all` is what the Stop hook, pre-commit and the
pipeline run, so it has the final word.

The file-check and formatting Make targets default to `check=all`:

| Value                        | Files selected                                                                                         |
| ---------------------------- | ------------------------------------------------------------------------------------------------------ |
| `check=all`                  | Every tracked file that still exists as a regular file.                                                |
| `check=staged-changes`       | Files added or changed in the index.                                                                   |
| `check=working-tree-changes` | Tracked files with changes outside the index. Files with only staged changes are excluded.             |
| `check=branch`               | Files changed since the resolved base's merge base with `HEAD`, including staged and unstaged changes. |

Only tracked files are selected, and checks read their working-tree contents,
even with `check=staged-changes`. Add new files to Git or check them directly.
This matters for agents. A file an agent has just created is invisible to the
checks until it is staged, so the repository's agent instructions tell agents to
stage new files. Each tool filters the selection to the file types it supports.
For example:

```shell
make lint check=working-tree-changes
make lint-shell check=branch
```

Shell lint includes dependent scripts, and changes to some shared rules expand
the selection. Run `make lint` after changing rules or exclusions.

Security readiness checks the repository baseline in every mode, even with no
changed workflows. Only the workflow and action selection is scoped. Run
`make lint-security-readiness` directly to see warnings. It follows
`lint-pipeline-contract` in the lint sequence. Successful tests capture the
checker output. See
[Security readiness](Harden_repository_security.md#security-readiness) for the
rules and the security readiness checks on the engineering dashboard.

`check=branch` compares the working tree with the merge base of the current
branch and its pull request or default branch. Set `BRANCH_NAME` to choose a
base ref explicitly:

```shell
make lint check=branch BRANCH_NAME=origin/main
```

The base must exist locally. The scripts do not fetch history.

## Configure rules and exclusions 🔧

A rule is a team decision, so change it as you would any shared standard:
deliberately, and with a review. When a check fails, prefer to fix the finding.
If the finding is a genuine exception, add the narrowest exclusion that covers
it. Change the rule itself only when the team's standard has changed.

Watch for the reverse in agent-written changes. An agent that a check blocks may
loosen the rule or exclude the file instead of fixing the code. The diff then
looks green, but the standard has quietly moved.

Edit the relevant tool's rules and exclusions. Exclusion formats differ:

- EditorConfig: [`.editorconfig`](../../../.editorconfig) sets rules.
  [`editorconfig-checker.json`](../../../scripts/config/editorconfig-checker.json)
  excludes paths using Go/RE2 expressions.
- Markdown lint:
  [`markdownlint.yaml`](../../../scripts/config/markdownlint.yaml) sets rules.
  [`.markdownlintignore`](../../../scripts/config/.markdownlintignore) excludes
  paths.
- Markdown formatter:
  [`prettierrc.yaml`](../../../scripts/config/prettierrc.yaml) sets rules.
  [`.prettierignore`](../../../scripts/config/.prettierignore) uses Git ignore
  patterns.
- Markdown links: [`lychee.toml`](../../../scripts/config/lychee.toml) checks
  local links by default. Its `exclude` expressions match links, not files.
- Shell lint: ShellCheck directives set rules.
  [`.commentlengthignore`](../../../scripts/config/.commentlengthignore) only
  excludes comment-length checks.
- Pipeline contract:
  [`check-pipeline-contract.jq`](../../../scripts/quality/check-pipeline-contract.jq)
  sets rules.
- Security readiness:
  [`check-security-readiness.jq`](../../../scripts/quality/check-security-readiness.jq)
  contains governance-owned rules and hardcoded approved licence references.
  [`security-readiness.yaml`](../../../scripts/config/security-readiness.yaml)
  records reviewed workflow write approvals. See
  [Security readiness](Harden_repository_security.md#security-readiness) for
  governance requirements and the engineering dashboard checks.

Exclusions apply to individual checks. `.gitignore` does not exclude tracked
files from these checks.

## Use native tools or Docker 🐳

Running a tool in its pinned image means every laptop and runner uses the same
version, so a check passes or fails the same way everywhere. The
container-capable quality checks use their pinned Docker images by default,
locally and in CI, even when native tools are installed. This also reduces
access to the host's files and network. To opt out for a command when the native
tool is available:

```shell
FORCE_USE_DOCKER=false make lint-markdown-format
```

Native mode is not recommended because tools inherit the user's or runner's file
and network access. The pipeline-contract and security-readiness checks always
run natively. The security-readiness check emits one warning, but does not fail,
when `FORCE_USE_DOCKER=false` is set. To make the opt-out persistent for local
development, set it in the team's shell profile. For a CI composite action, set
`FORCE_USE_DOCKER` to `"false"` in its `.github/actions/<check>/action.yaml`
step and ensure the native tool is available on the runner. This is not
recommended.

Container mode calls `docker` and needs a working runtime. A Podman shell alias
is not available to these scripts, so provide a `docker` executable as explained
in [Build Docker images](Build_Docker_images.md). The Markdown frontmatter check
still needs host `python3`. The pipeline-contract check needs host `yq` and
`jq`, while security readiness needs host `yq`, `jq` and `date`. Neither has a
Docker fallback. The Prettier container needs network access and a writable
checkout. Use `VERBOSE=true` on a failing target to see its commands.

## Add project checks ➕

The included checks cover the template's own files. Your project will need its
own, for example a type checker, an architecture rule or a licence check.

Add a check target in a module, a `*.mk` file under `scripts/`, and make it a
prerequisite of `lint` or another lifecycle target. A new check must handle its
own `check=...` file scope. See
[Make modules](Use_Bash_and_Make.md#make-modules) for an example.

Design a new check so it works as well for an agent as for a person:

- Make it deterministic. Pin the tool, and avoid the network where you can.
- Make it fast, or give its gate `paths` so it runs only when relevant files
  change.
- Make each finding actionable. Name the file, the rule and the reason, as the
  pipeline-contract message above does.
- Keep it read-only. Put anything that rewrites files behind `make format`.
- Separate the code from the environment. When the check cannot run for a reason
  outside the code, such as a missing tool or a stopped Docker daemon, print a
  line starting with `PREREQUISITE:` that says how to fix it. If that is the
  only problem, also write `prerequisite` to `QUALITY_GATE_RESULT_FILE` when the
  hook supplies that path, then exit non-zero. The line alone does not downgrade
  a failed gate. Follow the
  [prerequisite reporting contract](Run_quality_gate_on_agent_stop.md#gates-that-cannot-run-).

Then decide where the check runs. A target under `make lint` runs in the Stop
hook and whenever someone runs `make lint`. To run it in the hook on its own,
for example as a warning or only for some paths, add a gate in
`scripts/config/quality-gates.d/`. See
[Add or change a gate](Run_quality_gate_on_agent_stop.md#add-or-change-a-gate-).
Pre-commit and the pipeline's commit stage call each check individually. Add
yours to [`pre-commit.yaml`](../../../scripts/config/pre-commit.yaml) and the
CI/CD workflows as well, as the included checks are.
