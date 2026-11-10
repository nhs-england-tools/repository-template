# Run and configure quality checks ✅

- [Run and configure quality checks ✅](#run-and-configure-quality-checks-)
  - [Prerequisites 📋](#prerequisites-)
  - [Choose a command 🧭](#choose-a-command-)
  - [Choose which files to check 📂](#choose-which-files-to-check-)
  - [Configure rules and exclusions 🔧](#configure-rules-and-exclusions-)
  - [Use native tools or Docker 🐳](#use-native-tools-or-docker-)
  - [Add project checks ➕](#add-project-checks-)

## Prerequisites 📋

Run commands from the repository root after completing the
[quick start](../../README.md#quick-start-). The scripts need GNU Bash 5.2 or
later and GNU userland tools. Run `make toolchain-verify-gnu` to check `PATH`.

## Choose a command 🧭

Start with the template's lint checks, then format Markdown if needed:

```shell
make lint
make format check=working-tree-changes
git diff
make lint
```

`make lint` runs the included checks and stops at the first failure. Run an
individual target to work on a particular finding:

| Included check                | Behaviour                                                                       |
| ----------------------------- | ------------------------------------------------------------------------------- |
| `make lint-file-format`       | Checks encoding, line endings, indentation and whitespace against EditorConfig. |
| `make lint-markdown-format`   | Runs markdownlint and checks for a blank line after YAML frontmatter.           |
| `make lint-markdown-links`    | Checks local Markdown links with Lychee.                                        |
| `make lint-shell`             | Runs ShellCheck and checks comment length in shell and Make include files.      |
| `make lint-workflow-security` | Checks GitHub Actions workflows and local actions against the security rules.   |

Adapt the root lifecycle targets for your project. `make format` currently
formats Markdown, and `make typecheck` is a placeholder. `make test` is the
project's full test target. It currently runs the template's
[Bash suites](Write_and_run_Bash_tests.md), so add the project's other tests to
it. `make check` runs `format`, `lint`, `typecheck` and `test`, in that order.

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

Only tracked files are selected, and checks read their working-tree contents,
even with `check=staged-changes`. Add new files to Git or check them directly.
Each tool filters the selection to the file types it supports. For example:

```shell
make lint check=working-tree-changes
make lint-shell check=branch
```

Shell lint includes dependent scripts, and changes to some shared rules expand
the selection. Run `make lint` after changing rules or exclusions.

`check=branch` compares the working tree with the merge base of the current
branch and its pull request or default branch. Set `BRANCH_NAME` to choose a
base ref explicitly:

```shell
make lint check=branch BRANCH_NAME=origin/main
```

The base must exist locally. The scripts do not fetch history.

## Configure rules and exclusions 🔧

Edit the relevant tool's rules and exclusions. Exclusion formats differ:

- EditorConfig: [`.editorconfig`](../../.editorconfig) sets rules.
  [`editorconfig-checker.json`](../../scripts/config/editorconfig-checker.json)
  excludes paths using Go/RE2 expressions.
- Markdown lint: [`markdownlint.yaml`](../../scripts/config/markdownlint.yaml)
  sets rules. [`.markdownlintignore`](../../scripts/config/.markdownlintignore)
  excludes paths.
- Markdown formatter: [`prettierrc.yaml`](../../scripts/config/prettierrc.yaml)
  sets rules. [`.prettierignore`](../../scripts/config/.prettierignore) uses Git
  ignore patterns.
- Markdown links: [`lychee.toml`](../../scripts/config/lychee.toml) checks local
  links by default. Its `exclude` expressions match links, not files.
- Shell lint: ShellCheck directives set rules.
  [`.commentlengthignore`](../../scripts/config/.commentlengthignore) only
  excludes comment-length checks.
- Workflow security:
  [`check-workflow-security.jq`](../../scripts/quality/check-workflow-security.jq)
  sets rules.
  [`workflow-security.yaml`](../../scripts/config/workflow-security.yaml)
  records approved write permissions.

Exclusions apply to individual checks. `.gitignore` does not exclude tracked
files from these checks.

## Use native tools or Docker 🐳

The EditorConfig, Markdown and shell wrappers use native tools when available
and pinned Docker helper images otherwise. To force Docker for a supported
check:

```shell
make lint-markdown-format FORCE_USE_DOCKER=true
```

Container fallbacks call `docker` and need a working runtime. A Podman shell
alias is not available to these scripts, so provide a `docker` executable as
explained in [Build Docker images](Build_Docker_images.md). The Markdown
frontmatter check still needs host `python3`, and workflow security needs host
`yq` and `jq`. Use `VERBOSE=true` on a failing target to see its commands.

## Add project checks ➕

Add a check target in a `scripts/*.ext.mk` file and make it a prerequisite of
`lint` or another lifecycle target. A new check must handle its own `check=...`
file scope. See [Make extensions](Use_Bash_and_Make.md#make-extensions) for an
example.
