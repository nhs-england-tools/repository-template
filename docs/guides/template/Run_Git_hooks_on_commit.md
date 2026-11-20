# Run Git hooks on commit 🪝

- [Run Git hooks on commit 🪝](#run-git-hooks-on-commit-)
  - [Overview 🧭](#overview-)
  - [Key files 📁](#key-files-)
  - [Testing 🧪](#testing-)

## Overview 🧭

Git hooks are implemented as Make targets that pre-commit executes automatically
on each commit (after you run `make config` to install the hooks). Each hook
runs a `make` target, which in turn calls the appropriate script under
`scripts/quality/`. The same Make targets are reused in CI/CD, keeping local
checks and pipeline checks consistent.

The [pre-commit](https://pre-commit.com/) framework is a powerful tool for
managing Git hooks, providing automated hook installation and management
capabilities.

## Key files 📁

- Scripts
  - [`check-file-format.sh`](../../../scripts/quality/check-file-format.sh)
  - [`check-markdown-format.sh`](../../../scripts/quality/check-markdown-format.sh)
  - [`check-markdown-links.sh`](../../../scripts/quality/check-markdown-links.sh)
  - [`check-shell-lint.sh`](../../../scripts/quality/check-shell-lint.sh)
  - [`check-pipeline-contract.sh`](../../../scripts/quality/check-pipeline-contract.sh)
  - [`check-security-readiness.sh`](../../../scripts/quality/check-security-readiness.sh)
  - [`scan-secrets.sh`](../../../scripts/quality/scan-secrets.sh)
- Configuration
  - [`pre-commit.yaml`](../../../scripts/config/pre-commit.yaml)
  - [`init.mk`](../../../scripts/init.mk): make targets

## Testing 🧪

Review and trust `mise.toml` before installing the hooks. Run these commands
from the repository root. If you already ran `make config`, the hooks are
installed and you can skip `make githooks-config`:

```shell
mise trust mise.toml
make githooks-config
make githooks-run
```

`githooks-run` executes the entries in `pre-commit.yaml` against all files.
Secret scanning uses `check=whole-history`, as it does on each commit.

The security readiness hook runs after the pipeline contract hook. It always
runs, even when no files are selected, and shows its output on a pass. Run it
alone with:

```shell
pre-commit run check-security-readiness --config scripts/config/pre-commit.yaml --all-files
```

The same target runs after pipeline contract in commit-stage CI. See
[Security readiness](Harden_repository_security.md#security-readiness) for
offline rules and the security readiness checks on the engineering dashboard
that require remote state.

The last hook, `test`, runs `make test`. It needs the same prerequisites as the
tests, for example a running Docker. The agent quality gate is separate, see
[Run the quality gate when the agent stops](Run_quality_gate_on_agent_stop.md).
