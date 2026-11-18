# Run the quality gate when the agent stops 🚦

- [Run the quality gate when the agent stops 🚦](#run-the-quality-gate-when-the-agent-stops-)
  - [Overview 🧭](#overview-)
  - [Key files 📁](#key-files-)
  - [When the gate runs 🕒](#when-the-gate-runs-)
  - [Add or change a gate 🔧](#add-or-change-a-gate-)
  - [Pause and resume 🔁](#pause-and-resume-)
  - [Limits and cost 📏](#limits-and-cost-)
  - [Gates that cannot run 🚫](#gates-that-cannot-run-)
  - [When a gate fails 🔎](#when-a-gate-fails-)
  - [Troubleshooting 🔍](#troubleshooting-)
  - [Testing 🧪](#testing-)

## Overview 🧭

A GitHub Copilot agent may say it is done while `make lint` or `make test` still
fails. The quality gate closes that gap. When the agent tries to finish a turn,
a Stop hook runs the gates in
[`quality-gates.yaml`](../../../scripts/config/quality-gates.yaml). If a
blocking gate fails, the hook sends the report back and the agent continues. The
same gates run on demand with `make quality-gate`.

Only GitHub Copilot is supported. The hook was checked in the VS Code Local
harness. The Copilot harness, which VS Code uses when the Session Target is
Copilot, and Copilot CLI read the same file and payload format, but they are not
tested. The hook does nothing in GitHub Actions, which also runs Copilot cloud
agent, because the gates need tools and network access that its sandbox lacks.

## Key files 📁

- Scripts
  - [`quality-gate.sh`](../../../scripts/quality/quality-gate.sh): hook handler
    and command line
  - [`quality-gate.jq`](../../../scripts/quality/quality-gate.jq): validates and
    merges the gate configuration
- Configuration
  - [`quality-gates.yaml`](../../../scripts/config/quality-gates.yaml): the
    gates
  - `scripts/config/quality-gates.d/*.yaml`: optional project gates
  - [`quality-gate.json`](../../../.github/hooks/quality-gate.json): registers
    the hook
  - [`init.mk`](../../../scripts/init.mk): make targets
- Tests
  - [`quality-gate.test.sh`](../../../scripts/quality/tests/quality-gate.test.sh)

## When the gate runs 🕒

- **Prompt submitted.** A turn starts with the first prompt after the agent last
  finished. The hook records a baseline of the working tree then. It stores the
  changed paths with hashes of their contents and modes, never the prompt. A
  prompt that arrives before the agent finishes keeps the baseline. That covers
  a subagent's prompt, which VS Code sends with its parent's session, and the
  next prompt after a cancelled turn.
- **Agent stops.** The hook compares the tree with the baseline. It skips the
  gates when nothing changed in the turn, so a question never costs a run. It
  runs only the gates whose `paths` match the changed files. A change inside a
  nested repository, such as a submodule, counts. When it cannot read the tree,
  compare it or find the turn's baseline, it runs every enabled gate and records
  why. So a gate can run even when the agent changed nothing.
- **On demand.** `make quality-gate` runs the gates for the changed files. Use
  `scope=all` to run them for every file.

The gate does not run on commit. The Git pre-commit hooks in
[`pre-commit.yaml`](../../../scripts/config/pre-commit.yaml) do that, including
`make test`, so an agent that commits runs the tests at both points.

The hook reads the gate list and its rules from the commit at the start of the
turn. A change to them, or a commit made during the turn, applies from the next
turn, and the report notes it. Until a commit holds the gate list, and when no
baseline says where the turn started, the hook says which gate list it used. The
hook still runs the script, the Make targets and the tests from the working
tree, so review changes to those too. `make quality-gate` and
`make quality-gate-list` read the working tree.

## Add or change a gate 🔧

A gate is a Make target. Exit status 0 passes it. Put project gates in
`scripts/config/quality-gates.d/*.yaml` so template updates do not conflict:

```yaml
version: 1
gates:
  - name: architecture
    target: check-architecture
    paths: ["src/*"]
    mode: warn
  - name: test
    enabled: false
```

A gate with the name of an existing gate overrides only the fields it sets.
Drop-in files are read in byte order of their names, and dot files are ignored.
A name may use only ASCII letters, digits, `.`, `_` and `-`, starting with a
letter or digit, so a commit and the working tree order it alike. Commit the
file, as the hook reads the commit at the start of each turn. The fields are
documented in the header of `quality-gates.yaml`. Run `make quality-gate-list`
to see the result. An invalid file fails with the field and the reason.

In `paths`, `**/` matches any number of directories, `*` and `**` match any
characters including `/`, and `?` matches one character. Every other character
stands for itself, so `docs/**/*.md` matches `docs/README.md` and
`docs/guides/a.md`.

A gate can read the changed paths from the NUL-separated file named by
`QUALITY_GATE_CHANGED_FILES`.

## Pause and resume 🔁

```shell
make quality-gate-pause hours=2
make quality-gate-resume
```

Pausing is local to the worktree. It applies from the next prompt, so a pause
made while the agent works does not change the current turn. It expires after
the given hours, from 1 to 8. Use it for long refactors where a failing gate is
expected.

## Limits and cost 📏

- `max_blocks` is the number of times the hook may block one turn. It is 1 by
  default and at most 5. Each block starts another agent turn that costs AI
  credits.
- After a block, the hook runs the gates again only if the agent changed
  something. If it did not, the turn ends and the failures stand. The turn also
  ends if the hook cannot read how many times it has blocked.
- If a gate cannot start, the hook still blocks on failures it has already
  found and reports the remaining gates as unknown.
- The Copilot harness and Copilot CLI override a hook after eight blocks in a
  row. The Local harness documents no such limit, so `max_blocks` is the limit
  there. A hook that times out does not block.
- Each gate has a `timeout`. The hook stops a gate that runs over, and the
  report names it. Every process of the gate first gets `TERM`, so it can clean
  up, and any still running a second later gets `KILL`. The hook has a 60 second
  limit for all the gates combined, so the editor may stop it before an
  individual gate reaches its own timeout. When the editor stops the hook, at
  that limit or when you cancel the turn, the hook stops the running gate in the
  same way. A forced kill cannot be caught, so a gate may then outlive the hook.
- The report is cut to the last lines of each failing gate and about 8 KB in
  total. If even the list of gates does not fit, the report says how many it
  left out and where to find the full results.

## Gates that cannot run 🚫

A gate may not run because a tool or service is missing, for example Docker is
stopped. Its result is then unknown. The hook tells you what is missing and does
not block the agent. `make quality-gate` still fails.

`make test` handles this for you. For your own gate, do all three:

1. Print a line starting with `PREREQUISITE:` that says what is missing and how
   to check it.
2. Write `prerequisite` to the file named by `QUALITY_GATE_RESULT_FILE`.
3. Exit with a non-zero status.

Write the file only when a missing prerequisite is the only problem. Otherwise
the hook treats the gate as failed. Earlier versions needed only the
`PREREQUISITE:` line. A gate that still relies on that now blocks.

## When a gate fails 🔎

The hook does not give the agent permission to change files or the environment.

- In a review, report the failures. Do not fix them.
- When making changes, fix only the failures your changes caused.
- Report any other failure with the command and log the hook shows.
- Never weaken a test or turn off a gate to make it pass.

## Troubleshooting 🔍

- **The gate does not run.** In the Local harness, check that `chat.useHooks` is
  on. In the Copilot harness, check that `disableAllHooks` is not set in a hook
  file or a Copilot settings file. The last event is in
  `.git/quality-gate/last-hook.json`, the last run in `last-run.json` and each
  session's gate logs in `logs/<session>/`.
- **Gates ran during a review.** Check `selection_reason` in `last-run.json`.
  `changed-files` means files differ from the start of the turn, not that the
  agent changed them. Any other value means the hook could not tell, so it ran
  every gate. Either way, report the failures rather than fixing them.
- **It runs twice.** User level hooks in `~/.copilot/hooks` run in addition to
  this one. Keep only one Stop hook that runs the gates.
- **It cannot run `jq` or `yq`.** Run `mise trust` and `make config`. A mise
  shim fails until `mise.toml` is trusted and the tools are installed. The `yq`
  must be mikefarah yq version 4, not the Python `yq`.
- **It blocks on a gate you do not want.** Set `enabled: false` in a drop-in, or
  pause it.

To see what the hook decided, read its records before the next run replaces
them:

```shell
state="$(git rev-parse --git-path quality-gate)"
jq . "$state/last-hook.json" "$state/last-run.json"
```

Each record has these fields:

- `action`: what the hook did, for example `blocked`, `allowed` or `unchanged`.
- `selection_reason`: why it chose the gates, for example `changed-files`, or a
  fallback such as `missing-baseline` when it could not tell what changed.
- `scope`: `changed`, `all` or `none`.
- `session_status`: whether the editor sent a usable session ID.

The hook also keeps the last 50 events of each session in
`history/sessions/<session>/` and deletes state older than a week. The history
never holds prompts or test output. The next run replaces a gate's log, so copy
it if you need to keep it.

## Testing 🧪

```shell
./scripts/quality/tests/quality-gate.test.sh
make quality-gate-list
make quality-gate
```

The test suite also runs as part of `make test`.
