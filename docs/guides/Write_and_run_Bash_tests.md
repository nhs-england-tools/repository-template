# Write and run Bash tests 🧪

- [Write and run Bash tests 🧪](#write-and-run-bash-tests-)
  - [Prerequisites and discovery 🔍](#prerequisites-and-discovery-)
  - [Write a small suite 📝](#write-a-small-suite-)
  - [Capture expected failures 🚨](#capture-expected-failures-)
  - [Stub external commands 🧩](#stub-external-commands-)
  - [Use isolated fixtures 📁](#use-isolated-fixtures-)
  - [Run and debug suites 🔧](#run-and-debug-suites-)

The template provides a Bash test harness in
[test.lib.sh](../../scripts/tests/test.lib.sh) and a suite runner in
[run-test-suites.sh](../../scripts/tests/run-test-suites.sh). Use them for
repository scripts and Make wrappers. The template runs these suites through
the quick-feedback `make test` target. Add fast project and system tests, such
as unit tests, to that target. Keep slower tests in separate targets. See
[Use Bash and Make](Use_Bash_and_Make.md#compose-with-root-lifecycle-targets).

## Prerequisites and discovery 🔍

Complete the [quick start](../../README.md#quick-start-) and run
`make toolchain-verify-gnu`. Tests require the GNU Bash and userland versions
used by the scripts. Execute the commands below from the repository root.

`make test` discovers `*.test.sh` files under `scripts/`, including tracked
files and non-ignored untracked files. Keep each suite in a `tests/` directory
next to the code it tests, and make it executable. A discovered non-executable
suite fails the run. Ignored files and deleted files are excluded. Discovery
does not descend into a nested Git repository unless `dir` points inside it.

The full run includes the Docker integration suite, which needs a running Docker
daemon. Suites that stub Docker can run without the daemon. A missing runtime is
a prerequisite failure, not evidence that the integration passed.

## Write a small suite 📝

Create `scripts/example/greeting.lib.sh`:

```shell
#!/usr/bin/env bash

function greeting() {
  if [[ -z "${1:-}" ]]; then
    echo "name is required" >&2
    return 2
  fi
  printf 'Hello, %s!\n' "$1"
}
```

Create `scripts/example/tests/greeting.test.sh`:

```shell
#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2317,SC2329

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
source ./scripts/tests/test.lib.sh
source ./scripts/example/greeting.lib.sh

function test-greeting-with-name() {
  test-capture greeting "Ada Lovelace"
  assert-equal 0 "$TEST_STATUS" "exit status"
  assert-equal "Hello, Ada Lovelace!" "$TEST_STDOUT" "greeting"
  assert-equal "" "$TEST_STDERR" "stderr"
}

function test-greeting-without-name() {
  test-capture greeting
  assert-equal 2 "$TEST_STATUS" "exit status"
  assert-equal "" "$TEST_STDOUT" "stdout"
  assert-contains "$TEST_STDERR" "name is required"
}

test-run-suite test-greeting-with-name test-greeting-without-name
```

The ShellCheck directives account for sourced files and test functions called
indirectly by the harness. Use them only where needed. Make the suite executable
and run it:

```shell
chmod +x scripts/example/tests/greeting.test.sh
./scripts/example/tests/greeting.test.sh
```

Expect two `PASS` lines and a summary showing two passing tests. Register each
test explicitly in `test-run-suite`. It does not discover functions by name. An
empty test list fails. When adding behaviour, first check that the new test
fails for the intended reason, then implement the behaviour and rerun it.

## Capture expected failures 🚨

Each test runs in a subshell with `set -e` enabled. An unexpected failed command
fails the test immediately. Calling `exit`, even `exit 0`, also fails a test
because it did not return normally.

`test-capture` runs a command or function in a subshell and records:

| Variable      | Value                                            |
| ------------- | ------------------------------------------------ |
| `TEST_STATUS` | Exit status of the command.                      |
| `TEST_STDOUT` | Standard output, with trailing newlines removed. |
| `TEST_STDERR` | Standard error, with trailing newlines removed.  |

It returns success so the test can assert an expected non-zero status. Always
assert `TEST_STATUS` as well as relevant output. The captured command reads from
`/dev/null`, has tracing disabled and does not inherit `VERBOSE`. Variable and
directory changes inside it do not persist in the test.

Call `test-capture` directly. Avoid putting test functions or the suite runner
inside `if`, `!`, `&&` or `||` to handle failure, because those contexts can
disable Bash's errexit behaviour. For assertions, use the harness helpers:

| Helper                                          | Arguments                                                 |
| ----------------------------------------------- | --------------------------------------------------------- |
| `assert-equal`                                  | Expected value, actual value, optional description.       |
| `assert-contains` / `assert-not-contains`       | Text to search, fixed string, optional description.       |
| `assert-matches`                                | Value, extended regular expression, optional description. |
| `assert-file-exists` / `assert-file-not-exists` | File path.                                                |
| `assert-file-has-line`                          | File path, exact line.                                    |
| `assert-files-identical`                        | Expected file, actual file.                               |

For exact output including trailing newlines, write to a fixture file and use
`assert-files-identical`.

## Stub external commands 🧩

The harness creates a fresh `STUB_DIR` at the front of each test's `PATH`. Use
`test-stub` to replace a command with a small Bash body and record its
arguments. This example exercises the existing Compose status helper without
starting Docker:

```shell
function test-compose-status() {
  source "$TEST_REPO_ROOT/scripts/docker/docker.lib.sh"
  mkdir -p "$TEST_TMP/compose"
  printf 'services: {}\n' > "$TEST_TMP/compose/compose.yaml"
  test-stub docker 'exit 0'

  compose_dir="$TEST_TMP/compose" project=guide-demo \
    test-capture docker-compose-status

  assert-equal 0 "$TEST_STATUS" "exit status"
  assert-stub-called docker "compose version"
  assert-stub-called docker "compose --project-name guide-demo ps"
}
```

Add the function to a suite and its `test-run-suite` list. To simulate a
failure, use a body such as `echo "daemon unavailable" >&2; exit 1` and assert
the result. Stub bodies have access to their arguments through `"$@"` and to
exported variables.

`test-stub-calls docker` prints the recorded calls. Each argument is escaped
with Bash `printf %q`, so paths containing spaces need the corresponding escaped
form in `assert-stub-called`. `assert-stub-not-called` checks that no call was
recorded. Repeating `test-stub` replaces the body but keeps recorded calls
within that test.

The stub executable is a symlink to the shared dispatcher. Never write to that
symlink. Replace its body with `test-stub`. A stub only intercepts commands
resolved through `PATH`, so it does not replace an absolute executable path.

## Use isolated fixtures 📁

Each test gets `TEST_TMP` for scratch files. The harness removes it afterwards
and isolates shell state and Git identity/configuration. It does not isolate the
filesystem or network: scripts can still affect real resources. Put fixtures
under `TEST_TMP` and stub external commands before exercising them.

`test-isolate-path` restricts `PATH` to the harness's base tools plus tools you
name. Call it before creating command stubs when testing missing-tool or
fallback behaviour. For example, `test-isolate-path make` retains Make as well
as the base tools.

Use `test-create-repo "$TEST_TMP/repo" path/to/file ...` when the script needs
Git history. It creates a repository on `main` with one initial commit and the
requested repository files. Executable files are symlinked to the real checkout
for speed. Do not edit, `chmod` or `touch` those links. Create or copy separate
fixture files when a test needs to change them.

For shared, read-only fixture setup, define `test-suite-setup` and
`test-suite-teardown`. The harness calls them once before and after the suite.
They can use `SUITE_TMP`, which is removed on exit. Per-test variables such as
`TEST_TMP` and `STUB_DIR` are not available there. Teardown runs even when setup
or a test fails. Keep it safe to run after incomplete setup.

## Run and debug suites 🔧

Run one suite directly or restrict discovery to a directory:

```shell
./scripts/quality/tests/check-file-format.test.sh
dir=scripts/quality ./scripts/tests/run-test-suites.sh
make test
```

The suite runner starts all discovered suites in parallel, then prints their
output in a stable order and a pass/fail summary. A missing suite selection or
any failed suite produces a non-zero exit status.

Within a suite, `TEST_JOBS` controls parallel tests and defaults to the CPU
count. It does not limit how many suites `make test` starts. For a sequential,
verbose diagnostic run, use one suite:

```shell
TEST_JOBS=1 VERBOSE=true ./scripts/example/tests/greeting.test.sh
```

`VERBOSE=true` enables tracing and shows output from passing tests. To trace a
captured command itself, pass `bash -x` explicitly to `test-capture`, because
capture suppresses the harness's tracing. Debug output may include command
arguments, so use synthetic test data.

For timing data, set `TEST_PROFILE` to a writable file outside the checkout. The
harness appends each test's start time, end time and name. On interruption, the
harness stops running test process groups, waits up to `TEST_STOP_TIMEOUT`
seconds (default five), then kills remaining processes before teardown.
