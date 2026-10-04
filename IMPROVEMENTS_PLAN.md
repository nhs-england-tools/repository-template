# Improvements Plan

This plan tracks a batch of repository-template improvements. Twenty-two PRs
have merged into `v2` (see the [toolchain and setup merged
record](#merged-record--toolchain-and-setup-stack) and the [scan-secret and
markdown-linting merged record](#merged-record--scan-secret--markdown-linting-stack)).
The remaining work is organised into stacks and standalone PRs in
[Outstanding work](#outstanding-work--proposed-stacks). The remaining stacks
are ordered chains of PRs that share files and build on one another. Every
remaining proposal is self-contained and carries the context needed to raise it.

**Current priority**: land the outstanding proposals in the [recommended
order](#outstanding-work--proposed-stacks), then merge `v2` into `main`. Every
outstanding proposal was reviewed against `v2` on 2026-10-02. Stale diffs were
removed, verified defects and edge cases were added, and choices that need a
maintainer are listed under [Decisions needed before
implementation](#decisions-needed-before-implementation). Do not start a PR
that waits on an open decision.

---

## PR index — what each PR is about

All 35 PRs plus one optional tweak have a one-line summary and current status.
Detailed design notes remain only for proposals that are not merged or already
implemented by the merged stack. The stack is listed in the [toolchain and setup
merged record](#merged-record--toolchain-and-setup-stack), and remaining
proposals are grouped in [Outstanding work](#outstanding-work--proposed-stacks).
Status uses &#x2705; for merged, &#x1F6A7; for in progress, &#x1F7E1; for covered by another PR and &#x1F4CB; for planned work. D1 to D5 mark a planned PR that waits on an open [decision](#decisions-needed-before-implementation).

| PR         | Change                                          | Status                                    |
| ---------- | ----------------------------------------------- | ----------------------------------------- |
| 1          | ADR template and Tech Radar alignment           | &#x2705; Merged [GitHub #226][pr226]      |
| 2          | Make shell lint a real, fast failing gate       | &#x1F6A7; In progress · Stack 1 base      |
| 3          | Add and wire the `lint-shell` target            | &#x1F6A7; In progress · Stack 1           |
| 4          | Run shell lint in commit-stage CI               | &#x1F6A7; In progress · Stack 1           |
| 5          | Shell hygiene and clear image-pull failures     | &#x1F6A7; In progress · Stack 2, first    |
| 6          | Docker test isolation and runtime errors        | &#x1F7E1; Covered by [GitHub #259][pr259] |
| 7          | Markdown checks and check-mode guard            | &#x2705; Merged [GitHub #231][pr231]      |
| 8          | Secret scanning modes and hardening             | &#x2705; Merged [GitHub #230][pr230]      |
| Optional C | Document `FORCE_USE_DOCKER`                     | &#x1F6A7; In progress · Stack 1           |
| 9          | Require blank lines after YAML frontmatter      | &#x2705; Merged [GitHub #232][pr232]      |
| 10         | Format Markdown tables with Prettier            | &#x2705; Merged [GitHub #234][pr234]      |
| 11         | Skip deleted Markdown files in link checks      | &#x2705; Merged [GitHub #233][pr233]      |
| 12         | Reduce gitleaks false positives                 | &#x2705; Merged [GitHub #229][pr229]      |
| 13         | Copilot Stop hook for lint and test             | &#x1F4CB; Planned · optional · D4         |
| 14         | Improve pull-request template guidance          | &#x2705; Merged [GitHub #225][pr225]      |
| 15         | Native and Docker parity inventory              | &#x2705; Merged [GitHub #243][pr243]      |
| 24         | Refresh tools, runtimes, images and actions     | &#x2705; Merged [GitHub #244][pr244]      |
| 16         | Standardise unrecognised check-mode exit codes  | &#x1F4CB; Planned · Stack 3 · D1          |
| 17         | Use NUL-safe arrays for Markdown file lists     | &#x1F4CB; Planned · Stack 3               |
| 18         | Resolve the `check=branch` base dynamically     | &#x1F4CB; Planned · Stack 3 · D2          |
| 19         | Modernise file-format checks and ignore files   | &#x1F4CB; Planned · Stack 3 base · D3     |
| 20         | Migrate the toolchain manager from asdf to mise | &#x2705; Merged [GitHub #246][pr246]      |
| 21         | Add the SonarQube Cloud scan job                | &#x2705; Merged [GitHub #242][pr242]      |
| 22         | Keep `main`'s push trigger in the `v2` merge    | &#x1F4CB; Planned · during the `v2` merge |
| 23         | Fix remaining word splitting and globbing       | &#x1F4CB; Planned · Stack 3 top           |
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
| 35         | Assess tooling security and template defaults   | &#x1F4CB; Planned · standalone · D5       |

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

## Notes

- **Group by file, not by scattered concern.** Where several changes touch the
  same script, they are stacked as successive layers rather than raised as
  conflicting parallel PRs. [File ownership](#file-ownership) lists which PRs
  touch each file.
- **Snippets are illustrative.** A snippet in this plan pins a design choice.
  Implement against the current code, not against the snippet. Once a PR
  merges, reduce its section to a pointer to the merged PR.
- **Return the real status.** [SH-FN-007] requires every function to end with
  an explicit `return`. Where the last command's status is the function's
  result, a bare `return 0` hides failures whenever a caller uses the function
  in an `if`, `||` or `&&` context, because Bash suspends `set -e` there.
  Verified: with `set -e`, `f() { false; return 0; }; if f; then …` takes the
  success branch. Use `return 0` only after commands that cannot fail.
  Otherwise follow `scan-secrets.sh`: `local rc=0`, then `tool … || rc=$?`,
  then `return "$rc"`.
- **Handle awkward file names.** Build every file list with `git ls-files -z`
  or `git diff -z` and read it NUL-delimited, for example with
  `while IFS= read -r -d ''` or `mapfile -d ''`. Without `-z`, Git quotes
  non-ASCII names as `"caf\303\251.md"`, and the existing `[[ -f "$f" ]]`
  filter then drops them silently. Test every list with a space, glob
  characters (`notes[draft].md`), a non-ASCII character (`café.md`) and a
  leading dash.
- **Bash 5.2 is a given.** [SH-HDR-001] requires it and
  `make toolchain-verify-gnu` checks it, so features such as `mapfile -d ''`
  and associative arrays need no fallback.
- **Messages name the fix.** Every new error says what failed and how to fix
  it, for example the valid check modes or the `git fetch` command for a
  missing base, as [MK-LCL-008] requires.
- **Progress**: twenty-two PRs are merged into `v2`: PR 1, PR 14, the six
  scan-secret and markdown-linting PRs, PR 21, and all thirteen toolchain and
  setup PRs. On 2026-10-02 the full test suite passed on `v2`, and native
  ShellCheck 0.11.0 reported no findings across the 28 tracked shell scripts.

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
(#259) also delivered PR 6's Docker test isolation and prerequisite handling.
Do not raise duplicate PRs for any of this scope.

## Outstanding work — proposed stacks

Land the outstanding work in the order below. Within a stack, branch each PR
off the one below it and land the stack from the bottom up. Stacks 1 and 3 can
proceed in parallel once PR 5 has merged.

1. **Stack 2, shell hygiene**: `PR 5`. Land it first. It is small, keeps
   behaviour and touches one line in most check wrappers, so landing it first
   saves a rebase in Stacks 1 and 3.
2. **Stack 1, shell-lint gate**: `PR 2 → PR 3 → PR 4 → Optional C`. Each step
   is inert until the one below it lands.
3. **Stack 3, quality-script consistency**: `PR 19 → PR 16 → PR 17 → PR 18 →
PR 23`. The layers share the `scripts/quality/*` scripts, so stacking turns
   unavoidable overlap into small successive changes. PR 23 covers only what
   the earlier layers leave.
4. **Standalone**: `PR 35` at any time, and `PR 13` only after decision D4.
5. **Last**: `PR 22` is a checklist for the `v2` to `main` merge, not a commit
   on `v2`.

### Decisions needed before implementation

Each decision blocks only the PR named. Record the outcome in that PR's section
before implementation starts.

- **D1, PR 16: exit status for an unrecognised `check` mode.** Recommended:
  `126`. `scan-secrets.sh` already returns it on `v2` and `main`, so this
  changes three scripts rather than a released contract. Only direct script
  callers can see the status, because `make` exits `2` for any failing recipe.
- **D2, PR 18: how a developer declares a non-default base such as `v2`.**
  Recommended: a per-clone Git setting, `git config quality.baseBranch v2`. It
  persists across shells and needs no profile changes. The alternative is to
  export `BRANCH_NAME` in every shell.
- **D3, PR 19: syntax for `.editorconfigignore` entries.** Recommended:
  gitignore syntax, evaluated by Git. Developers already know it, and
  `.markdownlintignore` and `.prettierignore` use it. Regular expressions
  would need escaping, and an unescaped `.` or `[draft]` would match unrelated
  paths without warning.
- **D4, PR 13: whether the template ships an active Copilot Stop hook.**
  Recommended: not yet. VS Code runs hook files in `.github/hooks/` by default
  in every trusted workspace, so a tracked hook is on for every adopter rather
  than opt-in. Hooks are still in Preview, and each blocked stop consumes AI
  credits. Revisit when hooks reach general availability, or ship the scripts
  with an explicit enable step if adopters ask for the gate sooner.
- **D5, PR 35: whether a commercial supplier such as Chainguard may be part of
  the template's recommended toolchain.** Recommended: only as an optional
  overlay that an adopting team switches on with its own entitlement, never as
  a default, and only for gaps that PR 35 shows the free controls leave open.
  A default would need every adopting team to hold an entitlement and a CI
  credential, and workflows from forks cannot read CI secrets by default. D5
  limits only the Chainguard part of PR 35.

### File ownership

Each file that an outstanding PR changes, with the PRs in landing order. Test
suites under `scripts/**/tests/` change with the script they test.

- `scripts/docker/docker.lib.sh`: PR 5, then PR 23 for comments only
- `scripts/docker/dockerfile-linter.sh`: PR 5
- `scripts/quality/check-shell-lint.sh`: PR 5, PR 2
- `scripts/init.mk`: PR 2
- `Makefile`: PR 3
- `README.md`: PR 3, Optional C, PR 18, and PR 13 if D4 approves it
- `.github/actions/check-shell-lint/action.yaml` (new) and
  `.github/workflows/stage-1-commit.yaml`: PR 4
- `scripts/quality/check-file-format.sh`: PR 5, PR 19, PR 16, PR 18
- `scripts/config/.editorconfigignore` (new) and
  `scripts/config/.markdownlintignore`: PR 19
- `scripts/quality/check-markdown-format.sh` and
  `scripts/quality/check-markdown-links.sh`: PR 5, PR 16, PR 17, PR 18
- `scripts/quality/format-markdown-tables.sh`: PR 5, PR 17
- `scripts/quality/scan-secrets.sh`: PR 5, PR 16 for the message only, PR 18,
  PR 23
- `scripts/quality/quality.lib.sh` (new) and the existing
  `.github/actions/check-*/action.yaml` files: PR 18
- `scripts/docker/docker.mk`: PR 23
- `.github/workflows/cicd-1-pull-request.yaml`, the other conflicting files and
  `.github/contributing.md`: PR 22
- `docs/adr/` (new ADR): PR 35
- Hook configuration and scripts: PR 13, only if D4 approves it

**Cross-stack notes**:

- Do not duplicate the merged toolchain and setup stack.
- If Stack 1 or Stack 3 lands before PR 5, rebase PR 5. The conflict is one
  line per wrapper.
- PR 2 replaces the `find` loop in `scripts/init.mk`, and PR 19 removes the
  `$($filter)` splat from `check-file-format.sh`. PR 23 therefore leaves both
  files alone.
- If PR 2 lands before D1 is decided, PR 16 also updates
  `check-shell-lint.sh`.

---

## Merged record — scan-secret + markdown-linting stack

The scan-secret + markdown-linting batch was built as a local stack off `v2`,
reviewed, and has now been merged into `v2` in the order below. Each layer passed
the full pre-commit gate (`scan-secrets`, `check-file-format`,
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

## PR 2: Make `check-shell-lint` a real, fast gate

**Scope**: Build system and quality gate
**Risk**: Low. The target starts failing on findings, which is the purpose of
the change. Native ShellCheck 0.11.0 reported no findings across the 28 tracked
scripts on 2026-10-02.
**Depends on**: PR 5
**Files**: `scripts/init.mk`, `scripts/quality/check-shell-lint.sh` and
`scripts/quality/tests/check-shell-lint.test.sh`

**Problem**: `make check-shell-lint` never fails. The recipe swallows every
error with `||:` and only checks whether the output is empty. It has three
further defects:

- It starts one ShellCheck process per file, or one container per file in
  Docker mode, which means 28 container starts today.
- `for file in $$(find . -type f -name "*.sh")` splits names on whitespace and
  expands glob characters.
- `find .` also walks untracked and ignored paths. In an adopting repository
  that includes `node_modules/`, `.venv/` and local tool overlays, so the gate
  would lint third-party scripts.

The earlier proposal kept the logic in the recipe and piped the list into
`xargs shellcheck`. Plain `xargs` still splits on whitespace, and its fallback
loop still used `for file in $$files`. With GNU `xargs`, an empty list also runs
ShellCheck with no files, which exits `3` with "No files specified" rather than
hanging (verified). The design below replaces it.

**Change**: move the logic into the wrapper script and keep the recipe to one
line, as [MK-STR-004] requires.

- [ ] Add a `check=all` mode to `check-shell-lint.sh`. It lints every tracked
      `*.sh` file that still exists, in one ShellCheck call natively or one
      container in Docker mode.
- [ ] Build the list NUL-safely and pass it after `--`, so names with spaces,
      glob characters, non-ASCII characters or a leading dash reach ShellCheck
      intact:

  ```bash
  local -a files=()
  local file
  while IFS= read -r -d '' file; do
    [[ -f "$file" ]] && files+=("$file")
  done < <(git ls-files -z -- '*.sh')
  ```

- [ ] When the list is empty, do not call ShellCheck, and return `0`.
- [ ] Return ShellCheck's status unchanged, using the pattern in
      [Notes](#notes): `1` for findings and `2` when a file cannot be processed.
- [ ] Keep the single-file `file=<path>` mode and its tests unchanged, because
      `docker-shellscript-lint` in `docker.mk` uses it.
- [ ] Reject any other `check` value with the status agreed in
      [D1](#decisions-needed-before-implementation). If D1 is still open, use `1`
      and add this script to PR 16.
- [ ] Document the mode in the script header, including that untracked files
      are not linted, as the other check scripts already state.
- [ ] Replace the recipe with one line that matches the other check targets,
      `check=all ./scripts/quality/check-shell-lint.sh && echo "shell lint: ok"`,
      and describe the target as "Lint all tracked shell scripts".

**Edge cases**:

- **No tracked scripts**: ShellCheck is not called, and the target prints
  `shell lint: ok`.
- **Tracked file deleted in the working tree**: skipped, as PR 11 does for
  Markdown.
- **Untracked new script**: not linted until `git add`, as the header states.
- **Git-ignored local scripts, such as tool overlays**: not linted.
- **Name with a space, `[x]`, `café` or a leading `-`**: linted as exactly that
  file.
- **Vendored `scripts/docker/dgoss.sh`**: linted, and it passes today. Exclude
  it only if a future upstream update fails.
- **Scripts without a `.sh` extension**: out of scope, as today.
- **ShellCheck not installed**: falls back to the pinned `koalaman/shellcheck`
  image from `mise.toml`.
- **Image pull fails**: stops with the pull error before `docker run`, once
  PR 5 has landed.
- **Run outside `make`**: uses the first `shellcheck` on `PATH`. Under `make`,
  the mise shims put the pinned 0.11.0 first.

**Tests**: add these to `scripts/quality/tests/check-shell-lint.test.sh`,
using the existing stubs.

- [ ] `test-check-shell-lint-all-lints-every-tracked-script-in-one-call`
- [ ] `test-check-shell-lint-all-skips-deleted-and-untracked-files`
- [ ] `test-check-shell-lint-all-passes-awkward-names-intact`
- [ ] `test-check-shell-lint-all-without-scripts-does-not-call-shellcheck`
- [ ] `test-check-shell-lint-all-propagates-shellcheck-failure`
- [ ] `test-check-shell-lint-all-uses-one-docker-run-when-forced`
- [ ] `test-check-shell-lint-rejects-unknown-mode`

**Verification**:

- `make check-shell-lint` prints `shell lint: ok` and exits `0` on `v2`,
  natively and with `FORCE_USE_DOCKER=true`.
- With a deliberate ShellCheck finding, the target exits non-zero, shows the
  finding and does not print `shell lint: ok`, in both modes.
- `make test` passes.

---

## PR 3: Add a `lint-shell` target and include it in `make lint`

**Scope**: Build system and documentation
**Risk**: Low
**Depends on**: PR 2, so the new gate fails on findings
**Files**: `Makefile` and `README.md`

**Problem**: `make lint` does not lint shell scripts, and there is no
`lint-shell` target beside `lint-file-format`, `lint-markdown-format` and
`lint-markdown-links`.

**Change**:

- [ ] Add `lint-shell: # Lint all tracked shell scripts @Quality`, which runs
      `$(MAKE) check-shell-lint`.
- [ ] Call it from `lint` after `lint-markdown-links`, and add it to the
      `${VERBOSE}.SILENT` list.
- [ ] In the README "First run" section, add `shell lint: ok` as the fourth
      line of the expected `make lint` result. Change it in this PR, so the README
      never shows the wrong output.
- [ ] In the README "Common workflows" section, add `make lint-shell` to the
      specific checks. Add one sentence saying that `make lint` stops at the first
      failing check, and that `make -k lint` runs them all.

**Developer experience**:

- `make lint` gains about 4 seconds natively. One ShellCheck call over the 28
  tracked scripts took 3.8 seconds on a developer Mac on 2026-10-02. Docker
  mode adds one container start, not 28.
- `lint-shell` checks every tracked script, unlike the other `lint-*` targets,
  which check only the branch's changes. This is deliberate. It is fast enough,
  and it does not depend on the branch base resolution that PR 18 fixes.

**Out of scope**: adding shell lint to `scripts/config/pre-commit.yaml`. The
pre-commit hooks run with `check=all`, so it would add about 4 seconds to every
commit, including commits that change no scripts. Revisit if a
`staged-changes` mode is added.

**Verification**:

- `make help` lists `lint-shell` under Quality.
- `make lint` prints four `ok` lines that match the README.
- A ShellCheck finding makes both `make lint-shell` and `make lint` fail.

---

## PR 4: Run shell lint in commit-stage CI

**Scope**: CI quality gate
**Risk**: Low
**Depends on**: PR 2 and PR 3
**Files**: `.github/actions/check-shell-lint/action.yaml` (new) and
`.github/workflows/stage-1-commit.yaml`

**Problem**: the commit stage runs four checks: `scan-secrets`,
`check-file-format`, `check-markdown-format` and `check-markdown-links`.
Without this PR, the shell-lint gate never runs in CI.

The earlier snippet was stale. It pinned `actions/checkout` to v6.0.2 and used
`ubuntu-latest`. Every commit-stage job now uses `ubuntu-26.04`, checkout
v7.0.1 and a `jdx/mise-action` step that installs the pinned tool.

**Change**:

- [ ] Add a composite action that runs `make check-shell-lint`, mirroring the
      existing actions. It needs no `check` or `BRANCH_NAME` input.
- [ ] Add a "Check shell scripts" job after `check-markdown-links`, with the
      same shape as its neighbours. Copy the action SHAs from the neighbouring jobs
      at implementation time, because Dependabot keeps them current.

  ```yaml
  check-shell-lint:
    name: "Check shell scripts"
    runs-on: ubuntu-26.04
    timeout-minutes: 2
    steps:
      - name: "Checkout code"
        uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - name: "Set up mise"
        uses: jdx/mise-action@c2a87611a18de5b3828c5652fe268e992400cb5c # v4.3.0
        with:
          version: ${{ inputs.mise_version }}
          install: true
          install_args: "shellcheck"
          cache: true
          github_token: ${{ secrets.GITHUB_TOKEN }}
      - name: "Check shell scripts"
        uses: ./.github/actions/check-shell-lint
  ```

- [ ] Keep the default shallow checkout. The check lints tracked files and
      needs no history.

**Edge cases**:

- **The runner's preinstalled ShellCheck**: the mise step puts the pinned
  0.11.0 first, so CI matches `make` locally and the Docker pin.
- **mise cannot install ShellCheck**: the job fails. It must not fall back
  silently to the runner's unpinned version.
- **Required status checks**: where branch protection lists required checks,
  an administrator must add "Check shell scripts". Otherwise a failing job does
  not block merges. Say so in the PR description.

**Verification**:

- On a draft PR with a deliberate ShellCheck finding, "Check shell scripts"
  fails and shows the finding. Without the finding, it passes.
- The job finishes well within its 2-minute timeout.

---

## PR 5: Shell hygiene and clear image-pull failures

**Scope**: Shell script quality and developer experience
**Risk**: Low. Behaviour is unchanged, except that a failed image pull now
stops with the pull error.
**Depends on**: nothing. Land it before Stacks 1 and 3.
**Files**: `scripts/docker/docker.lib.sh`, `scripts/docker/dockerfile-linter.sh`,
`scripts/quality/check-shell-lint.sh`, one line in each of
`check-file-format.sh`, `check-markdown-format.sh`, `check-markdown-links.sh`,
`format-markdown-tables.sh` and `scan-secrets.sh` under `scripts/quality/`, and
the matching test suites

**Problem**:

1. **A failed image pull surfaces as a confusing `docker run` error.** Seven
   wrapper scripts declare and assign the image in one statement,
   `local image=$(name=… docker-get-image-version-and-pull)`. `local` succeeds
   whatever the command returns, so the failed pull is ignored and
   `docker run` starts with an empty image name. Verified with a stubbed
   `docker`: the pull failed, then `docker run` ran without an image and exited
   `125`. ShellCheck reports this as SC2155, but every site disables it, and
   `docker.lib.sh` disables it for the whole file on line 2.
2. **Implicit globals in `docker.lib.sh`.** `docker-build` assigns `tag` and
   `_get-effective-tag` assigns `version` without `local`, so both leak into
   the caller.
3. **Missing explicit returns and doc comments.** [SH-FN-007] requires an
   explicit return. `main` and `is-arg-true` have no doc comment in
   `check-shell-lint.sh` or `dockerfile-linter.sh`.

The earlier diff is obsolete. It targeted
`_replace-image-latest-by-specific-version` and `.tool-versions`, which merged
PRs 25 and 30 replaced. It also appended a bare `return 0` to every function,
which would hide real failures, as [Notes](#notes) explains.

**Change**:

- [ ] At each of the seven wrapper call sites, declare the variable first,
      return the pull status explicitly and remove the
      `# shellcheck disable=SC2155`. The explicit `|| return` matters because some
      callers, such as `run-check` in `scan-secrets.sh`, call the runner in a `||`
      context where `set -e` does not apply.

  ```bash
  local image
  image="$(name=koalaman/shellcheck docker-get-image-version-and-pull)" || return "$?"
  ```

- [ ] Remove the file-wide SC2155 disable from `docker.lib.sh` and fix each
      site it hides: `tag` in `docker-run`, `version`, `tag` and `digest` in
      `docker-get-image-version-and-pull`, and `branch_name` in
      `_get-git-branch-name`.
- [ ] Declare `tag` in `docker-build` and `version` in `_get-effective-tag`
      with `local`.
- [ ] Add explicit returns:
  - `return 0` where the last command cannot fail:
    `docker-get-image-version-and-pull`, `docker-check-test`,
    `_get-effective-version`, `_get-effective-tag`,
    `_get-all-effective-versions` and `_get-git-branch-name`
  - the status-preserving pattern where the last command's status is the
    result: `docker-build`, `docker-bake-dockerfile`, `docker-lint`,
    `docker-run`, `docker-push`, `docker-clean`,
    `version-create-effective-file`, `_create-effective-dockerfile`,
    `_pin-dockerfile-arg-versions`, `_append-metadata`, `_toml-table-entry`,
    and `main` and the `run-*` functions in both wrapper scripts
  - the same pattern for `_container-runtime-is-operational`, whose callers
    read `124` on timeout from `wait "$pid"`
  - nothing for `docker-pull-pinned-images`, `_get-docker-image-version` and
    `_toml-table-entries`, which already return explicitly
- [ ] Add one-line doc comments to `main` and `is-arg-true` where they are
      missing.

**Tests**:

- [ ] In each of the seven wrapper suites, add
      `test-<script>-stops-when-the-image-pull-fails`. Stub `docker` so that `pull`
      fails, force Docker mode, and assert a non-zero exit, the pull error on
      stderr and no `docker run` call. This covers the `scan-secrets.sh` path that
      runs inside `||`.
- [ ] In `scripts/docker/tests/docker-lib.test.sh`, call each status-carrying
      function inside `if` with a failing stub and assert that the failure branch
      runs. A bare `return 0` would break exactly this case. Cover at least
      `docker-lint`, `docker-run` with a container exit status of `42`, and
      `_container-runtime-is-operational` returning `124`.
- [ ] Assert that `tag` and `version` are unset in the caller after
      `docker-build`.

**Out of scope**:

- `docker-check-test` always exits `0` and reports `PASS` or `FAIL` on stdout.
  Callers compare that output, so keep it.
- `docker-run` and `docker-check-test` split `${args:-}` and `${cmd:-}` on
  purpose. PR 23 documents why.

**Verification**:

- `git ls-files -z -- '*.sh' | xargs -0 shellcheck` reports no findings with
  the SC2155 disables removed.
- `make test` passes, including the new tests. With Docker running,
  `make docker-test-suite-run` also passes.

---

## Optional PRs (maintainer's discretion)

### Optional C: Document `FORCE_USE_DOCKER` in the README

**File**: `README.md` · **Risk**: Very low · **Type**: documentation ·
**Depends on**: PR 3

PR 3 now owns the README changes for shell lint. This option covers the
remaining gap. The README never explains `FORCE_USE_DOCKER`, although every
check wrapper honours it.

- [ ] Add a short paragraph to "Common workflows". Explain that each check runs
      the native tool when it is installed and otherwise falls back to the pinned
      image in `mise.toml`. Explain that `FORCE_USE_DOCKER=true make lint` forces
      the container path, for example to reproduce a result with the exact pinned
      image.
- [ ] State what it needs: a running Docker daemon reachable through the
      `docker` command. On Apple silicon the images run as `linux/amd64` under
      emulation, so runs are slower.

---

## PR 13 (optional): Copilot agent hook to run `make lint` and `make test`

**Status**: Planned. Blocked on [D4](#decisions-needed-before-implementation).
**Scope**: Developer experience, an automated quality gate for AI agents
**Risk**: Medium. Hooks are a Preview feature, run code automatically in
trusted workspaces and can consume AI credits.
**Depends on**: D4
**Files**: if D4 approves it, a hook file under `.github/hooks/`,
`scripts/hooks/stop-gate.sh`, `scripts/hooks/record-tree-snapshot.sh`,
`scripts/hooks/_common.sh`, tests under `scripts/hooks/tests/` and `README.md`

**Current state**: nothing is delivered. `v2` tracks no files under
`.github/hooks/` or `scripts/hooks/`. Hook files in some local clones come from
a separate overlay tool, and that clone's local `.gitignore` changes exclude
them. That overlay also records prompt text, which this PR must never do.

**Goal**: when an agent turn has changed files, run `make lint` and then
`make test` before the agent stops. If either fails, block completion once and
give the agent the failure output. Turns that change nothing skip the gates.

**Corrections to the earlier design**, checked against the VS Code Local hooks
reference:

- `timeout` is in **seconds**, with a default of 30. The earlier values,
  `10000` and `60000`, meant hours.
- The documented `Stop` output is `hookSpecificOutput` with `hookEventName`,
  `decision: "block"` and a required `reason`. Put the truncated failure output
  in `reason`. `additionalContext` is not documented for `Stop`.
- `make test` is no longer a stub. The full suite took about 10 seconds on a
  developer Mac on 2026-10-02, and the Docker suite adds more when Docker is
  running.
- `jq` is already pinned in `mise.toml`.

**Requirements if D4 approves it**:

- [ ] `UserPromptSubmit` records only a working-tree fingerprint. It must not
      read, log or store prompt text.
- [ ] `Stop` skips the gates when the fingerprint is unchanged, and allows
      completion when `stop_hook_active` is `true`, so a failing gate blocks at
      most once per stop.
- [ ] Set `timeout` to 10 seconds for the snapshot hook and 120 seconds for the
      Stop hook. A hook that times out does not block, so the gate must finish well
      within its limit.
- [ ] Choose file names that cannot collide with local overlays, which use
      `quality-gates.json` and `scripts/hooks/stop-gate.sh`. Two Stop gates would
      run every check twice.
- [ ] Document in the README how to turn hooks off with the `chat.useHooks`
      setting, and that organisation policy may block them.
- [ ] Test the re-entry guard, the no-edit guard, the block output and a
      failing gate, with `make` stubbed.

**Edge cases**:

- **Offline developer**: `make lint` includes the Markdown link check, which
  needs the network. Run the same `make lint` as developers do, and accept that
  an offline run blocks once and then completes through the re-entry guard.
- **Other agent harnesses**: Copilot CLI, Claude and Codex sessions may read
  `.github/hooks/*.json` but use different events and payloads. Verify the hook
  on every harness the organisation supports.
- **Untrusted workspace, or hooks disabled by policy**: the hook does not run.
  CI still enforces the same gates.

**Verification**:

- After a lint-breaking edit, the hook blocks once with the lint output. After
  the fix, the agent completes.
- A question that edits nothing skips the gates.
- `echo '{"stop_hook_active":true}' | ./scripts/hooks/stop-gate.sh` prints
  `{}`.

---

## PR 16: Harmonise the unrecognised check-mode exit status

**Status**: Planned. Blocked on [D1](#decisions-needed-before-implementation).
**Scope**: Shell script consistency and usability
**Risk**: Low. A direct caller that mistypes a mode sees a different exit
status.
**Depends on**: PR 19 and D1
**Files**: `scripts/quality/check-file-format.sh`,
`scripts/quality/check-markdown-format.sh`,
`scripts/quality/check-markdown-links.sh`, the message in
`scripts/quality/scan-secrets.sh`, and the matching test suites

**Problem**: the scripts disagree. `scan-secrets.sh` returns `126` for an
unrecognised `check` mode and documents it, on `v2` and on `main`. The other
three scripts `exit 1`, which a direct caller cannot tell apart from a real
finding. No message lists the valid modes, so a developer who mistypes a mode
has to open the script to find them.

**Facts behind D1**:

- No caller in this repository tells the codes apart. Pre-commit and CI call
  the scripts through `make`, and `make` exits `2` whenever a recipe fails,
  whatever status the recipe returned.
- In shells, `126` usually means "found but not executable", so the message
  must state the real cause.
- Moving `scan-secrets.sh` to `1` instead would change its released,
  documented contract.

**Change**, assuming D1 keeps `126`:

- [ ] In each `*)` branch, replace `echo … >&2 && exit 1` with `echo … >&2`
      followed by `return 126`, and let `main`'s status propagate.
- [ ] Make every message list the valid modes, for example
      `Unrecognised check mode: bogus (expected one of: all, staged-changes, working-tree-changes, branch)`.
      Give `scan-secrets.sh` the same wording with its six modes.
- [ ] Add `126 - Unrecognised check mode` to each header's `Exit codes` block.
- [ ] Update the three `*-rejects-unknown-mode` tests, which assert `1` today,
      and assert the new message in all four suites.

**Edge cases**:

- **Empty `check=`**: falls back to the default mode, because the scripts read
  `${check:-…}`. Keep this and test it.
- **Different case, such as `check=ALL`**: unrecognised. Keep modes
  case-sensitive.

**Verification**: `check=bogus ./scripts/quality/<script>.sh` exits `126` and
lists the valid modes. A real finding still exits `1`. `make test` passes.

---

## PR 17: Use NUL-safe arrays for Markdown file lists

**Status**: Planned
**Scope**: Shell script correctness
**Risk**: Medium. It fixes a silent false pass, so results change for affected
file names.
**Depends on**: PR 16
**Files**: `scripts/quality/check-markdown-format.sh`,
`scripts/quality/check-markdown-links.sh`,
`scripts/quality/format-markdown-tables.sh` and the matching test suites

**Problem**: all three scripts build a newline-separated `files` string, pass
it to the runner functions as an environment variable, and rebuild it with
`local IFS=$'\n'` and `local -a file_list=($files)` under
`# shellcheck disable=SC2206`. Splitting on newlines already protects names
with spaces. Two defects remain:

1. **Non-ASCII names are dropped silently (verified).** Without `-z`,
   `git ls-files` and `git diff --name-only` quote such names, for example
   `"caf\303\251.md"`. In `check=all`, the `[[ -f "$f" ]]` filter then
   discards the file. A `café.md` with two lint errors passed `check=all` with
   exit status `0`, while `markdownlint café.md` reported both errors. The
   diff-based modes return the same quoted paths.
2. **Glob characters are expanded.** The unquoted array assignment still
   performs pathname expansion. With `notes[draft].md` and `notesd.md` in one
   directory, `notes[draft].md` becomes `notesd.md`, so the wrong file is
   checked without any warning.

The earlier text said that `check-markdown-links.sh` expands `$files` fully
unquoted. That is no longer true. It uses the same `IFS` construct as the other
two scripts.

**Change**:

- [ ] Build each mode's list with `-z` (`git ls-files -z`,
      `git diff -z --name-only`), read it NUL-delimited into an array, and keep the
      existing-file filter. See [Notes](#notes).
- [ ] Pass the array to the runner functions as arguments instead of through
      the `files` variable. Pass it to each tool after `--` where the tool supports
      that. Confirm `--` support in markdownlint-cli, lychee and Prettier during
      implementation, and prefix paths with `./` for any tool that lacks it.
- [ ] Pass the list to the frontmatter check as arguments,
      `python3 - "${files[@]}"`, read through `sys.argv[1:]`, instead of the
      newline-joined `files` variable.
- [ ] Replace `if [[ -n "$files" ]]` with `if (( ${#files[@]} > 0 ))`.
- [ ] Remove the SC2206 disables.

**Edge cases**, each covered by a test:

- **Awkward names**: a non-ASCII name, a space, glob characters
  (`notes[draft].md` beside `notesd.md`) and a leading dash are each checked as
  exactly that file.
- **Empty selection**, for example `check=working-tree-changes` with no
  changes: no tool runs, and the exit status is `0`.
- **Tracked file deleted in the working tree**: skipped, as PR 11 requires.
- **Renamed file**: checked under its new name.
- **Docker mode**: the container receives the same separate arguments.

**Tests**: in each of the three suites, add
`test-<script>-checks-awkward-file-names` for every applicable mode, natively
and in Docker mode. Assert the exact paths passed to the stubbed tool.

**Verification**: `make lint` and `make test` pass natively and with
`FORCE_USE_DOCKER=true`. Repeat the `café.md` reproduction: `check=all` now
reports both errors.

---

## PR 18: Resolve the `check=branch` base dynamically

**Status**: Planned. Blocked on [D2](#decisions-needed-before-implementation).
Supersedes the removed Optional A.
**Scope**: Shell script correctness and developer experience
**Risk**: Medium. It changes which files `make lint` selects.
**Depends on**: PR 17 and D2
**Files**: `scripts/quality/quality.lib.sh` (new),
`scripts/quality/check-file-format.sh`,
`scripts/quality/check-markdown-format.sh`,
`scripts/quality/check-markdown-links.sh`, `scripts/quality/scan-secrets.sh`,
the three existing `.github/actions/check-*/action.yaml` files, `README.md` and
the matching test suites

**Problem**: `check=branch`, which `lint-file-format`, `lint-markdown-format`
and `lint-markdown-links` use, compares with `${BRANCH_NAME:-origin/main}`.

1. **Hardcoded base.** A branch that targets anything other than
   `origin/main`, such as `master`, `develop` or a stacked base like `v2`, is
   compared with the wrong ref. On the `v2` stack, `lint-file-format` selected
   about 53 files instead of the 8 the branch changed. That is slow, and it
   fails on issues the branch did not introduce.
2. **Diff against the base tip.** `git diff <base>` also reports files that
   changed on the base after the branch forked.

Git does not record which branch a branch will merge into. That is pull request
metadata. `origin/HEAD` names the remote's default branch, `origin/main` here,
so no automatic rule can find a stacked base such as `v2` (verified). A
non-default base must be declared, which is decision D2.

Optional A forced `lint-markdown-links` to `check=all` because branch selection
was unreliable. Once selection is correct, branch-scoped link checks are
consistent with the other `lint-*` targets, and pre-commit and CI still run
`check=all`.

**Change**:

- [ ] Add `resolve-base-ref` to a new `scripts/quality/quality.lib.sh` that all
      four scripts source, so they resolve the base identically. The first match
      wins:
  1. `BRANCH_NAME`, the existing explicit override
  2. `origin/$GITHUB_BASE_REF`, which GitHub Actions sets on pull request
     events
  3. the per-clone setting agreed in D2, for example
     `git config quality.baseBranch v2`
  4. the remote default branch, from `git symbolic-ref refs/remotes/origin/HEAD`
  5. `origin/main`, today's default
- [ ] Resolve a short name such as `v2` to `origin/v2` when it exists and to
      the local `v2` otherwise, so offline work still resolves.
- [ ] Select files with
      `git diff --diff-filter=ACMRT -z --name-only "$(git merge-base "$base" HEAD)"`.
      This covers committed, staged and unstaged changes since the fork point, and
      ignores later changes on the base.
- [ ] Keep the commit range `<base>..HEAD` in `scan-secrets.sh`, using the
      resolved base.
- [ ] Print the resolved base and its source on stderr, for example
      `Comparing with origin/v2 (git config quality.baseBranch)`, so developers can
      see why files were selected.
- [ ] Remove the unused `export BRANCH_NAME=origin/<default branch>` lines from
      the three composite actions. Those actions run `check=all`, which ignores the
      variable. If a future CI step used `check=branch`, the export would override
      `GITHUB_BASE_REF` and select the wrong base.
- [ ] Document the resolution order and the D2 setting in each script header
      and in the README's "Common workflows" section.

**Edge cases**:

- **Base ref missing or not fetched**: fail with the ref name and the fix, for
  example `git fetch origin v2`. Never fall back to a whole-repository scan.
- **`origin/HEAD` not set**, which is common after `git remote add`: fall
  through to `origin/main`. If that is missing too, fail and suggest
  `git remote set-head origin --auto` or the D2 setting.
- **No `origin` remote**, for example in a fresh copy of the template: fail
  with a message that names the D2 setting and `BRANCH_NAME`.
- **Shallow clone without a merge base**: fail and suggest
  `git fetch --unshallow`. CI already checks out with `fetch-depth: 0`.
- **Detached `HEAD` in CI**: works, because `git merge-base` uses `HEAD`.
- **On the base branch, or no divergence**: the selection is empty. Check
  nothing, say that nothing changed, and exit `0`.
- **`BRANCH_NAME` exported by an unrelated tool**: it still wins, as today.
  The printed source makes this visible.

**Tests**, in each affected suite, with scratch repositories and a fake
`origin`:

- [ ] each layer wins over the layers below it
- [ ] a branch off `v2` with the D2 setting selects only its own changes
- [ ] changes made on the base after the fork are not selected
- [ ] every failure case above prints its message and exits non-zero

**Verification**: on a branch off `v2` with the D2 setting,
`make lint-file-format` selects only the branch's files. On a branch off
`main`, nothing needs configuring. `make test` passes.

---

## PR 19: Modernise `check-file-format.sh` and adopt an `.editorconfigignore`

**Status**: Planned. Blocked on [D3](#decisions-needed-before-implementation).
**Scope**: Shell script consistency and ignore-file ergonomics
**Risk**: Low
**Depends on**: PR 5 and D3
**Files**: `scripts/quality/check-file-format.sh`,
`scripts/config/.editorconfigignore` (new),
`scripts/config/.markdownlintignore` and
`scripts/quality/tests/check-file-format.test.sh`

**Problem**:

- editorconfig-checker is the only checker without a dedicated ignore file. Its
  exclusions live in the `Exclude` regular expressions in
  `editorconfig-checker.json`, which is empty today. markdownlint, gitleaks and
  Prettier each read a `.<tool>ignore` file in `scripts/config/`.
- The file list is a Git command string, `filter`, executed as `$($filter)`
  under `# shellcheck disable=SC2046,SC2086`. Its output is split and
  glob-expanded natively, and again inside the container's `sh -c` string.
  Non-ASCII names arrive quoted, as PR 17 describes.
- `main` and `is-arg-true` have no doc comments, and functions end without
  explicit returns.

The earlier proposal filtered paths with `grep -Ev`, which treats every entry as
a regular expression. A `.` matches any character and `[draft]` is a character
class, so an entry could exclude unrelated files without warning.

**Change**:

- [ ] Build the selection on the host as a NUL-safe array for each mode, with
      the existing-file filter, as in PR 17. Pass it to `ec` as arguments, natively
      and in the container. This removes `$($filter)` and both splitting steps, so
      PR 23 does not touch this script.
- [ ] Drop the entries that `scripts/config/.editorconfigignore` matches, using
      gitignore syntax evaluated by Git. List the matches with the command below
      and remove them from the selection, for example with an associative array.

  ```bash
  git ls-files -z --cached --ignored --exclude-from=scripts/config/.editorconfigignore
  ```

  Verified on Git 2.55: this applies file patterns, directory patterns such as
  `gen/`, negation such as `!keep.js` and escaped literal brackets to tracked
  paths, including names with spaces.

- [ ] Keep honouring `Exclude` in `editorconfig-checker.json`.
- [ ] When the selection is empty, do not call `ec`, and exit `0`. This
      replaces the `/dev/null` argument, which existed only to stop `ec` from
      checking every file when it received none.
- [ ] Ship `.editorconfigignore` with a two-line header comment in the style of
      `.prettierignore`, and give the empty `.markdownlintignore` the same kind of
      header.
- [ ] Add `local` declarations, doc comments and explicit returns that follow
      the rule in [Notes](#notes).

**Edge cases**:

- **Ignore file missing or empty**: nothing is excluded.
- **Comments and blank lines**: ignored, as in `.gitignore`.
- **Patterns that exclude every selected file**: `ec` is not called, and the
  exit status is `0`.
- **Negation and directory patterns**: behave as in `.gitignore`.
- **Awkward names**: as listed in PR 17.
- **Native and Docker modes**: identical selections and results.

**Tests**: add `test-check-file-format-honours-editorconfigignore` for the
native and Docker paths, `test-check-file-format-skips-ec-when-nothing-is-selected`
and `test-check-file-format-checks-awkward-file-names`.

**Out of scope**: generating ignore files from shared configuration, and a
`.lycheeignore`. Lychee exclusions belong in `lychee.toml`, because lychee only
reads `.lycheeignore` from the working directory, not from `scripts/config/`.

**Verification**: `make check-file-format check=all` passes. An entry in
`.editorconfigignore` excludes the matching path in both modes. `make test`
passes.

---

## PR 22: Keep `main`'s push trigger when `v2` merges into `main`

**Scope**: CI trigger correctness
**Risk**: Low, but timing-sensitive
**Depends on**: every other PR in this plan that is going into the same release
**Files**: `.github/workflows/cicd-1-pull-request.yaml` and the other
conflicting files, during the merge only, plus `.github/contributing.md`

**Problem**: on `v2`, the pull request workflow triggers on `push` to every
branch (`"**"`) and on `pull_request`. A commit pushed to a branch with an open
PR fires both events, so every stage runs twice, including two SonarQube Cloud
analyses of identical code. `main` fixed this on 2026-04-21 in `c861edf`
(#210) by narrowing `push` to `main`. `v2` forked earlier, at `e0f7568`.

`v2` must keep `"**"` until the merge. Narrowing it earlier would stop
push-triggered CI on `v2` itself while the remaining PRs merge into it.

**Review finding**: a separate commit on `v2` is not needed. `git merge-tree`
shows that merging `v2` into `main` already resolves the trigger block to
`branches: [main]`, because only `main` changed those lines. The same file
does conflict elsewhere, as do seven other files. A resolution that takes
`v2`'s side of the whole file would silently restore `"**"`.

**Tasks**, during the `v2` to `main` merge:

- [ ] List the conflicts with
      `git merge-tree --write-tree --name-only origin/main v2`. On 2026-10-02 they
      were `.github/dependabot.yaml`, the three `cicd-*.yaml` workflows and the
      four `stage-*.yaml` workflows. Resolve each conflict hunk by hunk. Never take
      one side of a whole workflow file.
- [ ] Check that the resolved trigger block is exactly `push` on
      `branches: [main]` and `pull_request` with
      `types: [opened, reopened, synchronize]`.
- [ ] If the conflicts are resolved by merging `main` into `v2`, make that the
      last change on `v2`. From then on `v2` receives no push-triggered runs, which
      is acceptable because the open `v2` to `main` PR still runs CI.
- [ ] Add one sentence to `.github/contributing.md`: a branch gets CI only once
      a pull request is open, so open a draft PR to see results early. `main` has
      behaved this way since April 2026.

**Verification**:

- Before the merge, a commit to a branch with an open PR against `v2` starts
  two runs.
- After the merge, a commit to a PR branch starts one run, triggered by
  `pull_request`, and a merge to `main` starts one run, triggered by `push`.
- The merged trigger block matches the one on `main` before the merge.

---

## PR 23: Fix the remaining word splitting in secret scanning and Make loops

**Status**: Planned
**Scope**: Shell script and Makefile correctness
**Risk**: Low to medium
**Depends on**: PR 18, at the top of Stack 3
**Files**: `scripts/quality/scan-secrets.sh`, `scripts/docker/docker.mk`,
comments in `scripts/docker/docker.lib.sh`, and
`scripts/quality/tests/scan-secrets.test.sh`

**Problem**: after PR 2, PR 17 and PR 19, three items remain from the
repository-wide audit.

1. **Native secret scanning fails when the clone path contains a space
   (verified).** `get-cmd-to-run` builds the gitleaks command as one string,
   and `run-gitleaks-natively` expands it unquoted (`gitleaks $cmd`, under
   `# shellcheck disable=SC2086`). From a clone in `dir with space/repo`,
   `check=last-commit` failed with
   `unable to load gitleaks config … /dir: no such file or directory`. The
   pre-commit hook therefore fails for any developer whose path contains a
   space, which is common on macOS and Windows. Docker mode works, because it
   mounts the repository at `/workdir`.
2. **`docker-shellscript-lint` in `docker.mk`** loops over
   `for file in $$(find scripts/docker -type f -name "*.sh")`, which splits
   names and also lints untracked files.
3. **Intentional splitting is undocumented**, so each new review raises it
   again.

**Change**:

- [ ] Build the gitleaks arguments as an array and run `gitleaks "${args[@]}"`
      and `docker run … "$image" "${args[@]}"`. Remove both SC2086 disables. Keep
      the six modes and their exit codes unchanged.
- [ ] Replace the `docker-shellscript-lint` loop with a NUL-safe loop over
      `git ls-files -z -- 'scripts/docker/*.sh'` that calls `check-shell-lint.sh`
      with `file=` for each existing file. The target sits in a "DO NOT edit"
      section, so keep the change minimal and say so in the PR description.
- [ ] Add a one-line reason beside each remaining disable:
  - `docker-run` and `docker-check-test` split `${args:-}` and `${cmd:-}` on
    purpose. Callers pass several options in one variable, for example
    `args="-p 8080:80" make docker-run`, and arrays cannot cross that
    environment-variable interface.
  - The `for version in $(_get-all-effective-versions) latest` loops expand
    Docker tags, whose grammar allows neither whitespace nor glob characters.
- [ ] Repeat the audit sweep for `SC2086`, `SC2206` and `SC2046` disables and
      for `for … in $(` across every tracked `.sh`, `.mk` and `Makefile`. Every
      remaining instance must be fixed or carry a reason. The vendored
      `scripts/docker/dgoss.sh` is out of scope.

**Tests**:

- [ ] `test-scan-secrets-works-from-a-path-with-spaces`, natively, for every
      check mode
- [ ] the same spaced path with the optional baseline and ignore files present
- [ ] `BRANCH_NAME` reaches gitleaks unchanged in `branch` mode

Use only valid Docker tags in any test. Tags cannot contain spaces.

**Verification**: the spaced-path reproduction passes natively.
`make scan-secrets`, `make docker-shellscript-lint` and `make test` pass.

---

## PR 35: Assess third-party tooling, installation approaches and template defaults

**Scope**: Assessment and recommendation
**Risk**: Low (documentation and planning). Spikes run outside the repository.
**Depends on**: nothing. Use the current `v2` toolchain as the baseline.
[D5](#decisions-needed-before-implementation) limits the Chainguard option.
**Files**: a new ADR in `docs/adr/`, written from the repository's ADR
template with the status Proposed

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

| Check                    | Benefit       | Basis                                  |
| ------------------------ | ------------- | -------------------------------------- |
| `scan-secrets`           | High          | GitGuardian data                       |
| `check-shell-lint`       | Medium        | ShellCheck catalogue, not enforced now |
| `check-markdown-links`   | Medium        | Judgement                              |
| `check-markdown-format`  | Low to medium | Maintainer experience                  |
| `check-file-format`      | Low to medium | Maintainer experience                  |
| `format-markdown-tables` | Low           | Cosmetic, supports MD060               |

- **Secrets** (GitGuardian 2025): 23.8 million new hardcoded secrets reached
  public GitHub in 2024, up 25%. 70% of secrets leaked in 2022 were still valid.
  35% of scanned private repositories held a plaintext secret. 58% of leaks were
  generic credentials, which push protection struggles to detect. A local scan
  stops a secret before it enters history.
- **Shell lint**: the ShellCheck README catalogues defects such as an unquoted
  `rm -rf "$VAR/"*`, masked exit codes in `export VAR=$(cmd)` and assignments
  lost in subshells. The 28 shell scripts pass today. The check is advisory
  (`||:` in `check-shell-lint`) and is in neither CI nor pre-commit, so a
  regression would go unnoticed.
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
keep secret scanning as a non-negotiable default, make shell lint a CI gate and
keep the format checks as a lighter tier.

**Current state**, verified on `v2` on 2026-10-03:

- mise is installed with `curl https://mise.run | sh`, as the README documents
  and as `make config` suggests when mise is missing.
- mise installs the 11 tools pinned in `[tools]`, including the `node` and
  `python` runtimes. Node runs markdownlint-cli and Prettier. Python runs
  pre-commit and the frontmatter check.
- `make format` fetches Prettier with `npx --yes prettier@3`, a floating major
  version that no file pins.
- Seven Docker fallback images are pinned by version tag and digest in
  `[_.docker]`. GitHub Actions are pinned by commit SHA. `dgoss.sh` is vendored.
  `make toolchain-install-gnu-macos` installs GNU tools and Bash through
  Homebrew.
- Dependabot covers `docker`, `github-actions`, `npm` and `pip`. It does not
  update `mise.toml`, so tool and image pins are refreshed by hand, as PR 24
  did. `.github/dependabot.yaml` sets no `cooldown`, so the default 3-day
  cooldown for version updates applies.
- All seven image wrappers run `docker run --rm --platform linux/amd64
--volume "$PWD…"` with no `--network`, `--read-only`, `--cap-drop`, user or
  read-only mount. A compromised image can read untracked files such as `.env`,
  change tracked files and reach the network. Native tools run with the
  developer's full privileges.
- No `mise.lock` is committed, so the transitive dependencies of the npm and
  PyPI tools are not fixed.
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
  - Not verified: which flavour holds all six tools, and whether versions can
    be pinned independently.
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
    modules. Building ourselves takes over that work for 11 tools, including
    the Haskell tools hadolint and shellcheck. View: low feasibility.
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
    attestations) where a backend supports them. Version 2 lockfiles also
    record the full npm and PyPI dependency graphs, which closes the transitive
    gap. URL checks need entries for every platform that installs tools, so set
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
  - View: complements container hardening in D. Check approval before any
    spike.
- **H. Release provenance verification.** `gh attestation verify` checks
  attestations for binaries and `oci://` images, and mise verifies GitHub
  attestations for backends that support them. The option is to verify in CI
  the tools that mise does not cover. Not verified: which of our 11 tools and
  7 images publish attestations. It needs the `gh` CLI and network access, and
  offline mode exists.
- **I. Isolated development environments.** Dev containers, Nix, devenv and
  Devbox pin or isolate the whole toolchain. I found only secondary
  comparisons, so their security properties are not verified. Dev containers
  need Docker and editor support, and Nix has a steeper learning curve. A single
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
      every check that is in neither CI nor pre-commit.
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
- [ ] Decide whether shell lint becomes a CI gate and whether the format checks
      form an optional tier.
- [ ] Build a threat-to-control table with four rows: a malicious release
      (cooldown, malware scan), a tampered artifact or registry (checksum,
      provenance, lockfile), a vulnerable dependency (patched builds, update
      cadence) and a compromised tool at run time (container hardening,
      sandbox). Map options A to J onto it and state what is left uncovered.
- [ ] Spike option D in a scratch clone: commit a `mise.lock`, add a Dependabot
      `cooldown`, apply the container flags to all seven wrappers and run the
      existing test suites. Record what breaks.
- [ ] Time-box one spike each for A (custom flavour), B1 and C. Measure image
      pull size, cold and warm `make lint` times natively and with
      `FORCE_USE_DOCKER=true`, the changes needed in wrappers and tests, and the
      cost per adopting team.
- [ ] Spike option E in a scratch clone: run rumdl against `markdownlint.yaml`,
      MD060 and the existing tests, and run prek against
      `scripts/config/pre-commit.yaml`. Record rule gaps, output differences
      and what Node and Python are still needed for.
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
- **Vendor outage**: `libraries.cgr.dev` has no uptime SLA, so name the
  fallback to upstream and who may approve it.
- **`FORCE_USE_DOCKER` parity**: native and Docker results must stay identical.
- **Existing configuration**: `gitleaks.toml`, `.gitleaksignore`, the lychee and
  markdownlint configuration and `dgoss.sh` must keep working.
- **Unapproved products**: Aikido Safe Chain and Socket Firewall are not
  approved, so no option may depend on them. Check the approval status of
  rumdl, prek, Harden-Runner and any other new supplier before a spike.
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
