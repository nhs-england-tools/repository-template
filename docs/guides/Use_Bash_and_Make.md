# Use Bash and Make

- [Use Bash and Make](#use-bash-and-make)
  - [Using Make](#using-make)
    - [Make extensions](#make-extensions)
      - [Root lifecycle target map](#root-lifecycle-target-map)
      - [Compose with root lifecycle targets](#compose-with-root-lifecycle-targets)
  - [Using Bash](#using-bash)
  - [Make and Bash working together](#make-and-bash-working-together)
  - [Conventions](#conventions)
    - [Debugging](#debugging)
    - [Scripts](#scripts)
    - [Shell lint](#shell-lint)

## Using Make

Use GNU Make 3.82 or later. Make resolves the first `bash` on `PATH` when it
starts and uses that executable for recipes. Keep GNU Bash 5.2 or later ahead of
older system versions on `PATH`.

Sample make target signature definition. In the Markdown examples below, the
leading spaces represent the tab required before each Make recipe line. Replace
them with a literal tab when adding the snippets to a Makefile.

```makefile
some-target: # Target description - mandatory: foo=[description]; optional: baz=[description, default is 'qux'] @Category
  # Recipe implementation...
```

- `some-target`: This is the name of the target you would specify when you want
  to run this particular target. Use the kebab-case naming convention and prefix
  with an underscore `_` to mark it as a "private" target. Prefix related
  targets consistently, for example `docker-*`. `make help` groups targets by
  `@Category`, not by name.
- `Target Description`: Provided directly after the target name as a single
  line, so be concise.
- `mandatory` parameters: Parameters that must be provided when invoking the
  target. Each parameter has its own description. Please follow the specified
  format as it is used by `make help`.
- `optional` parameters: Parameters that are not required when invoking the
  target. They may have a default value. Each parameter has its own description.
- `@Category` label: Used for grouping by the `make help` command.
- `Recipe implementation`: This section defines the actual commands or steps the
  target will execute. **Do not exceed 5 lines of effective code**. For more
  complex operations, use a shell script. Refer to the `docker-build`
  implementation in the [docker.mk](../../scripts/docker/docker.mk) file. More
  complex operations are implemented in the
  [docker.sh](../../scripts/docker/docker.lib.sh) script for readability and
  simplicity.

Run make target from a terminal:

```shell
foo=bar make some-target # Environment variable is passed to the make target execution process
make some-target foo=bar # Make argument is passed to the make target execution process
```

By convention we use uppercase variables for global settings that you would
ordinarily associate with environment variables. We use lower-case variables as
arguments to call functions or make targets, in this case.

All make targets should be added to the `${VERBOSE}.SILENT:` section of the
`make` file, which prevents `make` from printing commands before executing them.
The `${VERBOSE}` prefix on the `.SILENT:` special target allows toggling it if
needed. If you explicitly want output from a certain line, use `echo`.

It is worth noting that by default, `make` creates a new system process to
execute each line of a recipe. This is not the desired behaviour for us and the
entire content of a make recipe (a target) should be run in a single shell
invocation. This has been configured in this repository by setting the
[`.ONESHELL:`](https://www.gnu.org/software/make/manual/html_node/One-Shell.html)
special target in the `scripts/init.mk` file.

To see all available make targets, run `make help`.

### Make extensions

Add team targets without editing the main `Makefile`. The
[init.mk](../../scripts/init.mk) file loads every `*.ext.mk` file under
`scripts/` and its subdirectories, sorted by path. Its targets work with
`make <target>` and appear in `make help`. The example below assumes you also
create `scripts/backend/lambda-invoke.sh` in your project.

```makefile
# scripts/backend/backend.ext.mk

backend-lambda-invoke: event ?= events/default.json
backend-lambda-invoke: # Invoke a Lambda function locally - mandatory: name=[function name]; optional: event=[event file path, default is 'events/default.json'] @Development
  $(if $(name),,$(error name is required. Usage: make backend-lambda-invoke name=my-function))
  name=$(name) event=$(event) ./scripts/backend/lambda-invoke.sh

${VERBOSE}.SILENT: \
    backend-lambda-invoke \
```

Follow these rules:

- Name only entry points `*.ext.mk`. Name helpers `*.lib.mk`, like `*.lib.sh`
  for shell libraries, and include them from the entry point that needs them. An
  `*.ext.mk` file must not include another `*.ext.mk` file.
- All targets share one namespace. Prefix target names with the extension name,
  for example `backend-lambda-invoke`.
- Extend existing targets with a prerequisite, for example `lint: backend-lint`.
  Add to `clean::` and `config::` with a new double-colon rule. Do not give an
  existing single-colon target a second recipe, as Make replaces the first one
  and prints a warning.
- Keep extension paths free of spaces, as Make splits file lists on whitespace.
- When load order matters, use one `*.ext.mk` file that includes `*.lib.mk`
  files in the order needed.

#### Root lifecycle target map

This map covers common lifecycle targets, not every command shown by
`make help`. The full help also includes shared toolchain, Docker, quality-gate
and extension commands. The root `Makefile` provides stable target names for
common project tasks. Some already run template checks, while others are
placeholders for the adopting project. Implement a missing capability in the
root recipe or add it through an auto-loaded extension. Keep the public target
name stable either way.

| Target                                        | Template default                                                  | Project or extension responsibility                                           |
| --------------------------------------------- | ----------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| `config`                                      | Installs shared tools, hooks and pinned helper images.            | Add independent setup with a `config::` rule when needed.                     |
| `env`                                         | Placeholder for project environment setup.                        | Create or validate the language environment.                                  |
| `setup`                                       | Optional convenience target, not a core requirement.              | Compose `config` and `deps` for one-command onboarding.                       |
| `deps`                                        | Placeholder for project dependencies.                             | Install or synchronise locked application dependencies.                       |
| `deps-prod`                                   | Optional; no core default.                                        | Install only production dependencies when they differ from development deps.  |
| `deps-update`                                 | Optional; no core default.                                        | Update dependencies and their lock files explicitly.                          |
| `format`                                      | Formats Markdown files.                                           | Add language formatters as prerequisites.                                     |
| `lint`                                        | Runs common file, Markdown, shell and workflow checks.            | Add language or domain linters as prerequisites.                              |
| `typecheck`                                   | Placeholder for project type checking.                            | Add the selected static type checker.                                         |
| `test`                                        | Runs the template's shell test suites.                            | Add unit, integration or domain test targets.                                 |
| `test-unit` / `test-integration` / `test-all` | Optional; no core default.                                        | Add slower integration or end-to-end tiers to the fast `test` target.         |
| `check`                                       | Runs `format`, `lint`, `typecheck` and `test`.                    | Extend component targets; keep ordered aggregate semantics stable.            |
| `build`                                       | Placeholder for project artefact creation.                        | Build the package, binary, image or other artefact.                           |
| `run`                                         | Optional; no core default.                                        | Run the application in the foreground for local development.                  |
| `up` / `down`                                 | Optional; no core default.                                        | Start and stop an application or dependency stack.                            |
| `start` / `stop`                              | Optional; no core default.                                        | Start and stop a background service, managing only project-owned resources.   |
| `status` / `logs`                             | Optional; no core default.                                        | Inspect service state and view its logs.                                      |
| `install` / `uninstall`                       | Optional when shipping an installable package or command.         | Install and safely reverse that installation.                                 |
| `publish`                                     | Placeholder for publishing.                                       | Add publishing only when the project defines a release process.               |
| `deploy`                                      | Placeholder for deployment.                                       | Add deployment only when the project defines an environment and release flow. |
| `clean`                                       | Previews ignored-file cleanup and removes Docker build artefacts. | Add project-owned cleanup with a `clean::` rule when needed.                  |

For an ordered aggregate such as `check`, prefer a recipe that invokes each root
target in sequence:

```makefile
check: # Run all format, lint, type and test checks @Quality
  $(MAKE) format
  $(MAKE) lint
  $(MAKE) typecheck
  $(MAKE) test
```

This order matters when formatting changes files that linting or tests then
read. Recursive `$(MAKE)` calls propagate Make options, and the repository's
fail-fast shell makes the aggregate stop at the first failure. A prerequisite
list such as `check: format lint typecheck test` is suitable when the work is
independent. GNU Make may run independent prerequisites concurrently when
parallel execution is enabled. This template currently sets `.NOTPARALLEL`, but
the recipe still makes the required order explicit if that policy changes.

#### Compose with root lifecycle targets

Use the root targets as the stable interface for engineers and CI. An extension
can add its work as a prerequisite without replacing the recipe already owned by
the root `Makefile`:

```makefile
# Existing project target in the root Makefile
lint: # Run common and project lint checks @Quality
  $(MAKE) lint-markdown-format

# scripts/python/python.ext.mk
python-lint: # Lint Python source @Quality
  uv run ruff check src tests

lint: python-lint
```

The root `Makefile` still owns the public `lint` target and its common recipe.
The auto-loaded extension adds `python-lint` to its prerequisites. GNU Make
merges single-colon declarations for the same target, so `make lint` runs the
Python check and then the root recipe. This is why the extension does not need
to edit the root `Makefile` or define a second recipe for `lint`.

Choose extension target prefixes to reflect ownership. In a repository with one
primary ecosystem, a technology prefix is clear: a Python extension can add
`deps: python-deps`, `lint: python-lint`, `format: python-format`,
`typecheck: python-typecheck`, `test: python-test` and `build: python-build`.

In a larger domain-driven system, prefer the bounded context or domain as the
prefix. For example, an Orders extension might add `test: orders-test` and
`deploy: orders-deploy`, even if those recipes use Python, TypeScript or SQL
tools internally. The public target then describes the capability's domain owner
and can stay stable if its implementation technology changes. Separate domain
extensions can each add prerequisites to a root target such as `test`.

Database operations should follow the same ownership rule. Use a domain name
such as `orders-migrate` when a migration belongs to that bounded context, or a
technology name such as `database-migrate` when it is a shared platform
operation. Attach each operation only to the lifecycle targets that require it.
Use `config::` or `clean::` when separate extensions need independent setup or
cleanup recipes. Do not use double-colon rules as an override for a single-colon
target. A target cannot mix `:` and `::` rules, and double-colon rules run
separate recipes rather than merging prerequisites.

## Using Bash

Repository scripts use `#!/usr/bin/env bash`, so direct execution also selects
the first Bash on `PATH`. On macOS, put Homebrew's `bin` before `/bin` in your
shell profile and run `make toolchain-verify-gnu` to check the resolved version
and path.

Sample Bash function definition:

```shell
# Short function description
# Arguments (provided as environment variables):
#   foo=[description]
#   baz=[description, default is 'qux']
function some-shell-function() {
    # Function implementation...
```

Run Bash function from a terminal:

The function and script names in these examples are placeholders. See
[docker.lib.sh](../../scripts/docker/docker.lib.sh) for a bundled function
library.

```shell
source scripts/a-suite-of-shell-functions
foo=bar some-shell-function # Environment variable is accessible by the function executed in the same operating system process
```

```shell
source scripts/a-suite-of-shell-functions
foo=bar
some-shell-function # Environment variable is still accessible by the function
```

Run Bash script from a terminal, bear in mind that executing a script creates a
child operating system process:

```shell
# Environment variable has to be exported to be passed to a child process, DO NOT use this pattern
export foo=bar
scripts/a-shell-script
```

```shell
# or to be set in the same line before creating a new process, prefer this pattern over the previous one
foo=bar scripts/a-shell-script

# or when multiple variables are required
foo=bar \
baz=qux \
  scripts/a-shell-script
```

By convention we use uppercase variables for global settings that you would
ordinarily associate with environment variables. We use lower-case variables as
arguments to be passed into specific functions we call, usually on the same
line, right before the function name.

The command `set -euo pipefail` is commonly used in the Bash scripts, to
configure the behavior of the script in a way that makes it more robust and
easier to debug. Here is a breakdown of each option switch:

- `-e`: Ensures that the script exits immediately if any command returns a
  non-zero exit status.
- `-u`: Makes the script exit if there is an attempt to use an uninitialised
  variable.
- `-o pipefail`: ensures that if any command in a pipeline fails (i.e., returns
  a non-zero exit status), then the entire pipeline will return that non-zero
  status. By default, a pipeline returns the exit status of the last command.

## Make and Bash working together

Sample make target calling a Bash function. Notice that `baz` is going to be
accessible to the function as it is executed in the same operating system
process:

```makefile
some-target: # Run shell function - mandatory: foo=[description]
  source scripts/a-suite-of-shell-function
  baz=qux
  some-shell-function # 'foo' and 'baz' are accessible by the function
```

Sample make target calling another make target. In this case a parameter `baz`
has to be passed as a variable to the make target, which is executed in a child
process:

```makefile
some-target: # Call another target - mandatory: foo=[description]
  baz=qux \
    $(MAKE) another-target # 'foo' and 'baz' are passed to the make target
```

Run it from a terminal:

```shell
foo=bar make some-target
```

## Conventions

### Debugging

To assist in investigating scripting issues, the `VERBOSE` variable is available
for both Make and Bash scripts. If it is set to `true` or `1`, it prints all the
commands that the script executes to stderr. Here is how to use it:

for Make targets

```shell
VERBOSE=1 make docker-example-build
```

for Bash scripts

```shell
VERBOSE=1 scripts/quality/check-shell-lint.sh
```

### Scripts

Most scripts provided with this repository template can use tools installed on
your `PATH` if they are available or run them from within a Docker container. To
force a script to use Docker, the `FORCE_USE_DOCKER` variable is provided. This
feature allows you to use custom tooling if it is present on the command-line
path. Here is how to use it:

```shell
FORCE_USE_DOCKER=1 scripts/quality/check-shell-lint.sh
```

You can combine it with the `VERBOSE` flag to see the details of the execution
flow:

```shell
VERBOSE=1 FORCE_USE_DOCKER=1 scripts/quality/check-shell-lint.sh
```

### Shell lint

`make lint-shell` runs ShellCheck over every shell script known to Git, like the
other checks. Set `check=staged-changes`, `check=working-tree-changes` or
`check=branch` to lint only the changed scripts. Each changed, deleted or
renamed script also brings in the scripts that name it and the scripts those
name, so ShellCheck sees the same source context as a full run. A change to a
`.shellcheckrc` file or to `mise.toml`, which pins ShellCheck, lints every
script.

The target also fails any full-line comment longer than 80 characters in those
`*.sh` files and the tracked `*.mk` files, or only the changed ones in a scoped
mode. It counts bytes, so a non-ASCII character counts as more than one. The
shebang and comment lines that contain a URL are exempt. Code lines are not
limited.

For a one-file diagnostic, run ShellCheck directly:

```shell
shellcheck -- scripts/quality/check-shell-lint.sh
```
