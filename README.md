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
- [Docker](https://www.docker.com/) container runtime or a compatible tool, for example [Podman](https://podman.io/)
- [asdf](https://asdf-vm.com/) version manager

> [!NOTE]<br>
> The version of GNU make available by default on macOS is earlier than 3.82. You will need to upgrade it or certain `make` tasks will fail. On macOS, you will need [Homebrew](https://brew.sh/) installed, then to install `make`, like so:
>
> ```shell
> brew install make
> ```
>
> You will then see instructions to fix your [`$PATH`](https://github.com/nhs-england-tools/dotfiles/blob/main/dot_path.tmpl) variable to make the newly installed version available. If you are using [dotfiles](https://github.com/nhs-england-tools/dotfiles), this is all done for you.

- [GNU sed](https://www.gnu.org/software/sed/) and [GNU grep](https://www.gnu.org/software/grep/) are required for scripted command-line output processing
- [GNU coreutils](https://www.gnu.org/software/coreutils/) and [GNU binutils](https://www.gnu.org/software/binutils/) may be required to build dependencies like Python, which may need to be compiled during installation

> [!NOTE]<br>
> For macOS users, installation of the GNU toolchain has been scripted and automated as part of the `dotfiles` project. Please see this [script](https://github.com/nhs-england-tools/dotfiles/blob/main/assets/20-install-base-packages.macos.sh) for details.

- [Python](https://www.python.org/) required to run Git hooks
- [`jq`](https://jqlang.github.io/jq/) a lightweight and flexible command-line JSON processor

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
- Repository-specific tests (the Makefile notes that no tests are required for this template).
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

- Run `make config` to configure the local development environment.
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
```

Run the test entry point (template placeholder):

```shell
make test
```

### Examples

- Guides live in [docs/guides](docs/guides).
- ADR templates are stored in [docs/adr](docs/adr).

## Design notes

### Diagrams

The [C4 model](https://c4model.com/) provides a simple, consistent way to capture architecture diagrams. Keep diagram sources under version control. Suggested tools are [draw.io](https://app.diagrams.net/) and [Mermaid](https://github.com/mermaid-js/mermaid).

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
