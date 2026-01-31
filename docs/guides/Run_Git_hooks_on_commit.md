# Guide: Run Git hooks on commit

- [Guide: Run Git hooks on commit](#guide-run-git-hooks-on-commit)
  - [Overview](#overview)
  - [Key files](#key-files)
  - [Testing](#testing)

## Overview

Git hooks are implemented as Make targets that pre-commit executes automatically on each commit (after you run `make config` to install the hooks). Each hook runs a `make` target, which in turn calls the appropriate script under `scripts/quality/`. The same Make targets are reused in CI/CD, keeping local checks and pipeline checks consistent.

The [pre-commit](https://pre-commit.com/) framework is a powerful tool for managing Git hooks, providing automated hook installation and management capabilities.

## Key files

- Scripts
  - [`check-file-format.sh`](../../scripts/quality/check-file-format.sh)
  - [`check-markdown-format.sh`](../../scripts/quality/check-markdown-format.sh)
  - [`scan-secrets.sh`](../../scripts/quality/scan-secrets.sh)
- Configuration
  - [`pre-commit.yaml`](../../scripts/config/pre-commit.yaml)
  - [`init.mk`](../../scripts/init.mk): make targets

## Testing

You can run and test the process by executing the following commands from your terminal. These commands should be run from the top-level directory of the repository:

```shell
make githooks-config
make githooks-run
```
