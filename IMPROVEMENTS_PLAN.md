# Improvements Plan

This plan tracks a batch of repository-template improvements. Twenty-eight PRs
have merged into `v2` (see the
[toolchain and setup merged record](#merged-record--toolchain-and-setup-stack),
the
[scan-secret and markdown-linting merged record](#merged-record--scan-secret--markdown-linting-stack),
and the
[shell-lint and hygiene merged record](#merged-record--shell-lint-and-hygiene-stack)).
The remaining work is organised into one stack in
[Outstanding work](#outstanding-work--proposed-stack). The stack is an ordered
chain of PRs that share files and build on one another, followed by two PRs that
land last. Every remaining proposal is self-contained and carries the context
needed to raise it.

**Current priority**: land the stack in the
[recommended order](#outstanding-work--proposed-stack), then run the two last
PRs, PR 35 and PR 22. Re-auditing `v2` on 2026-10-24 found that the shared
NUL-safe path collector and array-based callers now cover part of PRs 17 and 19.
Those PRs remain planned: real-tool glob handling and required edge tests are
incomplete, `check-file-format.sh` still invokes the checker for an empty
selection, and `run-test-suites.sh` still passes a newline-separated list. No
outstanding PR meets its full completion criteria, so none is marked merged or
complete. Choices that need a maintainer are listed under
[Decisions needed before implementation](#decisions-needed-before-implementation).
Do not start a PR that waits on an open decision.

---

## PR index — what each PR is about

All 37 PRs plus two optional changes have a one-line summary and current status.
Detailed design notes remain only for planned proposals. Merged PRs are listed
in the [merged records](#merged-record--toolchain-and-setup-stack), and
remaining proposals are grouped in
[Outstanding work](#outstanding-work--proposed-stack). Status uses &#x2705; for
merged, &#x1F50D; for in review, &#x1F7E1; for covered by another PR and
&#x1F4CB; for planned work. D5 marks a planned PR that waits on an open
[decision](#decisions-needed-before-implementation).

| PR         | Change                                          | Status                                    |
| ---------- | ----------------------------------------------- | ----------------------------------------- |
| 1          | ADR template and Tech Radar alignment           | &#x2705; Merged [GitHub #226][pr226]      |
| 2          | Make shell lint a real, fast failing gate       | &#x2705; Merged [GitHub #268][pr268]      |
| 3          | Add and wire the `lint-shell` target            | &#x2705; Merged [GitHub #270][pr270]      |
| 4          | Run shell lint in commit-stage CI               | &#x2705; Merged [GitHub #271][pr271]      |
| 5          | Shell hygiene and clear image-pull failures     | &#x2705; Merged [GitHub #267][pr267]      |
| 6          | Docker test isolation and runtime errors        | &#x1F7E1; Covered by [GitHub #259][pr259] |
| 7          | Markdown checks and check-mode guard            | &#x2705; Merged [GitHub #231][pr231]      |
| 8          | Secret scanning modes and hardening             | &#x2705; Merged [GitHub #230][pr230]      |
| Optional C | Document `FORCE_USE_DOCKER`                     | &#x2705; Merged [GitHub #272][pr272]      |
| Optional D | Run tests within a suite in parallel            | &#x2705; Merged [GitHub #273][pr273]      |
| 9          | Require blank lines after YAML frontmatter      | &#x2705; Merged [GitHub #232][pr232]      |
| 10         | Format Markdown tables with Prettier            | &#x2705; Merged [GitHub #234][pr234]      |
| 11         | Skip deleted Markdown files in link checks      | &#x2705; Merged [GitHub #233][pr233]      |
| 12         | Reduce gitleaks false positives                 | &#x2705; Merged [GitHub #229][pr229]      |
| 13         | Copilot Stop hook for lint and test             | &#x1F4CB; Planned · stack 1 of 8 (base)   |
| 14         | Improve pull-request template guidance          | &#x2705; Merged [GitHub #225][pr225]      |
| 15         | Native and Docker parity inventory              | &#x2705; Merged [GitHub #243][pr243]      |
| 24         | Refresh tools, runtimes, images and actions     | &#x2705; Merged [GitHub #244][pr244]      |
| 16         | Standardise unrecognised check-mode exit codes  | &#x1F4CB; Planned · stack 3 of 8          |
| 17         | Use NUL-safe arrays for Markdown file lists     | &#x1F4CB; Planned · groundwork in `v2`    |
| 18         | Resolve the `check=branch` base dynamically     | &#x1F4CB; Planned · stack 5 of 8          |
| 19         | NUL-safe file lists and script hygiene          | &#x1F4CB; Planned · groundwork in `v2`    |
| 20         | Migrate the toolchain manager from asdf to mise | &#x2705; Merged [GitHub #246][pr246]      |
| 21         | Add the SonarQube Cloud scan job                | &#x2705; Merged [GitHub #242][pr242]      |
| 22         | Keep `main`'s push trigger in the `v2` merge    | &#x1F4CB; Planned · very last, `v2` merge |
| 23         | Fix remaining word splitting and globbing       | &#x1F4CB; Planned · stack 7 of 8          |
| 25         | Migrate from `.tool-versions` to `mise.toml`    | &#x2705; Merged [GitHub #247][pr247]      |
| 26         | Add GNU macOS install and verification targets  | &#x2705; Merged [GitHub #248][pr248]      |
| 27         | Verify Make and the container runtime           | &#x2705; Merged [GitHub #255][pr255]      |
| 28         | Pin the mise CLI version through `mise.toml`    | &#x2705; Merged [GitHub #256][pr256]      |
| 29         | Make GNU PATH setup idempotent                  | &#x2705; Merged [GitHub #257][pr257]      |
| 30         | Pin Dockerfile base images through ARG defaults | &#x2705; Merged [GitHub #258][pr258]      |
| 31         | Add the repository test harness and suites      | &#x2705; Merged [GitHub #259][pr259]      |
| 32         | Select Bash from `PATH` consistently            | &#x2705; Merged [GitHub #260][pr260]      |
| 33         | Scope CI version extraction to TOML tables      | &#x2705; Merged [GitHub #261][pr261]      |
| 34         | Report project setup state from `make config`   | &#x2705; Merged [GitHub #262][pr262]      |
| 35         | Assess tooling security and template defaults   | &#x1F4CB; Planned · very last · D5        |
| 36         | Repository-wide ShellCheck modes                | &#x1F4CB; Planned · stack 6 of 8          |
| 37         | Separate the Docker selector from `cmd`         | &#x1F4CB; Planned · stack 8 of 8          |

[pr225]: https://github.com/nhs-england-tools/repository-template/pull/225
[pr226]: https://github.com/nhs-england-tools/repository-template/pull/226
[pr229]: https://github.com/nhs-england-tools/repository-template/pull/229
[pr230]: https://github.com/nhs-england-tools/repository-template/pull/230
[pr231]: https://github.com/nhs-england-tools/repository-template/pull/231
[pr232]: https://github.com/nhs-england-tools/repository-template/pull/232
[pr233]: https://github.com/nhs-england-tools/repository-template/pull/233
[pr234]: https://github.com/nhs-england-tools/repository-template/pull/234
[pr242]: https://github.com/nhs-england-tools/repository-template/pull/242
[pr243]: https://github.com/nhs-england-tools/repository-template/pull/243
[pr244]: https://github.com/nhs-england-tools/repository-template/pull/244
[pr246]: https://github.com/nhs-england-tools/repository-template/pull/246
[pr247]: https://github.com/nhs-england-tools/repository-template/pull/247
[pr248]: https://github.com/nhs-england-tools/repository-template/pull/248
[pr255]: https://github.com/nhs-england-tools/repository-template/pull/255
[pr256]: https://github.com/nhs-england-tools/repository-template/pull/256
[pr257]: https://github.com/nhs-england-tools/repository-template/pull/257
[pr258]: https://github.com/nhs-england-tools/repository-template/pull/258
[pr259]: https://github.com/nhs-england-tools/repository-template/pull/259
[pr260]: https://github.com/nhs-england-tools/repository-template/pull/260
[pr261]: https://github.com/nhs-england-tools/repository-template/pull/261
[pr262]: https://github.com/nhs-england-tools/repository-template/pull/262
[pr267]: https://github.com/nhs-england-tools/repository-template/pull/267
[pr268]: https://github.com/nhs-england-tools/repository-template/pull/268
[pr270]: https://github.com/nhs-england-tools/repository-template/pull/270
[pr271]: https://github.com/nhs-england-tools/repository-template/pull/271
[pr272]: https://github.com/nhs-england-tools/repository-template/pull/272
[pr273]: https://github.com/nhs-england-tools/repository-template/pull/273

## Notes

- **Group by file, not by scattered concern.** Where several changes touch the
  same script, they are stacked as successive layers rather than raised as
  conflicting parallel PRs. [File ownership](#file-ownership) lists which PRs
  touch each file.
- **Snippets are illustrative.** A snippet in this plan pins a design choice.
  Implement against the current code, not against the snippet. Once a PR merges,
  reduce its section to a pointer to the merged PR.
- **Return the real status.** [SH-FN-007] requires every function to end with an
  explicit `return`. Where the last command's status is the function's result, a
  bare `return 0` hides failures whenever a caller uses the function in an `if`,
  `||` or `&&` context, because Bash suspends `set -e` there. Verified: with
  `set -e`, `f() { false; return 0; }; if f; then …` takes the success branch.
  Use `return 0` only after commands that cannot fail. Otherwise follow
  `scan-secrets.sh`: `local rc=0`, then `tool … || rc=$?`, then `return "$rc"`.
- **Handle awkward file names.** Build every file list with `git ls-files -z` or
  `git diff -z` and read it NUL-delimited, for example with
  `while IFS= read -r -d ''` or `mapfile -d ''`. Without `-z`, Git quotes
  non-ASCII names as `"caf\303\251.md"`, and the existing `[[ -f "$f" ]]` filter
  then drops them silently. Test every list with a space, glob characters
  (`notes[draft].md`), a non-ASCII character (`café.md`) and a leading dash.
- **Shared path-list contract.** Every script that selects file paths keeps its
  own modes, filters and defaults, but follows the same rules. Build the list as
  a Bash array from NUL-delimited Git output, never through command substitution
  or a newline-separated variable. Keep only paths that exist. Propagate Git
  failures. Pass the array as positional arguments, and forward each path as a
  separate argument natively and in Docker. Put tool options before `--` where
  the tool supports it, and otherwise prefix a leading-dash path with `./`.
  Prove with the pinned tool, not only a stub, that a path with glob characters
  is checked literally. Skip the tool, print a message and exit `0` when the
  list is empty. PR 19 applies the contract to `check-file-format.sh` and
  `run-test-suites.sh`, PR 17 to the three Markdown scripts, and PR 36 to
  `check-shell-lint.sh`, whose `check=all` already follows it. It does not apply
  to `scan-secrets.sh`, which passes Git ranges, to the `docker.lib.sh` loops
  over Docker tags, or to `dockerfile-linter.sh`, which takes one file.
- **Bash 5.2 is a given.** [SH-HDR-001] requires it and
  `make toolchain-verify-gnu` checks it, so features such as `mapfile -d ''` and
  associative arrays need no fallback.
- **Messages name the fix.** Every new error says what failed and how to fix it,
  for example the valid check modes or the `git fetch` command for a missing
  base, as [MK-LCL-008] requires.
- **Progress**: twenty-eight PRs are merged into `v2`: PR 1, PR 14, the six
  scan-secret and markdown-linting PRs, PR 21, thirteen toolchain and setup PRs,
  PR 5, PR 2, PR 3, PR 4, Optional C and Optional D. On 2026-10-02 the full test
  suite passed on `v2`, and native ShellCheck 0.11.0 reported no findings across
  the 28 shell scripts tracked then. GitHub stack #269 merged on 2026-10-15.
  Commit `6a236c6` then removed the vendored `scripts/docker/dgoss.sh`, so 27
  shell scripts are tracked on 2026-10-21 and none is vendored. Native
  ShellCheck reported no findings across them on 2026-10-21. Re-run `make test`
  before the first stack PR. PR 6 stays covered by PR 31, so it has no work
  left.

---

## Merged record — toolchain and setup stack

The following 13 PRs merged into `v2` in order, as confirmed by the latest 15
first-parent commits on `v2` on 2026-10-01. The plan numbers preserve the
original improvement sequence, while the GitHub numbers identify the merged PRs.

| Order | PR    | Merged PR     | Summary                                  |
| ----- | ----- | ------------- | ---------------------------------------- |
| 1     | PR 15 | [#243][pr243] | Native and Docker parity inventory       |
| 2     | PR 24 | [#244][pr244] | Pinned tool and workflow version refresh |
| 3     | PR 20 | [#246][pr246] | Migrate the toolchain manager to mise    |
| 4     | PR 25 | [#247][pr247] | Migrate version pins to `mise.toml`      |
| 5     | PR 26 | [#248][pr248] | GNU macOS installation and verification  |
| 6     | PR 27 | [#255][pr255] | Verify Make and the container runtime    |
| 7     | PR 28 | [#256][pr256] | Pin the mise CLI version                 |
| 8     | PR 29 | [#257][pr257] | Idempotent GNU PATH setup                |
| 9     | PR 30 | [#258][pr258] | Pin Dockerfile base image versions       |
| 10    | PR 31 | [#259][pr259] | Repository test harness and suites       |
| 11    | PR 32 | [#260][pr260] | Select Bash from `PATH`                  |
| 12    | PR 33 | [#261][pr261] | Scope CI version parsing to TOML tables  |
| 13    | PR 34 | [#262][pr262] | Report project setup state               |

The stack carries NHSE Engineering's Tech Radar change, which moved `asdf` to
**Contain** and `mise` to **Mainstream**, through setup and CI. The NHSE
Engineering Board approved the migration, so it needed no repository ADR. PR 31
(#259) also delivered PR 6's Docker test isolation and prerequisite handling. Do
not raise duplicate PRs for any of this scope.

## Outstanding work — proposed stack

Branch each PR off the one below it and land the stack from the bottom up. The
2026-10-24 re-audit found shared NUL-safe path collection partially implemented
for PRs 17 and 19. Neither PR meets its full completion criteria; the other six
stack PRs remain unstarted. See each PR section for verified current state and
remaining gaps.

**The stack**, in landing order:

| Position | PR    | Why it sits here                                                                |
| -------- | ----- | ------------------------------------------------------------------------------- |
| 1        | PR 13 | Independent. Landing it first puts the agent gate on every later PR             |
| 2        | PR 19 | NUL-safe selection and function hygiene across all scripts, before narrower PRs |
| 3        | PR 16 | The `126` mode contract, on top of PR 19's rewrite of `check-file-format.sh`    |
| 4        | PR 17 | NUL-safe Markdown lists, in the scripts PR 16 just changed                      |
| 5        | PR 18 | The shared base resolver, which needs PR 17's final file lists                  |
| 6        | PR 36 | ShellCheck modes, using PR 16's contract, PR 17's lists and PR 18's resolver    |
| 7        | PR 23 | `scan-secrets.sh` arguments after PR 18, and a sweep after PR 36 removed a loop |
| 8        | PR 37 | The Docker selector rename, after PR 23 documented `cmd` in `docker.lib.sh`     |

True dependencies, not just shared files, fix most of this order. PR 18 needs PR
17's arrays, PR 36's `branch` mode needs PR 18's resolver, PR 23 needs PR 18's
`scan-secrets.sh` changes, and PR 37 replaces a comment that PR 23 adds. PR 36
lands before PR 23 because the two share no file, and removing the
`docker-shellscript-lint` loop first leaves PR 23's sweep with no exception to
carry. PR 13 is independent of the others. Landing it first means the agent gate
and the commit-time `make test` check the other seven PRs as they are written,
which is also the real-world trial PR 13 needs. PR 36 then inserts its
ShellCheck hook above PR 13's final `make test` hook.

**Last, outside the stack**: PR 35 and then PR 22. PR 35 waits on decision D5
and is an assessment. PR 22 is a checklist for the `v2` to `main` merge, not a
commit on `v2`.

### Decisions needed before implementation

Open decisions block only the PR named. D1, D2 and D4 are decided. D3, the
syntax for an `.editorconfigignore`, was withdrawn on 2026-10-18 because PR 19
keeps exclusions in `editorconfig-checker.json`. Record other outcomes in the
affected PR's section before implementation starts.

- **D1, PR 16: exit status for an unrecognised `check` mode. Decided:** use
  `126` to preserve the existing documented contract in `scan-secrets.sh`. Only
  direct script callers can see the status, because `make` exits `2` for any
  failing recipe.
- **D2, PR 18: how `check=branch` finds the base locally. Decided:** infer it as
  the nearest ancestor branch of `HEAD` from the local commit graph, with
  `BRANCH_NAME` as the explicit override. No per-clone setting. A setting needs
  manual set-up and cannot differ between branches of one clone, while the
  inference resolves stacked bases such as `v2` without configuration. PR 18
  holds the verified design and its known limits.
- **D4, PR 13: active Copilot Stop hook. Decided:** the template ships an active
  hook. VS Code runs tracked hook files in `.github/hooks/` by default in
  trusted workspaces. Hooks are still in Preview, and each blocked stop consumes
  AI credits. PR 13 must make the default experience usable and document how
  adopters can disable the hook.
- **D5, PR 35: whether a commercial supplier such as Chainguard may be part of
  the template's recommended toolchain.** Recommended: only as an optional
  overlay that an adopting team switches on with its own entitlement, never as a
  default, and only for gaps that PR 35 shows the free controls leave open. A
  default would need every adopting team to hold an entitlement and a CI
  credential, and workflows from forks cannot read CI secrets by default. D5
  limits only the Chainguard part of PR 35.

### File ownership

Each file that a planned PR changes, with the PRs in landing order. Test suites
under `scripts/**/tests/` change with the script they test. GitHub stack #269 is
merged into `v2` and already touches many of these files. Build on it rather
than on the plan's older descriptions.

- `.github/hooks/quality-gate.json`, `scripts/hooks/quality-gate.sh` and its
  test suite (all new): PR 13
- Every tracked `*.sh` file: PR 19 for doc comments and explicit returns only,
  after PR 13 and before the PRs below
- `scripts/docker/docker.lib.sh`: PR 23 for comments only, PR 37
- `scripts/docker/tests/docker.test.sh`: PR 23, PR 37
- `scripts/docker/tests/docker-lib.test.sh`: PR 37
- `scripts/tests/test.lib.test.sh`: PR 23
- `docs/guides/Scripting_Docker.md`: PR 37
- `README.md`: PR 13, PR 18
- `docs/guides/Run_quality_gate_on_agent_stop.md` (new) and
  `docs/guides/Run_Git_hooks_on_commit.md`: PR 13
- `scripts/quality/check-file-format.sh`: PR 19, PR 16, PR 18
- `scripts/tests/run-test-suites.sh`: PR 13 for the header note, PR 19
- `scripts/quality/check-markdown-format.sh` and
  `scripts/quality/check-markdown-links.sh`: PR 16, PR 17, PR 18
- `scripts/quality/check-shell-lint.sh` and
  `scripts/quality/tests/check-shell-lint.test.sh`: PR 36
- `scripts/quality/format-markdown.sh`: PR 17
- `scripts/quality/scan-secrets.sh`: PR 16 for the message only, PR 18, PR 23
- `scripts/quality/quality.lib.sh` (new): PR 18, then PR 36 as a consumer
- The existing `.github/actions/check-*/action.yaml` files: PR 18
- `scripts/init.mk`: PR 13 adds the pause targets, PR 36 changes
  `check-shell-lint`
- `scripts/docker/docker.mk`: PR 36 removes `docker-shellscript-lint`, and PR 37
  renames the `_docker` selector. They change different blocks.
- `docs/guides/Bash_and_Make.md`: PR 36
- `scripts/config/pre-commit.yaml`: PR 13 adds the final `make test` hook, PR 36
  inserts the ShellCheck hook above it
- `.github/workflows/cicd-1-pull-request.yaml`, the other conflicting files and
  `.github/CONTRIBUTING.md`: PR 22
- `docs/adr/` (new ADR): PR 35

**Cross-stack notes**:

- Do not duplicate the merged toolchain and setup stack or GitHub stack #269.
- Stack #269 replaced the `find` loop in `scripts/init.mk`. PR 36 removes the
  remaining `find` loop in `docker-shellscript-lint`, and PR 19 removes the
  `$($filter)` splat from `check-file-format.sh`, so PR 23 leaves both alone.
- PR 16 changes only the four existing check-mode scripts. PR 36 brings
  `check-shell-lint.sh` to the same contract.

---

## Merged record — scan-secret + markdown-linting stack

The scan-secret + markdown-linting batch was built as a local stack off `v2`,
reviewed, and has now been merged into `v2` in the order below. Each layer
passed the full pre-commit gate (`scan-secrets`, `check-file-format`,
`check-markdown-format`, `check-markdown-links`) and `make lint` / `make test`.

| Order | PR    | Merged PR                                                                 | Summary                                                         |
| ----- | ----- | ------------------------------------------------------------------------- | --------------------------------------------------------------- |
| 1     | PR 12 | [#229](https://github.com/nhs-england-tools/repository-template/pull/229) | gitleaks allowlist: link-local IPs + lockfiles                  |
| 2     | PR 8  | [#230](https://github.com/nhs-england-tools/repository-template/pull/230) | `scan-secrets.sh` best practices + guard + six check modes      |
| 3     | PR 7  | [#231](https://github.com/nhs-england-tools/repository-template/pull/231) | markdown check scripts: best practices + guard + Docker workdir |
| 4     | PR 9  | [#232](https://github.com/nhs-england-tools/repository-template/pull/232) | enforce blank line after YAML frontmatter                       |
| 5     | PR 11 | [#233](https://github.com/nhs-england-tools/repository-template/pull/233) | skip deleted files in both markdown checks                      |
| 6     | PR 10 | [#234](https://github.com/nhs-england-tools/repository-template/pull/234) | `make format` via prettier + MD060 rule                         |

SonarQube Cloud static analysis (PR 21) was merged separately as
[#242](https://github.com/nhs-england-tools/repository-template/pull/242).

---

## Merged record — shell-lint and hygiene stack

The following six PRs merged into `v2` bottom-up as GitHub stack #269 on
2026-10-15. Their order matches the first-parent commit history.

| Order | PR         | Merged PR     | Summary                                     |
| ----- | ---------- | ------------- | ------------------------------------------- |
| 1     | PR 5       | [#267][pr267] | Shell hygiene and clear image-pull failures |
| 2     | PR 2       | [#268][pr268] | Make shell lint a tracked-file gate         |
| 3     | PR 3       | [#270][pr270] | Add shell lint to `make lint`               |
| 4     | PR 4       | [#271][pr271] | Run shell lint in commit-stage CI           |
| 5     | Optional C | [#272][pr272] | Document `FORCE_USE_DOCKER` workflows       |
| 6     | Optional D | [#273][pr273] | Run tests within a suite in parallel        |

Do not raise duplicate PRs for this scope.

---

## PR 13: Copilot agent hook to run `make lint` and `make test`

**Status**: Planned · stack position 1 of 8, the base.
[D4](#decisions-needed-before-implementation) approves an active hook in the
template. **Scope**: Developer experience, automated quality gates for AI agents
and Git commits **Risk**: Medium. Hooks are a Preview feature, run code
automatically in trusted workspaces and can consume AI credits. Running the full
test suite on every commit also adds commit latency and needs a running Docker
daemon. **Depends on**: nothing. It lands first so that the agent gate checks
every later PR in the stack while it is written. **Files**:

| File                                                  | Purpose                                                                        |
| ----------------------------------------------------- | ------------------------------------------------------------------------------ |
| `.github/hooks/quality-gate.json` (new)               | Registers the `UserPromptSubmit` and `Stop` events, both calling one script    |
| `scripts/hooks/quality-gate.sh` (new)                 | Records the turn's baseline, runs the gate on `Stop`, and pauses or resumes it |
| `scripts/hooks/tests/quality-gate.test.sh`            | Test suite, found by `make test` because it lives under `scripts/`             |
| `scripts/init.mk`                                     | Adds `quality-gate-pause` and `quality-gate-resume` beside `githooks-config`   |
| `scripts/config/pre-commit.yaml`                      | Adds the final `make test` hook                                                |
| `scripts/tests/run-test-suites.sh`                    | Removes the stale header note that `scripts/hooks` is git-ignored              |
| `docs/guides/Run_quality_gate_on_agent_stop.md` (new) | Guide for the agent gate, named like `Run_Git_hooks_on_commit.md`              |
| `docs/guides/Run_Git_hooks_on_commit.md`              | Documents the new `make test` pre-commit hook and its Docker prerequisite      |
| `README.md`                                           | Links the new guide from the guides list                                       |

One script, dispatched on the payload's `hook_event_name`, keeps the baseline,
gate and pause logic in one place and needs no shared library. Its name says
what it is, a quality gate, and matches the JSON file that registers it.

**Current state**, rechecked on 2026-10-24: no tracked quality-gate hook
configuration or implementation is present in `v2`. Loadout-managed or
git-ignored hook files in a developer's working tree do not count as template
implementation. `scripts/config/pre-commit.yaml` has the four quality hooks and
no `make test` hook. The header of `scripts/tests/run-test-suites.sh` still says
`scripts/hooks` is git-ignored.

**Goal**: when an agent turn has changed files, run `make lint` and then
`make test` before the agent stops. If either fails, block completion once and
give the agent the failure output. Turns that change nothing skip the gates.
Separately, run `make test` as the final Git pre-commit hook, after all quality
checks, so commits from both agent and non-agent workflows run the full suite.
The Git hook and Stop hook are independent, so an agent commit may run the suite
at both points. Neither gate replaces CI.

**Verified hook contract**, from the
[VS Code Local hooks reference](https://code.visualstudio.com/docs/agents/reference/hooks-reference)
on 2026-10-21:

- VS Code discovers workspace hooks in `.github/hooks/*.json`. The file holds a
  `hooks` object keyed by PascalCase event name, and each entry has
  `type: "command"`, `command` and an optional `timeout` in seconds, which
  defaults to 30. `chat.useHooks` turns all Local hooks on or off, and is on by
  default. Workspace hook files are subject to Workspace Trust.
- Every payload carries `hook_event_name`, `timestamp`, an optional `session_id`
  and an optional `cwd`. There is no turn identifier. `UserPromptSubmit` also
  carries `prompt`, the user's text. `Stop` also carries `stop_hook_active`,
  which is `true` when an earlier `Stop` hook already blocked.
- `Stop` blocks with exit status `0` and
  `{"hookSpecificOutput":{"hookEventName":"Stop","decision":"block","reason":"…"}}`,
  where `reason` is required. Any event can return `systemMessage`, a warning
  shown to the user without changing the decision. Exit status `2` blocks with
  stderr, and any other non-zero status shows a non-blocking warning.
- Each blocked stop starts further agent turns, which consume AI credits.
- `jq` is pinned in `mise.toml`.

**Requirements**:

- [ ] `quality-gate.json` registers `UserPromptSubmit` with a 10 second timeout
      and `Stop` with a 120 second timeout, both running
      `./scripts/hooks/quality-gate.sh`. A hook that times out does not block.
      Measure cold native and Docker runs, and raise the Stop budget or narrow
      the checks if they cannot reliably finish within it.
- [ ] The script reads stdin once with `jq` and extracts only `hook_event_name`,
      `session_id` and `stop_hook_active`. It never stores the payload in a
      shell variable, file or log, so the `prompt` text cannot leak, including
      through `VERBOSE=true` tracing.
- [ ] On `UserPromptSubmit`, record the turn's baseline: a SHA-256 fingerprint
      of `git rev-parse HEAD`, `git diff --binary HEAD` and the contents of
      every non-ignored untracked file, listed with
      `git ls-files -z --others --exclude-standard`. Store only the fingerprint
      under `$(git rev-parse --git-path quality-gate)/<session_id>`, creating
      the directory when it is missing. That directory is per worktree, never
      tracked and outside the working tree, so it cannot change the fingerprint.
      Delete baselines older than 7 days. Each prompt overwrites its session's
      baseline, which gives a per-turn baseline without a turn identifier.
- [ ] On `Stop`, print `{}` and exit `0` when `stop_hook_active` is `true`, so
      the gate blocks at most once per stop. Skip the gates when the session's
      baseline exists and the current fingerprint matches it. When `session_id`
      is missing, or the baseline is missing, unreadable or cannot be computed,
      run the gates and say in the output why the no-edit guard was unavailable.
- [ ] Run `make lint` then `make test` from the repository root, without
      modifying files or the Git index. Capture output in a temporary file that
      a trap deletes. On failure, block with a `reason` that names the command
      and exit status, ends with its last 60 lines and gives the rerun command.
      Classify the Docker suite's existing
      `ERROR Docker test suite cannot run: …` line as a prerequisite failure and
      give the fix, start Docker and rerun `make test`, rather than suggesting
      code changes.
- [ ] Pause the gate with `make quality-gate-pause`, which accepts `hours=` from
      1 to 8 with a default of 1, and resume it with `make quality-gate-resume`.
      Store the expiry time in the same `.git` state directory. While paused,
      `Stop` exits `0` with a `systemMessage` that names the expiry time and the
      resume command. An expired pause is deleted and the gate runs. The pause
      changes nothing else: not `make lint`, `make test`, CI or other hooks.
- [ ] Add a local hook with `entry: make test` as the final hook in
      `scripts/config/pre-commit.yaml`, after every quality hook. Use
      `language: system`, `pass_filenames: false` and `always_run: true`, so it
      runs once on every commit without receiving staged paths as arguments.
      Later PRs that add quality hooks, such as PR 36, insert them above it.
- [ ] Write `docs/guides/Run_quality_gate_on_agent_stop.md`: what the gate runs
      and when it skips, the once-per-stop re-entry guard, the latency and
      AI-credit cost, how to pause and resume it, how to turn off all hooks with
      `chat.useHooks`, how to confirm that exactly one Stop gate is active when
      user-level hooks in `~/.copilot/hooks` also exist, and that CI still
      enforces the same checks. Add the `make test` hook and its Docker
      prerequisite to `docs/guides/Run_Git_hooks_on_commit.md`. Link the new
      guide from the README guides list without repeating its content.
- [ ] Update the `run-test-suites.sh` header so it no longer says
      `scripts/hooks` is git-ignored.

**Tests**, in `scripts/hooks/tests/quality-gate.test.sh` with `make` stubbed:

- [ ] the re-entry guard prints `{}`, and a matching baseline skips the gates
- [ ] an edit to a tracked file, a staged change, a new commit and a change to
      the contents of an untracked file with an unchanged name each run the
      gates
- [ ] a missing `session_id` or missing baseline runs the gates and says why
- [ ] two sessions in one clone keep separate baselines
- [ ] a failing `make lint` blocks with valid Stop JSON whose `reason` holds the
      command, status and excerpt, and `make test` does not run
- [ ] the Docker prerequisite line is reported as a prerequisite failure
- [ ] a `prompt` value never appears in the state directory or in output,
      including with `VERBOSE=true`
- [ ] pause, expiry, resume and an out-of-range `hours=` value
- [ ] `pre-commit.yaml` places `make test` last with `always_run: true` and
      `pass_filenames: false`

Before shipping to adopters, smoke-test the active default, pause, resume and a
blocked stop in a real VS Code session.

**Edge cases**:

- **Broad lint selection until PR 18 lands**: the `lint-*` targets use
  `check=branch` against `origin/main`, so on a `v2` branch they select every
  file changed since `main`. `v2` passes `check=all` in CI, so this costs time
  but causes no false failures.
- **Offline developer**: `make lint` includes the Markdown link check, which
  needs the network. The excerpt shows lychee's network error. A blocked stop
  may pass on re-entry, but that does not mean lint passed.
- **Large or unreadable files**: when the fingerprint fails, run the gates
  instead of treating an incomplete fingerprint as proof that nothing changed.
- **Other agent harnesses**: Copilot CLI, Claude and Codex use their own hook
  formats and payloads. Claude-format hooks need `chat.useClaudeHooks`. The
  guide states that this gate is tested only in the VS Code Local harness.
- **Untrusted workspace, or hooks disabled by policy**: the hook does not run.
  CI still enforces the same gates.

**Verification**:

- After a lint-breaking edit, the hook blocks once with the lint output. After
  the fix, the agent runs both gates explicitly before claiming they pass.
- A question that edits nothing skips the gates.
- With Docker stopped, the failure names the prerequisite and the rerun command.
- `echo '{"hook_event_name":"Stop","stop_hook_active":true}' | ./scripts/hooks/quality-gate.sh`
  prints `{}`.
- A commit with a failing test is blocked by the pre-commit hook.

---

## PR 16: Harmonise the unrecognised check-mode exit status

**Status**: Planned · stack position 3 of 8. **Scope**: Shell script consistency
and usability **Risk**: Low. A direct caller that mistypes a mode sees a
different exit status. **Depends on**: PR 19 **Files**:
`scripts/quality/check-file-format.sh`,
`scripts/quality/check-markdown-format.sh`,
`scripts/quality/check-markdown-links.sh`, `scripts/quality/scan-secrets.sh`,
and their four matching test suites. These are the four existing quality scripts
in scope for this PR. PR 36 adds `check=` support to ShellCheck separately.

**Problem**: the scripts disagree. `scan-secrets.sh` returns `126` for an
unrecognised public `check=` value and documents it. The other three scripts
return `1`, which a direct caller cannot distinguish from a real finding. None
of the four public error messages lists the accepted modes, so a developer who
mistypes a value has to open the script to find them.

**Decision and behaviour**:

- Use `126` for an unrecognised check mode in all four scripts.
  `scan-secrets.sh` already documents and returns this status. Although shells
  commonly use `126` for "found but not executable", the diagnostic must make
  the actual cause explicit.
- This status is useful to direct script callers. Pre-commit and CI invoke the
  scripts through `make`, which returns `2` for any failed recipe and does not
  preserve the script's specific status.
- Do not change the ordinary finding/tool-failure status as part of this PR.

**Change**:

- [ ] In the public `check=` dispatch of all four scripts, write the
      unrecognised-mode diagnostic to stderr and return `126`. Ensure direct
      execution of each script propagates `main`'s status.
- [ ] Include the complete, ordered list of accepted public modes in each
      diagnostic. The three format/link checks accept
      `all, staged-changes, working-tree-changes, branch`. `scan-secrets.sh`
      accepts
      `all, staged-changes, working-tree-changes, branch, whole-history, last-commit`.
- [ ] Keep the defensive `get-cmd-to-run` guard in `scan-secrets.sh` at `126`.
      Its valid internal single-scan modes are
      `staged-changes, working-tree-changes, branch, whole-history, last-commit`;
      do not include the public aggregate mode `all` in that helper's
      expected-mode list.
- [ ] Add `126 - Unrecognised check mode` to the three headers that do not
      already document it. Keep the `scan-secrets.sh` exit-code documentation
      unchanged.
- [ ] Update the four `*-rejects-unknown-mode` tests to assert status `126`, the
      complete stderr diagnostic, and that no checker or Docker command runs for
      an invalid public mode.

**Edge cases**:

- **Unset or empty `check=`**: both select the documented default mode through
  `${check:-…}`. Preserve this behaviour and test an explicitly empty value.
- **Case and whitespace**: mode names remain case-sensitive and are not trimmed.
  For example, `check=ALL` and `check=' all'` are unrecognised and return `126`
  with the relevant accepted-mode list.
- **Valid mode lists differ**: do not copy the four-mode list into
  `scan-secrets.sh`, or its six-mode list into the other scripts. The public
  `all` mode in `scan-secrets.sh` remains an aggregate of its three local-change
  scans.
- **`check-shell-lint.sh` is out of scope**: PR 36 owns its repository-wide
  check modes and exit-status handling. Do not expand PR 16 to include it.

**Verification**: for each of the four scripts, invoke with `check=bogus` and
confirm exit `126`, the complete script-specific mode list on stderr, and no
checker invocation. Confirm `check=` still selects that script's default,
`check=ALL` is rejected, and a real finding still returns `1`. Run the four
matching test suites and `make test`.

---

## PR 17: Use NUL-safe arrays for Markdown file lists

**Status**: Planned · stack position 4 of 8 **Scope**: Shell script correctness
**Risk**: Medium. It fixes a silent false pass, so results change for affected
file names. **Depends on**: PR 16 **Files**:
`scripts/quality/check-markdown-format.sh`,
`scripts/quality/check-markdown-links.sh`, `scripts/quality/format-markdown.sh`
and the matching test suites

This PR applies the [shared path-list contract](#notes) to the three Markdown
scripts. In current `v2`, `git-files.lib.sh` and the Markdown callers already
use NUL-delimited Git output and Bash arrays, but the full PR is not complete.
`run-test-suites.sh` remains newline-based under PR 19.

**Current findings**: the old newline-separated Markdown file list and `SC2206`
splitting are gone. The shared collector preserves NUL-delimited paths, filters
deleted files and de-duplicates the branch-mode union. Existing tests cover some
newline and glob names with stubbed tools. The remaining gaps are:

- **Non-ASCII paths lack Markdown-specific tests.** The shared collector uses
  `-z`, but the Markdown fixtures do not cover a `café.md` path.
- **Glob handling is unproven with real tools.** Stubbed calls show argument
  boundaries, not whether the pinned markdownlint-cli, lychee or Prettier treats
  `notes[draft].md` as one literal file beside `notesd.md`.
- **The branch union lacks an overlap test.** The collector de-duplicates in
  first-seen order, but no test proves deterministic ordering when both diffs
  contain the same path.
- **The branch base is still the current base ref, not its fork point.** PR 18
  owns that separate selection change.

**Change**:

- [x] For every mode, build a Bash array from the corresponding NUL-delimited
      Git output (`git ls-files -z` or `git diff -z --name-only`). Preserve the
      current selection semantics, apply the existing-file filter to the final
      list in every mode, and propagate Git command failures. Do not move the
      NUL-delimited output through command substitution or a newline-separated
      environment variable. Git failures propagate. The shared collector and
      Markdown callers in `v2` implement this requirement.
- [x] Preserve the branch mode's unique, deterministic union of both diff
      results with NUL-safe processing. Do not reintroduce newline-based sort or
      de-duplication. The collector de-duplicates in first-seen order.
- [ ] Pass arrays to runner functions as positional arguments, then forward each
      path as a separate argument in native and Docker mode. Put all tool
      options before `--` and paths after it when the tool supports the
      end-of-options marker. For a tool without that marker, prefix a
      leading-dash path with `./`. This prefix does not escape glob characters.
- [ ] For each pinned CLI that expands glob patterns, ensure a path containing
      glob metacharacters is treated as the literal existing file. Use that
      tool's documented literal-path handling or escaping. Verify the effective
      file selection with the pinned tool, not only with a stub that records
      arguments. Confirm `--` support separately because it stops option parsing
      but does not disable glob expansion.
- [x] Pass the list to the frontmatter check as arguments,
      `python3 - "${files[@]}"`, read through `sys.argv[1:]`, instead of the
      newline-joined `files` variable. The current format checker does this.
- [x] Replace string emptiness checks with `(( ${#files[@]} > 0 ))`, so an empty
      selection does not invoke a tool. Current Markdown check/format wrappers
      skip their tools when the array is empty.
- [x] Remove the SC2206 disables from the three Markdown scripts.

**Edge cases**, each covered by a test:

- **Awkward names**: non-ASCII, spaces, a newline, glob characters
  (`notes[draft].md` beside `notesd.md`) and a leading dash are each selected
  and processed as exactly one literal file.
- **Empty selection**, for example `check=working-tree-changes` with no changes:
  no tool runs, and the exit status is `0`.
- **Tracked file deleted in the working tree**, including a staged modification
  followed by an unstaged deletion: skipped in every mode.
- **Renamed file**: checked once under its new name, never under the old name.
- **Overlapping branch diffs**: a path present in both diffs is passed once, in
  deterministic order.
- **Docker mode**: the container receives the same ordered, separate path
  arguments as native mode, including names with spaces, newlines and leading
  dashes.

**Tests**: in the `check-markdown-format` and `check-markdown-links` suites,
cover `all`, `staged-changes`, `working-tree-changes` and `branch`. In the table
formatter suite, cover the tracked-file selection. For every applicable mode,
verify awkward names natively and in Docker mode. Assert argument boundaries and
order in the stubs, and use the pinned CLI to prove a bracket-containing
filename and a newline-containing filename are each processed literally. Also
cover empty selection, the staged-then- deleted file, a rename, an overlapping
branch result, and a failing Git list command.

**Verification**: `make lint` and `make test` pass natively and with
`FORCE_USE_DOCKER=true`. Repeat the `café.md` reproduction: `check=all` now
reports both errors.

---

## PR 18: Resolve the `check=branch` base dynamically

**Status**: Planned · stack position 5 of 8.
[D2](#decisions-needed-before-implementation) is decided. Supersedes the removed
Optional A. **Scope**: Shell script correctness and developer experience
**Risk**: Medium. It changes which files `make lint` selects. **Depends on**: PR
17 **Files**: `scripts/quality/quality.lib.sh` (new),
`scripts/quality/tests/quality-lib.test.sh` (new),
`scripts/quality/check-file-format.sh`,
`scripts/quality/check-markdown-format.sh`,
`scripts/quality/check-markdown-links.sh`, `scripts/quality/scan-secrets.sh`,
the three existing `.github/actions/check-*/action.yaml` files, `README.md` and
the matching test suites

**Problem**: `check=branch`, which `lint-file-format`, `lint-markdown-format`
and `lint-markdown-links` use, compares with `${BRANCH_NAME:-origin/main}`. The
`branch` mode of `scan-secrets.sh` uses the same default.

1. **Hardcoded base.** A branch that targets anything other than `origin/main`,
   such as `master`, `develop` or a stacked base like `v2`, is compared with the
   wrong ref. On the `v2` stack, `lint-file-format` selected about 53 files
   instead of the 8 the branch changed. That is slow, and it fails on issues the
   branch did not introduce.
2. **Diff against the base tip.** `git diff <base>` also reports files that
   changed on the base after the branch forked.
3. **Misleading name.** `BRANCH_NAME` names the base to compare with, not the
   branch being checked. The branch being checked is always `HEAD`.

**Why the base can be inferred locally**: Git stores no "created from" name for
a branch, and `origin/HEAD` names only the remote's default branch. The commit
graph still identifies the parent. It is the branch whose merge base with `HEAD`
is closest to `HEAD`, so it leaves the fewest commits in `<merge base>..HEAD`.
Verified on this repository on 2026-10-18:

| Candidate                     | Merge base | Commits in `<merge-base>..HEAD` |
| ----------------------------- | ---------- | ------------------------------- |
| `v2` and `origin/v2`          | `6d9322b`  | 8                               |
| `main` and the other branches | `e0f7568`  | 52                              |

Only the merge base, called the fork point below, affects the result. Refs that
tie on the same fork point, such as `v2` and `origin/v2`, or two branches cut
from the same `v2` tip, select exactly the same files and commits. The tie-break
only chooses which name to print.

A plain nearest-ancestor rule fails in one verified case, a stacked child. When
`pr17` is cut from `pr16` and `pr16` then gets a review fix, `pr17` is nearer to
`pr16` than `v2` is. Choosing it would select too few files. The resolver
therefore excludes any candidate that forked from a commit this branch created,
as recorded in the branch's own reflog.

Optional A forced `lint-markdown-links` to `check=all` because branch selection
was unreliable. Once selection is correct, branch-scoped link checks are
consistent with the other `lint-*` targets, and pre-commit and CI still run
`check=all`.

**Decision, D2**: resolve the base in this order. The first match wins.

1. `BRANCH_NAME`, the explicit override. It accepts any ref.
2. `origin/$GITHUB_BASE_REF`, which GitHub Actions sets on pull request events.
3. The nearest ancestor branch, inferred locally as described below.
4. The remote default branch, from `git symbolic-ref refs/remotes/origin/HEAD`.
5. `origin/main`, today's default.

There is no per-clone setting. `BRANCH_NAME` covers the rare case where the
inference is wrong, and the printed base makes that case visible.

**Change**:

- [ ] Add `scripts/quality/quality.lib.sh`, sourced by all four scripts so they
      resolve the base identically. Follow the shell instructions: kebab-case
      names, a doc comment per function and explicit returns that carry the real
      status, as in [Notes](#notes). It provides three functions:
  - `resolve-base-ref` applies the order above. It prints the chosen ref on
    stdout and one line on stderr naming the ref, its source and the fork point,
    for example
    `Comparing with v2 (nearest ancestor branch, fork 6d9322b, 8 commits)`.
  - `find-nearest-ancestor-branch` implements step 3 as specified in the next
    item. It prints nothing when it finds no candidate, so resolution falls
    through to step 4.
  - `get-fork-point` prints `git merge-base "$base" HEAD`. When no merge base
    exists, it fails with the shallow-clone message below.
- [ ] Implement `find-nearest-ancestor-branch` in these steps. A prototype of
      each step was verified on this repository and in scratch repositories.
  1. Read the current branch with `git symbolic-ref --quiet --short HEAD`. On a
     detached `HEAD` there is no branch reflog, so print nothing.
  2. Read the default ref with
     `git symbolic-ref --quiet --short refs/remotes/origin/HEAD`, or use
     `origin/main` when that fails. When the current branch is the default
     branch itself, for example `main`, print the default ref. A long-lived
     default branch then compares with its remote copy and selects only unpushed
     work.
  3. Build the branch's own-commit set from
     `git reflog show --format='%H%x09%gs' "refs/heads/<branch>"`. Keep every
     entry except those that moved the branch onto another named ref:
     `branch: Created from <ref>`, `reset: moving to <ref>` and
     `merge <ref>: Fast-forward`, where `<ref>` is a name such as `v2` or `HEAD`
     rather than a commit hash. Those tips belong to the other branch. This
     exclusion is required. This branch's reflog contains `reset: moving to v2`,
     and counting that tip as its own wrongly excluded `v2` (verified). Also
     collect the refs named in those entries for the tie-break.
  4. List candidates with
     `git for-each-ref --format='%(refname:short)' --no-contains HEAD`
     `refs/heads refs/remotes` plus the same command with `--points-at HEAD`, so
     a branch with no commits yet still finds its parent. Exclude the current
     branch, its upstream from `git rev-parse --abbrev-ref '@{upstream}'` and
     symbolic refs such as `origin/HEAD`. Ref names cannot contain newlines, so
     one name per line is safe.
  5. For each candidate, compute `git merge-base HEAD "$ref"`. Skip the
     candidate when there is no merge base, which means unrelated history, or
     when the merge base is in the own-commit set, which means a child of this
     branch. Otherwise score it with `git rev-list --count "$fork..HEAD"`.
  6. Choose the lowest score. Break ties in this order: a ref named in the
     branch's reflog, then the default branch, then a local branch before a
     remote-tracking branch, then the ref name in byte order using
     `LC_ALL=C sort`.
  7. Use only POSIX `awk` features, because macOS ships the system `awk`. Pass
     every ref as a separate quoted argument.
- [ ] Resolve a short `BRANCH_NAME` or `GITHUB_BASE_REF` value such as `v2` to
      `origin/v2` when it exists and to the local `v2` otherwise, so offline
      work still resolves. Inferred candidates are existing refs and need no
      resolution.
- [ ] In branch mode, select files with
      `git diff --diff-filter=ACMRT -z --name-only "$fork_point"`, adding each
      script's existing pathspec, such as `"*.md"`. This single diff covers
      committed, staged and unstaged changes since the fork point and ignores
      later changes on the base. It replaces the two-diff union in the Markdown
      scripts. Keep PR 17's NUL-safe arrays and existing-file filter.
- [ ] In `scan-secrets.sh`, keep the commit range `<base>..HEAD` and use the
      resolved base.
- [ ] Remove the unused `export BRANCH_NAME=origin/<default branch>` lines from
      the three composite actions. Those actions run `check=all`, which ignores
      the variable. If a future CI step used `check=branch`, the export would
      override `GITHUB_BASE_REF` and select the wrong base.
- [ ] In each script header, describe `BRANCH_NAME` as the base ref to compare
      with, which overrides the inferred parent branch. In the README's "Common
      workflows" section, explain the resolution order, the printed
      `Comparing with` line and when to set `BRANCH_NAME`.

**Edge cases**, each covered by a test:

- **Branch moved onto its base with a reset**, as this branch was: resolves to
  `v2`.
- **New branch with no commits**: resolves to its parent with zero commits. The
  selection is empty, so nothing is checked, a message says so and the exit
  status is `0`.
- **Stacked child that still contains `HEAD`**: excluded by `--no-contains`.
- **Stacked child after the parent gets a review fix**: excluded by the
  own-commit set.
- **Long-lived branch with stacked children**, such as `v2`: its children are
  excluded, so it resolves to `main`.
- **On the default branch**: resolves to the remote default branch.
- **Siblings cut from the same tip**: they tie on one fork point and select the
  same files. The tie-break prints the reflog-named or default branch.
- **Branch rebased onto a newer base**, or with the base merged into it: the
  fork point moves forward, so only the branch's own changes are selected.
- **Detached `HEAD`**: inference is skipped. In CI, `GITHUB_BASE_REF` applies.
- **Explicit base missing or not fetched**: fail with the ref name and the fix,
  for example `git fetch origin v2`. Never fall back to a whole-repository scan.
- **`origin/HEAD` not set**, which is common after `git remote add`: fall
  through to `origin/main`. If that is missing too, fail and suggest
  `git remote set-head origin --auto` or `BRANCH_NAME`.
- **No `origin` remote**, for example in a fresh copy of the template: local
  branches can still be inferred. If nothing resolves, fail with a message that
  names `BRANCH_NAME`.
- **Shallow clone without a merge base**: fail and suggest
  `git fetch --unshallow`. CI already checks out with `fetch-depth: 0`.
- **`BRANCH_NAME` exported by an unrelated tool**: it still wins, as today. The
  printed source makes this visible.
- **Many refs**: one merge base and one count per candidate. All 34 refs in this
  clone took 0.17 seconds, so no caching is needed.

**Known limits**, documented in the README and pinned by tests rather than
hidden:

- **No local reflog history for the branch's commits.** This happens after a
  fresh clone, a `gh stack checkout`, reflog expiry by `git gc` (90 days by
  default) or with `core.logAllRefUpdates=false`. The child guard cannot see
  commits made elsewhere. A fetched child that forked before later parent
  commits can then win and select too few files. The printed base shows the
  wrong name, and `BRANCH_NAME` corrects it. Pre-commit and CI still run
  `check=all`, so nothing escapes the gates.
- **Squash-merged parent.** The branch keeps the parent's original commits until
  it is rebased, so the fork point is older and extra files are selected.
  GitHub's own pull request diff behaves the same way.

**Tests**: add `scripts/quality/tests/quality-lib.test.sh` for the resolver,
using scratch repositories, the real `git` and a fake `origin`.

- [ ] each resolution layer wins over the layers below it
- [ ] every edge case and known limit above produces its documented result
- [ ] changes made on the base after the fork are not selected
- [ ] the printed line names the ref, the source and the fork point
- [ ] every failure case prints its message and exits non-zero
- [ ] in each of the four script suites, `check=branch` uses the resolved fork
      point and `BRANCH_NAME` still overrides it

**Verification**: on this branch, `make lint-file-format` prints
`Comparing with v2 (nearest ancestor branch, …)` and selects only the branch's
files without any configuration. On `v2` it compares with `main`, and on `main`
it compares with `origin/main`. `make test` passes.

---

## PR 19: Make file-format and test-suite selection NUL-safe and apply function hygiene

**Status**: Planned · stack position 2 of 8. No open decision blocks it.
**Scope**: Shell script correctness and consistency **Risk**: Low to medium.
File selection changes for awkward names, and the hygiene commits touch
functions in every tracked shell script without changing their behaviour.
**Depends on**: PR 13, only for stack order. PR 13's new script is written to
the hygiene rules, so the sweep should find nothing in it. **Files**:
`scripts/quality/check-file-format.sh`, `scripts/tests/run-test-suites.sh` and
their test suites for the selection changes. Every tracked `*.sh` file for the
hygiene commits.

**Current findings**:

- `check-file-format.sh` now collects paths through `quality-collect-git-files`
  into a NUL-safe array and passes separate arguments to `editorconfig-checker`
  in native and Docker modes. This removes the old `$filter` command string and
  `sh -c` splitting.
- An empty selection still passes `/dev/null` to the checker instead of skipping
  it with a clear message. Its test still asserts the `/dev/null` call.
- The awkward-name tests use stubs and cover newline and glob paths, but do not
  test non-ASCII, spaces or leading dashes with the pinned checker. Literal glob
  handling by the real tool remains unverified.
- Exclusions live in the `Exclude` regular expressions in
  `scripts/config/editorconfig-checker.json`, which is empty today. JSON cannot
  hold comments, and nothing tells a developer where the list is or that its
  entries are regular expressions. The list stays in JSON. A separate ignore
  file is not needed.
- `run-test-suites.sh` finds suites with `find`, filters them one per line
  through `git check-ignore` and passes them on as a newline-separated `suites`
  variable. A suite path that contains a newline is split. No other PR in this
  plan covers this script.
- An audit of `v2` on 2026-10-18 found `main` and `is-arg-true` without a doc
  comment, as [SH-DOC-001] requires, in 18 scripts. These are
  `check-file-format.sh`, `run-test-suites.sh`, `stub.sh` (`main` only),
  `install-gnu-macos.sh`, `verify-gnu.sh` and all 13 `*.test.sh` suites.
  `test.lib.test.sh` also has an undocumented helper, `t`.
- The same audit, by heuristic, found functions that do not end with an explicit
  `return`, as [SH-FN-007] requires: `main` and both runners in
  `check-file-format.sh`, `check-frontmatter-blank-line` in
  `check-markdown-format.sh`, the four `check-*` functions in `verify-gnu.sh`,
  `t`, `test-suite-teardown` and three `test-harness-*` cases in
  `test.lib.test.sh`, and `test-suite-setup` in `verify-gnu.test.sh`. Stack #269
  already fixed `check-shell-lint.sh`, `dockerfile-linter.sh` and
  `docker.lib.sh`.

**Change**, selection:

- [x] Build the selection on the host as a NUL-safe Bash array for each mode,
      from `git ls-files -z` or `git diff -z --diff-filter=ACMRT --name-only`,
      and keep only paths that exist. Do not move the list through command
      substitution or an environment variable. Propagate Git failures instead of
      running the old `$filter > /dev/null` pre-run. This selection requirement
      is implemented in `v2` for `check-file-format.sh`.
- [ ] Pass the array to the runners as positional arguments and call
      `editorconfig-checker` with each path as a separate argument natively and
      in Docker, without `sh -c`. The direct command and array are now used, but
      `--workdir /check` is not explicit and literal path handling is
      unverified.
- [ ] Verify with the pinned `editorconfig-checker` whether it accepts `--` to
      end options. Use it if so, otherwise prefix a leading-dash path with `./`.
      Also verify that a path with glob characters, such as `notes[draft].txt`
      beside `notesd.txt`, is checked literally.
- [ ] When the selection is empty, do not call `editorconfig-checker`. Print
      `No files to check` and exit `0`. This replaces the `/dev/null` argument.
- [ ] Keep `Exclude` in `editorconfig-checker.json` as the only exclusion list.
      In the script header, say where it is, that entries are regular
      expressions matched against paths relative to the repository root, and
      that a literal `.` needs escaping and a pattern should be anchored, for
      example `^docs/generated/`. Confirm the regex dialect and matched path
      form with the pinned `editorconfig-checker`. Also document empty
      selection.
- [ ] Add `local` declarations to the functions in `check-file-format.sh`.
- [ ] In `run-test-suites.sh`, list suites with
      `git ls-files -z --cached --others --exclude-standard -- "$dir/*.test.sh"`,
      which selects the same tracked and non-ignored untracked files as today's
      `find` and `git check-ignore`. Unset Git's pathspec-mode variables, as
      `check-shell-lint.sh` does. Keep only paths that exist, keep the
      byte-order sort with `LC_ALL=C sort -z`, and pass the list to
      `run-test-suites` as an array instead of the `suites` variable. On a Git
      failure, stop with a message that names `$dir`.

**Change**, hygiene, as two separate commits so reviewers can tell comment-only
changes from code changes:

- [ ] Add an [SH-DOC-001] doc comment to every function that lacks one in every
      tracked `*.sh` file, starting with the `main` and `is-arg-true` gaps
      listed above. `test-*` cases are exempt because their names describe them,
      as [SH-TST-011] requires.
- [ ] End every function in the same files with an explicit `return`, following
      the rule in [Notes](#notes). Where the last command's status is the
      function's result, capture and return it instead of `return 0`. The
      standard `is-arg-true` from [SH-VAR-006] already returns on both branches
      and stays as it is. Re-run the audit after the change, because the list
      above comes from a heuristic.

**Edge cases**, each covered by a test:

- **Empty selection**, including with `dry_run=true`: the checker is not called,
  the message is printed and the exit status is `0`.
- **Tracked file deleted in the working tree**: skipped in every mode.
- **Renamed file**: checked once under its new name.
- **Awkward names**: non-ASCII, spaces, a newline, glob characters and a leading
  dash are each checked as exactly one literal file, natively and in Docker
  mode.
- **Missing base branch**: Git's error is shown, the checker is not called and
  the exit status is non-zero.
- **Behaviour after the hygiene commits**: a function whose status a caller
  tests in `if`, `||` or `&&` still returns its real status.

**Tests**:

- [ ] Replace `test-check-file-format-native-with-no-changes-checks-nothing`,
      which asserts the `/dev/null` call, with a test proving the checker is
      skipped for an empty selection.
- [ ] Update both Docker tests to assert direct `editorconfig-checker` arguments
      and `--workdir /check`.
- [ ] Add `test-check-file-format-checks-awkward-file-names` for native and
      Docker mode, and a test for a file deleted in the working tree.
- [ ] In `run-test-suites.test.sh`, cover suite names with a space and a
      non-ASCII character, an untracked suite that is included, an ignored suite
      that is excluded, the sort order and a missing directory.
- [ ] Keep `test-check-file-format-rejects-unknown-mode` at status `1`. PR 16
      changes it to `126`.
- [ ] `Exclude` is applied inside the checker, so stubs cannot prove it. Verify
      it with the pinned `editorconfig-checker` below.
- [ ] All existing suites pass unchanged after each hygiene commit.

**Out of scope**: a dedicated ignore file such as `.editorconfigignore`, and
removing the duplicated `is-arg-true` copies.

**Verification**:

- `make check-file-format check=all` and `make lint` pass natively and with
  `FORCE_USE_DOCKER=true`.
- With the pinned `editorconfig-checker`, a tracked `café.txt` with trailing
  whitespace fails `check=all`, and a temporary `Exclude` entry such as
  `^docs/generated/` skips the matching path in both modes.
- ShellCheck reports no findings and `make test` passes after each commit.

---

## PR 22: Keep `main`'s push trigger when `v2` merges into `main`

**Scope**: CI trigger correctness **Risk**: Low, but timing-sensitive **Depends
on**: every other PR in this plan that is going into the same release **Files**:
`.github/workflows/cicd-1-pull-request.yaml` and the other conflicting files,
during the merge only, plus `.github/CONTRIBUTING.md`

**Problem**: on `v2`, the pull request workflow triggers on `push` to every
branch (`"**"`) and on `pull_request`. A commit pushed to a branch with an open
PR fires both events, so every stage runs twice, including two SonarQube Cloud
analyses of identical code. `main` fixed this on 2026-04-21 in `c861edf` (#210)
by narrowing `push` to `main`. `v2` forked earlier, at `e0f7568`.

`v2` must keep `"**"` until the merge. Narrowing it earlier would stop
push-triggered CI on `v2` itself while the remaining PRs merge into it.

**Review finding**: a separate commit on `v2` is not needed. `git merge-tree`
shows that merging `v2` into `main` already resolves the trigger block to
`branches: [main]`, because only `main` changed those lines. The same file does
conflict elsewhere, as do seven other files. A resolution that takes `v2`'s side
of the whole file would silently restore `"**"`.

**Tasks**, during the `v2` to `main` merge:

- [ ] List the conflicts with
      `git merge-tree --write-tree --name-only origin/main v2`. On 2026-10-02
      they were `.github/dependabot.yaml`, the three `cicd-*.yaml` workflows and
      the four `stage-*.yaml` workflows. Resolve each conflict hunk by hunk.
      Never take one side of a whole workflow file.
- [ ] Check that the resolved trigger block is exactly `push` on
      `branches: [main]` and `pull_request` with
      `types: [opened, reopened, synchronize]`.
- [ ] If the conflicts are resolved by merging `main` into `v2`, make that the
      last change on `v2`. From then on `v2` receives no push-triggered runs,
      which is acceptable because the open `v2` to `main` PR still runs CI.
- [ ] Add one sentence to `.github/CONTRIBUTING.md`: a branch gets CI only once
      a pull request is open, so open a draft PR to see results early. `main`
      has behaved this way since April 2026.

**Verification**:

- Before the merge, a commit to a branch with an open PR against `v2` starts two
  runs.
- After the merge, a commit to a PR branch starts one run, triggered by
  `pull_request`, and a merge to `main` starts one run, triggered by `push`.
- The merged trigger block matches the one on `main` before the merge.

---

## PR 23: Fix remaining word splitting and globbing

**Status**: Planned · stack position 7 of 8 **Scope**: Shell script correctness
**Risk**: Medium. The change rebuilds the command that the pre-commit secret
scan runs, so a regression blocks every commit. Argument-level tests for every
check mode, natively and in Docker, contain that risk. **Depends on**: PR 18,
which also changes `scan-secrets.sh`. PR 36 lands first and removes the
`docker-shellscript-lint` loop, so the sweep below has no exception to carry.
**Files**: `scripts/quality/scan-secrets.sh`,
`scripts/quality/tests/scan-secrets.test.sh`, comments in
`scripts/docker/docker.lib.sh`, `scripts/docker/tests/docker.test.sh` and
`scripts/tests/test.lib.test.sh`

**Problem**: after stack #269, PRs 16 to 19 and PR 36, three items remain from
the repository-wide audit.

1. **Native secret scanning fails when the clone path contains a space
   (verified).** `get-cmd-to-run` builds the gitleaks command as one string, and
   `run-gitleaks-natively` expands it unquoted (`gitleaks $cmd`, under
   `# shellcheck disable=SC2086`). From a clone in `dir with space/repo`,
   `check=last-commit` failed with
   `unable to load gitleaks config … /dir: no such file or directory`. The
   unquoted expansion also applies pathname expansion, so glob characters in the
   path are unsafe too. The pre-commit hook and `make scan-secrets` therefore
   fail for any developer whose path contains a space, which is common on macOS
   and Windows. Docker mode works, because it mounts the repository at
   `/workdir`.
2. **Two test helpers still split command output without a reason.**
   `remove-test-images` in `docker.test.sh` runs `docker rmi $tags` under
   `# shellcheck disable=SC2086`, and `test.lib.test.sh` loops with
   `for pid in $(cat "$OUT/pids")`. Image references and process IDs contain no
   whitespace, but both break the sweep's rule.
3. **Intentional splitting is undocumented**, so each new review raises it
   again.

**Change**:

- [ ] Build the gitleaks arguments as an array and run `gitleaks "${args[@]}"`
      and `docker run … "$image" "${args[@]}"`. Remove both SC2086 disables.
      Keep the six modes, their exit codes, the aggregated `check=all` status
      and the native `GIT_CONFIG_*` isolation unchanged.
- [ ] Return the array through a Bash 5.2 nameref (`local -n`) that the caller
      declares, so the defensive `126` guard that PR 16 keeps in
      `get-cmd-to-run` still fails the check. Do not use
      `mapfile -d '' args < <(get-cmd-to-run)`, because a process substitution
      discards the function's exit status. Rename the function if its role
      changes, and update the doc comments from PR 19 that describe
      `cmd=[command to run]`.
- [ ] Fix the two test helpers with arrays. Read the tags with `mapfile -t` and
      run `docker rmi "${tags[@]}"`, then read the process IDs the same way.
      Remove the SC2086 disable.
- [ ] Add a one-line comment above each remaining disable or loop that splits on
      purpose:
  - `docker-run` and `docker-check-test` split `${args:-}` and `${cmd:-}` on
    purpose. Callers pass several options in one variable, for example
    `args="-p 8080:80" make docker-run`, and arrays cannot cross that
    environment-variable interface. Describe `cmd` as an interface for direct
    function callers only. PR 37 fixes the Make route and updates the comment.
  - The `docker-check-test` disable also covers SC2154, because `check` comes
    from the environment. Give that its own reason.
  - The `for version in $(_get-all-effective-versions) latest` loops expand
    Docker tags, whose grammar allows neither whitespace nor glob characters.
    These loops carry no disable, so the comment goes above each loop.
- [ ] Repeat the audit sweep for `SC2086`, `SC2206` and `SC2046` disables and
      for `for … in $(` across every tracked `.sh`, `.mk` and `Makefile`. Every
      remaining instance must be fixed or carry a reason.

**Tests**: build every expected value with `printf '%q'`. The stub records each
argument with `printf '%q '`, so a path passed as one argument appears as
`dir\ with\ space`, while a split path appears as separate words. Use one
fixture path with a space, a glob character and a non-ASCII character, for
example `dir with space [x] café/repo`. An absolute clone path cannot start with
a dash.

- [ ] extend `test-scan-secrets-builds-the-command-for-each-mode` to run from
      the awkward path natively, so every check mode is covered without a
      near-copy of the test
- [ ] the same path with the optional baseline and ignore files present
- [ ] the same path with `FORCE_USE_DOCKER=true`, which pins the Docker argument
      array and the quoted `--volume "$PWD:$dir"`
- [ ] in `branch` mode, the resolved `<base>..HEAD` range reaches gitleaks as
      one `--log-opts` argument. PR 18's suites already test that `BRANCH_NAME`
      overrides the inferred base.
- [ ] the existing `check=all` and git-config isolation tests pass unchanged

Use only valid Docker tags in any test. Tags cannot contain spaces.

**Out of scope**:

- Any change to the `args` environment-variable interface of the Docker helpers.
- **`cmd` cannot reach `docker-run` through Make (verified).** `make docker-run`
  calls `$(MAKE) _docker cmd="run"`, and Make exports command-line variables to
  recipes. The function therefore always sees `cmd=run`, appends `run` to the
  container command and ignores a caller's `cmd`. PR 37 fixes this.
- Quoting of Make-level expansions in recipes, such as
  `$(realpath $(or ${dir}, …))` in `_docker`. ShellCheck cannot see them, and
  the sweep's patterns do not match them.

**Verification**:

- Clone into an awkward path with
  `git clone --quiet . "/tmp/dir with space [x] café/repo"`, then run
  `check=last-commit ./scripts/quality/scan-secrets.sh` there with native
  gitleaks. Before the fix it fails with `unable to load gitleaks config …`.
  After it, the scan completes.
- In that clone, after `make githooks-config`, a commit passes the secret-scan
  hook.
- `make scan-secrets check=all` passes natively and with
  `FORCE_USE_DOCKER=true`.
- ShellCheck reports no findings and `make test` passes. Commands, output and
  exit codes are otherwise unchanged for existing users.

---

## PR 36: Make ShellCheck repository-wide and check-mode aware

**Status**: Planned · stack position 6 of 8 **Scope**: Shell lint coverage and
developer experience **Risk**: Medium. Direct invocation changes its default
from `check=file`, which lints the wrapper itself, to `check=all`. `check=all`
widens from tracked files to tracked and non-ignored untracked files. The
refactor must not make the full check noticeably slower than the current
`check=all`. **Depends on**: PR 18, whose `quality.lib.sh` resolver the new
`branch` mode uses. It also follows PR 16's `126` contract and the
[shared path-list contract](#notes) that PR 17 finished applying. **Files**:
`scripts/quality/check-shell-lint.sh`,
`scripts/quality/tests/check-shell-lint.test.sh`, `scripts/init.mk`,
`scripts/docker/docker.mk`, `scripts/config/pre-commit.yaml`,
`.github/actions/check-shell-lint/action.yaml`,
`.github/workflows/stage-1-commit.yaml`, and `docs/guides/Bash_and_Make.md`

**Problem**: on `v2`, stack #269 left `check-shell-lint.sh` with two modes.
`check=file`, the default, lints one `file=` path and falls back to linting
itself. `check=all` lints every tracked existing `*.sh` file in one call,
selected NUL-safely with `git ls-files -z`. `make check-shell-lint` runs it once
with `check=all`, and `make lint`, the composite action and the
`stage-1-commit.yaml` job already use it. Four gaps remain:

1. **No scoped modes.** There is no `staged-changes`, `working-tree-changes` or
   `branch` mode, unlike the other quality checks, and an unrecognised mode
   returns `1`.
2. **Untracked scripts are skipped.** A new script is not linted until it is
   staged.
3. **Duplicate Docker loop.** `docker-shellscript-lint` in `docker.mk` still
   loops over `$(find scripts/docker …)`, which splits unusual paths and repeats
   part of `check=all`.
4. **No pre-commit hook.** `scripts/config/pre-commit.yaml` runs the other four
   quality checks but not ShellCheck.

**Decision and behaviour**:

- The wrapper accepts the same modes as the other repository checks: `all`,
  `staged-changes`, `working-tree-changes`, and `branch`.
- `all` is the default, including when `check=` is explicitly empty. It lints
  every tracked and non-ignored untracked `*.sh` file anywhere in the
  repository, without exclusions by directory or purpose. This includes new
  scripts before they are staged, tests, the agent hook script and Docker
  helpers. Git-ignored build and dependency output is not repository source and
  remains excluded. This widens `v2`'s tracked-only `check=all`, so update the
  header notes that say untracked scripts are not linted.
- The scoped modes select only shell scripts from their corresponding Git change
  sets. `branch` sources `scripts/quality/quality.lib.sh` and selects from PR
  18's fork point, exactly as the other four checks do.
- Invalid modes return `126` and list the four accepted modes, following PR 16.
- Remove the `file=` interface. A one-file diagnostic is not a repository
  quality-check mode. Developers can invoke ShellCheck directly when they need
  to investigate one file. Today only `docker-shellscript-lint` and the
  wrapper's own tests pass `file=`, and both change in this PR. Afterwards
  `check=file` is an unrecognised mode and returns `126`.
- `make check-shell-lint` invokes the wrapper once, defaults to `check=all`, and
  forwards an explicit `check` Make variable, for example
  `make check-shell-lint check=staged-changes`.
- Remove `docker-shellscript-lint`. Docker scripts are already covered by
  `check=all`; a second target would only repeat part of the repository check.
- Add ShellCheck to the shared quality-check sequence: `scan-secrets` →
  `check-file-format` → `check-markdown-format` → `check-markdown-links` →
  `check-shell-lint`. The workflow job already follows the existing checks. Keep
  the workflow's existing parallel job execution; do not add `needs`
  dependencies solely to serialize these independent checks.
- Keep the composite action at `.github/actions/check-shell-lint/action.yaml`
  and the `check-shell-lint` job in `stage-1-commit.yaml`, which PR 4 added.
  Confirm the action still runs `make check-shell-lint check=all` with the
  pinned ShellCheck from mise.
- Add a `check-shell-lint` hook to `scripts/config/pre-commit.yaml` after the
  Markdown hooks and above PR 13's final `make test` hook. Use
  `pass_filenames: false` and run `make check-shell-lint check=all`, consistent
  with the existing whole-repo quality hooks.
- Preserve native-versus-Docker selection, `FORCE_USE_DOCKER`, `VERBOSE`, and
  the current lint-result reporting and failure policy. This PR changes file
  selection, not whether ShellCheck findings fail the Make target.
- Use one deterministic path order for every mode and preserve that order when
  invoking ShellCheck natively or in Docker, so diagnostics do not reorder
  between execution environments.

**Change**:

- [ ] Build each mode's shell-script file list from Git and pass it to
      ShellCheck as an array. Use NUL-delimited Git output so spaces, glob
      characters, non-ASCII names and leading dashes are preserved. Ensure an
      empty file list succeeds without invoking ShellCheck with no paths. End
      ShellCheck options before passing paths, so a leading-dash filename is
      treated as a path rather than an option.
- [ ] Use Git's NUL-delimited tracked and non-ignored untracked path list for
      `all`, for example
      `git ls-files --cached --others --exclude-standard -z -- '*.sh'`. Do not
      use `find`, because it also discovers Git-ignored build and dependency
      output.
- [ ] Set the wrapper and Make target default to `all`. Forward a caller's
      `check` value from Make without changing the wrapper's native/Docker
      fallback or reporting policy.
- [ ] Remove `file=` and update all callers and usage documentation. Remove the
      Docker-only lint target rather than replacing it with another loop. The
      target is inside a marked "DO NOT edit" block; state why its removal is
      intentional in the PR description and leave the rest of that block
      unchanged.
- [ ] Document `126 - Unrecognised check mode` in the wrapper header.

**Tests**:

- [ ] Replace single-file/default-to-self tests with tests that prove the
      default and explicit empty mode lint all tracked and non-ignored untracked
      shell scripts, including scripts in different directories. Also verify
      Git-ignored generated files are excluded.
- [ ] Cover staged, working-tree and branch selection, filtering out non-shell
      files, and the missing-base-branch diagnostic.
- [ ] Cover file names with spaces, glob characters, non-ASCII characters and
      leading dashes, plus an empty selected file set.
- [ ] Verify native and forced-Docker execution each receive multiple selected
      paths without splitting or glob expansion.
- [ ] Assert all modes produce the same deterministic path ordering in native
      and Docker execution.
- [ ] Record an apples-to-apples performance baseline for the current
      `check=all` and the refactored `check=all`, using the same tracked and
      non-ignored untracked shell-script paths, ShellCheck version, host and
      warm tool/image caches. Measure native and forced-Docker runs separately,
      exclude tool installation and image-pull time, and compare the median of
      five timed runs after one warm-up. The refactored full check's median must
      be no more than 10% slower in either mode, which allows for timing noise.
      If it is slower, find and fix the cause before merging. Report timings and
      file count in the PR.
- [ ] Assert an invalid mode returns `126`, lists all accepted modes, and does
      not invoke ShellCheck or Docker. Keep the direct ShellCheck failure test.
- [ ] Verify `make check-shell-lint` invokes the wrapper once with `check=all`,
      accepts an explicit mode, and `docker-shellscript-lint` is no longer
      defined.
- [ ] Verify the existing composite action and workflow job install/use
      ShellCheck and invoke `check=all`; verify the pre-commit hook invokes the
      same target and mode with `pass_filenames: false`.
- [ ] Verify the check order remains `scan-secrets` → `check-file-format` →
      `check-markdown-format` → `check-markdown-links` → `check-shell-lint` in
      both the pre-commit hook list and workflow job declaration, with existing
      workflow parallelism unchanged, and that `make test` stays the last
      pre-commit hook.

**Verification**: the focused ShellCheck test suite passes.
`make check-shell-lint` covers all tracked and non-ignored untracked repository
shell scripts once. The existing reporting/failure policy is unchanged, and
`make test` passes.

---

## PR 37: Separate the Docker target selector from the container command

**Status**: Planned · stack position 8 of 8, the top **Scope**: Docker module
correctness and developer experience **Risk**: Low to medium. `_docker` is a
private target, but adopters may call `$(MAKE) _docker cmd=…` from their own
targets in the editable part of `docker.mk`. Those calls must change with this
PR. **Depends on**: PR 23, which adds the comment on `docker-run`'s `cmd` that
this PR replaces. PR 36 also edits `docker.mk`, in a different block. **Files**:
`scripts/docker/docker.mk`, `scripts/docker/docker.lib.sh`,
`scripts/docker/tests/docker-lib.test.sh`, `scripts/docker/tests/docker.test.sh`
and `docs/guides/Scripting_Docker.md`

**Problem**: `cmd` has two meanings in the Docker module.

1. In `docker.mk`, `cmd` selects the function. `make docker-run` runs
   `$(MAKE) _docker cmd="run"`, and `_docker` then calls `docker-${cmd}`.
2. In `docker.lib.sh`, `docker-run` reads `cmd` again as the container command,
   in `docker run … "${tag}" ${cmd:-}`.

GNU Make exports command-line variables to recipes, so `docker-run` always sees
`cmd=run` (verified). Docker treats `run` as the container command and replaces
the image's `CMD`. For an image without an `ENTRYPOINT`, the container fails
with `exec: "run": executable file not found in $PATH` and exit status `127`
(verified). The walkthrough in `docs/guides/Scripting_Docker.md` uses
`CMD ["python", "main.py"]`, so it cannot print the `hello world` it documents.
Passing `make docker-run cmd="…"` does not help, because the inner `cmd="run"`
overrides it. The tests miss this because they all call the shell functions
directly, and none goes through `make docker-run`.

**Decision**: rename the selector, not the container command. `_docker` takes
`docker_fn`, for example `$(MAKE) _docker docker_fn="run"`, which matches the
existing `docker_dir` and `docker_image` names. `cmd` and `args` keep their
meaning as the container command and the `docker run` options, so direct
function callers and the existing tests do not change. Renaming `cmd` in
`docker.lib.sh` instead would break every direct caller of `docker-run` and
`docker-check-test`.

**Change**:

- [ ] Rename the selector in `_docker` from `cmd` to `docker_fn` and update
      every `$(MAKE) _docker …` call in `docker.mk`. When `docker_fn` is empty,
      fail with a message that names it and gives an example.
- [ ] Add `cmd=[command to run in the container]` and
      `args=[docker run options]` to the `docker-run` help text, so `make help`
      shows how to pass them.
- [ ] Update the `_docker` help text and the `docker-run` and
      `docker-check-test` doc comments. Replace PR 23's "direct function callers
      only" note on `cmd`, because `cmd` now works through Make too.
- [ ] In `docs/guides/Scripting_Docker.md`, keep the `hello world` example and
      add an override such as
      `DOCKER_IMAGE=my-shiny-app make docker-run cmd="python --version"`. Add a
      short note for adopters: custom targets that call `$(MAKE) _docker cmd=…`
      must switch to `docker_fn=`.

**Tests**:

- [ ] drive `make docker-run` with `docker` stubbed and assert that the recorded
      call ends with the image tag when `cmd` is unset. No existing test goes
      through Make, so this test fails on `v2` with a trailing `run`.
- [ ] the same call with `cmd="python --version"` and `args="--env A=1"` records
      both in place
- [ ] `make docker-bake-dockerfile`, `make docker-push` and `make clean` still
      reach their functions, with `docker` stubbed
- [ ] `_docker` with an empty `docker_fn` fails and names the variable
- [ ] in `docker.test.sh`, with real Docker,
      `make docker-run cmd="python --version"` prints the version that
      `test-docker-run-executes-the-command` expects

**Out of scope**:

- How `docker-run` and `docker-check-test` split `args` and `cmd`, which PR 23
  documents.
- Quoting of Make-level expansions in `_docker`, such as
  `$(realpath $(or ${dir}, …))`.
- `docker-check-test`, which has no Make target and is unaffected.

**Verification**:

- On `v2`, `make docker-run` for an image without an `ENTRYPOINT` fails with
  `exec: "run": executable file not found in $PATH`. After the change it runs
  the image's `CMD`.
- The `Scripting_Docker.md` walkthrough prints `hello world`.
- `make test` passes, and `make docker-test-suite-run` passes with Docker
  available.

---

## PR 35: Assess third-party tooling, installation approaches and template defaults

**Status**: Planned · very last, outside the stack · waits on D5. No ADR draft
exists in the repository. **Scope**: Assessment and recommendation **Risk**: Low
(documentation and planning). Spikes run outside the repository. **Depends on**:
nothing. Use the current `v2` toolchain as the baseline.
[D5](#decisions-needed-before-implementation) limits the Chainguard option.
**Files**: a new ADR in `docs/adr/`, written from the repository's ADR template
with the status Proposed

**Context**: reviewers raised two concerns: tools installed by scripts fetched
from external URLs, and the maintenance burden of a growing toolset. The merged
toolchain work pinned every tool and image, but pinning does not show whether
each tool is needed, how it is obtained or who keeps it current. The checks in
`scripts/quality` were also challenged on 2026-10-03.

Most of the attack surface is what the tools depend on. The wrappers run each
tool natively or in a container, so a compromised release or dependency runs
with a developer's or a CI runner's access. The ADR must say what each check is
worth, which control reduces which risk and what it costs developers.

**Value of the checks**

_Maintainer position_ (experience, not yet measured):

- Linters keep the codebase consistent and readable. LLMs work on language, so a
  consistent codebase is easier for an agent to read and extend, and the checks
  give it fast, deterministic feedback.
- Later changes carry no noise from line endings, whitespace, table alignment or
  editor settings, so humans and agents review smaller diffs.
- Per-team checks have two costs. Each team chooses, installs and pins its own
  tools with no shared integrity controls, which can widen the attack surface.
  Each team also spends effort on tooling instead of business value. Central
  ownership lets the controls in this PR be applied and reviewed once.

| Check                   | Benefit       | Basis                     |
| ----------------------- | ------------- | ------------------------- |
| `scan-secrets`          | High          | GitGuardian data          |
| `check-shell-lint`      | Medium        | ShellCheck docs; CI gate  |
| `check-markdown-links`  | Medium        | Judgement                 |
| `check-markdown-format` | Low to medium | Maintainer experience     |
| `check-file-format`     | Low to medium | Maintainer experience     |
| `format-markdown`       | Low           | Cosmetic; table alignment |

- **Secrets** (GitGuardian 2025): 23.8 million new hardcoded secrets reached
  public GitHub in 2024, up 25%. 70% of secrets leaked in 2022 were still valid.
  35% of scanned private repositories held a plaintext secret. 58% of leaks were
  generic credentials, which push protection struggles to detect. A local scan
  stops a secret before it enters history.
- **Shell lint**: the ShellCheck README catalogues defects such as an unquoted
  `rm -rf "$VAR/"*`, masked exit codes in `export VAR=$(cmd)` and assignments
  lost in subshells. The 27 tracked shell scripts passed on 2026-10-21, as the
  28 did on 2026-10-02. `make lint` and the commit-stage CI job now run the
  check and fail on findings. It is not in pre-commit, so a regression surfaces
  only at `make lint` or in CI.
- **Format, links and tables**: no defect data. Their value is consistency and
  smaller diffs, not security.

_AI agents_: no study tests repo-level lint enforcement against agent outcomes.
Adjacent studies, retrieved 2026-10-03:

- **Deterministic feedback helps.** SWE-agent (arXiv 2405.15793) resolved 18.0%
  of SWE-bench Lite with edit-time linting and 15.0% without, above the 17.3% to
  18.7% range of six repeat runs. 51.7% of runs had a rejected edit, and the
  chance of recovery fell from 90.5% to 57.2% after one. The linter checked only
  syntax and undefined names. Blyth et al. (2508.14419) cut GPT-4o's security
  issues from over 40% to 13% and readability violations from over 80% to 11% in
  ten rounds of Bandit and Pylint feedback, on one model and small snippets
  scored by the same tools. Unguided LLM "improvement" rounds raised critical
  vulnerabilities 37.6% after five rounds (Shukla et al., 2506.11022).
- **Structure helps weaker models.** Borg et al. (2601.02200) found five medium
  LLMs broke behaviour 15% to 30% less often on healthy code across 5,000 Python
  files. Sonnet 4.5 and Claude Code showed no significant difference. The metric
  measures structural smells, not formatting. The files are
  competitive-programming code and the authors work for the metric's vendor.
- **Formatting does not.** Removing indentation, whitespace and newlines changed
  Pass@1 by at most 4.2%, not significantly, across ten LLMs on completion tasks
  and cut input tokens about 25% (Pan et al., 2508.13666). The format checks
  cannot be justified as helping LLM comprehension.
- **Context.** Context files do not generally raise agent success and add over
  20% cost, but agents follow their instructions (Gloaguen et al., 2602.11988).
  Enforcing conventions in lint configuration may therefore beat prose in
  AGENTS.md, which is an inference. Unmerged agent PRs were larger and more
  often failed CI, an association only (Ehsani et al., 2601.15195).

_Challenges_:

- **"GitHub secret scanning covers it."** Push protection misses generic
  credentials, and a local scan acts before history.
- **"Editors and CI already lint."** Editor settings differ per developer, which
  is the source of the noise. Shared configuration run by the same wrappers
  locally, in hooks and in CI gives every developer and agent one result.
- **"Format checks have no security value."** Agreed. Keep them cheap and make
  them the first candidates for an optional tier.

There is no defect-catch history for this repository, and the ADR must not cite
the number of commits that mention these tools as evidence. Preliminary view:
keep secret scanning as a non-negotiable default, keep shell lint as a CI gate
and keep the format checks as a lighter tier.

**Current state**, verified on `v2` on 2026-10-03, with the shell-lint and
pre-commit facts refreshed on 2026-10-20 and the Dependabot and `dgoss.sh` facts
on 2026-10-21:

- mise is installed with `curl https://mise.run | sh`, as the README documents
  and as `make config` suggests when mise is missing.
- mise installs the 11 tools pinned in `[tools]`, including the `node` and
  `python` runtimes. Node runs markdownlint-cli and Prettier. Python runs
  pre-commit and the frontmatter check.
- `make format` fetches Prettier with `npx --yes prettier@3`, a floating major
  version that no file pins.
- Seven Docker fallback images are pinned by version tag and digest in
  `[_.docker]`. GitHub Actions are pinned by commit SHA. Commit `6a236c6`
  removed the vendored `dgoss.sh` in favour of Testcontainers guidance.
  `make toolchain-install-gnu-macos` installs GNU tools and Bash through
  Homebrew.
- Dependabot covers `docker`, `github-actions`, `npm` and `pip`. It does not
  update `mise.toml`, so tool and image pins are refreshed by hand, as PR 24
  did. Since commit `6a236c6`, `.github/dependabot.yaml` sets a 7-day `cooldown`
  for every ecosystem.
- All seven image wrappers run
  `docker run --rm --platform linux/amd64 --volume "$PWD…"` with no `--network`,
  `--read-only`, `--cap-drop`, user or read-only mount. A compromised image can
  read untracked files such as `.env`, change tracked files and reach the
  network. Native tools run with the developer's full privileges.
- `mise.lock` is committed in `v2` with lockfile format version 2, and the
  toolchain enables locking, provenance checks and a seven-day minimum release
  age. The lock records npm/PyPI dependency graphs where the mise backend
  supports them. This closes the earlier missing-lockfile gap; it does not
  replace review of new tool releases or install-time behavior.
- All four hooks in `scripts/config/pre-commit.yaml` are `repo: local` and call
  `make`.
- To confirm: compiled binaries with built-in dependencies (gitleaks, lychee,
  hadolint, shellcheck, editorconfig-checker, `jq`, `yq`) risk the release
  artifact. Tools that resolve a graph at install or run time (markdownlint-cli
  and Prettier from npm, pre-commit from PyPI) risk the whole graph.

**Options**, from vendor documentation and the Docker Hub API on 2026-10-03.
"Not verified" marks a gap the assessment must close.

- **A. MegaLinter as the quality layer.**
  - The default flavour has 133 linters and a compressed `linux/amd64` image of
    about 4.7 GB, including tools we never use such as Trivy, Semgrep and
    Checkov. `ci_light` has 23 linters at about 0.7 GB, `documentation` has 52
    at about 1.5 GB, and custom flavours are possible. The sizes are for
    `latest`, which Docker Hub shows as last pushed on 2026-02-28, so re-measure
    a pinned release.
  - Its secret scanners are betterleaks, trufflehog, kingfisher and secretlint.
    I did not find gitleaks, so a switch changes `gitleaks.toml`, the ignore
    file format and the baseline.
  - It moves the dependency risk to one publisher and ties tool versions to its
    releases. It replaces the seven wrappers and their tests and removes the
    native fast path. A custom flavour means publishing our own image, with the
    costs of B and C.
  - Not verified: which flavour holds all six tools, and whether versions can be
    pinned independently.
  - View: low feasibility as a default. Keep it as the comparison baseline.
- **B. Own the sources.** The ADR must say which meaning is intended.
  - **B1, mirror approved artifacts.** Copy releases and images into an
    organisation registry and promote them after a cooldown and a scan. mise
    supports this through `url_replacements`, `aqua.registries` and
    `self_update.repository`. The cost is a promotion pipeline per tool, run by
    the organisation and not by this template.
  - **B2, build from cloned source.** The Wolfi lychee 0.24.2 package carries
    about 16 manual crate bumps for advisories and asks for 18 CPUs and 13 GiB
    to build. The Wolfi gitleaks 8.30.1 package pins a commit and bumps four Go
    modules. Building ourselves takes over that work for 11 tools, including the
    Haskell tools hadolint and shellcheck. View: low feasibility.
  - **Scanning.** Static analysis of third-party source can flag install
    scripts, obfuscation and network calls, but it is weak against a small
    malicious change by a trusted maintainer. The cooldown is stronger. uv has
    `[tool.uv.audit] malware-check`, which uses OSV and is off by default.
- **C. Chainguard containers and libraries.**
  - **Containers.** Shellcheck and hadolint images exist. The hadolint image
    runs as UID 65532, so mounted files must be readable by that user. Flag
    compatibility with the upstream images is not verified. `node` and `python`
    are in the free starter set as `latest` only. The shellcheck and hadolint
    pages offer only a trial, which means an entitlement. The free tier allows
    five images, and the pricing and image pages disagree on whether older
    versions are included. Catalogue licensing starts at $19K for a team of 10.
  - **Libraries.** Python, JavaScript and Java libraries are rebuilt from
    verified source with signed SBOMs and provenance and scanned for malware.
    The upstream fallback serves unbuilt packages after a configurable 7-day
    cooldown. Pricing is a quote per ecosystem and developer count. Access needs
    an entitlement and a pull token (30-day default life, 365-day maximum).
    There is no uptime SLA, and Chainguard advises proxying through our own
    artifact manager. The pricing page says CVE backports are currently Python
    only. Confirm whether that covers our Python tool.
  - **Fit.** Libraries help only markdownlint-cli, Prettier and pre-commit, and
    nothing for the compiled binaries. Wolfi has gitleaks 8.30.1 and lychee
    0.24.2, the versions we pin. Image pages for gitleaks, lychee,
    editorconfig-checker and markdownlint returned 404 under the names I tried,
    so check with `chainctl images list` and an `apk` search.
  - **Template impact.** The wrappers hardcode upstream image names, for example
    `name=koalaman/shellcheck`, so a different registry needs an override in a
    follow-up PR. Traps from the earlier trial: `uv sync` keeps a same-version
    PyPI wheel without `--reinstall`, and `chainctl libraries update-hashes`
    exits non-zero when any package is withheld even though it migrated the
    rest.
  - View: strong supply-chain properties for the npm and PyPI part, but a paid
    dependency for every adopter. Shortlist as an opt-in overlay under D5.
- **D. Lower-cost controls with no new supplier.**
  - **mise lockfile.** `lockfile = true` and `mise install --locked` record
    checksums, URLs and provenance (SLSA, cosign, minisign or GitHub
    attestations) where a backend supports them. Version 2 lockfiles also record
    the full npm and PyPI dependency graphs, which closes the transitive gap.
    URL checks need entries for every platform that installs tools, so set
    `lockfile_platforms`.
  - **Cooldown at bump time.** mise's `minimum_release_age` defaults to 24 hours
    but filters only fuzzy requests. Exact pins and lockfile selections are not
    filtered, and only the `npm:` and `pypi:` backends forward the cutoff to
    transitive dependencies. Our pins are exact, so the cooldown belongs in the
    bump tool. Dependabot supports `cooldown` for `docker`, `github-actions`,
    `npm` and `pip`, not for security updates, and cannot update `mise.toml`.
    Renovate has a `mise` manager, `mise.lock` maintenance and
    `minimumReleaseAge`. The `[_.docker]` table would probably need a custom
    manager, which is not verified. npm has `min-release-age` and
    `min-release-age-exclude`. uv has `exclude-newer` and
    `exclude-newer-package`.
  - **Container hardening.** Add `--network none` to every wrapper except
    lychee, plus `--read-only`, `--cap-drop ALL`,
    `--security-opt no-new-privileges` and `:ro` mounts for checkers that do not
    write. Prettier needs write access. Test the non-root user mapping on Linux
    and the Podman fallback.
  - **Native sandbox.** mise has `sandbox.deny_net`, `deny_write` and
    `deny_read` for `mise run` and `mise exec`. Assess their maturity.
  - View: high feasibility and low developer cost. Spike it first, then decide
    how much of the other options is still justified.
- **E. Shrink the dependency graph with single-binary tools.**
  - **rumdl** is a Rust binary with no runtime dependencies. It has 88 rules,
    finds markdownlint configuration files, has `fmt` and `--fix` and a
    Prettier-compatible preset, ships a Docker image and has a mise registry
    entry. It is Beta, and Firefox and Docker Docs use it.
  - **prek** is a Rust replacement for pre-commit that reads the same
    configuration and needs no Python runtime. It verifies checksums of
    toolchain downloads, has `prek update --cooldown-days` and detects impostor
    commits. It is pre-1.0 (0.5.4), and CPython and Airflow use it. All four of
    our hooks are `repo: local`, so migration should be small.
  - **hk** is the mise author's hook manager. It uses Pkl configuration and
    integrates with mise. It has no stated security features.
  - **Effect.** Node exists to run markdownlint-cli and Prettier. If rumdl
    replaces both, the npm graph leaves the quality path. If prek replaces
    pre-commit, the PyPI graph leaves it too, apart from the frontmatter check.
  - Not verified: whether rumdl covers our `markdownlint.yaml` rules and the
    MD060 table alignment, how its output differs from Prettier's, whether the
    frontmatter check could use `yq`, and the bus factor of both projects.
  - View: high payoff if the spike passes. Needs a decision on adopting pre-1.0
    tools.
- **F. Native package-manager controls for the npm and PyPI part.**
  - **pnpm** has `minimumReleaseAge` (1440 minutes by default since v11),
    `trustPolicy: no-downgrade`, which fails when trust evidence falls, and
    `blockExoticSubdeps`, which is on by default. mise's `npm.package_manager`
    setting can select pnpm for `npm:` tools.
  - **npm v12**, announced by GitHub, disables install scripts by default and
    blocks git and URL dependencies. Check that markdownlint-cli and Prettier
    install without scripts.
  - **Why cooldown matters.** The March 2026 LiteLLM release passed pip hash
    checks because it carried legitimate credentials, and it was live for about
    three hours. Hashes and lockfiles do not stop a bad new release, so cooldown
    and containment are the controls that help.
  - Not verified: how `npm.package_manager = "pnpm"` interacts with mise's
    transitive cooldown forwarding.
  - Excluded: Aikido Safe Chain and Socket Firewall are not approved by the
    organisation, so the ADR must not recommend them.
- **G. CI egress control.**
  - **Harden-Runner** (StepSecurity) audits and then blocks outbound traffic
    with a domain allowlist. The vendor reports that it detected the
    `tj-actions/changed-files`, Trivy and axios compromises. The Community tier
    is free for public repositories on GitHub-hosted runners. Private
    repositories and self-hosted runners need a paid plan.
  - **GitHub Actions network firewall** is a technical preview that logs
    outbound traffic. Blocking is future work.
  - Not verified: whether the organisation approves Harden-Runner, and whether
    the repositories adopting the template are public.
  - View: complements container hardening in D. Check approval before any spike.
- **H. Release provenance verification.** `gh attestation verify` checks
  attestations for binaries and `oci://` images, and mise verifies GitHub
  attestations for backends that support them. The option is to verify in CI the
  tools that mise does not cover. Not verified: which of our 11 tools and 7
  images publish attestations. It needs the `gh` CLI and network access, and
  offline mode exists.
- **I. Isolated development environments.** Dev containers, Nix, devenv and
  Devbox pin or isolate the whole toolchain. I found only secondary comparisons,
  so their security properties are not verified. Dev containers need Docker and
  editor support, and Nix has a steeper learning curve. A single
  organisation-built, digest-pinned tool image is a related idea with the
  maintenance costs of B and C.
- **J. Central distribution of the checks.** Publish `scripts/quality` as a
  versioned, attested release or reusable workflow that teams pin, so each team
  does not copy and maintain tooling. This answers the per-team objection and
  overlaps with B1. Not researched, so treat it as judgement. It needs a
  decision on who owns releases and how teams receive updates.

**Proposed work**:

- [ ] For each tool and image, record its purpose, its callers (`make` target,
      CI job or pre-commit hook), install source, integrity check, update
      mechanism, upstream health and whether it could become optional. Name
      every check that is missing from CI or from pre-commit.
- [ ] Assess each installation path, starting with `curl … | sh`. Compare a
      package manager install, a checksum-verified release download and mise's
      own verification options.
- [ ] Identify overlapping capabilities and the smallest default toolset that
      keeps the quality gates useful.
- [ ] Write the value of the checks into the ADR: the benefit table, the
      evidence and the responses. Mark each claim as measured, cited or
      judgement, and do not present the format checks as security controls.
- [ ] Test the agent claim in a scratch clone. Give an agent the same small set
      of tasks with the checks on and off. Record noisy diff lines, retries and
      style review comments, and which checks run in seconds inside the edit
      loop. Report the result even if it does not support the claim.
- [ ] Estimate the per-team alternative: what a team must choose, install, pin
      and maintain, and its effort and attack surface against the template.
- [ ] Decide whether shell lint also joins pre-commit, which PR 36 proposes, and
      whether the format checks form an optional tier.
- [ ] Build a threat-to-control table with four rows: a malicious release
      (cooldown, malware scan), a tampered artifact or registry (checksum,
      provenance, lockfile), a vulnerable dependency (patched builds, update
      cadence) and a compromised tool at run time (container hardening,
      sandbox). Map options A to J onto it and state what is left uncovered.
- [x] Commit a `mise.lock` with platform pins and supported provenance data.
      This is already present in `v2`.
- [ ] In a scratch clone, apply the container flags to all seven wrappers and
      run the existing test suites. Record what breaks.
- [ ] Time-box one spike each for A (custom flavour), B1 and C. Measure image
      pull size, cold and warm `make lint` times natively and with
      `FORCE_USE_DOCKER=true`, the changes needed in wrappers and tests, and the
      cost per adopting team.
- [ ] Spike option E in a scratch clone: run rumdl against `markdownlint.yaml`,
      MD060 and the existing tests, and run prek against
      `scripts/config/pre-commit.yaml`. Record rule gaps, output differences and
      what Node and Python are still needed for.
- [ ] Spike option F: install the npm tools through pnpm under mise, confirm
      that `minimumReleaseAge` and `trustPolicy` apply, and check the tools
      install with install scripts disabled.
- [ ] For options G and H, confirm organisational approval, then record which
      tools and images publish attestations and whether CI egress control is
      available for the repositories that adopt the template.
- [ ] Assess options I and J: the onboarding cost of an isolated environment,
      and who would own and release a central distribution of `scripts/quality`.
- [ ] Assess how pins stay current without Dependabot support for `mise.toml`
      (Renovate, a scheduled job or a documented manual refresh).
- [ ] Recommend an approach with its trade-offs and coverage gaps, and list the
      follow-up PRs.

**Edge cases the assessment must name**:

- **Forks and external contributors**: workflows from forks cannot read CI
  secrets by default, so a Chainguard pull token is unavailable. Say how their
  pull requests still pass.
- **Credential lifetime**: a 30-day token expires silently. Name who rotates it
  and what the failure tells a developer to do.
- **Urgent security fixes**: a cooldown must not delay them. Dependabot's
  cooldown skips security updates, and mise and npm have exclusion lists.
- **Digest pins against `latest`-only images**: a `latest`-only image moves
  under a version tag and digest pin, and versioned tags may need a paid plan.
- **Offline, air-gapped and Apple silicon use**: the images run as `linux/amd64`
  under emulation, and a mirror must also work offline.
- **File ownership**: non-root images and `--read-only` mounts can break a
  linter that writes a cache or a report.
- **Vendor outage**: `libraries.cgr.dev` has no uptime SLA, so name the fallback
  to upstream and who may approve it.
- **`FORCE_USE_DOCKER` parity**: native and Docker results must stay identical.
- **Existing configuration**: `gitleaks.toml`, `.gitleaksignore`, the lychee and
  markdownlint configuration must keep working.
- **Unapproved products**: Aikido Safe Chain and Socket Firewall are not
  approved, so no option may depend on them. Check the approval status of rumdl,
  prek, Harden-Runner and any other new supplier before a spike.
- **Pre-1.0 and single-maintainer tools**: rumdl and prek are pre-1.0. Name the
  fallback if a release breaks or the project stalls.

**Deliverable and verification**: an ADR in Proposed status and a list of
follow-up PRs. Keep the choice of tools and installation methods open until the
evidence supports a decision. The ADR covers installation security, toolset
size, maintenance burden, the value of each check and every edge case above. It
records options A to J, the rationale and the measured developer cost of each,
and it labels each claim as measured, cited or judgement. A maintainer accepts
or rejects it.

---
