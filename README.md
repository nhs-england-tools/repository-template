# Repository Template 🧰

A repository template that provides a baseline structure and quality checks for
new projects.

## Why this project exists 🎯

New projects need a consistent structure, tooling and documentation before
delivery work can begin. This template brings them together through a project
layout, Make-based quality checks and developer guides. Engineers can spend less
time on initial setup and tailor the starting point to their project.

## Quick start 🚀

### Prerequisites

The following software packages, or their equivalents, are expected to be
installed and configured:

- [GNU Make](https://www.gnu.org/software/make/) 3.82 or later
- GNU Bash 5.2 or later, with `bash` on `PATH` before older system versions
- [Docker](https://www.docker.com/) container runtime or a compatible tool, for
  example [Podman](https://podman.io/). The quick start requires a runtime for
  `make toolchain-verify-gnu`. `make config` pulls helper images only when a
  runtime is available.
- [mise](https://mise.jdx.dev/) toolchain manager, installed with
  `curl https://mise.run | sh`. Activate it in your shell profile to run pinned
  tools directly, for example `echo 'eval "$(mise activate zsh)"' >> ~/.zshrc`.
  Make targets find pinned tools without shell activation.
- [GNU sed](https://www.gnu.org/software/sed/),
  [GNU grep](https://www.gnu.org/software/grep/),
  [GNU awk](https://www.gnu.org/software/gawk/),
  [GNU findutils](https://www.gnu.org/software/findutils/) and
  [GNU diffutils](https://www.gnu.org/software/diffutils/) are required: some of
  this repository's own scripts use GNU-only flags (for example bare `sed -i`
  in-place edits, `date --date=`), which behave differently or do not exist on
  macOS's built-in BSD tools.
- [GNU coreutils](https://www.gnu.org/software/coreutils/) may be required to
  build dependencies like Python, which may need to be compiled during
  installation. `mise` installs a prebuilt Python where available, so this
  compilation step is now the fallback case rather than the default.

> [!NOTE]<br> macOS supplies older Make and Bash versions. Install
> [Homebrew](https://brew.sh/). After cloning your new repository, run:
>
> ```shell
> brew install make
> make toolchain-install-gnu-macos
> ```
>
> Homebrew's `make` formula provides `gmake`. The target installs Bash and the
> other GNU tools, but not GNU Make. Add GNU Make's `libexec/gnubin` and the
> `PATH` line printed by the target to your shell profile before system paths.
> The target can offer to append its line for you. If you use
> [dotfiles](https://github.com/nhs-england-tools/dotfiles), its
> [`PATH` configuration](https://github.com/nhs-england-tools/dotfiles/blob/main/dot_path.tmpl)
> may already cover this. See its
> [base packages script](https://github.com/nhs-england-tools/dotfiles/blob/main/assets/20-install-base-packages.macos.sh)
> for its installation flow.

### Set up

On GitHub, choose **New repository** and select
`nhs-england-tools/repository-template` from **Choose a template**. Choose the
owner, name and visibility, then create the repository. Follow the
[repository setup guide](docs/guides/template/Set_up_a_new_repository.md) to
tailor it.

Clone your new repository using its **Code** URL, replacing `OWNER` and
`REPOSITORY` with its details:

```shell
git clone https://github.com/OWNER/REPOSITORY.git
cd REPOSITORY
```

Review `mise.toml`, then trust it, verify the system tools and configure the
toolchain. `make config` installs pinned native tools, including
[Python](https://www.python.org/) for Git hooks and
[`jq`](https://jqlang.github.io/jq/):

```shell
mise trust mise.toml
make toolchain-verify-gnu
make config
```

### First run

Run the default quality checks:

```shell
make lint
```

Expected result:

```plaintext
file format: ok
markdown format: ok
markdown links: ok
shell lint: ok
workflow security checks: ok
```

## What it does ⚙️

**Key features**

- Provides a baseline repository structure with documentation and scripts.
- Includes Makefile targets for configuration, linting, and testing.
- Supplies quality check scripts for file format, markdown format, markdown
  links, shell linting, secrets scanning, and GitHub Actions workflow security.
- Offers developer and user guidance in the docs directory.
- Includes workflow definitions under the .github directory for CI/CD
  configuration.

**Out of scope / non-goals**

- Project-specific dependency installation, build, publish, and deploy steps
  (they are marked as TODOs in the Makefile).
- Project-specific tests are not included by default. `make test` is the
  quick-feedback target for development and currently runs the template's own
  scripts. Add fast project and system tests, such as unit tests, when adopting
  the template.
- Formatting automation for project source code beyond Markdown. The template
  formatter covers Markdown files only.

## How it solves the problem 🧩

1. The template provides common tooling, quality checks and guidance that teams
   would otherwise set up for each new repository.
2. Teams tailor the [Makefile](Makefile) and
   [guides](docs/guides/template/README.md) to their project and use the time
   saved on setup to deliver product features that meet user needs and create
   business value.

## How to use 📖

### Configuration

`make config` installs pinned native tools and Git hooks. When Docker or Podman
is available, it also pulls pinned helper images. Adapt the configuration in
[scripts/config](scripts/config) to your project.

TODO: confirm any additional configuration steps required for new projects.

### Common workflows

Run the template's lint checks and tests before opening a pull request:

```shell
make lint
make test
```

`make lint` checks tracked files. It does not run the test suites or secret
scan. The [pre-commit hooks](docs/guides/template/Run_Git_hooks_on_commit.md)
also run `make test` and `make scan-secrets`. To scan repository history
yourself:

```shell
make scan-secrets
```

Format Markdown in tracked working-tree changes, then review the diff:

```shell
make format check=working-tree-changes
git diff
```

To limit the file checks to changes on your branch while developing:

```shell
make lint check=branch
```

The
[quality-check guide](docs/guides/template/Run_and_configure_quality_checks.md)
covers individual targets, file scopes, tool fallbacks and project checks.
Follow
[Harden repository security](docs/guides/template/Harden_repository_security.md)
for workflow permissions and
[Update Dependencies](docs/guides/template/Update_Dependencies.md) for tool,
image, action and package updates.

### Examples

Use the [guide index](docs/guides/template/README.md) to find task-specific
instructions and the
[ADR template](docs/adr/ADR-nnn_Any_Decision_Record_Template.md) to record
technology decisions.

## Design notes 📝

The recommended approach for architecture diagrams is the
[C4 model](https://c4model.com/), supported by [LikeC4](https://likec4.dev/).
Use [Mermaid](https://github.com/mermaid-js/mermaid) for diagrams embedded in
Markdown. Keep diagram sources under version control. Aim for modular,
configurable components that projects can extend or replace. TODO: add
project-specific modularity guidance when this template is adopted.

## Security 🔒

For vulnerability reporting guidance, see [SECURITY.md](.github/SECURITY.md).

## Support 💬

For help using this project,
[open a support request in GitHub Issues](https://github.com/nhs-england-tools/repository-template/issues/new?template=1_support_request.yaml).

## Contributing 🤝

See the contributing guide at [CONTRIBUTING.md](.github/CONTRIBUTING.md). Please
follow the [Code of Conduct](.github/CODE_OF_CONDUCT.md) when participating.

At a high level:

- Configure your environment with `make config`.
- Run `make lint` and `make test` before raising a change.
- TODO: confirm the contribution workflow (issues, pull requests, and review
  expectations).

## Repository layout 🗂️

- [.github/workflows](.github/workflows): CI workflows.
- [docs/guides/template](docs/guides/template): task-specific setup, testing and
  tooling guides.
- [docs/adr](docs/adr): Architecture Decision Record template.
- [scripts](scripts): configuration, quality checks, Docker helpers and tests.
- [Makefile](Makefile): entry point for setup, checks and tests.

## Licence 📜

Released under the [MIT Licence](LICENCE.md).
