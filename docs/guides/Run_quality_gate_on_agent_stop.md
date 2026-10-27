# Run the quality gate when the agent stops

- [Run the quality gate when the agent stops](#run-the-quality-gate-when-the-agent-stops)
  - [Overview](#overview)
  - [Key files](#key-files)
  - [When the gate runs](#when-the-gate-runs)
  - [Add or change a gate](#add-or-change-a-gate)
  - [Pause and resume](#pause-and-resume)
  - [Limits and cost](#limits-and-cost)
  - [Gates that cannot run](#gates-that-cannot-run)
  - [Troubleshooting](#troubleshooting)
  - [Testing](#testing)

## Overview

A GitHub Copilot agent may say it is done while `make lint` or `make test` still
fails. The quality gate closes that gap. When the agent tries to finish a turn,
a Stop hook runs the gates in
[`quality-gates.yaml`](../../scripts/config/quality-gates.yaml). If a blocking
gate fails, the hook sends the report back and the agent continues. The same
gates run on demand with `make quality-gate`.

Only GitHub Copilot is supported. The hook was checked in the VS Code Local
harness. The Copilot harness, which VS Code uses when the Session Target is
Copilot, and Copilot CLI read the same file and payload format, but they are not
tested. The hook does nothing in GitHub Actions, which also runs Copilot cloud
agent, because the gates need tools and network access that its sandbox lacks.

## Key files

- Scripts
  - [`quality-gate.sh`](../../scripts/quality/quality-gate.sh): hook handler and
    command line
  - [`quality-gate.jq`](../../scripts/quality/quality-gate.jq): validates and
    merges the gate configuration
- Configuration
  - [`quality-gates.yaml`](../../scripts/config/quality-gates.yaml): the gates
  - `scripts/config/quality-gates.d/*.yaml`: optional project gates
  - [`quality-gate.json`](../../.github/hooks/quality-gate.json): registers the
    hook
  - [`init.mk`](../../scripts/init.mk): make targets
- Tests
  - [`quality-gate.test.sh`](../../scripts/quality/tests/quality-gate.test.sh)

## When the gate runs

- **Prompt submitted.** A turn starts with the first prompt after the agent last
  finished. The hook records a baseline of the working tree then. It stores the
  changed paths with hashes of their contents and modes, never the prompt. A
  prompt that arrives before the agent finishes keeps the baseline. That covers
  a subagent's prompt, which VS Code sends with its parent's session, and the
  next prompt after a cancelled turn.
- **Agent stops.** The hook compares the tree with the baseline. It skips the
  gates when nothing changed in the turn, so a question never costs a run. It
  runs only the gates whose `paths` match the changed files. A change inside a
  nested repository, such as a submodule, counts. When it cannot read the tree
  or compare it, it runs every enabled gate and says so.
- **On demand.** `make quality-gate` runs the gates for the changed files. Use
  `scope=all` to run them for every file.

The gate does not run on commit. The Git pre-commit hooks in
[`pre-commit.yaml`](../../scripts/config/pre-commit.yaml) do that, including
`make test`, so an agent that commits runs the tests at both points.

The hook reads the gate list and its rules from the commit at the start of the
turn. A change to them, or a commit made during the turn, applies from the next
turn, and the report notes it. Until a commit holds the gate list, and when no
baseline says where the turn started, the hook says which gate list it used. The
hook still runs the script, the Make targets and the tests from the working
tree, so review changes to those too. `make quality-gate` and
`make quality-gate-list` read the working tree.

## Add or change a gate

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

## Pause and resume

```shell
make quality-gate-pause hours=2
make quality-gate-resume
```

Pausing is local to the worktree. It applies from the next prompt, so a pause
made while the agent works does not change the current turn. It expires after
the given hours, from 1 to 8. Use it for long refactors where a failing gate is
expected.

## Limits and cost

- `max_blocks` is the number of times the hook may block one turn. It is 1 by
  default and at most 5. Each block starts another agent turn that costs AI
  credits.
- The Copilot harness and Copilot CLI override a hook after eight blocks in a
  row. The Local harness documents no such limit, so `max_blocks` is the limit
  there. A hook that times out does not block.
- Each gate has a `timeout`. The hook stops a gate that runs over, and the
  report names it. Every process of the gate first gets `TERM`, so it can clean
  up, and any still running a second later gets `KILL`. The hook has a 300
  second limit that covers all the gates. When the editor stops the hook, at
  that limit or when you cancel the turn, the hook stops the running gate in the
  same way. A forced kill cannot be caught, so a gate may then outlive the hook.
- The report is cut to the last lines of each failing gate and about 8 KB in
  total.

## Gates that cannot run

When a gate cannot run for a reason that is not the code, it should print
`PREREQUISITE: <how to fix it>`. The Docker test suite's
`ERROR ... cannot run: ...` line is recognised too. The hook does not block for
such a gate. It tells you what to fix and that the gate's result is unknown, and
it tells the agent not to change the environment. `make quality-gate` still
fails, because the gate did not pass.

## Troubleshooting

- **The gate does not run.** In the Local harness, check that `chat.useHooks` is
  on. In the Copilot harness, check that `disableAllHooks` is not set in a hook
  file or a Copilot settings file. The last event is in
  `.git/quality-gate/last-hook.json`, the last run in `last-run.json` and each
  session's gate logs in `logs/<session>/`.
- **It runs twice.** User level hooks in `~/.copilot/hooks` run in addition to
  this one. Keep only one Stop hook that runs the gates.
- **It cannot run `jq` or `yq`.** Run `mise trust` and `make config`. A mise
  shim fails until `mise.toml` is trusted and the tools are installed. The `yq`
  must be mikefarah yq version 4, not the Python `yq`.
- **It blocks on a gate you do not want.** Set `enabled: false` in a drop-in, or
  pause it.

## Testing

```shell
./scripts/quality/tests/quality-gate.test.sh
make quality-gate-list
make quality-gate
```

The test suite also runs as part of `make test`.
