# Run and configure quality checks ✅

- [Run and configure quality checks ✅](#run-and-configure-quality-checks-)
  - [Prerequisites 📋](#prerequisites-)
  - [Choose a command 🧭](#choose-a-command-)
  - [Choose which files to check 📂](#choose-which-files-to-check-)
    - [Branch comparisons](#branch-comparisons)
  - [Configure rules and exclusions 🔧](#configure-rules-and-exclusions-)
  - [Check Markdown links offline 🔗](#check-markdown-links-offline-)
  - [Use native tools or Docker 🐳](#use-native-tools-or-docker-)
  - [Troubleshooting 🔍](#troubleshooting-)
  - [Add project checks ➕](#add-project-checks-)
  - [Related guides 📚](#related-guides-)

## Prerequisites 📋

Run the commands below from the repository root. Complete the
[quick start](../../README.md#quick-start-) first, including reviewing and
trusting `mise.toml` and running `make config`. This installs the pinned native
tools, installs Git hooks and pulls the pinned helper images.

The scripts need GNU Bash 5.2 or later and the repository's GNU userland tools.
Use `make toolchain-verify-gnu` to check the tools selected by `PATH`. Make adds
mise's shims to recipe environments. Direct tool commands also need mise
activation in your shell.

## Choose a command 🧭

Start with validation, then format Markdown if needed:

```shell
make lint
make format check=working-tree-changes
git diff
make lint
```

`make lint` stops at the first failing check. Run an individual target to work
on a particular finding:

| Command                       | Behaviour                                                                                      |
| ----------------------------- | ---------------------------------------------------------------------------------------------- |
| `make lint-file-format`       | Checks encoding, line endings, indentation and whitespace against EditorConfig.                |
| `make lint-markdown-format`   | Runs markdownlint and checks for a blank line after YAML frontmatter.                          |
| `make lint-markdown-links`    | Checks local Markdown links with Lychee.                                                       |
| `make lint-shell`             | Runs ShellCheck and checks full-line comments in shell and Make include files.                 |
| `make lint-workflow-security` | Validates GitHub Actions workflows and local actions against the security rules.               |
| `make format`                 | Rewrites Markdown with Prettier, including table alignment. Currently calls `format-markdown`. |
| `make typecheck`              | A placeholder for project-specific type checking.                                              |
| `make test`                   | Runs every discovered Bash test suite.                                                         |
| `make check`                  | Runs `format`, `lint`, `typecheck` and `test`, in that order.                                  |

The lint targets validate files without rewriting them. `make format` and
`make check` can change files. Neither stages the results. Review `git diff`
after formatting, especially if a selected file has both staged and unstaged
changes. Prettier does not fix every markdownlint or EditorConfig finding.

Secret scanning is a separate target, `make scan-secrets`. Its default is
`check=whole-history`, and its scopes differ from the file checks below. See
[Scan secrets](Scan_secrets.md).

## Choose which files to check 📂

The file-check and formatting Make targets default to `check=all`:

| Value                        | Files selected                                                                                         |
| ---------------------------- | ------------------------------------------------------------------------------------------------------ |
| `check=all`                  | Every tracked file that still exists as a regular file.                                                |
| `check=staged-changes`       | Files added or changed in the index.                                                                   |
| `check=working-tree-changes` | Tracked files with changes outside the index. Files with only staged changes are excluded.             |
| `check=branch`               | Files changed since the resolved base's merge base with `HEAD`, including staged and unstaged changes. |

Each tool filters that selection to the file types it checks. Untracked files
are excluded, including new guides or scripts that have not been added to Git.
Deleted paths are not passed to a file checker.

The checks read selected files from the working tree. A direct
`check=staged-changes` run therefore sees unstaged edits to a partially staged
file too. During a commit, pre-commit temporarily stashes unstaged edits before
running its hooks. The configured hooks use `check=all`.

For example:

```shell
make lint check=working-tree-changes
make lint-markdown-format check=staged-changes
make lint-shell check=branch
```

Call `make lint-shell check=...` to run only shell lint in the selected scope.
`make lint check=...` applies that scope to shell lint alongside the other
checks. Shell lint also selects scripts which refer to changed, renamed or
deleted scripts and their dependencies. Changes to ShellCheck configuration or
`mise.toml` expand it to every shell script. See
[Shell lint](Use_Bash_and_Make.md#shell-lint) for the comment-length rules.

The workflow security check expands to every workflow and local action when its
allowlist, script or jq rules change. Other configuration changes do not
automatically expand all file checks. After changing shared rules or exclusions,
run `make lint` and, if formatter settings changed, `make format` before
linting.

Direct scripts have different defaults: the EditorConfig and Markdown scripts
default to `working-tree-changes`, while shell lint and workflow security
default to `all`. Prefer the Make targets or set `check` explicitly.

### Branch comparisons

`check=branch` resolves the comparison base in this order:

1. `GITHUB_BASE_REF`, when set by GitHub Actions.
2. `BRANCH_NAME`, used exactly as supplied, including a commit or remote ref.
3. The current branch's open pull request base, read with GitHub CLI.
4. `origin/HEAD`, then `origin/main` if `origin/HEAD` cannot be resolved.

A branch name from GitHub resolves to `origin/<branch>` first, then a local
branch. The check prints the selected base, its source and the merge-base
commit. It compares the working tree with that commit, not just the latest
commit or the current base tip.

To choose a base explicitly:

```shell
make lint check=branch BRANCH_NAME=origin/main
```

Use a ref that exists locally. The scripts do not fetch history. If the base is
missing, fetch it with `git fetch origin main`, substituting the required
branch. For a missing merge base in a shallow checkout, fetch more history or
run `git fetch --unshallow`.

GitHub CLI lookup has a five-second timeout. If the CLI is unavailable, finds no
open pull request or times out, the default branch is used. Set
`QUALITY_GH_TIMEOUT` to a positive number of seconds to change the timeout.

## Configure rules and exclusions 🔧

Edit the configuration for the relevant tool. Exclusion formats are not
interchangeable:

| Check or formatter | Rules                                                                            | Exclusions                                                                                                                                                                      |
| ------------------ | -------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| EditorConfig       | [`.editorconfig`](../../.editorconfig)                                           | `Exclude` in [`editorconfig-checker.json`](../../scripts/config/editorconfig-checker.json) uses Go/RE2 regular expressions against repository-relative paths.                   |
| Markdown format    | [`markdownlint.yaml`](../../scripts/config/markdownlint.yaml)                    | [`.markdownlintignore`](../../scripts/config/.markdownlintignore) uses ignore patterns, applied by markdownlint from the repository root.                                       |
| Markdown formatter | [`prettierrc.yaml`](../../scripts/config/prettierrc.yaml)                        | [`.prettierignore`](../../scripts/config/.prettierignore) uses Git ignore rules relative to the repository root. The wrapper filters paths before running Prettier.             |
| Markdown links     | [`lychee.toml`](../../scripts/config/lychee.toml)                                | `exclude` contains regular expressions matching links, rather than input file paths.                                                                                            |
| Shell lint         | ShellCheck directives in scripts or a `.shellcheckrc`                            | [`.commentlengthignore`](../../scripts/config/.commentlengthignore) uses Git ignore rules relative to the repository root. It skips only comment-length checks, not ShellCheck. |
| Workflow security  | [`check-workflow-security.jq`](../../scripts/quality/check-workflow-security.jq) | [`workflow-security.yaml`](../../scripts/config/workflow-security.yaml) records approved write permissions for specific workflow jobs. It is not a general file exclusion list. |

For example, to exclude generated Markdown under `docs/generated/` from
EditorConfig checking, add an anchored expression to `Exclude`:

```json
{
  "Exclude": ["^docs/generated/"]
}
```

For Prettier, put the path pattern in `scripts/config/.prettierignore` instead:

```gitignore
docs/generated/
```

An exclusion applies only to its own check. The frontmatter blank-line check
runs on every selected Markdown file even when markdownlint ignores it. Adding a
tracked path to `.gitignore` does not remove it from the checks.

## Check Markdown links offline 🔗

The default [`lychee.toml`](../../scripts/config/lychee.toml) sets
`offline = true` and `root_dir = "."`. Both native and Docker runs check local
links, without testing whether external websites respond:

```shell
make lint-markdown-links check=working-tree-changes
```

For a single file, including an untracked draft, use the installed tool
directly:

```shell
lychee --config scripts/config/lychee.toml --no-progress --quiet -- docs/guides/Use_Bash_and_Make.md
```

Keep relative links valid from the Markdown file's directory. Docker runs with
`--network none`, so changing `offline` to `false` does not enable external
checks in the container. Online checking requires a native run with network
access and corresponding Lychee configuration.

## Use native tools or Docker 🐳

The EditorConfig, Markdown and shell wrappers use the native tool when it is on
`PATH`. If it is missing, or `FORCE_USE_DOCKER=true`, they use the helper image
pinned in [`mise.toml`](../../mise.toml):

```shell
make lint-markdown-format FORCE_USE_DOCKER=true
make lint-shell check=working-tree-changes FORCE_USE_DOCKER=true VERBOSE=true
```

Docker mode needs a running runtime and access to its socket. Missing images are
pulled before use. The linter containers use a read-only checkout and no
network. The Prettier container has a writable checkout and network access to
download the pinned Prettier version with `npx`.

Some checks always run on the host. The Markdown frontmatter check needs
`python3`, and workflow security needs `yq` and `jq` with no Docker fallback.
`FORCE_USE_DOCKER=true make lint` still needs those host tools.

## Troubleshooting 🔍

| Symptom                                     | What to check                                                                                                                                                                                        |
| ------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| A new file is skipped                       | Check `git status --short`. The wrappers select tracked files only. Run the relevant tool directly for an untracked draft, or add the file when it is ready to enter the index.                      |
| A staged check reports an unstaged edit     | The wrapper reads the working-tree copy. Review `git diff` and `git diff --cached` for that file.                                                                                                    |
| A scoped lint run checks many shell scripts | `make lint` forces full shell lint. Individual shell checks also include related scripts and expand on configuration changes.                                                                        |
| Formatting succeeded but lint failed        | Prettier and the linters enforce different rules. Read the reported rule, fix the source and rerun the failing target.                                                                               |
| Local checks pass but CI fails              | Compare the file scope, tool versions, resolved branch base and native versus Docker mode. Run `make lint` for the full tracked scope and use `FORCE_USE_DOCKER=true` to reproduce container checks. |
| Docker reports a socket or connection error | Start the runtime and check access with `docker info`. An unavailable runtime is a prerequisite failure.                                                                                             |
| A script reports an unsupported Bash option | Run `make toolchain-verify-gnu` and fix `PATH` so the required Bash and GNU tools resolve first.                                                                                                     |

Use `VERBOSE=true` on the failing target to see the executed commands. For an
EditorConfig file-selection preview, run:

```shell
make lint-file-format check=working-tree-changes dry_run=true
```

## Add project checks ➕

Add a `*.ext.mk` file under `scripts/`, define a named check target and attach
it as a prerequisite of `lint` or another suitable lifecycle target. Shared Make
setup discovers these files automatically. Do not give `lint` a second recipe.
Follow the example in [Make extensions](Use_Bash_and_Make.md#make-extensions).

Keep checks separate from formatters and return a non-zero status for findings.
A project check must implement any file scoping it needs. Passing `check=...`
does not automatically filter inputs for a new command.

## Related guides 📚

- [Run Git hooks on commit](Run_Git_hooks_on_commit.md) for automatic commit
  checks.
- [Run the quality gate when the agent stops](Run_quality_gate_on_agent_stop.md)
  for gate configuration and project drop-ins. Its `scope` option is separate
  from the file-check `check` option.
- [Harden repository security](Harden_repository_security.md) for workflow
  policy, approved permissions and tool-container boundaries.
- [Scan secrets](Scan_secrets.md) for Gitleaks scopes and configuration.
- [Write and run Bash tests](Write_and_run_Bash_tests.md) for test discovery and
  focused test runs.
- [Update Dependencies](Update_Dependencies.md) for native tool and image pins.
