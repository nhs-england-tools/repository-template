# Use Bash and Make 🐚

- [Use Bash and Make 🐚](#use-bash-and-make-)
  - [Using Make 🧰](#using-make-)
    - [Make modules](#make-modules)
      - [Load order](#load-order)
      - [Write a module](#write-a-module)
      - [Write a library](#write-a-library)
      - [Add a service Makefile](#add-a-service-makefile)
      - [Directory contract](#directory-contract)
      - [Why it works this way](#why-it-works-this-way)
      - [Rules and caveats](#rules-and-caveats)
      - [Root lifecycle target map](#root-lifecycle-target-map)
      - [Compose with root lifecycle targets](#compose-with-root-lifecycle-targets)
  - [Clean up files and Docker resources 🧹](#clean-up-files-and-docker-resources-)
    - [Git cleanup options](#git-cleanup-options)
    - [Docker cleanup](#docker-cleanup)
  - [Using Bash 🐚](#using-bash-)
  - [Make and Bash working together 🔗](#make-and-bash-working-together-)
  - [Conventions 📏](#conventions-)
    - [Structured data and jq](#structured-data-and-jq)
    - [Scripts](#scripts)
    - [Shell lint](#shell-lint)
    - [Debugging](#debugging)

## Using Make 🧰

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
  implementation in the [docker.lib.mk](../../../scripts/docker/docker.lib.mk)
  file. More complex operations are implemented in the
  [docker.sh](../../../scripts/docker/docker.lib.sh) script for readability and
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

### Make modules

Add team and project targets without editing the shared Make files. Make files
have four roles:

| File                                | Role                                                                                     | Loaded by                                                                                          |
| ----------------------------------- | ---------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| `scripts/init.mk`                   | Initialiser. Make settings, `help`, `include-once`, shared quality and toolchain targets | The Makefile that `make` runs. A repeated include is a no-op                                       |
| `scripts/**/*.lib.mk`               | Library. Shared targets or variables that other Make files use                           | `$(call include-once,<path>)` in the file that needs it                                            |
| `scripts/**/*.mk` (any other name)  | Module. Your capability, for example `scripts/backend/backend.mk`                        | `init.mk`, automatically, for a root Makefile. `$(call include-once,<path>)` in a service Makefile |
| `Makefile` in the root or a service | Entry point. Includes `init.mk` and owns lifecycle recipes                               | `make`, from its own directory or with `-C` or `-f`                                                |

`<path>` is the file's path under `scripts/`, for example
`backend/backend.lib.mk`. A root Makefile is any Makefile in the repository root
directory. Every other Makefile that includes `init.mk` is a service Makefile.

The template's own Docker targets follow the same rules. They live in the
[docker.lib.mk](../../../scripts/docker/docker.lib.mk) library, which `init.mk`
loads before anything else.

#### Load order

[init.mk](../../../scripts/init.mk) loads files in this fixed order:

1. It locates itself from `MAKEFILE_LIST`, so every later path is relative to
   `init.mk`, not to the directory you run `make` in.
2. It loads `scripts/docker/docker.lib.mk`.
3. It defines the shared settings and targets, including `include-once`.
4. For a root Makefile only, it loads every other `*.mk` file under `scripts/`,
   skipping `init.mk` itself and every `*.lib.mk` file. Make's `sort` orders
   them by full path. A service Makefile skips this step.
5. Make then reads the rest of the entry-point `Makefile`, including its
   `include-once` calls.

A file named with `include-once` loads at that point, unless it has already
loaded. Discovery in step 4 skips a module that has already loaded.

Make's `sort` compares full paths byte by byte. The files in one directory
therefore sort together, and `scripts/a.mk` sorts before `scripts/a/00-first.mk`
because `.` sorts before `/`:

```text
scripts/a.mk
scripts/a/00-first.mk
scripts/a/01-second.mk
scripts/b.mk
scripts/z/00-last.mk
```

A numeric prefix such as `00-` orders files within one directory only. It does
not move `scripts/z/00-last.mk` ahead of `scripts/b.mk`.

#### Write a module

A module is any `*.mk` file under `scripts/` whose name does not end in
`.lib.mk`. From the repository root, its targets work with `make <target>` and
appear in `make help`. A service Makefile must name a module before it can use
it, see [Add a service Makefile](#add-a-service-makefile). The example below
assumes you also create `scripts/backend/lambda-invoke.sh`.

```makefile
# scripts/backend/backend.mk

backend-lambda-invoke: event ?= events/default.json
backend-lambda-invoke: # Invoke a Lambda function locally - mandatory: name=[function name]; optional: event=[event file path, default is 'events/default.json'] @Development
  $(if $(name),,$(error name is required. Usage: make backend-lambda-invoke name=my-function))
  name=$(name) event=$(event) "$(REPOSITORY_SCRIPTS_DIR)/backend/lambda-invoke.sh"

${VERBOSE}.SILENT: \
    backend-lambda-invoke \
```

Refer to repository files through `$(REPOSITORY_SCRIPTS_DIR)` or
`$(REPOSITORY_ROOT_DIR)`. Both are absolute, so a path built from them stays
correct from a service directory and after a recipe changes directory. Quote
them in recipes, in case the repository path contains spaces.

Prefix a module's own variable names with the module name, for example
`BACKEND_EVENTS_DIR`. Modules share one variable namespace, and Make expands a
variable in a recipe when the recipe runs, not when Make reads the module. If
two modules set the same variable, the recipes of both see the value that Make
read last.

#### Write a library

Name a file `*.lib.mk` when it should load only where another Make file asks for
it, like `*.lib.sh` for shell libraries. Name it with `include-once` and its
path under `scripts/`:

```makefile
# scripts/backend/backend.mk

$(call include-once,backend/backend.lib.mk)
```

`include-once` loads each path at most once per Make run, so several modules and
Makefiles can name the same library. A library needs no include guard and can
use any shell syntax in its recipes. The call expresses the dependency. Load
order between modules does not.

Load modules and libraries with `include-once`, never with a plain `include`. A
plain `include` does not record the file, so a later `include-once` of the same
file loads it again. Make then redefines its targets and prints override
warnings. `init.mk` is the only file under `scripts/` that a Makefile includes
with a plain `include`.

#### Add a service Makefile

Keep reusable Make code under `scripts/`. An application or service in its own
directory gets its own `Makefile`. It includes `init.mk` relative to itself,
then names the modules it uses. The `include` line comes first, because
`include-once` and the repository path variables exist only after it:

```makefile
# services/orders/Makefile

SERVICE_DIR := $(dir $(lastword $(MAKEFILE_LIST)))
include $(SERVICE_DIR)../../scripts/init.mk
$(call include-once,orders/orders.mk)
```

Naming a module brings its targets and its lifecycle prerequisites. Take this
Orders module, and a Billing module that adds `test: billing-test` in the same
way:

```makefile
# scripts/orders/orders.mk

orders-test: # Run the Orders tests @Quality
  cd "$(REPOSITORY_ROOT_DIR)/services/orders"
  uv run pytest

test: orders-test
```

The `test` commands then run:

| Command                                                        | Runs                                                       |
| -------------------------------------------------------------- | ---------------------------------------------------------- |
| `make test` in the repository root                             | `billing-test`, `orders-test`, then the root `test` recipe |
| `make -C services/orders test`                                 | `orders-test`                                              |
| `make -f services/orders/Makefile test` in the repository root | `orders-test`                                              |

Run a service Makefile with `make -C services/orders <target>`, or with
`make <target>` from inside `services/orders`. The `$(SERVICE_DIR)` prefix also
makes `make -f services/orders/Makefile <target>` work from the repository root.

A service Makefile loads only the modules it names, so the lifecycle
prerequisites of other modules, such as Billing's `test: billing-test`, never
reach it. `init.mk` does not include the root `Makefile` either, so a service
Makefile defines its own lifecycle recipes where it needs them. The shared
targets from `init.mk` and `docker.lib.mk`, such as `lint-shell` and
`docker-build`, are always available.

#### Directory contract

The directory a recipe runs in depends on what the target is for:

| Targets                                                                                     | Run in                    | Why                                                      |
| ------------------------------------------------------------------------------------------- | ------------------------- | -------------------------------------------------------- |
| Shared checks, formatting, secret scans, quality gates, toolchain, Git hooks, `clean` (Git) | The repository root       | They check and configure the whole repository            |
| Docker and Compose targets, `version-create-effective-file`, module and service targets     | The directory `make` uses | They build, run or version the service next to its files |

Docker image targets default to the directory Make runs in. At the repository
root, they default to `infrastructure/images/$DOCKER_IMAGE` instead when
`DOCKER_IMAGE` is set, and fail if that directory is missing. See
[image directory defaults](Build_Docker_images.md#use-a-different-image-directory).

Write a recursive call in shared code, a module or a service Makefile as:

```makefile
  $(MAKE) -C "$(CURDIR)" -f "$(MAKE_ENTRY_POINT)" <target>
```

`$(CURDIR)` is the directory Make runs in. `MAKE_ENTRY_POINT` names the Makefile
that `make` started with, exactly as Make was given it, so a relative name is
relative to `$(CURDIR)`. Together they reach the same Makefile even after the
recipe has changed directory, and keep a service Makefile selected with `-f` in
charge. A plain `$(MAKE) <target>` reads whichever `Makefile` sits in the
recipe's current directory. The root `Makefile`'s own recipes use a plain
`$(MAKE)`. That is safe there, because the root Makefile runs from the
repository root and its recipes do not change directory first.

`REPOSITORY_ROOT_DIR` and `REPOSITORY_SCRIPTS_DIR` are the absolute paths of the
repository root and its `scripts/` directory.

#### Why it works this way

- **Plain `*.mk` names.** An engineer adds `backend.mk` and it works. There is
  no special suffix to learn, and the name matches every other Make project.
- **Explicit libraries.** Automatic loading is convenient for entry points but
  hides dependencies. A `*.lib.mk` file loads only where an `include-once` call
  names it, so the dependency stays visible in the code that needs it.
- **The root loads every module, a service names its own.** The root Makefile
  serves the whole repository, so a module adds its targets and lifecycle
  prerequisites there without anyone editing the root Makefile. A service
  Makefile serves one service, so it loads only the modules it names. A missing
  name fails with `No rule to make target`, rather than running another
  service's work in the wrong directory.
- **Docker first, by name.** Template libraries load before any module. A module
  can therefore read a Docker variable, such as `DOCKER_IMAGE`, while Make reads
  the module. Adding a prerequisite, such as `docker-build: backend-generate`,
  works in any load order.
- **Full-path sorting.** Make's `sort` compares bytes, not locale rules, so
  every machine and CI runner loads the same order.
- **One location for modules.** Searching only `scripts/` keeps discovery fast
  and predictable. Application directories stay free of hidden Make side effects
  and opt in through their own `Makefile`.
- **Self-located, relative includes.** `init.mk` finds its files from
  `MAKEFILE_LIST`, not the current directory, so it loads from any service. It
  includes them by relative path, because Make splits file lists on spaces. The
  Make files therefore still load when the directory that holds the repository
  has a space in its path.
- **`include-once` instead of include guards.** An include guard wraps a whole
  file in a Make conditional. When Make skips that block, it reads a recipe line
  that starts with a shell `else` as a Make `else` and stops. `include-once`
  records each loaded path instead, so libraries need no guard. Only `init.mk`
  keeps one, because a Makefile includes it before `include-once` exists. A
  repeated include of `init.mk` is a silent no-op rather than an error, so a
  harmless repeat does not break every command.

#### Rules and caveats

- All targets and variables share one namespace across modules, libraries and
  the entry point. Prefix their names with the module name, for example
  `backend-lambda-invoke` and `BACKEND_EVENTS_DIR`.
- Extend existing targets with a prerequisite, for example `lint: backend-lint`.
  Add to `clean::` and `config::` with a new double-colon rule. Do not give an
  existing single-colon target a second recipe, as Make replaces the first one
  and prints a warning.
- Load modules and libraries with `include-once` only. A plain `include` of a
  module or library that discovery or `include-once` also loads redefines its
  targets. Include `init.mk` itself with a plain `include`.
- A module that needs another file's variables while Make reads it names that
  file with `include-once` above the first line that uses them. Recipes can use
  any target or variable that has loaded, because all files load before any
  target runs.
- Naming `docker/docker.lib.mk` with `include-once`, or including `init.mk`
  again, is a no-op, because both have already loaded. Leave such lines out so
  the load order stays easy to read.
- In `init.mk`, no recipe line may start with a Make conditional keyword such as
  `ifdef`, `ifeq`, `else` or `endif`, because of its include guard. Use an early
  `exit`, or keep `else` on the same line as other shell code. The loader tests
  include `init.mk` twice to catch this. Other Make files have no such limit.
- For a root Makefile, every `*.mk` file under `scripts/` loads, including
  symlinked files and files in test directories. `find` does not enter symlinked
  directories, so modules inside one do not load. Name a fixture `*.lib.mk` or
  keep it outside `scripts/`.
- Sorting is by byte. `10-` sorts before `9-`, and uppercase before lowercase.
  Use zero-padded prefixes such as `00-` and `01-`, and lowercase names.
- Ordering is not dependency management. Name the file you need with
  `include-once`.
- A malformed module stops every `make` command of a root Makefile, including
  `make help`, and every command of a service Makefile that names it.
- `include-once` loads files under `scripts/` only. Include a file elsewhere,
  such as a service's own `*.mk` file, with a plain `include`.
- Keep the names of files and directories inside the repository free of spaces,
  as Make splits file lists on whitespace.
- `make -f` does not change directory. Use `make -C <dir>` when service recipes
  must run in the service directory.
- The root `Makefile` runs from the repository root, as engineers and CI do.
  From elsewhere, use `make -C <repository root>`.

#### Root lifecycle target map

This map covers common lifecycle targets, not every command shown by
`make help`. The full help also includes shared toolchain, Docker, quality-gate
and module commands. The root `Makefile` provides stable target names for common
project tasks. Some already run template checks, while others are placeholders
for the adopting project. Implement a missing capability in the root recipe or
add it through a module. Keep the public target name stable either way.

The build stage calls `make build` in its first artefact job. The publish
workflow calls `make publish` after creating the GitHub release. The deploy
workflow checks out the selected tag and calls `make deploy`, with `TAG` set to
that tag. These jobs install the pinned mise tools before calling the targets.
Implement the project recipes and configure dependency installation, artefact
transfer, credentials and environments where needed. The second build job
remains an example for projects with another artefact.

| Target                                        | Template default                                                  | Project or module responsibility                                              |
| --------------------------------------------- | ----------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| `config`                                      | Installs shared tools, hooks and pinned helper images.            | Add independent setup with a `config::` rule when needed.                     |
| `env`                                         | Placeholder for project environment setup.                        | Create or validate the language environment.                                  |
| `setup`                                       | Optional convenience target, not a core requirement.              | Compose `config` and `deps` for one-command onboarding.                       |
| `deps`                                        | Placeholder for project dependencies.                             | Install or synchronise locked application dependencies.                       |
| `deps-prod`                                   | Optional. No core default.                                        | Install only production dependencies when they differ from development deps.  |
| `deps-update`                                 | Optional. No core default.                                        | Update dependencies and their lock files explicitly.                          |
| `format`                                      | Formats Markdown files.                                           | Add language formatters as prerequisites.                                     |
| `lint`                                        | Runs common file, Markdown, shell and workflow checks.            | Add language or domain linters as prerequisites.                              |
| `typecheck`                                   | Placeholder for project type checking.                            | Add the selected static type checker.                                         |
| `test`                                        | Fast development feedback. Template suites run here               | Add fast project/system tests, such as unit tests                             |
| `test-unit` / `test-integration` / `test-all` | Optional. No core default.                                        | Add slower integration and end-to-end tiers as separate targets.              |
| `check`                                       | Runs `format`, `lint`, `typecheck` and `test`.                    | Extend component targets. Keep ordered aggregate semantics stable.            |
| `build`                                       | Placeholder for project artefact creation.                        | Build the package, binary, image or other artefact.                           |
| `run`                                         | Optional. No core default.                                        | Run the application in the foreground for local development.                  |
| `up` / `down`                                 | Optional. No core default.                                        | Start and stop an application or dependency stack.                            |
| `start` / `stop`                              | Optional. No core default.                                        | Start and stop a background service, managing only project-owned resources.   |
| `status` / `logs`                             | Optional. No core default.                                        | Inspect service state and view its logs.                                      |
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

Use the root targets as the stable interface for engineers and CI. A module can
add its work as a prerequisite without replacing the recipe already owned by the
root `Makefile`:

```makefile
# Existing project target in the root Makefile
lint: # Run common and project lint checks @Quality
  $(MAKE) lint-markdown-format

# scripts/python/python.mk
python-lint: # Lint Python source @Quality
  cd "$(REPOSITORY_ROOT_DIR)"
  uv run ruff check src tests

lint: python-lint
```

The root `Makefile` still owns the public `lint` target and its common recipe.
The module adds `python-lint` to its prerequisites. GNU Make merges single-colon
declarations for the same target, so `make lint` runs the Python check and then
the root recipe. This is why the module does not need to edit the root
`Makefile` or define a second recipe for `lint`. A service Makefile gets the
same prerequisite for its own `lint` only if it names `python/python.mk`.

Choose module target prefixes to reflect ownership. In a repository with one
primary ecosystem, a technology prefix is clear: a Python module can add
`deps: python-deps`, `lint: python-lint`, `format: python-format`,
`typecheck: python-typecheck`, `test: python-test` and `build: python-build`.

In a larger domain-driven system, prefer the bounded context or domain as the
prefix. For example, an Orders module might add `test: orders-test` and
`deploy: orders-deploy`, even if those recipes use Python, TypeScript or SQL
tools internally. The public target then describes the capability's domain owner
and can stay stable if its implementation technology changes. Separate domain
modules can each add prerequisites to a root target such as `test`.

Database operations should follow the same ownership rule. Use a domain name
such as `orders-migrate` when a migration belongs to that bounded context, or a
technology name such as `database-migrate` when it is a shared platform
operation. Attach each operation only to the lifecycle targets that require it.
Use `config::` or `clean::` when separate modules need independent setup or
cleanup recipes. Do not use double-colon rules as an override for a single-colon
target. A target cannot mix `:` and `::` rules, and double-colon rules run
separate recipes rather than merging prerequisites.

## Clean up files and Docker resources 🧹

`make clean` runs the separate `clean::` recipes in
[docker.lib.mk](../../../scripts/docker/docker.lib.mk),
[init.mk](../../../scripts/init.mk), the root Makefile and any modules. The
shared Git recipe previews file cleanup by default. The Docker recipe removes
image tags and generated files immediately, even without `CONFIRM=true`.

The shared Git recipe always covers the whole repository, also when a service
Makefile runs it. It prints `Git cleanup covers the whole repository at <path>`
before it previews or deletes anything.

Preview the commands from every recipe with `make -n clean` before running
cleanup. Check any project modules too. `CONFIRM` is not a preview switch for
the whole target.

### Git cleanup options

These options control the shared Git recipe:

| Option           | Default            | Effect                                                                                                          |
| ---------------- | ------------------ | --------------------------------------------------------------------------------------------------------------- |
| `CONFIRM=true`   | Preview only       | Deletes selected files and empty directories. Enables restoring tracked files when `UNSTAGED=true` is also set. |
| `UNTRACKED=true` | Ignored files only | Includes other untracked files as well as ignored files. Files in the index are kept.                           |
| `UNSTAGED=true`  | Keep tracked edits | Restores tracked files from the index, discarding their unstaged changes. Staged changes are kept.              |

The default selection uses `git clean -d -X`. With `UNTRACKED=true`, it uses
`git clean -d -x`. Both can include local configuration, caches and virtual
environments. Confirmed cleanup also removes empty directories outside Git's
metadata. `UNSTAGED=true` uses `git restore -- .`, so a partially staged file
returns to its staged contents, not necessarily to `HEAD`.

The following examples assume the `my-shiny-app` image directory from
[Build Docker images](Build_Docker_images.md#quick-start) exists. Each command
also runs the Docker cleanup described below. `dir` selects the image directory
only. Git cleanup still covers the repository.

Inspect the commands without executing the cleanup recipes:

```shell
make -n clean DOCKER_IMAGE=my-shiny-app dir=infrastructure/images/my-shiny-app
```

Preview ignored-file cleanup, then apply it after reviewing the output:

```shell
make clean DOCKER_IMAGE=my-shiny-app dir=infrastructure/images/my-shiny-app
make clean DOCKER_IMAGE=my-shiny-app dir=infrastructure/images/my-shiny-app CONFIRM=true
```

To include other untracked files, use the same selection for preview and apply:

```shell
make clean DOCKER_IMAGE=my-shiny-app dir=infrastructure/images/my-shiny-app UNTRACKED=true
make clean DOCKER_IMAGE=my-shiny-app dir=infrastructure/images/my-shiny-app UNTRACKED=true CONFIRM=true
```

To also discard unstaged edits, first review `git diff` and `git diff --cached`.
The following selection includes ignored files and tracked edits, while keeping
other untracked files:

```shell
make clean DOCKER_IMAGE=my-shiny-app dir=infrastructure/images/my-shiny-app UNSTAGED=true
make clean DOCKER_IMAGE=my-shiny-app dir=infrastructure/images/my-shiny-app UNSTAGED=true CONFIRM=true
```

Combine `UNTRACKED=true` and `UNSTAGED=true` only when both sets of changes
should be removed. Git cannot recover deleted untracked files or discarded
unstaged content that was never committed or otherwise saved.

### Docker cleanup

The Docker recipe attempts to remove the selected image's tags listed in its
`.version` file, plus `latest`. It ignores image-removal failures, for example
when a container still uses the image. It then removes these generated files
from the selected directory:

- `.version`
- `Dockerfile.effective`
- `Dockerfile.effective.dockerignore`

The source `Dockerfile` and `VERSION` are kept. Use `DOCKER_IMAGE` and an
existing `dir` or `docker_dir` to select the image. Without a directory option,
the wrapper uses the
[image directory defaults](Build_Docker_images.md#use-a-different-image-directory).
At the repository root with `DOCKER_IMAGE` set, that is
`infrastructure/images/$DOCKER_IMAGE`. Otherwise it is the directory `make` runs
in, where generated files with the names above will be removed. A missing image
directory fails the Docker recipe before the Git cleanup runs.

To run just the image cleanup, call the internal wrapper explicitly:

```shell
make _docker docker_fn=clean DOCKER_IMAGE=my-shiny-app dir=infrastructure/images/my-shiny-app
```

This command acts immediately and does not use the Git cleanup options. Compose
has its own `make docker-compose-clean` target, which removes the selected
stack's containers and network while retaining volumes. It does not run through
`make clean`. See
[Run services with Docker Compose](Run_Docker_Compose_services.md).

## Using Bash 🐚

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
[docker.lib.sh](../../../scripts/docker/docker.lib.sh) for a bundled function
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

## Make and Bash working together 🔗

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

## Conventions 📏

### Structured data and jq

Separate command entrypoints, execution and structured-data logic:

- **Make exposes commands.** Targets such as `make lint-security-readiness`
  provide the same interface locally, in Git hooks and in CI.
- **Bash orchestrates execution.** Shell scripts select files, check required
  tools, run commands and handle diagnostics and exit statuses.
- **jq processes structured data.** It reads JSON and evaluates rules or
  transforms objects and arrays. A `.jq` file contains jq source code, not
  configuration. The `jq` executable runs that code.

Use jq rather than `grep` or `sed` to extract fields from nested JSON. For YAML
input, a shell script can use `yq` to convert it to JSON before passing it to
jq. Keeping the rules separate avoids fragile shell text parsing and makes them
easier to read and test.

For example,
[check-security-readiness.sh](../../../scripts/quality/check-security-readiness.sh)
handles file selection and reporting, while
[check-security-readiness.jq](../../../scripts/quality/check-security-readiness.jq)
contains the governance rules and returns diagnostics. The shell script turns
those diagnostics into warnings or failures.

A jq file can be a standalone program, executed with `jq -f`, or a module loaded
with `include` from a directory supplied through `jq -L`. The security readiness
rules use the module form. Both approaches keep structured-data logic out of
Make recipes and shell orchestration.

### Scripts

Most scripts provided with this template run their tools in pinned Docker
containers by default. This limits access to the host's files and network. To
use a native tool instead, set `FORCE_USE_DOCKER=false`. Native mode has the
user's full access and is not recommended for repository quality checks. For
example:

```shell
FORCE_USE_DOCKER=false scripts/quality/check-shell-lint.sh
```

The same variable works for Make targets and shell profiles. For a CI composite
action, set `FORCE_USE_DOCKER=false` in `.github/actions/<check>/action.yaml`
and make the native tool available on the runner. This is not recommended. The
pipeline-contract and security-readiness checks always run natively. Security
readiness warns once, but does not fail, when native mode is selected.

Combine the opt-out with `VERBOSE` to see the execution details:

```shell
VERBOSE=1 FORCE_USE_DOCKER=false scripts/quality/check-shell-lint.sh
```

### Diagnostics

Report errors, warnings and notices with `print-diagnostic` from
[github-actions.lib.sh](../../../scripts/cicd/github-actions.lib.sh). Do not use
`echo ... >&2` or hand-written `ERROR:` labels. In GitHub Actions the function
writes an annotation that appears on the run summary. Locally it prints an
`ERROR:`, `WARNING:` or `NOTICE:` line to stderr.

Choose the level by what happens next:

- `error` when the command fails or returns a non-zero status.
- `warning` when the command carries on, but the result is incomplete, such as a
  failed cleanup or an unwritten state file.
- `notice` when the user should know about a fallback or a manual step.

Shell scripts source the library next to the other `source` lines. A Make recipe
sources it before its first check, because each recipe runs in a new shell:

```makefile
my-target: # Example target @Others
  source "$(REPOSITORY_ROOT_DIR)/scripts/cicd/github-actions.lib.sh"
  [[ -n "${name}" ]] || { print-diagnostic error "name is required, for example: make my-target name=x"; exit 1; }
```

The library sets `set -euo pipefail`. Avoid `grep -q` at the end of a pipe after
sourcing it. `grep -q` stops reading at the first match, and `pipefail` can then
report the writer's `SIGPIPE` as a failure. Redirect `grep` output to
`/dev/null` instead.

Some output is deliberately not a diagnostic:

- Progress lines, prompts and replies to prompts, such as
  `Checking docker (up to 10s)`.
- Report rows on stdout, such as `make toolchain-verify-gnu` results and the
  test runner summary. A single diagnostic follows them when they fail.
- `PREREQUISITE:` lines, which the test runner and the quality gate parse.
- Workflow steps that run before checkout, or that never run outside GitHub
  Actions. They write `::error::` directly, because the library is not available
  or adds nothing there.

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

To exempt files such as vendored scripts from the comment check, list them in
`scripts/config/.commentlengthignore` with `.gitignore` rules, relative to the
repository root. ShellCheck still lints them. A scoped mode that changes that
file checks the comments of every script and Make file.

For a one-file diagnostic, run ShellCheck directly:

```shell
shellcheck -- scripts/quality/check-shell-lint.sh
```

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
