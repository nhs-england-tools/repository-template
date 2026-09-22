# Improvements Plan

This plan tracks a batch of repository-template improvements. Nine PRs have
already merged into `v2` (see [Merged record](#merged-record--scan-secret--markdown-linting-stack));
the remaining work is organised into a small number of **independent stacks** —
each an ordered chain of PRs that share files and build on one another — plus two
standalone PRs, all set out in [Outstanding work](#outstanding-work--proposed-stacks).
Stacks are independent of each other and can be raised in parallel; within a
stack, branch each PR off the one below it. Every outstanding PR is self-contained
and carries the context needed to raise it.

---

## PR index — what each PR is about

All 22 PRs plus one optional tweak, with a one-line summary each; full detail is
in the correspondingly named section below, and the outstanding ones are grouped
into stacks in [Outstanding work](#outstanding-work--proposed-stacks). The
_Status_ column names each outstanding PR's stack and its in-stack dependency.
**PR 22 is a fixed exception**: it must be the very last commit on `v2`, applied
immediately before merging `v2` into `main` — see its entry for why.

| PR             | What it is about                                                                                                                                                                                                                                                                                                                                                                                     | Status                                                                                |
| -------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| **PR 1**       | ADR template: require NHS Tech Radar alignment and replace star ratings with a weighted-scoring model (weights + totals).                                                                                                                                                                                                                                                                            | ✅ Merged ([#226](https://github.com/nhs-england-tools/repository-template/pull/226)) |
| **PR 2**       | Make `check-shell-lint` a real gate — fail on any finding — with a fast single native run and a pinned per-file Docker fallback.                                                                                                                                                                                                                                                                     | Stack 1 · base                                                                        |
| **PR 3**       | Add a discoverable `lint-shell` target and wire it into `make lint`.                                                                                                                                                                                                                                                                                                                                 | Stack 1 · needs PR 2                                                                  |
| **PR 4**       | Add a `check-shell-lint` composite action and commit-stage CI job so the shell-lint gate runs in CI.                                                                                                                                                                                                                                                                                                 | Stack 1 · needs PR 2–3                                                                |
| **PR 5**       | Behaviour-preserving shell best practices (`local` / `return 0` / quoting / docs) in the lib and simple quality scripts.                                                                                                                                                                                                                                                                             | Stack 2 · base                                                                        |
| **PR 6**       | Harden the Docker test suite (`docker.test.sh`) with best practices and test isolation.                                                                                                                                                                                                                                                                                                              | Stack 2 · needs PR 5                                                                  |
| **PR 7**       | Markdown check scripts: best practices + check-mode guard in `check-markdown-format.sh` and `check-markdown-links.sh`.                                                                                                                                                                                                                                                                               | ✅ Merged ([#231](https://github.com/nhs-england-tools/repository-template/pull/231)) |
| **PR 8**       | `scan-secrets.sh`: best practices + check-mode guard + a six-mode `check` vocabulary aligned with the other quality scripts (`all`, `staged-changes`, `working-tree-changes`, `branch`, `whole-history`, `last-commit`), plus native/Docker-parity fixes, all proven by scenario testing.                                                                                                            | ✅ Merged ([#230](https://github.com/nhs-england-tools/repository-template/pull/230)) |
| **Optional C** | Document shell linting and `FORCE_USE_DOCKER` in the README.                                                                                                                                                                                                                                                                                                                                         | Stack 1 · top (docs)                                                                  |
| **PR 9**       | Enforce a blank line after YAML frontmatter (markdownlint rule + fixes).                                                                                                                                                                                                                                                                                                                             | ✅ Merged ([#232](https://github.com/nhs-england-tools/repository-template/pull/232)) |
| **PR 10**      | Add `make format` to auto-format markdown tables with Prettier (native `npx` or Docker) plus scoped config.                                                                                                                                                                                                                                                                                          | ✅ Merged ([#234](https://github.com/nhs-england-tools/repository-template/pull/234)) |
| **PR 11**      | Skip deleted files in the markdown link check (branch mode).                                                                                                                                                                                                                                                                                                                                         | ✅ Merged ([#233](https://github.com/nhs-england-tools/repository-template/pull/233)) |
| **PR 12**      | Reduce gitleaks false positives (link-local IPs + comprehensive Python/JS-TS/Terraform lockfile allowlist).                                                                                                                                                                                                                                                                                          | ✅ Merged ([#229](https://github.com/nhs-england-tools/repository-template/pull/229)) |
| **PR 13**      | Copilot agent Stop hook that runs `make lint` + `make test` before finishing (snapshot-only, no prompt logging).                                                                                                                                                                                                                                                                                     | Standalone · opt-in (Preview)                                                         |
| **PR 14**      | Enrich the pull-request template with description/context guidance and a "How to test it" section.                                                                                                                                                                                                                                                                                                   | ✅ Merged ([#225](https://github.com/nhs-england-tools/repository-template/pull/225)) |
| **PR 15**      | Native/Docker tool parity: add native `.tool-versions` pins for the CLIs still missing one (shellcheck, hadolint, lychee, jq) so native runs match the Docker images. Stays on asdf; foundation for PR 20.                                                                                                                                                                                           | Stack 4 · base                                                                        |
| **PR 16**      | Harmonise the "unrecognised check mode" exit code across the quality-script suite so a usage error is distinct from a check failure.                                                                                                                                                                                                                                                                 | Stack 3 · needs PR 19                                                                 |
| **PR 17**      | Replace unquoted `$files` word-splitting with bash arrays in the markdown check/format scripts so paths with spaces are handled correctly.                                                                                                                                                                                                                                                           | Stack 3 · needs PR 16                                                                 |
| **PR 18**      | Resolve the `check=branch` base dynamically (explicit / CI / default-branch) and diff from the merge-base, so `lint-*` targets scope correctly for any branch merged to any base. Supersedes the removed Optional A.                                                                                                                                                                                 | Stack 3 · top · needs PR 17                                                           |
| **PR 19**      | Promote the former Optional B (now expected): modernise `check-file-format.sh` and adopt a `.editorconfigignore` so editorconfig exclusions use the same dedicated ignore-file pattern as the other linters; add self-documenting headers to the empty ignore-file placeholders.                                                                                                                     | Stack 3 · base                                                                        |
| **PR 20**      | Migrate the toolchain manager from `asdf` to `mise` (registry backends, no per-tool plugins, CI action, docs, ADR, `deps-outdated`/`upgrade`). Depends on PR 15.                                                                                                                                                                                                                                     | Stack 4 · top · needs PR 15, ADR-gated                                                |
| **PR 21**      | Add a `perform-static-analysis` CI job, using the official `SonarSource/sonarqube-scan-action`, so SonarQube Cloud analysis runs on PRs and `main` pushes now that automatic analysis is disabled.                                                                                                                                                                                                   | ✅ Merged ([#242](https://github.com/nhs-england-tools/repository-template/pull/242)) |
| **PR 22**      | Port the `main` push-trigger fix (`branches: ["**"]` -> `branches: [main]`) onto `v2`, stopping the double-run on every PR-branch commit. Must be the last commit on `v2`, applied immediately before merging `v2` into `main`.                                                                                                                                                                      | Standalone · must land last                                                           |
| **PR 23**      | Repo-wide word-splitting/quoting/globbing audit: harden the remaining unquoted `$filter`/`$cmd`/`$args` command-string splats and `for x in $(find …)` loops in `check-file-format.sh`, `scan-secrets.sh`, `docker.lib.sh`, `init.mk`, and `docker.mk` — the same anti-pattern PR 17 fixes, but for the scripts and Makefiles it doesn't touch. Confirms there are no tracked Python files affected. | Stack 3 · top · needs PR 18                                                           |

## Notes

- **Grouping principle: by file/layer, not scattered concern.** Where several
  changes touch the same script, they are stacked as successive layers rather than
  raised as conflicting parallel PRs — see
  [Outstanding work](#outstanding-work--proposed-stacks) for the full stack map.
- **Before merging Stack 1 (PR 2/3/4)**, run `make check-shell-lint` on `v2` to
  confirm the existing scripts already pass, so enabling the gate does not
  immediately break the build. `PR 4` is the genuinely new piece: without it the
  `lint-shell` gate never runs in CI.
- **PR 13 (Copilot hooks)** enforces `make lint`/`make test` when the agent tries
  to finish, using a minimal snapshot-only guard so no user prompt text is
  recorded. It needs `jq` and relies on the Copilot Agent hooks **Preview**
  feature, so it is opt-in.
- **PR 15 (native/Docker parity)** is a low-risk foundation: it adds native pins
  for the CLIs still missing one (`shellcheck`, `hadolint`, `lychee`, `jq`) so the
  native and Docker paths agree, without changing the tool manager — so it needs no
  ADR and can land on its own. (`editorconfig-checker`, `gitleaks` and `nodejs`
  are already at native/Docker parity.)
- **PR 20 (asdf → mise)** builds on PR 15 and is analysis-only and ADR-gated: it
  changes a documented, org-wide prerequisite, so land it behind maintainer
  agreement rather than as a routine stacked PR.
- **PR 18 supersedes the former Optional A**: rather than forcing `make lint` to
  check all markdown links repo-wide, it fixes `check=branch` base resolution so
  branch-scoped link checking is correct and consistent with the other `lint-*`
  targets. Optional A and its branch `pr/A-lint-all-links` have been removed from
  this plan.
- **Diffs are dropped once a PR is implemented.** Each PR's diff (or new-file
  content) below is illustrative only, to support review before implementation.
  As soon as a PR is merged, its diff block is removed from this plan and replaced
  with a one-line pointer to the merged PR.
- **Progress**: nine PRs are merged into `v2` — PR 1
  ([#226](https://github.com/nhs-england-tools/repository-template/pull/226)),
  PR 14 ([#225](https://github.com/nhs-england-tools/repository-template/pull/225)),
  and the scan-secret + markdown-linting stack: PR 12
  ([#229](https://github.com/nhs-england-tools/repository-template/pull/229)),
  PR 8 ([#230](https://github.com/nhs-england-tools/repository-template/pull/230)),
  PR 7 ([#231](https://github.com/nhs-england-tools/repository-template/pull/231)),
  PR 9 ([#232](https://github.com/nhs-england-tools/repository-template/pull/232)),
  PR 11 ([#233](https://github.com/nhs-england-tools/repository-template/pull/233)),
  PR 10 ([#234](https://github.com/nhs-england-tools/repository-template/pull/234)),
  plus PR 21 ([#242](https://github.com/nhs-england-tools/repository-template/pull/242)).
  All other PRs remain outstanding — see
  [Outstanding work](#outstanding-work--proposed-stacks).

---

## Outstanding work — proposed stacks

The outstanding items are organised into four independent stacks plus two
standalone PRs. Stacks are independent of each other and may be raised in
parallel; within a stack, branch each PR off the one below it and land them
bottom-up. The one fixed rule across everything is that **PR 22 lands last**.

| Stack | Theme                      | Order (bottom → top)                  | Notes                                                                                                                 |
| ----- | -------------------------- | ------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| 1     | Shell-lint gate            | PR 2 → PR 3 → PR 4 → Optional C       | Genuine dependency chain; the only hard sequence in the plan                                                          |
| 2     | Shell hygiene              | PR 5 → PR 6                           | Behaviour-preserving; disjoint files from Stack 1                                                                     |
| 3     | Quality-script consistency | PR 19 → PR 16 → PR 17 → PR 18 → PR 23 | Regrouped; all re-touch the same `scripts/quality/*` files; PR 23 also reaches into `docker.lib.sh` and the Makefiles |
| 4     | Toolchain modernisation    | PR 15 → PR 20                         | PR 20 is ADR-gated                                                                                                    |
| —     | Standalone                 | PR 13; PR 22                          | PR 13 opt-in any time; PR 22 must be the final commit before `v2`→`main`                                              |

**Stack 1 — Shell-lint gate.** `PR 2` (real gate in `init.mk`) → `PR 3`
(`lint-shell` target) → `PR 4` (CI action + job) → `Optional C` (README note). A
true linear chain: each step is inert until the one below it lands.

**Stack 2 — Shell hygiene.** `PR 5` (`docker.lib.sh`, `dockerfile-linter.sh`,
`check-shell-lint.sh`) → `PR 6` (`docker.test.sh`). Behaviour-preserving `local` /
`return 0` / docs. Touches different files from Stack 1, so the two can run in
parallel.

**Stack 3 — Quality-script consistency (regrouped).** `PR 19` (modernise
`check-file-format.sh` + adopt `.editorconfigignore`) → `PR 16` (harmonise the
`*)` unrecognised-mode exit code to `126`) → `PR 17` (bash arrays instead of
`$files` word-splitting) → `PR 18` (dynamic `check=branch` base via a shared
`quality.lib.sh`) → `PR 23` (repo-wide word-splitting/quoting/globbing audit).
Originally these were meant to fold into the per-file PRs
7/8/10, but those are now merged and closed, so they are raised as one ordered
stack instead. Because 16/17/18 each re-touch the same markdown/format scripts,
stacking them turns unavoidable overlap into clean successive layers: baseline
hygiene first, then a one-line exit-code change, then the array refactor, then the
larger base-resolution change on top. `PR 23` sits on top of all three, extending
the same word-splitting fix to the scripts PR 17 doesn't touch —
`check-file-format.sh`'s `$($filter)` splat, `scan-secrets.sh`'s `$cmd` splat, and
the equivalent `docker.lib.sh` / Makefile `for … in $(find …)` loops — so every
place the repo builds a dynamic argument or file list from an unquoted string is
treated consistently.

**Stack 4 — Toolchain modernisation.** `PR 15` (add the missing native
`.tool-versions` pins — `shellcheck`, `hadolint`, `lychee`, `jq` — so native runs
match the Docker images) → `PR 20` (asdf → mise, ADR-gated). Clean dependency:
PR 15 settles _what_ to pin, PR 20 changes _how_ it is provisioned.

**Standalone.**

- **PR 13** (Copilot Stop-hook) — opt-in, depends on a Preview feature; land any
  time as a single PR.
- **PR 22** (push-trigger fix) — **must be the last commit on `v2`**, immediately
  before merging to `main`. Never branch anything on top of it.

**Cross-stack notes.**

- Stacks 1–4 are mutually independent (disjoint files) and can be raised
  concurrently; only the order _within_ each stack is fixed.
- Stack 1's `PR 4` and Stack 4's `PR 15` both edit `.github/workflows/*`, but add
  different jobs/steps — trivial to reconcile.
- Stack 3's `PR 23` also touches `scripts/docker/docker.lib.sh` (Stack 2's file)
  and `scripts/init.mk` / `scripts/docker/docker.mk` (untouched by any other
  stack) to close out the remaining word-splitting instances outside the
  markdown scripts — a deliberate, small overlap with Stack 2, same precedent as
  the PR 4/PR 15 case above.
- Final landing order into `v2`: any of Stacks 1–4 and PR 13 in any order, then
  **PR 22 last**.

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

## PR 1: ADR template — weighted scoring and Tech Radar alignment

**Status**: ✅ Merged into `v2` as [#226](https://github.com/nhs-england-tools/repository-template/pull/226).

**Scope**: Documentation / process
**Risk**: Low
**Depends on**: nothing
**Files**: `docs/adr/ADR-nnn_Any_Decision_Record_Template.md`

**Context**: Improves the Architecture Decision Record template so decisions are
comparable and aligned with NHS engineering standards. It (a) requires technology
choices to align with the NHS Tech Radar, with deviations justified in-ADR, and
(b) replaces ad-hoc star ratings with an explicit weighted-scoring model
(`Weight` column, per-option _Top criteria_ and _Weighted option score_, and a
_Total score_ row). Fully independent of all other PRs.

**Verification**: `make check-markdown-format check=all` and visual review of the
rendered template.

**Diff**: Removed — merged as [#226](https://github.com/nhs-england-tools/repository-template/pull/226); see the PR for the full change.

---

## PR 2: Make `check-shell-lint` fast and fail on lint errors

**Scope**: Build system / quality gate
**Risk**: Low
**Depends on**: nothing
**Files**: `scripts/init.mk`

**Context**: The upstream `check-shell-lint` target swallows errors (`||:`) and
only checks whether _output_ is empty, so a failing script that prints nothing is
never caught and the target never exits non-zero — it is not a real gate. This
rewrite makes the gate **correct** (non-zero exit on any finding) **and fast**,
using a two-path design:

- **Fast path** (native ShellCheck present, Docker not forced): lint every script
  in a **single `xargs shellcheck` invocation** instead of one process/container
  per file — one process instead of N.
- **Fallback / forced-container path** (`FORCE_USE_DOCKER=true` or no native
  ShellCheck): lint per file via the existing `check-shell-lint.sh` wrapper so CI
  can pin the ShellCheck version; a `failed` flag guarantees a non-zero exit.

> **Empty-file guard**: piping an empty string into `xargs shellcheck` invokes
> ShellCheck with no arguments, which **blocks on stdin**. `if [ -z "$files" ]`
> avoids the hang. No new tool dependency — `xargs` is POSIX.

**Verification**:

- `make check-shell-lint` → `shell lint: ok`, exit `0` on a clean tree (fast path).
- Inject a script with a ShellCheck error → exit `1` (both paths).
- `FORCE_USE_DOCKER=true make check-shell-lint` → per-file container path, exit `0`
  on a clean tree.
- With all `*.sh` temporarily removed → `shell lint: ok`, exit `0` (does not hang).

**Diff**:

```diff
diff --git a/scripts/init.mk b/scripts/init.mk
--- a/scripts/init.mk
+++ b/scripts/init.mk
@@ check-shell-lint
-check-shell-lint: # Lint all shell scripts in this project, do not fail on error, just print the error messages @Quality
- output=$$(for file in $$(find . -type f -name "*.sh"); do
-  file=$${file} scripts/quality/check-shell-lint.sh ||:;
- done 2>&1)
- if [ -z "$$output" ]; then
-  echo "shell lint: ok"
- else
-  printf "%s\n" "$$output";
- fi
+check-shell-lint: # Lint all shell scripts in this project @Quality
+ files=$$(find . -type f -name "*.sh")
+ if [ -z "$$files" ]; then
+  echo "shell lint: ok"
+ elif command -v shellcheck > /dev/null 2>&1 && [[ ! "$${FORCE_USE_DOCKER:-false}" =~ ^(true|yes|y|on|1|TRUE|YES|Y|ON)$$ ]]; then
+  # Fast path: lint all scripts in a single native shellcheck invocation.
+  # shellcheck disable=SC2086
+  echo "$$files" | xargs shellcheck
+  echo "shell lint: ok"
+ else
+  # Fallback / forced-container path: per file via the wrapper so CI can
+  # pin ShellCheck independently of the runner's preinstalled version.
+  failed=0
+  for file in $$files; do
+   if ! file=$${file} scripts/quality/check-shell-lint.sh; then
+    failed=1
+   fi
+  done
+  [ $$failed -eq 0 ] || exit 1
+  echo "shell lint: ok"
+ fi
```

---

## PR 3: Add a `lint-shell` target and include it in `lint`

**Scope**: Build system
**Risk**: Low
**Depends on**: **PR 2** (so the newly wired-in gate actually enforces failures)
**Files**: `Makefile`

**Context**: Adds a discoverable `lint-shell` target (mirroring `lint-file-format`,
`lint-markdown-format`, `lint-markdown-links`), wires it into the aggregate `lint`
target, and adds it to the `.SILENT` list. After PR 2, `make lint` now enforces
shell linting.

**Verification**: `make lint-shell` runs the linter; `make lint` includes it;
`make help` lists `lint-shell` under `@Quality`.

**Diff**:

```diff
diff --git a/Makefile b/Makefile
--- a/Makefile
+++ b/Makefile
@@ -21,10 +21,14 @@ lint-markdown-format: # Check markdown formatting @Quality
 lint-markdown-links: # Check markdown links @Quality
  $(MAKE) check-markdown-links check=branch

+lint-shell: # Check shell scripts @Quality
+ $(MAKE) check-shell-lint
+
 lint: # Run linter to check code style and errors @Quality
  $(MAKE) lint-file-format
  $(MAKE) lint-markdown-format
  $(MAKE) lint-markdown-links
+ $(MAKE) lint-shell

 typecheck: # Run type checker @Quality
  # TODO: Implement type checking required for this repository
@@ -61,6 +65,7 @@ ${VERBOSE}.SILENT: \
  lint-file-format \
  lint-markdown-format \
  lint-markdown-links \
+ lint-shell \
  publish \
  test \
  typecheck \
```

---

## PR 4: Run shell lint in CI (new)

**Scope**: CI / quality gate
**Risk**: Low
**Depends on**: **PR 2** and **PR 3**
**Files**: `.github/actions/check-shell-lint/action.yaml` _(new)_,
`.github/workflows/stage-1-commit.yaml`

**Context**: This is a **gap in the current CI setup**. PR 3 adds a `lint-shell` target,
but the commit-stage workflow only runs four checks — `scan-secrets`,
`check-file-format`, `check-markdown-format`, `check-markdown-links` — and there is
**no `check-shell-lint` action** (verified: `.github/actions/` contains only those
four; `stage-1-commit.yaml` wires them at lines 45/56/67/78 and has no aggregation
gate). Without this PR the new shell-lint gate never runs in CI. The action mirrors
the existing `check-markdown-format` composite action but calls
`make check-shell-lint` (no `check`/`BRANCH_NAME` needed — the target has no
check modes).

**Verification**: open a PR with a shellcheck violation → the new
_"Check shell scripts"_ job fails in the commit stage.

**New file** — `.github/actions/check-shell-lint/action.yaml`:

```yaml
name: "Check shell script lint"
description: "Lint all shell scripts with ShellCheck"
runs:
  using: "composite"
  steps:
    - name: "Check shell script lint"
      shell: bash
      run: |
        make check-shell-lint
```

**Workflow change** — add a job after `check-markdown-links` (ends at line 78):

```diff
diff --git a/.github/workflows/stage-1-commit.yaml b/.github/workflows/stage-1-commit.yaml
--- a/.github/workflows/stage-1-commit.yaml
+++ b/.github/workflows/stage-1-commit.yaml
@@ -75,3 +75,12 @@ jobs:
       - name: "Check Markdown links"
         uses: ./.github/actions/check-markdown-links
+  check-shell-lint:
+    name: "Check shell scripts"
+    runs-on: ubuntu-latest
+    timeout-minutes: 2
+    steps:
+      - name: "Checkout code"
+        uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2
+        with:
+          fetch-depth: 0
+      - name: "Check shell scripts"
+        uses: ./.github/actions/check-shell-lint
```

> Pin `actions/checkout` to the same SHA the workflow already uses (currently
> `de0fac2…` = v6.0.2) so the repo's pinning convention is preserved.

---

## PR 5: Shell scripting best practices — library and simple quality scripts

**Scope**: Shell script quality
**Risk**: Low (behaviour-preserving)
**Depends on**: nothing
**Files**: `scripts/docker/docker.lib.sh`, `scripts/docker/dockerfile-linter.sh`,
`scripts/quality/check-shell-lint.sh`

**Context**: Applies three consistent, behaviour-preserving patterns to the files
whose _only_ change is hygiene: (a) explicit `return 0` at the end of each function
so success paths don't depend on the last command's exit code; (b) `local`
declarations for previously-implicit globals (`tag`, `line`, `content`,
`effective_line`, `name`, `version`, `file`); and (c) a one-line documentation
comment for functions that lacked one (`main`, `is-arg-true`). `v2` already
documents most functions, so this is a small, mechanical delta.

**Verification**: `make check-shell-lint` → `shell lint: ok`; Docker build/test
targets still succeed (`scripts/docker/tests/docker.test.sh` — requires Docker).

**Diff — `scripts/docker/docker.lib.sh`**:

```diff
diff --git a/scripts/docker/docker.lib.sh b/scripts/docker/docker.lib.sh
--- a/scripts/docker/docker.lib.sh
+++ b/scripts/docker/docker.lib.sh
@@ -26,7 +26,7 @@ function docker-build() {
   version-create-effective-file
   _create-effective-dockerfile

-  tag=$(_get-effective-tag)
+  local tag=$(_get-effective-tag)

   docker build \
     --progress=plain \
@@ -51,6 +51,8 @@ function docker-build() {
       docker tag "${tag}" "${DOCKER_IMAGE}:${version}"
     fi
   done
+
+  return 0
 }

 # Create the Dockerfile.effective file to bake in version info
@@ -62,6 +64,8 @@ function docker-bake-dockerfile() {

   version-create-effective-file
   _create-effective-dockerfile
+
+  return 0
 }

 # Run hadolint over the generated Dockerfile.
@@ -69,7 +73,10 @@ function docker-bake-dockerfile() {
 #  dir=[path to the image directory where the Dockerfile.effective is located, default is '.']
 function docker-lint() {
   local dir=${dir:-$PWD}
-  file=${dir}/Dockerfile.effective ./scripts/docker/dockerfile-linter.sh
+  local file="${dir}/Dockerfile.effective"
+  file="$file" ./scripts/docker/dockerfile-linter.sh
+
+  return 0
 }

 # Check test Docker image.
@@ -88,6 +95,8 @@ function docker-check-test() {
     "${DOCKER_IMAGE}:$(_get-effective-version)" 2>/dev/null \
     ${cmd:-} \
   | grep -q "${check}" && echo PASS || echo FAIL
+
+  return 0
 }

 # Run Docker image.
@@ -105,6 +114,8 @@ function docker-run() {
     ${args:-} \
     "${tag}" \
     ${DOCKER_CMD:-}
+
+  return 0
 }

 # Push Docker image.
@@ -118,6 +129,8 @@ function docker-push() {
   for version in $(dir="$dir" _get-all-effective-versions) latest; do
     docker push "${DOCKER_IMAGE}:${version}"
   done
+
+  return 0
 }

 # Remove Docker resources.
@@ -134,6 +147,8 @@ function docker-clean() {
     .version \
     Dockerfile.effective \
     Dockerfile.effective.dockerignore
+
+  return 0
 }

 # Create effective version from the VERSION file.
@@ -158,6 +173,8 @@ function version-create-effective-file() {
       sed "s/\(\${hash}\|\$hash\)/$(git rev-parse --short HEAD)/g" \
     > "$dir/.version"
   fi
+
+  return 0
 }

 # ==============================================================================
@@ -187,6 +204,7 @@ function docker-get-image-version-and-pull() {
   local versions_file="${TOOL_VERSIONS:=$(git rev-parse --show-toplevel)/.tool-versions}"
   local version="latest"
   if [ -f "$versions_file" ]; then
+    local line
     line=$(grep "docker/${name} " "$versions_file" | sed "s/^#\s*//; s/\s*#.*$//" | grep "${match_version:-".*"}" || true)
     [ -n "$line" ] && version=$(echo "$line" | awk '{print $2}')
   fi
@@ -214,6 +232,8 @@ function docker-get-image-version-and-pull() {
   fi

   echo "${name}:${version}"
+
+  return 0
 }

 # ==============================================================================
@@ -236,6 +256,8 @@ function _create-effective-dockerfile() {
   cp "${dir}/Dockerfile" "${dir}/Dockerfile.effective"
   _replace-image-latest-by-specific-version
   _append-metadata
+
+  return 0
 }

 # Replace image:latest by a specific version.
@@ -250,12 +272,16 @@ function _replace-image-latest-by-specific-version() {

   if [ -f "$versions_file" ]; then
     # First, list the entries specific for Docker to take precedence, then the rest but exclude comments
+    local content
     content=$(grep " docker/" "$versions_file"; grep -v " docker/" "$versions_file" ||: | grep -v "^#")
     echo "$content" | while IFS= read -r line; do
       [ -z "$line" ] && continue
-      line=$(echo "$line" | sed "s/^#\s*//; s/\s*#.*$//" | sed "s;docker/;;")
-      name=$(echo "$line" | awk '{print $1}')
-      version=$(echo "$line" | awk '{print $2}')
+      local effective_line
+      local name
+      local version
+      effective_line=$(echo "$line" | sed "s/^#\s*//; s/\s*#.*$//" | sed "s;docker/;;")
+      name=$(echo "$effective_line" | awk '{print $1}')
+      version=$(echo "$effective_line" | awk '{print $2}')
       sed -i "s;\(FROM .*\)${name}:latest;\1${name}:${version};g" "$dockerfile"
     done
   fi
@@ -276,6 +302,8 @@ function _replace-image-latest-by-specific-version() {

   # Do not ignore the issue if 'latest' is used in the effective image
   sed -Ei "/# hadolint ignore=DL3007$/d" "${dir}/Dockerfile.effective"
+
+  return 0
 }

 # Append metadata to the end of Dockerfile.
@@ -290,6 +318,8 @@ function _append-metadata() {
     "$(git rev-parse --show-toplevel)/scripts/docker/Dockerfile.metadata" \
   > "$dir/Dockerfile.effective.tmp"
   mv "$dir/Dockerfile.effective.tmp" "$dir/Dockerfile.effective"
+
+  return 0
 }

 # Print top Docker image version.
@@ -300,6 +330,8 @@ function _get-effective-version() {
   local dir=${dir:-$PWD}

   head -n 1 "${dir}/.version" 2> /dev/null ||:
+
+  return 0
 }

 # Print the effective tag for the image with the version. If you don't have a VERSION file
@@ -309,11 +341,13 @@ function _get-effective-version() {
 function _get-effective-tag() {

   local tag=$DOCKER_IMAGE
-  version=$(_get-effective-version)
+  local version=$(_get-effective-version)
   if [ -n "$version" ]; then
     tag="${tag}:${version}"
   fi
   echo "$tag"
+
+  return 0
 }

 # Print all Docker image versions.
@@ -324,6 +358,8 @@ function _get-all-effective-versions() {
   local dir=${dir:-$PWD}

   cat "${dir}/.version" 2> /dev/null ||:
+
+  return 0
 }

 # Print Git branch name. Check the GitHub variables first and then the local Git
@@ -340,4 +376,6 @@ function _get-git-branch-name() {
   fi

   echo "$branch_name"
+
+  return 0
 }
```

**Diff — `scripts/docker/dockerfile-linter.sh`**:

```diff
diff --git a/scripts/docker/dockerfile-linter.sh b/scripts/docker/dockerfile-linter.sh
--- a/scripts/docker/dockerfile-linter.sh
+++ b/scripts/docker/dockerfile-linter.sh
@@ -15,6 +15,7 @@ set -euo pipefail

 # ==============================================================================

+# Run dockerfile linter in native or Docker mode.
 function main() {

   cd "$(git rev-parse --show-toplevel)"
@@ -25,6 +26,8 @@ function main() {
   else
     file="$file" run-hadolint-in-docker
   fi
+
+  return 0
 }

 # Run hadolint natively.
@@ -34,6 +37,8 @@ function run-hadolint-natively() {

   # shellcheck disable=SC2001
   hadolint "$(echo "$file" | sed "s#$PWD#.#")"
+
+  return 0
 }

 # Run hadolint in a Docker container.
@@ -54,10 +59,15 @@ function run-hadolint-in-docker() {
       hadolint \
         --config /workdir/scripts/config/hadolint.yaml \
         "/workdir/$(echo "$file" | sed "s#$PWD#.#")"
+
+  return 0
 }

 # ==============================================================================

+# Check whether the supplied argument represents a true boolean value.
+# Arguments:
+#   $1=[value to evaluate]
 function is-arg-true() {

   if [[ "$1" =~ ^(true|yes|y|on|1|TRUE|YES|Y|ON)$ ]]; then
```

**Diff — `scripts/quality/check-shell-lint.sh`**:

```diff
diff --git a/scripts/quality/check-shell-lint.sh b/scripts/quality/check-shell-lint.sh
--- a/scripts/quality/check-shell-lint.sh
+++ b/scripts/quality/check-shell-lint.sh
@@ -15,6 +15,7 @@ set -euo pipefail

 # ==============================================================================

+# Run shellcheck in native or Docker mode.
 function main() {

   cd "$(git rev-parse --show-toplevel)"
@@ -26,6 +27,8 @@ function main() {
   else
     file="$file" run-shellcheck-in-docker
   fi
+
+  return 0
 }

 # Run ShellCheck natively.
@@ -35,6 +38,8 @@ function run-shellcheck-natively() {

   # shellcheck disable=SC2001
   shellcheck "$(echo "$file" | sed "s#$PWD#.#")"
+
+  return 0
 }

 # Run ShellCheck in a Docker container.
@@ -53,10 +58,15 @@ function run-shellcheck-in-docker() {
     --workdir /workdir \
     "$image" \
       "/workdir/$(echo "$file" | sed "s#$PWD#.#")"
+
+  return 0
 }

 # ==============================================================================

+# Check whether the supplied argument represents a true boolean value.
+# Arguments:
+#   $1=[value to evaluate]
 function is-arg-true() {

   if [[ "$1" =~ ^(true|yes|y|on|1|TRUE|YES|Y|ON)$ ]]; then
```

---

## PR 6: Docker test suite — best practices and test isolation

**Scope**: Docker test suite
**Risk**: Low
**Depends on**: PR 5 (shared conventions; different file, no merge conflict)
**Files**: `scripts/docker/tests/docker.test.sh`

**Context**: Applies the same hygiene as PR 5 and improves test isolation. Test
helpers previously relied on shell globals (`cmd`, `check`, `name`,
`match_version`, `TOOL_VERSIONS`, `DOCKER_CMD`) leaking from the calling scope;
they are now passed explicitly per command, making each test hermetic. The generic
suite hooks are renamed `test-docker-suite-setup`→`test-suite-setup` and
`…-teardown`→`test-suite-teardown`, and assertions use explicit
`&& return 0 || return 1`.

**Verification**: `scripts/docker/tests/docker.test.sh` (requires Docker running) →
all tests pass; `make check-shell-lint` → ok.

**Diff**:

```diff
diff --git a/scripts/docker/tests/docker.test.sh b/scripts/docker/tests/docker.test.sh
--- a/scripts/docker/tests/docker.test.sh
+++ b/scripts/docker/tests/docker.test.sh
@@ -13,6 +13,7 @@ set -euo pipefail

 # ==============================================================================

+# Execute the Docker shell test suite.
 function main() {

   cd "$(git rev-parse --show-toplevel)"
@@ -22,8 +23,8 @@ function main() {
   DOCKER_IMAGE=repository-template/docker-test
   DOCKER_TITLE="Repository Template Docker Test"

-  test-docker-suite-setup
-  tests=( \
+  test-suite-setup
+  local tests=( \
     test-docker-build \
     test-docker-image-from-signature \
     test-docker-version-file \
@@ -41,24 +42,31 @@ function main() {
     }
   done
   echo "Total: ${#tests[@]}, Passed: $(( ${#tests[@]} - status )), Failed: $status"
-  test-docker-suite-teardown
+  test-suite-teardown
   [ $status -gt 0 ] && return 1 || return 0
 }

 # ==============================================================================

-function test-docker-suite-setup() {
+# Set up suite-level fixtures.
+function test-suite-setup() {

   :
+
+  return 0
 }

-function test-docker-suite-teardown() {
+# Tear down suite-level fixtures.
+function test-suite-teardown() {

   :
+
+  return 0
 }

 # ==============================================================================

+# Test Docker image build.
 function test-docker-build() {

   # Arrange
@@ -69,17 +77,20 @@ function test-docker-build() {
   docker image inspect "${DOCKER_IMAGE}:$(_get-effective-version)" > /dev/null 2>&1 && return 0 || return 1
 }

+# Test replacement of `latest` image signatures.
 function test-docker-image-from-signature() {

   # Arrange
-  TOOL_VERSIONS="$(git rev-parse --show-toplevel)/scripts/docker/tests/.tool-versions.test"
+  local tool_versions
+  tool_versions="$(git rev-parse --show-toplevel)/scripts/docker/tests/.tool-versions.test"
   cp Dockerfile Dockerfile.effective
   # Act
-  _replace-image-latest-by-specific-version
+  TOOL_VERSIONS="$tool_versions" _replace-image-latest-by-specific-version
   # Assert
   grep -q "FROM python:.*-alpine.*@sha256:.*" Dockerfile.effective && return 0 || return 1
 }

+# Test creation of effective version file.
 function test-docker-version-file() {

   # Arrange
@@ -95,30 +106,36 @@ function test-docker-version-file() {
   ) && return 0 || return 1
 }

+# Test docker check helper command output.
 function test-docker-test() {

   # Arrange
-  cmd="python --version"
-  check="Python"
+  local cmd="python --version"
+  local check="Python"
+  local output
   # Act
-  output=$(docker-check-test)
+  output=$(cmd="$cmd" check="$check" docker-check-test)
   # Assert
-  echo "$output" | grep -q "PASS"
+  echo "$output" | grep -q "PASS" && return 0 || return 1
 }

+# Test docker run helper output.
 function test-docker-run() {

   # Arrange
-  cmd="python --version"
+  local docker_cmd="python --version"
+  local output
   # Act
-  output=$(docker-run)
+  output=$(DOCKER_CMD="$docker_cmd" docker-run)
   # Assert
-  echo "$output" | grep -Eq "Python [0-9]+\.[0-9]+\.[0-9]+"
+  echo "$output" | grep -Eq "Python [0-9]+\.[0-9]+\.[0-9]+" && return 0 || return 1
 }

+# Test cleanup of Docker image resources.
 function test-docker-clean() {

   # Arrange
+  local version
   version="$(_get-effective-version)"
   # Act
   docker-clean
@@ -126,22 +143,26 @@ function test-docker-clean() {
   docker image inspect "${DOCKER_IMAGE}:${version}" > /dev/null 2>&1 && return 1 || return 0
 }

+# Test retrieval and pull of external image version.
 function test-docker-get-image-version-and-pull() {

   # Arrange
-  name="ghcr.io/nhs-england-tools/github-runner-image"
-  match_version=".*-rt.*"
+  local name="ghcr.io/nhs-england-tools/github-runner-image"
+  local match_version=".*-rt.*"
   # Act
-  docker-get-image-version-and-pull > /dev/null 2>&1
+  name="$name" match_version="$match_version" docker-get-image-version-and-pull > /dev/null 2>&1
   # Assert
   docker images \
     --filter=reference="$name" \
     --format "{{.Tag}}" \
-  | grep -vq "<none>"
+  | grep -vq "<none>" && return 0 || return 1
 }

 # ==============================================================================

+# Check whether the supplied argument represents a true boolean value.
+# Arguments:
+#   $1=[value to evaluate]
 function is-arg-true() {

   if [[ "$1" =~ ^(true|yes|y|on|1|TRUE|YES|Y|ON)$ ]]; then
```

---

## PR 7: Markdown check scripts — best practices and check-mode guard

**Status**: ✅ Merged into `v2` as [#231](https://github.com/nhs-england-tools/repository-template/pull/231).

**Scope**: Shell script quality / defensive scripting
**Risk**: Low
**Files**: `scripts/quality/check-markdown-format.sh`,
`scripts/quality/check-markdown-links.sh`

**Summary**: Applies the shared shell conventions and adds a `*)` catch-all to the
`case $check` dispatch so an unrecognised mode fails loudly instead of silently
producing an empty file list. Also sets an explicit `--workdir /workdir` on the
markdownlint Docker run and aligns `check-markdown-links.sh`'s default mode
(`all` → `working-tree-changes`) with the sibling check scripts.

---

## PR 8: `scan-secrets.sh` — best practices, guard, and a six-mode check vocabulary

**Status**: ✅ Merged into `v2` as [#230](https://github.com/nhs-england-tools/repository-template/pull/230).

**Scope**: Shell script quality / bug fix
**Risk**: Low
**Files**: `scripts/quality/scan-secrets.sh`, `scripts/init.mk` (make-target help text)

**Summary**: Hardens `scan-secrets.sh` (`local` declarations, a `*)` guard that
exits `126`, quoted `--workdir "$dir"`, consistent `--redact`, and explicit
exit-code propagation so the aggregated `all` mode cannot mask an earlier leak).
Replaces the old three-mode dispatch with the same six-mode `check` vocabulary as
the other quality scripts:

| `check=`               | Scans                                                       |
| ---------------------- | ----------------------------------------------------------- |
| `all`                  | staged + working-tree + branch (a full local check)         |
| `staged-changes`       | the index (changes staged for commit)                       |
| `working-tree-changes` | unstaged working-tree modifications                         |
| `branch`               | commits made on this branch since it diverged from the base |
| `whole-history`        | every commit on every branch — **the default**              |
| `last-commit`          | the tip commit only                                         |

The default stays `whole-history`, matching the `scan-secrets` make target and the
CI/pre-commit wiring; the new `branch` mode carries the scoped behaviour. A
native/Docker fingerprint-parity fix runs native gitleaks with
`GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null` so a developer's global
git config cannot make native fingerprints diverge from CI's Docker run.

---

## Optional PRs (maintainer's discretion)

### Optional C: Document shell linting and `FORCE_USE_DOCKER` in the README

**File**: `README.md` · **Risk**: Very low · **Type**: documentation

After PRs 3–4, add a one-line note that shell scripts are linted with ShellCheck
via `make lint-shell` (part of `make lint`), and that all checks honour the
`FORCE_USE_DOCKER` environment variable. Improves discoverability for teams
adopting the template.

---

## PR 9: Enforce a blank line after YAML frontmatter

**Status**: ✅ Merged into `v2` as [#232](https://github.com/nhs-england-tools/repository-template/pull/232).

**Scope**: Markdown quality
**Risk**: Low
**Files**: `scripts/quality/check-markdown-format.sh`

**Summary**: markdownlint does not enforce a blank line between a file's closing
YAML frontmatter `---` and the first content line (MD022 ignores frontmatter
delimiters). A small `check-frontmatter-blank-line` function, invoked after
markdownlint, flags files whose content starts immediately after the frontmatter.
Native, `python3`-only (already present wherever `pre-commit` runs).

---

## PR 10: Auto-format markdown tables with Prettier

**Status**: ✅ Merged into `v2` as [#234](https://github.com/nhs-england-tools/repository-template/pull/234).

**Scope**: Markdown tooling / developer experience
**Risk**: Low — **adds a new runtime dependency** (Node/`npx` or the Docker `node` image)
**Files**: `scripts/quality/format-markdown-tables.sh` (new),
`scripts/config/prettierrc.yaml` (new), `scripts/config/.prettierignore` (new),
`scripts/config/markdownlint.yaml`, `Makefile`, `.tool-versions`

**Summary**: Implements the `format` target (previously a TODO stub) as a Prettier
wrapper that aligns markdown tables to the MD060 `aligned` style, run either
natively via `npx prettier@3` or through the pinned `node` Docker image. Prettier
is scoped to tables only (`proseWrap: preserve`), and `.tool-versions` gains a
matching native `nodejs` pin alongside the pinned `node` Docker image so native
and Docker execution share the same runtime. `make lint-markdown-format` enforces
the MD060 rule.

---

## PR 11: Skip deleted files in the markdown link check

**Status**: ✅ Merged into `v2` as [#233](https://github.com/nhs-england-tools/repository-template/pull/233).

**Scope**: Robustness
**Risk**: Low
**Files**: `scripts/quality/check-markdown-links.sh`

**Summary**: In `check=all` mode the link checker fed `git ls-files "*.md"`
straight to lychee, which can list a tracked file deleted but not yet staged,
making lychee error on a missing path. The fix filters the list to existing files
only. The same deleted-file filter was extended to `check-markdown-format.sh`.

---

## PR 12: Reduce gitleaks false positives (link-local IPs + lockfile allowlist)

**Status**: ✅ Merged into `v2` as [#229](https://github.com/nhs-england-tools/repository-template/pull/229).

**Scope**: Secret-scanning config
**Risk**: Low
**Files**: `scripts/config/gitleaks.toml`

**Summary**: Extends the gitleaks allowlist with two general-purpose, low-risk
categories: the `169.254.0.0/16` link-local IPv4 range in the IP-address allowlist
regex, and a single regex matching any path ending in `.lock` (at any depth) to
cover Python, JavaScript/TypeScript, and Terraform/OpenTofu lockfiles whose hashes
routinely trip secret scanners. `package-lock.json`, `npm-shrinkwrap.json`, and
`pnpm-lock.yaml` remain covered by gitleaks' own default global allowlist. Both
reduce false positives without weakening real secret detection.

---

## PR 13 (optional): Copilot agent hook to run `make lint` + `make test`

**Scope**: Developer experience / automated quality gate
**Risk**: Low — **opt-in; depends on a Preview feature**
**Depends on**: nothing (uses the existing `make lint`; `make test` may be a stub)
**Files**: `.github/hooks/quality-gates.json` (new), `scripts/hooks/stop-gate.sh`
(new), `scripts/hooks/record-tree-snapshot.sh` (new), `scripts/hooks/_common.sh`
(new)

**Context**: VS Code Copilot **Agent hooks** run a command at chat lifecycle
events. This wires a `Stop` hook that runs `make lint` then `make test` when the
agent tries to finish and **blocks completion** (returning the failure output to
the agent) if either fails — automating the inner quality loop without relying on
the agent remembering to run the gates. Only this general-purpose Stop-gate
capability is included; no other hook behaviours (for example prompt logging or
workflow-mode switching) are part of this PR.

Two guards keep it usable:

- **Re-entry guard** — if the hook is already active (`stop_hook_active`) it allows
  completion, preventing infinite loops.
- **No-edit guard** — a `UserPromptSubmit` hook records a working-tree fingerprint
  at the start of the turn; the Stop gate skips `make lint`/`make test` when the
  tree is unchanged (a pure question-and-answer turn).

> **Privacy design decision**: the `UserPromptSubmit` hook deliberately does
> **not** log verbatim user prompt text anywhere. `record-tree-snapshot.sh`
> writes only the tree fingerprint the no-edit guard needs — no prompt content
> is recorded.

**Maturity caveat (why optional)**: Copilot Agent hooks (`.github/hooks/*.json`)
are a **Preview** feature and the schema may change (VS Code also reads the Claude
Code `.claude/settings.json` format). Adopt as an opt-in developer aid, not a hard
gate. `make test` is a TODO stub in `v2` today, so that half of the gate is a no-op
until the repository implements tests (a stub exits `0`, so the gate still passes).

**Dependencies**: `jq`, `make`, `git`, and `shasum`/`cksum` (the last is near
universal). `jq` is **not** currently pinned in `.tool-versions` — add it or document
it as a prerequisite.

**Verification**:

- Edit a tracked file so it fails `make lint`, then end the chat → the Stop hook
  **blocks** with the lint output; fix it and end again → completes.
- Ask a question without editing anything → the no-edit guard skips the gates.
- `echo '{"stop_hook_active":true}' | ./scripts/hooks/stop-gate.sh` → emits `{}`
  (re-entry guard).

**New file — `.github/hooks/quality-gates.json`**:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "type": "command",
        "command": "./scripts/hooks/record-tree-snapshot.sh",
        "timeout": 10000
      }
    ],
    "Stop": [
      {
        "type": "command",
        "command": "./scripts/hooks/stop-gate.sh",
        "timeout": 60000
      }
    ]
  }
}
```

**New file — `scripts/hooks/stop-gate.sh`**:

```bash
#!/bin/bash

set -euo pipefail

# Stop hook that runs `make lint` and `make test` before allowing the agent to
# complete. Blocks completion if either quality gate fails.
#
# Usage:
#   $ echo '{}' | ./stop-gate.sh
#
# Dependencies: jq, make, git.
#
# Notes:
#   1) Invoked by VS Code Copilot Agent hooks (a Preview feature; schema may
#      change). Do not run interactively.
#   2) Uses a re-entry guard to prevent infinite loops.
#   3) The no-edit guard relies on record-tree-snapshot.sh (UserPromptSubmit).
#   4) Diagnostics: ${COPILOT_PROMPT_LOG_DIR:-~/.local/state/copilot-prompts}/{hooks,errors}.log

# ==============================================================================

# shellcheck disable=SC1091
source "$(dirname "$0")/_common.sh"

function main() {

  hook_init_diagnostics "Stop"

  cd "$(git rev-parse --show-toplevel)"

  local input
  input=$(cat)

  # Re-entry guard: if this hook is already active, allow completion.
  local hook_active
  hook_active=$(echo "$input" | jq -r '.stop_hook_active // empty')
  if [[ "$hook_active" == "true" ]]; then
    echo '{}'
    return 0
  fi

  # No-edit guard: compare the current tree fingerprint with the snapshot taken
  # at UserPromptSubmit. If they match, this turn did not modify any files
  # (typical Q&A) and the quality gates have nothing to verify.
  local snapshot_path
  snapshot_path="$(hook_tree_snapshot_path)"
  if [[ -f "$snapshot_path" ]]; then
    local before after
    before="$(cat "$snapshot_path" 2>/dev/null || true)"
    after="$(hook_tree_fingerprint)"
    if [[ -n "$before" && "$before" == "$after" ]]; then
      hook_diag "Stop: tree unchanged since UserPromptSubmit; skipping make lint/test"
      echo '{}'
      return 0
    fi
  fi

  local lint_output
  local lint_exit=0
  lint_output=$(make lint 2>&1) || lint_exit=$?

  if [[ $lint_exit -ne 0 ]]; then
    emit-block "make lint failed" "$lint_output"
    return 0
  fi

  local test_output
  local test_exit=0
  test_output=$(make test 2>&1) || test_exit=$?

  if [[ $test_exit -ne 0 ]]; then
    emit-block "make test failed" "$test_output"
    return 0
  fi

  # Both gates passed - allow completion.
  echo '{}'

  return 0
}

# Emit a blocking response with the given reason and detail.
# Arguments:
#   $1 - reason summary
#   $2 - detail output
function emit-block() {

  local reason="$1"
  local detail="$2"

  jq -n \
    --arg event "Stop" \
    --arg decision "block" \
    --arg reason "$reason" \
    --arg detail "$detail" \
    '{hookSpecificOutput: {hookEventName: $event, decision: $decision, reason: $reason, additionalContext: $detail}}'

  return 0
}

# ==============================================================================

main "$@"

exit 0
```

**New file — `scripts/hooks/record-tree-snapshot.sh`** (a snapshot-only hook that
never logs prompt text):

```bash
#!/bin/bash

set -euo pipefail

# UserPromptSubmit hook: record the working-tree fingerprint so the Stop gate
# (stop-gate.sh) can detect whether the turn changed any files and skip
# `make lint` / `make test` on pure question-and-answer turns.
#
# This does NOT record prompt text.
#
# Usage:
#   $ echo '{}' | ./record-tree-snapshot.sh

# ==============================================================================

# shellcheck disable=SC1091
source "$(dirname "$0")/_common.sh"

function main() {

  hook_init_diagnostics "UserPromptSubmit"

  # The hook payload is not needed; consume and discard stdin.
  cat > /dev/null

  hook_tree_fingerprint > "$(hook_tree_snapshot_path)" 2>/dev/null || true

  echo '{}'

  return 0
}

main "$@"

exit 0
```

**New file — `scripts/hooks/_common.sh`** (diagnostics + tree-fingerprint helpers;
no prompt logging):

```bash
#!/bin/bash

# Shared diagnostics helpers for VS Code Agent hook scripts.
#
# Source this file at the top of every hook script:
#
#   source "$(dirname "$0")/_common.sh"
#   hook_init_diagnostics "<hook-event-name>"
#
# After init, stderr from the calling script is appended to a sibling
# `errors.log` so set -e exits, jq parse errors, and missing dependencies
# leave an inspectable trail. Each invocation also appends a one-line marker
# to `hooks.log` so it is possible to see whether a hook fired at all.
#
# Log location (first match wins):
#   1. $COPILOT_PROMPT_LOG_DIR  (explicit override)
#   2. $XDG_STATE_HOME/copilot-prompts
#   3. $HOME/.local/state/copilot-prompts

# ==============================================================================

# Resolve and create the diagnostics log directory.
# Echoes the absolute path on stdout. Safe to call multiple times.
function hook_log_dir() {

  local log_dir
  if [[ -n "${COPILOT_PROMPT_LOG_DIR:-}" ]]; then
    log_dir="$COPILOT_PROMPT_LOG_DIR"
  elif [[ -n "${XDG_STATE_HOME:-}" ]]; then
    log_dir="$XDG_STATE_HOME/copilot-prompts"
  else
    log_dir="$HOME/.local/state/copilot-prompts"
  fi
  mkdir -p "$log_dir"
  echo "$log_dir"
}

# Initialise diagnostics for the calling hook.
# Arguments:
#   $1 - hook event name (e.g. "Stop", "UserPromptSubmit")
function hook_init_diagnostics() {

  local event="${1:-unknown}"
  local log_dir
  log_dir="$(hook_log_dir)"

  exec 2>>"${log_dir}/errors.log"

  printf '[%s] %s pid=%s cwd=%s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    "$event" \
    "$$" \
    "$(pwd)" \
    >>"${log_dir}/hooks.log"
}

# Append a free-form diagnostic line to errors.log with a timestamp prefix.
# Arguments:
#   $@ - message tokens (joined with spaces)
function hook_diag() {

  printf '[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >&2
}

# Compute a stable path for the per-repo working-tree snapshot used to detect
# whether the current turn modified any files. Keyed by an absolute-path hash so
# concurrent repositories do not collide. Echoes the snapshot file path.
function hook_tree_snapshot_path() {

  local log_dir
  log_dir="$(hook_log_dir)"

  local repo_root
  repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

  local key
  if command -v shasum >/dev/null 2>&1; then
    key="$(printf '%s' "$repo_root" | shasum | awk '{print $1}')"
  else
    key="$(printf '%s' "$repo_root" | cksum | awk '{print $1}')"
  fi

  echo "${log_dir}/turn-snapshot.${key}"
}

# Compute a fingerprint of the current working tree (untracked + staged +
# unstaged) so two snapshots can be compared cheaply. Echoes the hex digest, or
# the literal string "no-git" when not inside a git repo.
function hook_tree_fingerprint() {

  if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
    echo "no-git"
    return 0
  fi

  local hasher
  if command -v shasum >/dev/null 2>&1; then
    hasher="shasum"
  else
    hasher="cksum"
  fi

  { git status --porcelain=v1 2>/dev/null; git diff --no-color 2>/dev/null; \
    git diff --cached --no-color 2>/dev/null; } \
    | "$hasher" | awk '{print $1}'
}
```

---

## PR 14: Enrich the pull-request template to elicit high-quality descriptions

**Status**: ✅ Merged into `v2` as [#225](https://github.com/nhs-england-tools/repository-template/pull/225).

**Scope**: Documentation / contributor & coding-agent experience
**Risk**: Low (template-only; no code paths)
**Depends on**: nothing
**Files**: `.github/pull_request_template.md`

**Context**: The current PR template offers only one-line prompts for _Description_
and _Context_ and has **no testing section**, so pull requests — increasingly
authored by coding agents — vary widely in quality. This rewrites the guidance to
elicit the structure of a known-good PR (for example #222): a summary plus a
file-by-file change list in _Description_; motivation, previous behaviour, and
trade-offs in _Context_; and a new **How to test it** section with prerequisites,
numbered tests, expected results, and clean-up. Guidance is written as explicit
instructions because a coding agent usually populates it. Existing sections (Type
of changes, Checklist, Sensitive Information Declaration) are preserved, and one
checklist item is added to confirm the testing steps were provided.

**Verification**: open a draft PR → the rendered template shows the new _How to
test it_ section and the expanded guidance; `make check-markdown-format check=all`
passes on the file.

**Diff**: Removed — merged as [#225](https://github.com/nhs-england-tools/repository-template/pull/225); see the PR for the full change.

---

## PR 15: Native/Docker tool parity and a complete dependency inventory

**Scope**: Build system / developer tooling / dependency pinning
**Risk**: Low–Medium — adds native version pins (and, under asdf, the matching
plugins) and reconciles version drift. It changes **no** prerequisite and **no**
tool manager, so it needs no ADR; the behaviour of every quality gate is preserved.
**Depends on**: nothing hard. It complements **PR 2**/**PR 4** (pinning `shellcheck`
natively makes the shell-lint fast path reproducible) and **PR 10** (which already
adds a native `nodejs` pin version-matched to its `node` Docker image). It is the
**foundation for PR 20** (asdf → mise): this PR decides _what_ to pin and reaches
native/Docker parity; PR 20 changes _how_ those pins are provisioned.
**Files**: `.tool-versions`, `scripts/init.mk`, `.github/workflows/*.yaml`

> **Note**: net-new work (this repository does not pin these natively today). No
> diff at this stage — design and analysis only. This PR stays on **asdf**; the
> tool-manager swap is the separate **PR 20**.

**Context**: `.tool-versions` pins tool versions and is installed by
`scripts/init.mk` (`_install-dependency` → `asdf plugin add` + `asdf install`;
`_install-dependencies` loops over the non-comment lines). The file plays two roles:
real native pins (top section) and Docker-image pins (the `# docker/...` comment
block, parsed by `docker.lib.sh`). The problem this PR fixes is an **under-pinned
native path**: only a handful of tools are pinned for native execution (`gitleaks`,
`pre-commit`, `editorconfig-checker`, and — once PR 10 lands — `nodejs`). Everything
else the scripts shell out to natively — `shellcheck`, `hadolint`, `lychee`,
`markdownlint`, and the `jq` the README lists as a prerequisite — runs at **whatever
version the developer's machine happens to have**, while the pinned versions only
take effect in Docker mode. Native and Docker runs are therefore not guaranteed to
agree.

**Analysis 1 — how the native path is wired today**:

- `scripts/init.mk`: `_install-dependency` runs `asdf plugin add ${name} ||:` then
  `asdf install ${name}`; `_install-dependencies` greps `^[a-z]` lines out of
  `.tool-versions` and calls `_install-dependency` for each.
- `Makefile` `config::` calls `$(MAKE) _install-dependencies`.
- Every quality wrapper (`scan-secrets.sh`, `check-file-format.sh`,
  `check-markdown-format.sh`, `check-markdown-links.sh`, `check-shell-lint.sh`,
  `dockerfile-linter.sh`, `format-markdown-tables.sh`) already picks native _or_
  Docker via `command -v <tool>` + `FORCE_USE_DOCKER`. This PR pins the native side;
  the Docker fallback is untouched.

**Analysis 2 — dependency inventory and the native/Docker parity gap** (the core of
the "is everything in `.tool-versions`, e.g. `jq`?" question). "Native pin today" is
the `.tool-versions` top section; "Docker pin today" is the `# docker/...` block:

| Tool                               | Used natively by                                    | Native pin today      | Docker pin today         | Parity action                                                        |
| ---------------------------------- | --------------------------------------------------- | --------------------- | ------------------------ | -------------------------------------------------------------------- |
| `shellcheck`                       | `check-shell-lint.sh`, `check-shell-lint` fast path | ✗ (uses host version) | ✓ `v0.11.0`              | Pin `aqua:koalaman/shellcheck` to match the image                    |
| `hadolint`                         | `dockerfile-linter.sh`                              | ✗                     | ✓ `2.14.0`               | Pin `aqua:hadolint/hadolint` to match the image                      |
| `lychee`                           | `check-markdown-links.sh`                           | ✗                     | ✓ `0.22.0`               | Pin `aqua:lycheeverse/lychee`                                        |
| `markdownlint(-cli)`               | `check-markdown-format.sh`                          | ✗                     | ✓ `v0.47.0`              | Pin `node` + `markdownlint-cli2` (npm), or keep Docker-only          |
| `editorconfig-checker`             | `check-file-format.sh`                              | ✓ `3.11.1`            | ✓ `v3.11.1`              | Keep — already at parity                                             |
| `node` / `npx`                     | `format-markdown-tables.sh` (Prettier, PR 10)       | ✓ `22.23.2` (PR 10)   | ✓ `22.23.2-slim` (PR 10) | Keep — already at parity once PR 10 lands                            |
| `jq`                               | README lists it as a prerequisite                   | ✗                     | —                        | **Pin `aqua:jqlang/jq`** — currently unpinned despite being required |
| `gitleaks`                         | `scan-secrets.sh`                                   | ✓ `8.30.0`            | ✓ `v8.30.0`              | Keep — already at parity                                             |
| `pre-commit`                       | `githooks-config`                                   | ✓ `4.5.1`             | —                        | Keep (native-only is fine)                                           |
| `git`,`make`,`docker`,`gh`,`rsync` | various                                             | n/a (system)          | n/a                      | Out of scope — host/system tools, not version-managed here           |

The gap is stark: only 3–4 tools are pinned for native use, but 4 others are
Docker-only and one (`jq`) is unpinned entirely. Pinning **every** CLI the scripts
call makes `make lint`/`make test` produce identical results native or
`FORCE_USE_DOCKER=true` — full native/Docker parity. (`node` is already handled by
PR 10: native `nodejs 22.23.2` plus the narrowed `docker/node 22.23.2-slim` pin.
The registry shorthands, e.g. `aqua:jqlang/jq`, are the **mise** form used by
PR 20; under asdf this PR adds the equivalent plugin + pinned version.)

**Analysis 3 — version currency** ("are these the latest versions?"). Current
pins are `gitleaks 8.30.0`, `pre-commit 4.5.1`, `editorconfig-checker 3.11.1`,
plus the Docker-only pins `shellcheck v0.11.0`, `lychee 0.22.0`,
`markdownlint-cli v0.47.0`, `hadolint 2.14.0`. Rather than hard-code "latest"
numbers that go stale, this PR flags the one confirmed gap: `jq` is
**unpinned** despite being listed as a prerequisite in the README. Everything
else should be confirmed against upstream at implementation time — not guessed
here. (PR 20 adds a repeatable `mise outdated`/`upgrade` workflow for this.)

**Proposed changes** (prose, no diff):

- **`.tool-versions`** — promote all natively-used CLIs into the pinned top section
  (`jq`, `shellcheck`, `hadolint`, `lychee`, `editorconfig-checker`, plus the
  existing `gitleaks`, `pre-commit`, and PR 10's `nodejs`). Converge each native pin
  with its `# docker/...` counterpart so the two paths match. Leave
  the `# docker/...` comments exactly as they are.
- **`scripts/init.mk`** — no mechanism change: the existing `_install-dependencies`
  loop already installs every non-comment line, so the added pins are picked up (each
  new tool gets its `asdf plugin add` via `_install-dependency`).
- **CI** — ensure the commit-stage provisions the pinned native tools (`asdf install`)
  so the checks run the pinned versions rather than the runner's preinstalled ones;
  the Docker fallback remains for images without a native equivalent.

**Verification**:

- `make config` installs every pinned tool; each `<tool> --version` natively matches
  the `.tool-versions` pin **and** the corresponding `# docker/...` pin for
  `shellcheck`, `jq`, `hadolint`, `lychee`, `editorconfig-checker`, `nodejs`.
- `make lint` and `make test` pass natively and with `FORCE_USE_DOCKER=true` with
  identical results (parity).

**Out of scope**: the tool-manager migration (that is **PR 20**); the Docker-image
pinning mechanism (unchanged).

---

## PR 16: Harmonise the "unrecognised check mode" exit code across the suite

**Status**: New — surfaced during the PR 7 consistency review. Not yet built.

**Scope**: Shell script consistency / usability
**Risk**: Low
**Type**: consistency (small judgement-call on which code to standardise on)
**Files**: `scripts/quality/check-markdown-format.sh`,
`scripts/quality/check-markdown-links.sh`, `scripts/quality/check-file-format.sh`
(aligning with `scripts/quality/scan-secrets.sh`)

**Context**: The quality scripts disagree on how an unrecognised `check` mode is
reported. `scan-secrets.sh` (PR 8) uses `return 126` and documents it in an
`Exit codes` block, deliberately distinguishing a usage error from a real finding
(`1`). `check-markdown-format.sh`, `check-markdown-links.sh` and
`check-file-format.sh` instead `echo … >&2 && exit 1`, conflating "you passed a
bad mode" with "the check failed". (`check-shell-lint.sh` is out of scope — it is
file-based and has no `check`-mode dispatch to guard.) This divergence means a
caller cannot rely on the exit code to tell a misconfiguration apart from a
genuine lint/format/secret failure.

**Proposed change**: Standardise on `scan-secrets.sh`'s convention — `126` for an
unrecognised check mode — across every quality script, and add/extend the header
`Exit codes` block in each so the contract is documented:

```text
# Exit codes:
#   0   - All checks passed
#   1   - Checks failed
#   126 - Unrecognised check mode
```

Concretely, replace `echo "Unrecognised check mode: $check" >&2 && exit 1` with an
`echo … >&2; return 126` in each `*)` catch-all (and let `main`'s return propagate),
matching `scan-secrets.sh`. If the maintainer prefers `1` everywhere instead, the
alternative is to standardise `scan-secrets.sh` down to `1`; either way the suite
should agree. Recommendation: keep `126`, because a distinct usage code is more
useful to CI and callers.

**Placement**: Third layer of **Stack 3** (`PR 19` → `PR 16` → `PR 17` → `PR 18`),
branched off PR 19. It touches `check-file-format.sh` (modernised by PR 19) plus
the two markdown check scripts, so keeping it in the stack lets the exit-code
change sit on the PR 19 baseline without conflicting with PR 17/18 above it.

**Verification**: For each script, `check=nonsense ./scripts/quality/<script>.sh`
exits `126` and prints `Unrecognised check mode: nonsense`; a real failure still
exits `1`; `shellcheck` passes on all four scripts; `make lint` and `make test`
are green.

---

## PR 17: Use bash arrays instead of unquoted `$files` word-splitting

**Status**: New — surfaced during the PR 7 consistency review. Not yet built.

**Scope**: Shell script correctness / defensive scripting
**Risk**: Low–Medium (behavioural parity to verify)
**Type**: hardening
**Files**: `scripts/quality/check-markdown-format.sh`,
`scripts/quality/check-markdown-links.sh`,
`scripts/quality/format-markdown-tables.sh` (PR 10); optionally
`scripts/quality/check-file-format.sh` (the `$($filter)` splat)

**Context**: All three scripts build a newline-separated `files` string, but they
are not equally exposed — the space-splitting half of this bug is already fixed
in two of the three:

- `check-markdown-links.sh` expands **`$files` fully unquoted** (`# shellcheck
disable=SC2086`) under the default `IFS`, so a tracked path containing a space
  is split into separate arguments, _and_ any literal glob metacharacter (`*`,
  `?`, `[...]`) in a path is pathname-expanded. Both failure modes apply.
- `check-markdown-format.sh` and `format-markdown-tables.sh` already scope
  `IFS=$'\n'` before building `file_list=($files)` (`# shellcheck disable=SC2206`),
  which **does** stop the space-splitting failure — verified: with `IFS=$'\n'`, a
  `files` string containing the line `a b.md` yields a single array element
  `a b.md`, not two. But the array assignment is still an **unquoted** expansion,
  so bash still performs pathname (glob) expansion on each line: a tracked path
  containing `*`, `?`, or `[...]` can be silently replaced by an unrelated file
  that happens to match the pattern elsewhere in the repository. Verified with a
  live repro: with both `notes[draft].md` and `notesd.md` present in the same
  directory, `IFS=$'\n'; a=(notes[draft].md)` yields `a[0]=notesd.md` — the
  **wrong file**, silently, with no error. That is a worse failure than plain
  word-splitting: it doesn't just mis-parse, it lints/links the wrong file
  instead of the intended one, and nothing signals that it happened.

So the space-vs-newline half of this bug is essentially solved already for two of
the three scripts; the glob-expansion half is unsolved in all three, and
`check-markdown-links.sh` still has neither protection.

**Proposed change**: Replace the string-based `files` variable and the
`IFS=$'\n'`/`($files)` construct with a real array built via `mapfile`, which
performs no word-splitting _or_ pathname expansion on its input, removing the
`SC2086`/`SC2206` disables:

```bash
local -a files
mapfile -t files < <(git ls-files "*.md")   # or the per-mode git command, one path per line
# ...
if [ "${#files[@]}" -gt 0 ]; then
  run-markdownlint-natively "${files[@]}"   # passed positionally, not via env var
fi
```

Verified: re-running the `notes[draft].md` / `other.md` repro above with
`mapfile -t files <<< "$files"` instead of the `IFS`/array construct preserves
both filenames exactly, with no glob expansion.

Because the current design passes `files` to the runner functions **as an
environment variable** (a string), this PR also adjusts the runner interface to
accept the list positionally (e.g. `run-markdownlint-natively "${files[@]}"`) so the
array survives without re-splitting. The empty-list guard (`if [ -n "$files" ]`)
becomes `if [ "${#files[@]}" -gt 0 ]`. The same treatment applies to the prettier
wrapper added in PR 10.

**Placement**: Third-from-top layer of **Stack 3**, branched off PR 16. It
re-touches the two markdown check scripts (and the PR 10 prettier wrapper) plus,
optionally, `check-file-format.sh`'s `$($filter)` splat — all already sitting on
the PR 19/PR 16 baseline below it. Kept separate from PR 16 (different concern,
different lines) so each layer stays reviewable on its own.

**Verification**: Add a temporary tracked Markdown file with a space in its name and
confirm both checks lint it (native and `FORCE_USE_DOCKER=true`); confirm the empty
selection (`check=working-tree-changes` with no changes) runs nothing rather than
linting the whole repo; `shellcheck` passes with the `SC2086` disables removed;
`make lint` and `make test` are green.

---

## PR 18: Resolve the `check=branch` base dynamically (any branch → any base)

**Status**: New — surfaced during the PR 7 review and the `check=branch` scoping
investigation. Recorded only (not yet built). **Supersedes the removed Optional A.**
**Top of Stack 3** (`PR 19` → `PR 16` → `PR 17` → `PR 18`), branched off PR 17.

**Scope**: Shell script correctness / developer experience
**Risk**: Low–Medium (base-resolution and diff-semantics changes need verification)
**Type**: hardening + judgement-call
**Files**: `scripts/quality/check-markdown-format.sh`,
`scripts/quality/check-markdown-links.sh`, `scripts/quality/check-file-format.sh`,
`scripts/quality/scan-secrets.sh` (its `branch` mode), and optionally a shared
`scripts/quality/quality.lib.sh`; `Makefile` `lint-*` targets

**Context**: `check=branch` compares against `${BRANCH_NAME:-origin/main}` using a
two-dot `git diff <ref>`. This is wrong in two ways for a template repo that must
work for **any** branch merged to **any** base:

1. **Hardcoded base.** The default is `origin/main`. Git does not record a branch's
   merge target (that is PR metadata), so any branch targeting something other than
   `origin/main` (a `master`/`develop` default, a release branch, or a stacked base
   like `v2`) is compared against the wrong ref. On the local `v2` stack this made
   `lint-file-format` select ~53 files (nearly the whole repo) instead of the ~8
   that differ from `v2` — slow, and liable to fail on pre-existing issues unrelated
   to the branch.
2. **Two-dot vs merge-base.** `git diff <base>` also reports files the base advanced
   since the branch forked, not just the branch's own changes.

**Proposed change** (recommended combination):

- **Base resolution (layered, first hit wins).** Add a `resolve-base-ref` helper:
  1. `BRANCH_NAME` — explicit override (already supported; keep as the escape hatch).
  2. `GITHUB_BASE_REF` — authoritative PR merge target in GitHub Actions PR events
     (`origin/$GITHUB_BASE_REF`).
  3. `BASE_BRANCH` (new) or `git config custom.baseBranch` — optional per-repo default
     for long-lived non-default bases such as `v2`.
  4. `git symbolic-ref refs/remotes/origin/HEAD` — the remote's real default branch
     (resolves to `origin/main` here) instead of a hardcoded literal.
  5. `origin/main` — final fallback (preserves today's behaviour).
- **Diff from the merge-base (two-dot against the merge-base).** Select files with
  `git diff --diff-filter=ACMRT --name-only "$(git merge-base "$base" HEAD)"`. This
  keeps uncommitted work-in-progress in scope (important for local/pre-commit runs)
  while ignoring whatever the base advanced after the fork. On this branch it yields
  the branch's real delta rather than the whole `v2 ← origin/main` divergence.
- **Placement.** Prefer a shared `scripts/quality/quality.lib.sh` sourced by all four
  scripts (single source of truth), or duplicate the helper per script to match the
  current no-shared-lib style. Resolving inside the scripts (not only the Makefile)
  keeps direct `./script.sh` invocation correct.

**Why this supersedes Optional A**: Optional A forced `lint-markdown-links` to
`check=all` because branch-scoped link checking was unreliable and considered less
thorough. With `check=branch` resolving the base correctly, branch-scoped link
checking becomes reliable and consistent with `lint-file-format` and
`lint-markdown-format`, so forcing `check=all` is no longer wanted. Repo-wide link
checking is still enforced by pre-commit and CI, which call `check=all` directly, so
dropping Optional A loses nothing there.

**Edge cases to handle**: base ref missing or not fetched (fail with a clear message,
never silently fall back to a whole-repo scan); empty selection when on the base or
with no divergence (must mean "check nothing" — coordinate with the native/Docker
`/dev/null` backstop parity issue, which the native `check-file-format.sh` path
lacks); detached HEAD (CI); shallow clones (`git merge-base` needs history — CI
already checks out with `fetch-depth: 0`); offline (fall back to a local `<base>`
ref when `origin/<base>` is absent).

**Minimal alternative**: if only the hardcoded default is a concern, swap
`origin/main` for the dynamic default branch (`git symbolic-ref refs/remotes/origin/HEAD`)
and keep two-dot. This fixes `main`/`master`/`develop` repos but not stacked or
non-default bases (so it would not have fixed the `v2` case).

**Verification**: on a feature branch off any base, `BASE_BRANCH`/`BRANCH_NAME`
unset, `make lint-file-format` (and the two markdown variants) select only the
branch's changed files; on a PR-triggered CI run, selection matches `GITHUB_BASE_REF`;
`BRANCH_NAME`/`BASE_BRANCH` override still works; `shellcheck` passes; `make lint`
and `make test` are green natively and with `FORCE_USE_DOCKER=true`.

---

## PR 19: Modernise `check-file-format.sh` and adopt a `.editorconfigignore`

**Status**: Expected — promoted from the former Optional B (no longer optional).
Not yet built.

**Scope**: Shell script consistency + ignore-file ergonomics
**Risk**: Low
**Type**: consistency / hardening
**Files**: `scripts/quality/check-file-format.sh`,
`scripts/config/.editorconfigignore` (new placeholder),
`scripts/config/.markdownlintignore` (header comment)

**Context**: `check-file-format.sh` is the only quality script that has not yet been
modernised to the shared conventions from PRs 5–8, and editorconfig is the only
linter whose exclusions are hidden inside a config file
(`editorconfig-checker.json`'s `Exclude` regex) rather than a dedicated, discoverable
ignore file. markdownlint (`.markdownlintignore`), gitleaks (`.gitleaksignore`), and —
via PR 10 — prettier (`.prettierignore`) all read a `.<tool>ignore` placeholder;
editorconfig does not.

**Change**:

- **Modernise the script.** Apply the shared conventions from PRs 5–8: scope
  variables with `local`, end functions with an explicit `return 0`, and document
  `main` and `is-arg-true`. (This is the original Optional B scope.)
- **Adopt a `.editorconfigignore`.** Teach `check-file-format.sh` to read
  `scripts/config/.editorconfigignore` and drop matching paths from the file list
  before invoking editorconfig-checker (skip comment/blank lines, anchor each entry,
  filter with `grep -Ev`). Ship an **empty `.editorconfigignore`
  placeholder** carrying a header comment. This gives all four linters the same
  "add exclusions to a dedicated ignore file" ergonomics. Keep
  `editorconfig-checker.json`'s `Exclude` honoured as well so nothing regresses.
- **Self-document the placeholders.** Add a header comment to the currently empty
  (0-byte) `scripts/config/.markdownlintignore`, matching PR 10's `.prettierignore`
  placeholder style, so every ignore-file placeholder explains its purpose.

**Deliberately not in scope**: an automated ignore-file population mechanism (for
example, generating these ignore files from a shared config) — that is a larger
change than this PR's scope and can be proposed separately if it becomes useful.
Lychee is left as is: its exclusions belong in `lychee.toml`, and a
`scripts/config/.lycheeignore` would be inert (lychee only auto-reads
`.lycheeignore` from the working directory, not from `scripts/config/`).

**Placement**: **Base of Stack 3** (`PR 19` → `PR 16` → `PR 17` → `PR 18`). It
modernises `check-file-format.sh` to the shared conventions so the exit-code
(PR 16), array (PR 17), and base-resolution (PR 18) layers above it sit on a
consistent baseline rather than editing an un-modernised script.

**Verification**: `make check-file-format check=all` passes; an entry added to
`scripts/config/.editorconfigignore` excludes the matching path (native and
`FORCE_USE_DOCKER=true`); `editorconfig-checker.json` `Exclude` still applies;
`shellcheck` passes on `check-file-format.sh`; `make lint` and `make test` are green.

---

## PR 20: Migrate the developer toolchain manager from `asdf` to `mise`

**Scope**: Build system / developer tooling / CI / documentation
**Risk**: Medium — changes a documented prerequisite and the `make config`
contract, and touches CI. The behaviour of every quality gate is preserved; only
_how the tools are provisioned_ changes (the _what-to-pin_ is already settled by
PR 15).
**Depends on**: **PR 15** (the native/Docker parity + dependency inventory). PR 15
establishes the pinned tool set; this PR swaps the manager that provisions it. Also
complements **PR 2**/**PR 4** (reproducible native `shellcheck`) and **PR 10**
(native `node`).
**Files**: `.tool-versions`, `scripts/init.mk`, `.github/workflows/*.yaml`
(+ a mise setup step), `README.md`, `docs/onboarding.md`, a new ADR under
`docs/adr/`, and the `docker`/`makefile` instruction files that reference asdf.

> **Note**: This is a net-new improvement to this repository (it currently uses
> asdf throughout). Because it changes an org-wide, documented prerequisite,
> it should be gated behind maintainer agreement and recorded as an ADR (the repo
> already has an ADR process under `docs/adr/`). No diff is included at this
> stage — this entry is the design and analysis only.

**Context**: With PR 15 the native path is fully pinned, but it is still provisioned
by [asdf](https://asdf-vm.com/), which carries two remaining costs this PR removes:

- **Per-tool plugin management.** Every tool needs an `asdf plugin add` against a
  third-party plugin repository before it can be installed. Plugins are arbitrary
  shell, are unversioned, and are a supply-chain surface.
- **Shim indirection.** asdf routes every invocation through shims, which is slower
  and a frequent source of "wrong version on PATH" confusion.

[mise](https://mise.jdx.dev/) (mise-en-place) is a drop-in replacement that reads the
same `.tool-versions` file, so migration is incremental, and it closes both gaps:

- It resolves tools through **backends** — primarily [aqua](https://mise.jdx.dev/dev-tools/backends/aqua.html)
  and `github` — with **no per-tool plugins**, and with checksum/SLSA verification.
  (New asdf/vfox plugins are no longer accepted into the mise registry precisely for
  supply-chain reasons.) Every tool this template uses is in the registry: `jq`
  (`aqua:jqlang/jq`), `shellcheck` (`aqua:koalaman/shellcheck`), `hadolint`
  (`aqua:hadolint/hadolint`), `lychee` (`aqua:lycheeverse/lychee`), `gitleaks`
  (`aqua:gitleaks/gitleaks`), `editorconfig-checker`, `pre-commit`, `node`
  (`core:node`), `prettier` (`npm:prettier`), `markdownlint-cli2` (`npm`).
- It installs everything in one shot (`mise install`), runs pinned tools with
  `mise exec`/shims/`mise activate`, ships an official GitHub Action
  (`jdx/mise-action@v3`) with caching, and answers "are we on the latest versions?"
  directly with `mise outdated` / `mise upgrade`.

Crucially, the repository's extended `# docker/...` pins in `.tool-versions` are
**comments**, which mise ignores exactly as asdf does, so
`docker-get-image-version-and-pull` in `scripts/docker/docker.lib.sh` keeps working
unchanged. Migration does not touch the Docker-image pinning mechanism.

**Analysis — how mise differs (and why it is a drop-in)**:

- Reads `.tool-versions` (asdf-compatible) **and** the idiomatic `mise.toml`; either
  can be the source of truth.
- No `plugin add` step: `mise install` provisions the whole config; `mise use
tool@ver` adds+installs+writes config.
- Activation choice: `mise activate` for interactive shells vs **shims** for
  CI/IDEs/scripts (better fit here). `make` can also just call `mise exec --`.
- CI: `jdx/mise-action@v3` (install + cache), or bootstrap with `curl
https://mise.run | sh` + `mise install`. `MISE_SAFE=1` disables any code execution
  for untrusted config; `mise.toml` with tasks/env/hooks triggers a one-time trust
  prompt (`.tool-versions` alone does not).
- Gotcha to plan for: some backends hit the GitHub API and can be rate-limited on
  shared runners — set `MISE_GITHUB_TOKEN`/`GITHUB_TOKEN` in CI.

**Proposed changes** (prose, no diff):

- **`scripts/init.mk`** — replace the asdf targets with mise: `_install-dependencies`
  becomes a thin wrapper around `mise install`; drop `asdf plugin add`/`asdf install`.
  Keep the `_install-dependency name=…` entry point as an optional convenience
  mapping to `mise use ${name}@${version}` so downstream `config::` overrides still
  work. `config::` continues to call `$(MAKE) _install-dependencies`.
- **`.tool-versions`** — keep it as the single source of truth (mise reads the pinned
  set that PR 15 completed, and `docker.lib.sh` keeps parsing the comment block).
  Optionally rewrite the native pins with mise registry shorthands. Leave the
  `# docker/...` comments exactly as they are.
- **CI** — add a mise setup step (`jdx/mise-action@v3`, `install: true`,
  `cache: true`) to the commit-stage workflow so the checks run the **pinned** native
  tools; the Docker fallback remains for images without a native equivalent.
  Configure `GITHUB_TOKEN` for mise to avoid API rate limits. (The workflows already
  use `astral-sh/setup-uv`; `uv` can later move under mise too, but that is out of
  scope here.)
- **Docs** — swap the asdf prerequisite for mise in `README.md` and
  `docs/onboarding.md` (install via `curl https://mise.run | sh`, then `make config`);
  update the `docker`/`makefile` instruction file references, including the "Tool
  Version Management (asdf)" heading.
- **New `deps-outdated` / `deps-upgrade` targets** — wrap `mise outdated` and
  `mise upgrade` so keeping pins current is a first-class, repeatable workflow (the
  durable answer to the "latest versions" question raised in PR 15).
- **ADR** — add `docs/adr/ADR-005_Tool_Version_Manager.md` (or next number) recording
  asdf → mise, with the Tech Radar alignment note the PR 1 template now requires.

**Optional idiomatic evolution** (follow-up, not required for this PR): move the
native pins into a `mise.toml` `[tools]` table and optionally add `[tasks]` that wrap
the `make` gates and `[env]` for shared variables. If pins move out of
`.tool-versions`, repoint `TOOL_VERSIONS` in `docker.lib.sh` at whichever file retains
the `# docker/...` block, and account for the `mise.toml` trust prompt in CI
(`mise trust` or `MISE_SAFE=1`).

**Migration & compatibility**:

- Incremental: because mise reads `.tool-versions`, the repo works under mise the
  moment contributors install it; the asdf removal is a documentation and `init.mk`
  change, not a data-format change.
- Contributors install mise once and either enable shims or `mise activate`.
- Tools that previously had no asdf plugin (or that we now source from aqua) will no
  longer resolve under asdf — acceptable, since asdf is being dropped, but it is the
  reason this is a clean cut-over rather than a dual-support state.

**Risks & mitigations**:

- _Prerequisite change_ → gate behind an ADR and a short contributor note.
- _CI fetches tools from the network_ → `jdx/mise-action` caching + `GITHUB_TOKEN`.
- _Trust prompts / code execution_ → keep `.tool-versions` (no code) for this PR; use
  `MISE_SAFE=1` if a `mise.toml` with tasks is introduced later.
- _Windows_ → the asdf backend is disabled by default on Windows, but every tool here
  is available via aqua/core, so Windows contributors are better off, not worse.

**Verification**:

- `make config` provisions everything via `mise install`; `mise ls` shows all pinned
  tools at the expected versions.
- `mise exec -- shellcheck --version` (and the same for `jq`, `yq`, `hadolint`,
  `lychee`, `editorconfig-checker`) matches the `.tool-versions` pin **and** the
  corresponding `# docker/...` pin.
- `make lint` and `make test` pass natively and with `FORCE_USE_DOCKER=true`, with
  identical results (parity).
- `make deps-outdated` reports cleanly; CI (commit stage) is green with the mise step
  in place.

**Out of scope**: the Docker-image pinning mechanism (unchanged); the _what-to-pin_
decisions (owned by PR 15); forcing a `mise.toml`/tasks model (optional follow-up);
migrating `uv` under mise.

---

## PR 21: SonarQube Cloud scan via the official GitHub Action

**Status**: ✅ Merged into `v2` as [#242](https://github.com/nhs-england-tools/repository-template/pull/242).

**Scope**: CI / quality gate
**Risk**: Low — new job only; skips gracefully if `SONAR_TOKEN` is not available
(for example on a fork pull request, or before the token is configured)
**Files**: `.github/workflows/stage-2-test.yaml`, `.github/workflows/cicd-1-pull-request.yaml`,
`.gitignore`

**Summary**: Adds a `perform-static-analysis` job to `stage-2-test.yaml` calling
the official [`SonarSource/sonarqube-scan-action`](https://github.com/SonarSource/sonarqube-scan-action)
(pinned by SHA), so SonarQube Cloud analysis runs on PRs and `main` pushes now
that Automatic Analysis is disabled. Analysis-scope properties are passed as
inline `args:` (no composite action, no `sonar-scanner.properties` file), and the
scan step is skipped rather than failed when `SONAR_TOKEN` is absent. `SONAR_TOKEN`
is a required `workflow_call` secret passed explicitly from
`cicd-1-pull-request.yaml`.

**Follow-up (admin-side)**: after the job has run at least once, add
`SonarCloud Code Analysis` as a required status check on `main` via a branch
ruleset so a failed quality gate blocks merge. This also depends on the SonarQube
Cloud project being a **bound** project for PR decoration. GitHub's required-checks
picker only lists checks that have reported at least once, so this can only be
configured after this job has run successfully.

**Known limitation (fixed by PR 22)**: on `v2` the `push` trigger still matches
`branches: ["**"]`, so this job runs twice per PR commit (once for `push`, once for
`pull_request: synchronize`). **PR 22** carries the fix and must land last.

---

## PR 22: Fix the `push` trigger double-run — last commit before merging `v2` to `main`

**Scope**: CI / trigger correctness
**Risk**: Low change, but **timing-sensitive** — see below for why this cannot land
early
**Depends on**: every other PR in this plan already merged into `v2`. This must be
the **final** commit on `v2`, applied **immediately before** merging `v2` into
`main`, not raised in normal stack order.
**Files**: `.github/workflows/cicd-1-pull-request.yaml`

**Context**: `main` already carries this fix, as commit `c861edf` ("ci: restrict
push trigger to main and add synchronize to PR trigger - ENG-1023 (#210)",
2026-04-21). `v2` forked from `main` before that commit and has diverged
independently since — verified with `git merge-base --is-ancestor c861edf v2`,
which returns false even though `v2`'s own tip is newer by calendar date. `v2`'s
`cicd-1-pull-request.yaml` still triggers on:

```yaml
on:
  push:
    branches:
      - "**"
  pull_request:
    types: [opened, reopened, synchronize]
```

`push` and `pull_request` are independent, OR'd triggers. A commit pushed to any
branch with an open PR fires **both** a `push` event (matched by `branches:
["**"]`) and a `pull_request: synchronize` event, starting two independent runs
of the whole workflow. `test-stage` (and therefore **PR 21**'s
`perform-static-analysis` job) has no conditional gate, so it runs twice per PR
commit — doubling CI time and, for PR 21, doubling SonarQube Cloud analysis
submissions for identical code. `main`'s fix narrows the `push` trigger to
`branches: [main]` only, so a PR-branch commit only ever triggers via
`pull_request`, and `push` only fires once — on the eventual merge commit.

**Why this must be the last commit on `v2`, not an ordinary stacked PR**: this
whole work package is built as a stack of branches merged into `v2` over time,
and `v2` — not `main` — is the effective integration branch for that entire
period. Narrowing `push` to `branches: [main]` early would mean `v2` itself (a
branch literally named `v2`, not `main`) stops matching the `push` trigger for
the rest of the work package's lifetime: every subsequent merge of a stacked PR
into `v2` would silently lose its push-triggered CI run (build/acceptance
stages, the Sonar job, etc.), leaving `v2`'s own HEAD unvalidated between merges
except while a PR is still open against it. Landing this fix only immediately
before the `v2` → `main` merge means `v2` keeps its current full CI coverage
for as long as it is being actively built up, and the corrected trigger takes
effect at exactly the moment `v2`'s content becomes `main`'s content.

**Sequencing**: raise this as the top-most commit on `v2`, after every other PR
in this plan that is going into the same release has already been merged. Do not
branch further PRs on top of it. Merge it into `v2`, then merge `v2` into `main`
in the same change window.

**Verification**: before this lands, a commit to a branch with an open PR
against `v2` triggers the workflow twice (`push` + `pull_request: synchronize` —
confirm via the Actions run list). After this PR is merged into `v2` and `v2` is
merged into `main`: a commit to a PR branch triggers only via `pull_request`; a
merge to `main` triggers only via `push`; `git diff v2..main --
.github/workflows/cicd-1-pull-request.yaml` shows no difference on this trigger
block.

**Diff**:

```diff
diff --git a/.github/workflows/cicd-1-pull-request.yaml b/.github/workflows/cicd-1-pull-request.yaml
--- a/.github/workflows/cicd-1-pull-request.yaml
+++ b/.github/workflows/cicd-1-pull-request.yaml
@@ -5,7 +5,7 @@
 on:
   push:
     branches:
-      - "**"
+      - main
   pull_request:
     types: [opened, reopened, synchronize]
```

---

## PR 23: Repo-wide word-splitting, quoting, and globbing audit

**Status**: New — surfaced while reviewing PR 17's markdown-script fix. A
repo-wide scan (grepping every tracked `.sh`, `.mk`, and `Makefile` for
`SC2086`/`SC2206`/`SC2046` disables, `for … in $(…)` loops, and unquoted
command-string splats) confirmed the same anti-pattern recurs outside the
markdown scripts PR 17 covers. Recorded only (not yet built).

**Scope**: Shell script / Makefile correctness / defensive scripting
**Risk**: Low–Medium (behavioural parity to verify per script; same class of
risk as PR 17)
**Type**: hardening
**Depends on**: PR 18 (branches off the top of Stack 3, after the array pattern
and base-resolution logic land)
**Files**: `scripts/quality/check-file-format.sh`,
`scripts/quality/scan-secrets.sh`, `scripts/docker/docker.lib.sh`,
`scripts/init.mk`, `scripts/docker/docker.mk`

**Context**: PR 17 fixes the `$files` word-splitting anti-pattern in the three
markdown scripts only. The repo-wide scan found the identical pattern —
building a dynamic argument or file list as a plain string, then expanding it
unquoted — recurring in scripts and Makefiles PR 17 does not touch:

- **`check-file-format.sh`** (`run-editorconfig-natively`/`-in-docker`):
  `filter` holds a _git command string_ (e.g. `"git diff --diff-filter=ACMRT
--name-only origin/main"`), executed unquoted via `$($filter)` (`# shellcheck
disable=SC2046,SC2086`) — double word-splitting: the filter command itself is
  split by `IFS`, then its file-list output is split/glob-expanded again. The
  Docker path re-splits it a third time inside a `sh -c "... \$($filter) ..."`
  string.
- **`scan-secrets.sh`** (`run-gitleaks-natively`/`-in-docker`, already merged as
  PR 8): `cmd` holds a full `gitleaks` command line built up piecewise, then
  invoked unquoted (`gitleaks $cmd`, `docker run … $cmd`, both `# shellcheck
disable=SC2086`). Any interpolated segment containing a space (a custom
  `--config`/`--gitleaks-ignore-path`, a `BRANCH_NAME` with a space) would
  silently mis-split.
- **`docker.lib.sh`**: `for version in $(_get-all-effective-versions) latest;
do …` (in `docker-build`, `docker-push`, `docker-clean`) word-splits _and_
  glob-expands the unquoted command substitution; `docker-check-test`/
  `docker-run` expand `${args:-}`/`${cmd:-}` unquoted (`# shellcheck
disable=SC2086,SC2154`) to build the `docker run` argument list from a
  caller-supplied string — the same class of issue as `scan-secrets.sh`'s
  `$cmd`.
- **`init.mk`** (`check-shell-lint`) and **`docker.mk`**
  (`docker-shellscript-lint`): both do `for file in $$(find … -name "*.sh");
do …`, unquoted inside a Make recipe — any script path containing a space or
  glob character is split/expanded incorrectly. PR 2's own rewrite of
  `check-shell-lint` switches to `echo "$$files" | xargs shellcheck`; plain
  `xargs` still splits on whitespace by default, so that replacement needs
  `xargs -d '\n'` (or `-0`) too, rather than being assumed safe — this is
  flagged here and re-checked as part of PR 23's verification, cross-referenced
  against PR 2.
- **Python**: no `.py` files are tracked in the repository (`git ls-files
'*.py'` is empty). The only embedded Python — the frontmatter-blank-line
  check's heredoc in `check-markdown-format.sh` — receives the file list via a
  `files` environment variable and splits it with `.splitlines()`, not shell
  word-splitting, so it was reviewed and found clean; no fix needed there.
- Reviewed and found **already correct** (no change needed, listed here so the
  audit is documented as complete rather than silently skipped): `docker.lib.sh`'s
  `_replace-image-latest-by-specific-version` (`echo "$content" | while IFS=
read -r line; do …`); the markdown scripts' `git ls-files … | while IFS= read
-r f; do …`; and `docker.test.sh`'s `for test in "${tests[@]}"; do …`.
  `scripts/docker/dgoss.sh` is a vendored upstream script (see its own header)
  and is explicitly out of scope for repo-authored fixes.

**Proposed change**: Apply the same treatment as PR 17 throughout — replace
command-string splats with arrays passed positionally, and replace `for x in
$(find …)` with a `find … -print0 | while IFS= read -r -d '' file; do …` (or a
quoted array populated via `mapfile -d ''`) so filenames survive intact. For
`check-file-format.sh` and `scan-secrets.sh`, build the underlying `git`/
`gitleaks` invocation as a bash array (`cmd=(gitleaks detect --source "$dir"
…)`) and call it with `"${cmd[@]}"` instead of composing a single string. For
`docker.lib.sh`'s `docker run` wrappers, accept `args`/`cmd` as arrays rather
than free-form strings.

**Placement**: New top layer of **Stack 3** (`PR 19` → `PR 16` → `PR 17` →
`PR 18` → `PR 23`), branched off PR 18. It deliberately also touches
`scripts/docker/docker.lib.sh` (Stack 2's file) and `scripts/init.mk`/
`scripts/docker/docker.mk` (untouched by any other stack) — a small, acceptable
overlap with Stack 2, the same precedent as PR 4/PR 15 both touching
`.github/workflows/*` above.

**Verification**: For each touched script, add a temporary tracked file/path
with a space in its name (or a version/branch value with a space where
applicable) and confirm the command still runs against the exact intended
target; `shellcheck` passes with the `SC2086`/`SC2046`/`SC2206` disables removed
(or narrowed to only the cases that genuinely still need them); `make lint` and
`make test` are green; re-run the grep sweep used to build this audit
(`SC2086`/`SC2206`/`SC2046` disables and `for … in $(` across every tracked
`.sh`/`.mk`/`Makefile`) and confirm no unaddressed instance remains outside
vendored/third-party files.
