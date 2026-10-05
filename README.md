# Repository Template

A repository template that provides a baseline structure and quality checks for new projects.

## Why this project exists

**Purpose**
Provide a reliable starting point for new repositories by including a concise, self-documented structure and a small, essential tooling set.

**Benefit to the engineers**
Reduce the time spent on initial setup and documentation, while encouraging clarity and maintainability from the outset.

**Problem it solves**
New projects often need consistent structure, tooling, and documentation patterns before any delivery work can begin. This template standardises that starting point.

**How it solves it (high level)**
It bundles a minimal project layout, a Makefile with quality targets, scripts for common checks, and documentation guides so teams can configure and extend them for their needs.

## Quick start

### Prerequisites

The following software packages, or their equivalents, are expected to be installed and configured:

- [GNU make](https://www.gnu.org/software/make/) 3.82 or later
- GNU Bash 5.2 or later, with `bash` on `PATH` before older system versions
- [Docker](https://www.docker.com/) container runtime or a compatible tool, for example [Podman](https://podman.io/)
- [mise](https://mise.jdx.dev/) toolchain manager, installed with `curl https://mise.run | sh` and activated in your shell profile, for example `echo 'eval "$(mise activate zsh)"' >> ~/.zshrc`. `make config` trusts this repository's `mise.toml` and installs every pinned native tool, including [Python](https://www.python.org/) (needed to run Git hooks) and [`jq`](https://jqlang.github.io/jq/). The `make` targets find the pinned toolchain tools without activation, but running them directly needs it.

> [!NOTE]<br>
> The GNU Make and Bash versions supplied by macOS are too old. Install [Homebrew](https://brew.sh/), then install both tools:
>
> ```shell
> brew install make bash
> ```
>
> Put Homebrew's `bin` and GNU Make's `libexec/gnubin` before system directories on [`PATH`](https://github.com/nhs-england-tools/dotfiles/blob/main/dot_path.tmpl). Make and directly executed scripts then use Homebrew Bash. If you use [dotfiles](https://github.com/nhs-england-tools/dotfiles), this may already be configured.

- [GNU sed](https://www.gnu.org/software/sed/), [GNU grep](https://www.gnu.org/software/grep/), [GNU awk](https://www.gnu.org/software/gawk/), [GNU findutils](https://www.gnu.org/software/findutils/) and [GNU diffutils](https://www.gnu.org/software/diffutils/) are required: some of this repository's own scripts use GNU-only flags (for example bare `sed -i` in-place edits, `date --date=`), which behave differently or do not exist on macOS's built-in BSD tools.
- [GNU coreutils](https://www.gnu.org/software/coreutils/) may be required to build dependencies like Python, which may need to be compiled during installation. `mise` installs a prebuilt Python where available, so this compilation step is now the fallback case rather than the default.

> [!NOTE]<br>
> On macOS, run `make toolchain-install-gnu-macos` to install Bash and the other GNU tools via Homebrew, then add the `PATH` line it prints to your shell profile (it can also offer to append it for you). Run `make toolchain-verify-gnu` on any OS to check GNU Make 3.82+, Bash 5.2+, the other GNU tools and a Docker or Podman runtime. The verifier reports missing tools without installing them. See the [base packages script](https://github.com/nhs-england-tools/dotfiles/blob/main/assets/20-install-base-packages.macos.sh) if you use dotfiles.

### Set up

Clone the repository:

```shell
git clone https://github.com/nhs-england-tools/repository-template.git
cd repository-template
```

Install and configure tooling:

```shell
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
```

## What it does

**Key features**

- Provides a baseline repository structure with documentation and scripts.
- Includes Makefile targets for configuration, linting, and testing.
- Supplies quality check scripts for file format, markdown format, markdown links, shell linting, and secrets scanning.
- Offers developer and user guidance in the docs directory.
- Includes workflow definitions under the .github directory for CI/CD configuration.

**Out of scope / non-goals**

- Project-specific dependency installation, build, publish, and deploy steps (they are marked as TODOs in the Makefile).
- Tests for a project's own code. `make test` only covers the template's own scripts.
- Code formatting automation (the Makefile notes that no formatting is required for this template).

## How it solves the problem

1. A team clones the repository and installs the documented prerequisites.
2. The `make config` target sets up the development tooling entry points.
3. Quality checks are run through Makefile targets that call scripts in [scripts/quality](scripts/quality).
4. Documentation templates and guides in [docs](docs) are used to capture design and delivery decisions.

Key terms:

- **Quality checks**: the scripts in [scripts/quality](scripts/quality) that validate formatting, linting, links, and secrets scanning.
- **Makefile targets**: standard entry points in [Makefile](Makefile) for configuration, linting, and testing tasks.

## How to use

### Configuration

- Run `make config` to trust `mise.toml`, install the pinned native toolchain, pull pinned Docker helper images and configure the local development environment.
- Tooling configuration files live in [scripts/config](scripts/config); update these to match your project needs.
- TODO: confirm any additional configuration steps required for new projects.

### Common workflows

Run the standard quality checks:

```shell
make lint
```

Run specific checks when you only need one:

```shell
make lint-file-format
make lint-markdown-format
make lint-markdown-links
make lint-shell
```

`make lint` stops at the first failing check.

Each check uses its native tool when it is installed and otherwise falls back
to the image pinned in `mise.toml`. To force the container path, for example to
reproduce a result with the pinned image, run:

```shell
FORCE_USE_DOCKER=true make lint
```

This requires a running Docker daemon reachable through the `docker` command.
On Apple silicon, images run as `linux/amd64` under emulation, so checks are
slower.

Run the tests:

```shell
make test
```

`make test` runs every `*.test.sh` suite under [scripts](scripts) in parallel through [run-test-suites.sh](scripts/tests/run-test-suites.sh). The Docker integration suite needs a running Docker daemon. A new suite is picked up automatically when it is executable and git does not ignore it. Keep it in a `tests/` directory next to the scripts it tests.

### Examples

- Guides live in [docs/guides](docs/guides).
- ADR templates are stored in [docs/adr](docs/adr).

## Design notes

### Diagrams

The [C4 model](https://c4model.com/) provides a simple, consistent way to capture architecture diagrams. Keep diagram sources under version control. Suggested tools are [Structurizr](https://structurizr.com/), [LikeC4](https://likec4.dev/), [Mermaid](https://github.com/mermaid-js/mermaid) and [draw.io](https://app.diagrams.net/).

### Modularity

Aim for modular, configurable components so projects can extend or replace parts without large rewrites. TODO: add project-specific modularity guidance when this template is adopted.

## Security

For vulnerability reporting guidance, see [security.md](.github/security.md).

## Support

TODO: confirm the support or contact route for this repository (for example issues, discussions, or a team mailbox).

## Contributing

See the contributing guide at [contributing.md](.github/contributing.md).

At a high level:

- Configure your environment with `make config`.
- Run quality checks using `make lint` before raising a change.
- Run the test entry point with `make test`.
- TODO: confirm the contribution workflow (issues, pull requests, and review expectations).

## Repository layout

- [.github/workflows](.github/workflows) — CI/CD workflow definitions for the template.
- [docs/adr](docs/adr) — Architecture Decision Record template.
- [docs/guides](docs/guides) — guides for developers and users (for example Bash and Make, Git hooks, secrets scanning).
- [scripts/config](scripts/config) — configuration for quality and tooling checks.
- [scripts/quality](scripts/quality) — scripts for file format, markdown, shell linting, and secrets scanning.
- [scripts/docker](scripts/docker) — Docker helper scripts and related test assets.
- [Makefile](Makefile) — primary entry point for quality and configuration tasks.

## Licence

Released under the [MIT Licence](LICENCE.md)
