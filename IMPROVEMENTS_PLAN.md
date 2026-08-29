# Improvements Plan

Each recommended pull request is self-contained, carries the context needed to
raise it, and (except where noted) includes a copy-paste-ready diff. The PRs form
a single incremental pipeline intended to be raised as
[GitHub stacked pull requests](https://docs.github.com/en/pull-requests/how-tos/stacked-pull-requests),
each branch built on the one before it; dependencies are stated explicitly where
they exist.

---

## PR index — what each PR is about

All 20 PRs plus one optional tweak, with a one-line summary each; full detail
is in the correspondingly named section below. They are listed in application
order — raise them as a stack, each PR branched off the one above it; per-PR
dependencies are called out in the _Status_ column and in the [Notes](#notes).

| PR             | What it is about                                                                                                                                                                                                                                                                          | Status                                                                                |
| -------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| **PR 1**       | ADR template: require NHS Tech Radar alignment and replace star ratings with a weighted-scoring model (weights + totals).                                                                                                                                                                 | ✅ Merged ([#226](https://github.com/nhs-england-tools/repository-template/pull/226)) |
| **PR 2**       | Make `check-shell-lint` a real gate — fail on any finding — with a fast single native run and a pinned per-file Docker fallback.                                                                                                                                                          | Recommended                                                                           |
| **PR 3**       | Add a discoverable `lint-shell` target and wire it into `make lint`.                                                                                                                                                                                                                      | Recommended · needs PR 2                                                              |
| **PR 4**       | Add a `check-shell-lint` composite action and commit-stage CI job so the shell-lint gate runs in CI.                                                                                                                                                                                      | New · needs PR 2–3                                                                    |
| **PR 5**       | Behaviour-preserving shell best practices (`local` / `return 0` / quoting / docs) in the lib and simple quality scripts.                                                                                                                                                                  | Recommended                                                                           |
| **PR 6**       | Harden the Docker test suite (`docker.test.sh`) with best practices and test isolation.                                                                                                                                                                                                   | Recommended · pattern of PR 5                                                         |
| **PR 7**       | Markdown check scripts: best practices + check-mode guard in `check-markdown-format.sh` and `check-markdown-links.sh`.                                                                                                                                                                    | ✅ Built locally · 3 of 6                                                             |
| **PR 8**       | `scan-secrets.sh`: best practices + check-mode guard + a six-mode `check` vocabulary aligned with the other quality scripts (`all`, `staged-changes`, `working-tree-changes`, `branch`, `whole-history`, `last-commit`), plus native/Docker-parity fixes, all proven by scenario testing. | ✅ Built locally · 2 of 6                                                             |
| **Optional C** | Document shell linting and `FORCE_USE_DOCKER` in the README.                                                                                                                                                                                                                              | Optional                                                                              |
| **PR 9**       | Enforce a blank line after YAML frontmatter (markdownlint rule + fixes).                                                                                                                                                                                                                  | ✅ Built locally · 4 of 6                                                             |
| **PR 10**      | Add `make format` to auto-format markdown tables with Prettier (native `npx` or Docker) plus scoped config.                                                                                                                                                                               | ✅ Built locally · 6 of 6                                                             |
| **PR 11**      | Skip deleted files in the markdown link check (branch mode).                                                                                                                                                                                                                              | ✅ Built locally · 5 of 6                                                             |
| **PR 12**      | Reduce gitleaks false positives (link-local IPs + comprehensive Python/JS-TS/Terraform lockfile allowlist).                                                                                                                                                                               | ✅ Built locally · 1 of 6                                                             |
| **PR 13**      | Copilot agent Stop hook that runs `make lint` + `make test` before finishing (snapshot-only, no prompt logging).                                                                                                                                                                          | Optional · needs jq + Preview hooks                                                   |
| **PR 14**      | Enrich the pull-request template with description/context guidance and a "How to test it" section.                                                                                                                                                                                        | ✅ Merged ([#225](https://github.com/nhs-england-tools/repository-template/pull/225)) |
| **PR 15**      | Native/Docker tool parity: pin every natively-used CLI in `.tool-versions` to match its Docker image and fix version drift (editorconfig-checker, hadolint, jq, yq). Stays on asdf; foundation for PR 20.                                                                                 | New · foundation for PR 20                                                            |
| **PR 16**      | Harmonise the "unrecognised check mode" exit code across the quality-script suite so a usage error is distinct from a check failure.                                                                                                                                                      | New · touches PR 7/8 files + PR 19                                                    |
| **PR 17**      | Replace unquoted `$files` word-splitting with bash arrays in the markdown check/format scripts so paths with spaces are handled correctly.                                                                                                                                                | New · touches PR 7/10 files                                                           |
| **PR 18**      | Resolve the `check=branch` base dynamically (explicit / CI / default-branch) and diff from the merge-base, so `lint-*` targets scope correctly for any branch merged to any base. Supersedes the removed Optional A.                                                                      | New · touches PR 7/8 files + PR 19                                                    |
| **PR 19**      | Promote the former Optional B (now expected): modernise `check-file-format.sh` and adopt a `.editorconfigignore` so editorconfig exclusions use the same dedicated ignore-file pattern as the other linters; add self-documenting headers to the empty ignore-file placeholders.          | New · expected · touches PR 7/8/16/18 files                                           |
| **PR 20**      | Migrate the toolchain manager from `asdf` to `mise` (registry backends, no per-tool plugins, CI action, docs, ADR, `deps-outdated`/`upgrade`). Depends on PR 15.                                                                                                                          | New · analysis-only, ADR-gated                                                        |

## Notes

- **Shell PRs (5–8) are grouped by file, not by concern.** Splitting by concern
  would fragment single files across multiple PRs and create merge conflicts;
  grouping by file yields disjoint, independently mergeable changes.
- **PRs 5–8 have no inter-dependencies** and may be raised in parallel or as a
  single "shell quality" PR. The only hard sequence is the lint-gate chain
  **PR 2 → PR 3 → PR 4**.
- **PR 4 is the one genuinely new addition**: without it the
  new `lint-shell` gate never runs in CI.
- Before merging PR 2/3/4, run `make check-shell-lint` on `v2` to confirm the
  existing scripts already pass, so enabling the gate does not immediately break
  the build.
- **PR 9–13 are additive**: PR 2 already includes the fast-path optimisation;
  PRs 9 and 11 build on PR 7 (same files); PR 10 (`make format`) is scoped to
  markdown tables; PR 12 is an independent config tweak.
- **PR 10** and **PR 13** carry external dependencies: PR 10 needs Node/`npx` (or
  the pinned `node` Docker image); PR 13 needs `jq` and relies on the Copilot Agent
  hooks **Preview** feature, so both are opt-in.
- **PR 13 (Copilot hooks)** enforces `make lint`/`make test` when the agent tries
  to finish, using a minimal snapshot-only guard so no user prompt text is
  recorded.
- **Diffs are dropped once a PR is implemented.** Each PR's diff (or new-file
  content) below is illustrative only, to support review before implementation.
  As soon as a PR is merged or built locally, its diff block is removed from this
  plan — the real change lives in the merged commit or the local branch — and
  replaced with a one-line pointer to where it can be found. Apply the same
  treatment to any remaining PR once it is next implemented.
- **PR 15 (native/Docker parity)** is a low-risk foundation: it pins every
  natively-used CLI in `.tool-versions` to match its Docker image and fixes version
  drift, without changing the tool manager, so it needs no ADR and can land on its
  own.
- **PR 20 (asdf → mise)** builds on PR 15 and is analysis-only and ADR-gated: it
  changes a documented, org-wide prerequisite, so land it behind maintainer
  agreement rather than as a routine stacked PR.
- **PR 16–18 are consistency follow-ups** surfaced by the PR 7 review. All re-touch
  files already hardened in PRs 7/8/10 (and PR 19), so raise them as new layers
  above the existing scan-secret + markdown-linting stack, or fold each into the
  matching per-file PR. They are independent of each other (different concern,
  different lines) and carry no external dependencies. **PR 18 supersedes the former
  Optional A**: rather than forcing `make lint` to check all markdown links repo-wide,
  it fixes `check=branch` base resolution so branch-scoped link checking is correct
  and consistent with the other `lint-*` targets. Optional A and its branch
  `pr/A-lint-all-links` have been removed from this plan and the local stack.
- **Progress**: PR 1 and PR 14 are merged into `v2` (as
  [#226](https://github.com/nhs-england-tools/repository-template/pull/226) and
  [#225](https://github.com/nhs-england-tools/repository-template/pull/225)
  respectively). All other PRs in the index remain outstanding.
- **This plan document is its own branch, first in the local stack**: `v2` →
  **`pr/00-improvements-plan`** (this file, no code) → the six scan-secret +
  markdown-linting PRs below. Keeping the plan out of the code PRs means it can
  be reviewed and merged independently of any of them.
- **Built locally — scan-secret + markdown-linting stack**: this batch has been
  built as a local stack of six branches on top of `pr/00-improvements-plan`, in
  the order **PR 12** → **PR 8** → **PR 7** → **PR 9** → **PR 11** → **PR 10**,
  each branched off the one before it. The two scan-secret PRs are deliberately at
  the front. **PR 12** (gitleaks allowlist) lands the link-local IP and Terraform
  lockfile false-positive fixes before any other commit, and **PR 8** hardens
  `scan-secrets.sh`. Landing these first clears the secret-scan pre-commit blocker
  (see the next note) so the later markdown PRs are not stopped by unrelated,
  invalid findings. **PR 7** is the markdown base (both check scripts). **PR 9** and
  **PR 11** build on it. **PR 10**
  adds `make format`. Branch names, commit hashes, the review outcome, and the
  CLI commands to switch, review, and push the stack are in the
  [Local stacked PRs](#local-stacked-prs--build-record-and-cli) section below.
- **Secret-scan blocker resolved by PR 12**: while building the stack, the
  `scan-secrets` pre-commit hook flagged `169.254.0.0` (the documented
  `169.254.0.0/16` link-local range) through the `ipv4` rule in this plan file and
  blocked commits. This is a false positive and is fully addressed by **PR 12**,
  which adds `169.254.x.x` to the gitleaks `ipv4` allowlist. Verified against the
  regex: the current allowlist does not suppress it, the PR 12 allowlist does, and
  genuine public IPs are still detected. No extra fix is required, and placing
  PR 12 first removes the blocker for the rest of the stack.

---

## Local stacked PRs — build record and CLI

This batch was built as a **local** stack of seven branches off `v2` using the
`gh stack` (gh-stack) extension: the plan document's own branch
(`pr/00-improvements-plan`), followed by the six scan-secret + markdown-linting
PRs. Nothing has been pushed to the remote. Every commit passed the full
pre-commit gate (`scan-secrets`, `check-file-format`, `check-markdown-format`,
`check-markdown-links`), and `make lint` and `make test` pass on the top of the
stack.

### Build record

Branches are listed bottom (closest to `v2`) to top. Commit hashes are the current
local values and will change if the stack is rebased or pushed.

| Order | PR    | Branch                         | Commit    | Summary                                                                                         |
| ----- | ----- | ------------------------------ | --------- | ----------------------------------------------------------------------------------------------- |
| 0     | —     | `pr/00-improvements-plan`      | `HEAD`    | this plan document (no code)                                                                    |
| 1     | PR 12 | `pr/12-gitleaks-allowlist`     | `836bce5` | gitleaks allowlist: link-local IPs + lockfiles                                                  |
| 2     | PR 8  | `pr/08-scan-secrets-hardening` | `cd17054` | `scan-secrets.sh` best practices + guard + 6 check modes + scenario-testing fixes               |
| 3     | PR 7  | `pr/07-markdown-check-scripts` | `4cde6f5` | markdown check scripts: best practices + guard + explicit Docker workdir + aligned default mode |
| 4     | PR 9  | `pr/09-frontmatter-blank-line` | `7009b81` | enforce blank line after YAML frontmatter                                                       |
| 5     | PR 11 | `pr/11-skip-deleted-links`     | `7f7fdf7` | skip deleted files in both markdown checks                                                      |
| 6     | PR 10 | `pr/10-prettier-tables`        | `e3fcb4e` | `make format` via prettier + MD060 rule                                                         |

### Review outcome

Each layer was reviewed by two independent code-review agents (shell correctness,
and config/build/security). High-confidence findings were sent back and fixed
before this record was written:

- **PR 11 `set -e` bug (caught during build):** the deleted-file filter first used
  `[ -f "$f" ] && printf …`; under `set -euo pipefail` that aborts when the deleted
  file is last in the list. Replaced with an `if/then/fi` body that always exits 0.
- **PR 11 scope (review):** the same deleted-file filter was extended to
  `check-markdown-format.sh` (its `all` mode is the pre-commit and CI default), so
  the commit now hardens both check scripts.
- **PR 10 prettier filter (review):** the hand-rolled `.prettierignore` pre-filter
  fed globs into `grep -E` and could silently format nothing on GNU grep. Removed
  it; prettier honours `.prettierignore` itself via `--ignore-path`. Also added the
  deleted-file filter and replaced `echo … | xargs` with a direct argument splat.
- **PR 9 (review):** documented the `python3` host dependency in the script header.

Both reviewers re-verified the fixes and reported no remaining findings and no
regressions. All four shell scripts pass `shellcheck`.

### Known limitation (out of scope)

The `branch` check mode of the markdown check scripts can still pass a
deleted-but-unstaged path to the linter (its second `git diff --name-only` has no
existence filter). This is pre-existing behaviour, not introduced by this stack,
and `branch` is not the pre-commit or CI default (both use `check=all`, which is
fixed here). Left as a follow-up.

### CLI: switch, review, and push the local stack

Prerequisite: the gh-stack extension (`gh extension install github/gh-stack`).

> Note: `v2` may carry uncommitted local changes (for example edits to
> `Makefile`, `.gitignore`, or `.github/copilot-instructions.md` from unrelated
> local tooling). Because the stack also edits `Makefile`, git will refuse to
> switch branches until those are dealt with. Run `git stash` (or commit them)
> before switching to a stack branch, then `git stash pop` after returning to
> `v2`. Run `gh stack view --json` from any stack branch, not from `v2` (the
> trunk is not part of the stack).

Switch between the local PRs:

```bash
git stash                                          # park any local changes first
gh stack checkout pr/07-markdown-check-scripts     # jump to a specific layer
gh stack view --json                               # see the whole stack (JSON)
gh stack bottom          # go to the first layer above v2 (the plan document)
gh stack top             # go to the last layer (PR 10)
gh stack down            # move one layer toward v2
gh stack up              # move one layer away from v2
git checkout pr/09-frontmatter-blank-line          # plain git also works
```

Review the changes, one layer at a time or cumulatively:

```bash
git --no-pager log --oneline --reverse v2..pr/10-prettier-tables   # the 7 commits
git show pr/11-skip-deleted-links                                  # one layer: message + diff
git --no-pager diff v2..pr/10-prettier-tables                      # the whole stack as one diff
```

Run the quality gates on any layer (checkout the branch first):

```bash
make lint      # file-format + markdown-format + markdown-links
make test      # template stub in this repo
```

Push to the remote only when you are ready (this is the first network step):

```bash
gh stack push                # push all seven branches, do NOT open PRs
gh stack submit --auto       # push AND open a draft PR per branch, linked as a stack
gh stack submit --auto --open   # same, but open the PRs ready for review
```

To tear the stack down locally without touching the remote:

```bash
gh stack unstack --local     # remove local stack tracking (keeps the branches)
git branch -D pr/00-improvements-plan pr/12-gitleaks-allowlist ...   # delete branches if desired
```

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

**Status**: ✅ Built locally — position 3 of 6 in the scan-secret + markdown-linting
stack (`v2` → PR 12 → PR 8 → **PR 7** → PR 9 → PR 11 → PR 10). Branch
off PR 8.

**Scope**: Shell script quality / defensive scripting
**Risk**: Low
**Depends on**: PR 5 (shared conventions; different files, no conflict)
**Files**: `scripts/quality/check-markdown-format.sh`,
`scripts/quality/check-markdown-links.sh`

**Context**: Applies the PR 5 patterns (`local check`/`local files`, `return 0`,
`main`/`is-arg-true` docs) and adds a `*)` catch-all to the `case $check` dispatch
so an unrecognised mode fails loudly instead of silently producing an empty file
list. (Upstream `check-file-format.sh` already has this guard; these two scripts
are the ones missing it among the markdown checks.) It also lands two consistency
fixes surfaced during review:

- **Explicit `--workdir /workdir` on the markdownlint Docker run.** The command
  passed repo-relative file paths and absolute config paths but set no working
  directory, so it worked only because the `markdownlint-cli` image ships with an
  implicit `WORKDIR /workdir`. `check-markdown-links.sh`, `check-shell-lint.sh`
  and `scan-secrets.sh` all set `--workdir` explicitly; this makes the markdown
  format script match and removes the reliance on an image default.
- **`check-markdown-links.sh` default mode `all` → `working-tree-changes`.** Every
  caller (pre-commit, the Makefile targets, the CI composite actions) passes
  `check=all` explicitly, so this only affects bare direct invocations and brings
  the script's default into line with `check-markdown-format.sh` and
  `check-file-format.sh`.

**Verification**:
`make check-markdown-format check=all` and `make check-markdown-links check=all`
→ ok; `check=nonsense ./scripts/quality/check-markdown-format.sh` → exits `1` with
`Unrecognised check mode: nonsense`. `shellcheck` passes on both scripts. Docker
mode resolves relative file paths under `/workdir`, and
`./scripts/quality/check-markdown-links.sh` with no `check` set now scans
working-tree changes.

**Diff**: Removed — built locally on `pr/07-markdown-check-scripts`
(commit `4cde6f5`); see `git show pr/07-markdown-check-scripts` or
`git diff v2..pr/07-markdown-check-scripts -- scripts/quality/check-markdown-format.sh scripts/quality/check-markdown-links.sh`
for the change.

---

## PR 8: `scan-secrets.sh` — best practices, guard, and a six-mode check vocabulary

**Status**: ✅ Built locally — position 2 of 6 in the scan-secret + markdown-linting
stack (`v2` → PR 12 → **PR 8** → PR 7 → PR 9 → PR 11 → PR 10). Branch
off PR 12. Brought to the front with PR 12 as part of the scan-secret group.

**Scope**: Shell script quality / bug fix
**Risk**: Low
**Depends on**: PR 5 (shared conventions; single file, no conflict)
**Files**: `scripts/quality/scan-secrets.sh`, `scripts/init.mk` (make-target help text)

**Context**: Combines the hygiene and correctness fixes for this file with a
`check` vocabulary that matches the other quality scripts. `local` declarations,
`main`/`run-check`/`is-arg-true` docs, a `*)` guard (returns `126`, matching the
documented exit code), the **quoting fix** `--workdir "$dir"` (prevents
word-splitting on paths with spaces), consistent `--redact` across all modes,
and explicit exit-code propagation (`run-check` and the `run-gitleaks-*` helpers
capture and return gitleaks' code) so the aggregated `all` mode cannot mask a
leak found by an earlier sub-check.

**Check-mode redesign**: `scan-secrets.sh` previously understood only
`whole-history`, `last-commit` and `staged-changes`, with different semantics
and a different default from the sibling scripts. It now offers the same
six-mode vocabulary as `check-file-format.sh` / `check-markdown-format.sh` /
`check-markdown-links.sh`, each mapped to the appropriate gitleaks invocation:

| `check=`               | gitleaks invocation                                   | Scans                                                       |
| ---------------------- | ----------------------------------------------------- | ----------------------------------------------------------- |
| `all`                  | runs the three below, aggregated                      | staged + working-tree + branch (a full local check)         |
| `staged-changes`       | `protect --staged`                                    | the index (changes staged for commit)                       |
| `working-tree-changes` | `protect`                                             | unstaged working-tree modifications                         |
| `branch`               | `detect --log-opts ${BRANCH_NAME:-origin/main}..HEAD` | commits made on this branch since it diverged from the base |
| `whole-history`        | `detect` (gitleaks' default `git log --all`)          | every commit on every branch — **the default**              |
| `last-commit`          | `detect --log-opts -1`                                | the tip commit only                                         |

The default is `whole-history` (all commits on all branches), matching the
`scan-secrets` make target (`check ?= whole-history`) and the CI/pre-commit
wiring. `branch` is the scoped mode: it only walks this branch's own commits, so
it does not fail on secrets that live only on an unrelated branch another
developer pushed. An unrecognised mode prints `Unrecognised check mode` and
exits `126`.

> Note: this supersedes the earlier interim change that made `whole-history`
> itself branch-scoped (`--log-opts HEAD`). Per the maintainers' intent
> (`whole-history` = the most thorough scan, and the "do not change
> `check=whole-history`" note on the CI action), `whole-history` again scans all
> branches, and the new `branch` mode carries the scoped behaviour. CI and the
> pre-commit hook remain on `check=whole-history`; switch them to `check=branch`
> if per-branch isolation is preferred over full-history scanning.

**Native/Docker parity fix (kept from the prior round)**: gitleaks' Fingerprint
is `<commit>:<file>:<rule>:<line>`. On a developer machine with a customised
global git config (e.g. `git config --global log.date relative`, a common
dotfiles setting), native gitleaks inherits it and its git-log parser drops the
commit hash from findings (`Commit: ""`), whereas the pinned Docker image runs
its own bundled git with no user config. The scan still fails either way (no
security gap), but the Fingerprint text would diverge between a developer's
native run and CI's Docker run of the identical commit, silently breaking
`.gitleaks-baseline.json` suppression consistency. `run-gitleaks-natively` now
runs gitleaks with `GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null`,
making native fingerprints deterministic and identical to Docker's.

**Scenario testing (this update)** — every claim below was proven twice, with
two independent fixture sets, in disposable `/tmp` sandboxes that copied this
script, `docker.lib.sh`, `gitleaks.toml` and `.tool-versions` verbatim and ran
the real code paths (never the real repo). A delegated agent used
`aws-access-token` fixtures; an independent judging pass used high-entropy
`generic-api-key` fixtures. Both reached identical conclusions. The sandbox
planted five distinct secrets: one on an unmerged `other` branch (S_OTHER), two
committed on the `feature` branch (S_BRANCH in commit C1, S_LAST in the tip
commit C2), one unstaged working-tree edit (S_WT), and one staged-only file
(S_STAGED). Results, checked on the `feature` branch:

| `check=`               | Finds                                          | Correctly excludes                     | Exit |
| ---------------------- | ---------------------------------------------- | -------------------------------------- | ---- |
| `staged-changes`       | S_STAGED                                       | S_WT, committed, other-branch          | 1    |
| `working-tree-changes` | S_WT                                           | S_STAGED, committed, other-branch      | 1    |
| `branch`               | S_BRANCH + S_LAST                              | S_OTHER, uncommitted                   | 1    |
| `last-commit`          | S_LAST (tip only)                              | S_BRANCH (earlier commit), uncommitted | 1    |
| `whole-history`        | S_BRANCH + S_LAST + **S_OTHER**                | uncommitted                            | 1    |
| `all`                  | S_STAGED + S_WT + S_BRANCH + S_LAST (3 passes) | S_OTHER                                | 1    |
| default (no `check`)   | identical to `whole-history`                   | —                                      | 1    |
| invalid (`bogus`)      | — (`Unrecognised check mode`)                  | —                                      | 126  |

The decisive proofs: `whole-history` finds the unmerged **other-branch** secret
(S_OTHER) — confirming the `--all` traversal — while `branch` and `all` exclude
it; `last-commit` finds only the tip commit; staged vs working-tree are cleanly
separated; and `all` performs exactly three gitleaks passes and fails if any
finds a leak.

**Native vs Docker parity** was verified for all six modes plus the default and
invalid cases: identical exit codes and identical finding sets, with matching
fingerprints (including commit hashes for the detect modes, thanks to the
`GIT_CONFIG` isolation above). The `detect` modes (`branch`, `whole-history`,
`last-commit`) are fully robust. The `staged-changes` mode is likewise robust
(it diffs the index, not the working tree).

**Documented non-issue (working-tree-changes + Docker)**: running a native
gitleaks scan and a Docker gitleaks scan back-to-back on the _same_ working tree
can make the second (Docker) `working-tree-changes` scan miss the change,
because the native run rewrites git's racy-index stat cache and the container's
older git then sees the unstaged file as clean across the bind-mount boundary.
This is a test-sequencing artifact, not a production path — a real scan runs
once, via one runtime; a single Docker `working-tree-changes` run (even after a
normal IDE `git status`/`git diff`) detects the secret correctly, and both
`staged-changes` and all `detect` modes are immune. On developer machines
gitleaks is a pinned native tool, so the local `protect` modes run natively in
practice, and CI/pre-commit use `whole-history` (a `detect` mode).

**Verification**: `make scan-secrets check=<mode>` for every mode runs on the
real tree; `check=bogus` → `Unrecognised check mode` and exit `126`;
`make check-shell-lint`, `make lint` and `make test` all pass on top of the
full 6-branch stack; real-tree `check=whole-history` (all branches, ~3.6 MB) and
`check=branch` scans are clean.

**Diff**: Removed — built locally on `pr/08-scan-secrets-hardening`
(commit `cd17054`); see `git show pr/08-scan-secrets-hardening` or
`git diff v2..pr/08-scan-secrets-hardening -- scripts/quality/scan-secrets.sh`
for the change. Summary of the behavioural core: `main()` dispatches `all` to
three aggregated `run-check` calls and every other mode (`staged-changes`,
`working-tree-changes`, `branch`, `whole-history`, `last-commit`) to a single
`run-check`; `run-check` and the `run-gitleaks-*` helpers capture gitleaks'
exit code (`|| rc=$?`) and `return "$rc"` so the `all` aggregation is correct,
and `run-gitleaks-natively` prefixes the call with
`GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null`. `scripts/init.mk`
updates the make-target help to
`check=all|staged-changes|working-tree-changes|branch|whole-history|last-commit`.

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

**Status**: ✅ Built locally — position 4 of 6 in the scan-secret + markdown-linting
stack (`v2` → PR 12 → PR 8 → PR 7 → **PR 9** → PR 11 → PR 10). Branch
off PR 7.

**Scope**: Markdown quality
**Risk**: Low
**Depends on**: PR 7 (same file — `check-markdown-format.sh`)
**Files**: `scripts/quality/check-markdown-format.sh`

**Context**: markdownlint does not enforce a blank line between a file's closing
YAML frontmatter `---` and the first content line (MD022 ignores frontmatter
delimiters). A small `check-frontmatter-blank-line` function, invoked after
markdownlint, flags files whose content starts immediately after the
frontmatter. Useful for repositories whose instruction/prompt/ADR files begin with
frontmatter. Dependency: `python3` only (already present wherever `pre-commit`
runs); native, no Docker path needed.

**Verification**: a `.md` file with frontmatter immediately followed by content
fails with `missing blank line after YAML frontmatter`; inserting the blank line
passes. `make check-markdown-format check=all` stays green on the current tree.

**Diff**: Removed — built locally on `pr/09-frontmatter-blank-line`
(commit `7009b81`); see `git show pr/09-frontmatter-blank-line` or
`git diff v2..pr/09-frontmatter-blank-line -- scripts/quality/check-markdown-format.sh`
for the change.

---

## PR 10: Auto-format markdown tables with Prettier

**Status**: ✅ Built locally — position 6 of 6 (last) in the scan-secret +
markdown-linting stack (`v2` → PR 12 → PR 8 → PR 7 → PR 9 → PR 11 →
**PR 10**). Branch off PR 11. Raised last because it introduces a new runtime
dependency (Node/`npx` or the Docker `node` image) and has no code dependency on
the earlier PRs.

**Scope**: Markdown tooling / developer experience
**Risk**: Low — **adds a new runtime dependency** (Node/`npx` or the Docker `node` image)
**Depends on**: nothing (independent; complements PR 7/9)
**Files**: `scripts/quality/format-markdown-tables.sh` (new),
`scripts/config/prettierrc.yaml` (new), `scripts/config/.prettierignore` (new),
`scripts/config/markdownlint.yaml`, `Makefile`, `.tool-versions`

**Context**: This implements the `format` target (a TODO stub in `v2`) as a
Prettier wrapper that aligns markdown tables to the MD060 `aligned` style, run
either natively via `npx prettier@3` or through the pinned `node` Docker image.
Tables are common in READMEs, ADRs, and guides, and manual alignment is tedious —
this makes `make format` do it automatically and `make lint-markdown-format`
enforce it via the accompanying MD060 rule.

**Dependency note**: this is the only markdown item that adds a new runtime
dependency — Node.js/`npx`, or a running Docker daemon plus the pinned `node`
image. The cost is contained: Prettier is scoped to markdown **tables only**
(`proseWrap: preserve` prevents any prose or code reformatting), and the script
falls back to the pinned Docker `node` image when `npx` is absent, so a local Node
install is not strictly required.

**Native/Docker parity note**: `.tool-versions` pins the `node` Docker image
(`docker/node 22.23.2-slim@sha256:…`) for the container path. To keep native and
Docker execution on the same runtime — and to follow the template's dual-pin
convention already used for `editorconfig-checker` and `gitleaks` — a **matching
native pin `nodejs 22.23.2`** is added to the asdf section. That is the exact Node
version inside the pinned digest (read from the image), with a
`keep in sync with the nodejs version above` note on the Docker line. This also
populates the `nodejs_version` that the CI pipeline already extracts from
`.tool-versions` (`grep "^nodejs\s"` in `cicd-1-pull-request.yaml` /
`cicd-3-deploy.yaml`), which was previously empty. The Docker tag was **narrowed
from `22-slim` to `22.23.2-slim`** so it reads as an exact version like every other
pin in the file (`gitleaks v8.30.0`, `shellcheck v0.11.0`, …) and visibly matches the
native `nodejs` pin. This is cosmetic-but-consistent: `docker.lib.sh` pulls **by
digest** (`docker pull node@sha256:…`) and only uses the tag as a local label, so the
**digest is the true immutability guarantee** — indeed the live `22-slim` and even
`22.23.2-slim` tags have since been rebuilt to a newer digest, while the pinned digest
stays fixed at the validated 22.23.2 image. When bumping Node, update the native pin,
the Docker tag, and the digest together. Note the tool that actually governs
`make format` output is Prettier (`npx --yes prettier@3`), whose exact 3.x is resolved
at runtime in both paths; pinning Prettier exactly (for example `prettier@3.3.3`) would
be the
higher-impact determinism follow-up.

**New/changed files**: `scripts/quality/format-markdown-tables.sh` (new),
`scripts/config/prettierrc.yaml` (new), `scripts/config/.prettierignore` (new),
`scripts/config/markdownlint.yaml` (adds MD060), `Makefile` (implements the
`format` target), `.tool-versions` (pins the `node` image plus the matching
native `nodejs` version).

**Diff**: Removed — built locally on `pr/10-prettier-tables`
(commit `e3fcb4e`); see `git show pr/10-prettier-tables` or
`git diff v2..pr/10-prettier-tables` for the change.

**Verification**: `make format` aligns tracked `*.md` tables in place;
`make lint-markdown-format check=all` passes MD060; `FORCE_USE_DOCKER=true make format`
uses the pinned node image.

---

## PR 11: Skip deleted files in the markdown link check

**Status**: ✅ Built locally — position 5 of 6 in the scan-secret + markdown-linting
stack (`v2` → PR 12 → PR 8 → PR 7 → PR 9 → **PR 11** → PR 10). Branch
off PR 9 (or off PR 7, since both touch different files with no conflict).

**Scope**: Robustness
**Risk**: Low
**Depends on**: PR 7 (same file — `check-markdown-links.sh`)
**Files**: `scripts/quality/check-markdown-links.sh`

**Context**: In `check=all` mode the link checker feeds `git ls-files "*.md"`
straight to lychee. `git ls-files` can list a tracked file that no longer exists on
disk (deleted but not yet staged), making lychee error on a missing path. The fix
filters the list to existing files only — a small, self-contained robustness fix.

**Verification**: `make check-markdown-links check=all` succeeds even when a tracked
`*.md` file is deleted in the working tree but not yet staged.

**Diff**: Removed — built locally on `pr/11-skip-deleted-links`
(commit `7f7fdf7`); see `git show pr/11-skip-deleted-links` or
`git diff v2..pr/11-skip-deleted-links` for the change.

---

## PR 12: Reduce gitleaks false positives (link-local IPs + lockfile allowlist)

**Status**: ✅ Built locally — position 1 of 6 in the scan-secret +
markdown-linting stack (`v2` → **PR 12** → PR 8 → PR 7 → PR 9 → PR 11 →
PR 10). Branch off `v2`. Placed first so the gitleaks allowlist fix lands before
any other commit and stops the link-local IP false positive from blocking the rest
of the stack.

**Scope**: Secret-scanning config
**Risk**: Low
**Depends on**: nothing
**Files**: `scripts/config/gitleaks.toml`

**Context**: Extends the gitleaks allowlist with two general-purpose, low-risk
categories: the `169.254.0.0/16` link-local IPv4 range in the IP-address
allowlist regex, and a comprehensive dependency-lockfile allowlist covering the
most popular and modern Python, JavaScript/TypeScript, and Terraform/OpenTofu
tooling (their hashes routinely trip secret scanners). Both reduce false
positives for any repository without weakening real secret detection.

**Lockfile coverage (broadened from the original enumerated list)**: rather than
naming each lockfile individually, the allowlist uses a single regex matching
any path ending in `.lock` (optionally followed by another extension), at any
depth — covering Python (`poetry.lock`, `Pipfile.lock`, `uv.lock`, `pdm.lock`),
JavaScript/TypeScript (`yarn.lock`, `bun.lock`, `deno.lock`), and
Terraform/OpenTofu (`.terraform.lock.hcl`). `gitleaks` `paths` entries are
regular expressions, not globs — a literal glob such as `*.lock` would crash
gitleaks outright (invalid regex, no argument for the repetition operator), so
proper regex is used. Verified empirically against the installed gitleaks
binary: `poetry.lock`, `Pipfile.lock`, `uv.lock`, `pdm.lock`, `yarn.lock`,
`bun.lock`, `deno.lock`, and `.terraform.lock.hcl` are all suppressed
(including nested paths); `package-lock.json`, `npm-shrinkwrap.json`, and
`pnpm-lock.yaml` remain covered by gitleaks' own default global allowlist
(`useDefault = true`), not by this pattern; negative-control files (e.g.
`requirements.txt`, `unlock.py`, `lockdown.txt`) are still flagged; and a
genuine injected secret is still detected. Trade-off: this is broader than an
enumerated list — it would also allowlist any future file whose name happens
to end in `.lock`, which is an accepted, documented risk for the reduction in
maintenance burden. The one accepted gap is Bun's legacy binary lockfile
(`bun.lockb`), which does not end in `.lock` and is not in gitleaks' own
defaults either; Bun's current default format, the text-based `bun.lock`, is
covered.

**Resolves a real blocker**: during the first attempt to build this stack, the
`scan-secrets` pre-commit hook flagged `169.254.0.0` (the `169.254.0.0/16`
link-local example in `IMPROVEMENTS_PLAN.md`) through the `ipv4` rule and blocked
every commit. The `169.254.x.x` allowlist entry below removes exactly that false
positive. Verified against the regex: the current allowlist does not match
`169.254.0.0`, the updated allowlist does, and genuine public IPs remain detected.
This is why PR 12 sits at the base of the stack.

**Verification**: `make scan-secrets check=whole-history` no longer flags
lockfile hashes or link-local addresses; genuine secrets are still detected.

**Diff**: Removed — built locally on `pr/12-gitleaks-allowlist`
(commit `836bce5`); see `git show pr/12-gitleaks-allowlist` or
`git diff v2..pr/12-gitleaks-allowlist -- scripts/config/gitleaks.toml`
for the change.

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
`scripts/quality/check-markdown-links.sh`, `scripts/quality/check-file-format.sh`,
`scripts/quality/check-shell-lint.sh` (aligning with `scripts/quality/scan-secrets.sh`)

**Context**: The quality scripts disagree on how an unrecognised `check` mode is
reported. `scan-secrets.sh` (PR 8) uses `return 126` and documents it in an
`Exit codes` block, deliberately distinguishing a usage error from a real finding
(`1`). `check-markdown-format.sh`, `check-markdown-links.sh` and
`check-file-format.sh` instead `echo … >&2 && exit 1`, conflating "you passed a
bad mode" with "the check failed". `check-shell-lint.sh` has no dispatch guard at
all. This divergence means a caller cannot rely on the exit code to tell a
misconfiguration apart from a genuine lint/format/secret failure.

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

**Placement**: This re-touches files already hardened in PR 7 (markdown checks)
and PR 8 (`scan-secrets.sh`), so slot it as a new layer **above** the existing
scan-secret + markdown-linting stack, or fold it into PR 7 / PR 8 / PR 19 if
the maintainer wants a single pass per file. No hard dependency beyond the scripts
existing.

**Verification**: For each script, `check=nonsense ./scripts/quality/<script>.sh`
exits `126` and prints `Unrecognised check mode: nonsense`; a real failure still
exits `1`; `shellcheck` passes on all five scripts; `make lint` and `make test`
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

**Context**: The markdown scripts build a newline-separated `files` string and then
rely on **unquoted** `$files` (guarded by `# shellcheck disable=SC2086`) to split
it into arguments for `markdownlint` / `lychee`. This is the repo-wide pattern, but
it is the classic word-splitting anti-pattern (`[SH-ANT-001]`, `[SH-ANT-006]`): any
tracked Markdown path containing a space or glob character is split or expanded
incorrectly. It works today only because the repository has no such paths.

**Proposed change**: Collect the file list into a bash array and expand it quoted,
removing the `SC2086` disables:

```bash
local -a files
mapfile -t files < <(git ls-files "*.md")   # or the per-mode git command
# ...
if [ "${#files[@]}" -gt 0 ]; then
  files=("${files[@]}") run-…            # pass via a name-ref or a positional splat
fi
```

Because the current design passes `files` to the runner functions **as an
environment variable** (a string), this PR also adjusts the runner interface to
accept the list positionally (e.g. `run-markdownlint-natively "${files[@]}"`) so the
array survives without re-splitting. The empty-list guard (`if [ -n "$files" ]`)
becomes `if [ "${#files[@]}" -gt 0 ]`. The same treatment applies to the prettier
wrapper added in PR 10.

**Placement**: Re-touches PR 7 (markdown checks) and PR 10 (`format-markdown-tables.sh`),
so slot it as a new layer **above** the existing stack, or fold it into PR 7 / PR 10.
Keep it separate from PR 16 (different concern, different lines) unless doing a single
per-file pass. `check-file-format.sh`'s `$($filter)` splat can be included here or in
PR 19.

**Verification**: Add a temporary tracked Markdown file with a space in its name and
confirm both checks lint it (native and `FORCE_USE_DOCKER=true`); confirm the empty
selection (`check=working-tree-changes` with no changes) runs nothing rather than
linting the whole repo; `shellcheck` passes with the `SC2086` disables removed;
`make lint` and `make test` are green.

---

## PR 18: Resolve the `check=branch` base dynamically (any branch → any base)

**Status**: New — surfaced during the PR 7 review and the `check=branch` scoping
investigation. Recorded only (not yet built). **Supersedes the removed Optional A.**

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

**Relationship**: touches the same file as PR 16 (exit-code harmonisation) and PR 18
(base resolution); if those land together, apply all three in one pass over
`check-file-format.sh`. No hard dependency.

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
