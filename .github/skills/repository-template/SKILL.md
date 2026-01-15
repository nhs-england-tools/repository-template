---
name: repository-template
description: Toolkit for creating a code repository from template, or/and updating it in parts from the content of the template that contains example of use of tools like make, pre-commit git hooks, Docker, Terraform etc.
---

# Repository Template Skill

This skill enables adopting, configuring, or removing capabilities from the [NHS England Tools Repository Template](https://github.com/nhs-england-tools/repository-template). Each capability is modular and can be applied independently.

## Source Reference

All implementation files are located in the `assets/` subdirectory, which is a git subtree of the upstream repository template. When copying files to a target repository, use the contents from:

```text
.github/skills/repository-template/assets/
```

For example, to adopt `scripts/init.mk`, copy from:

```text
.github/skills/repository-template/assets/scripts/init.mk
```

to your target repository's `scripts/init.mk`.

⚠️ Distribution note: this SKILL file is mirrored verbatim across three homes - the NHS England shared GitHub Copilot prompt catalogue (similar to the [Awesome GitHub Copilot Customizations](https://github.com/github/awesome-copilot)), the upstream [Repository Template](https://github.com/nhs-england-tools/repository-template), and every repository created from that template. Keep the wording identical in all locations, instead of editing per environment, detect where you are and resolve paths accordingly.

🤖 Assistant behaviour: when a user asks broad questions such as _"repository template – describe how to use this skill"_, respond by summarising the capability list below, you must list all the capabilities in a tabular form as the next step and invite user to issue a follow-up prompt that names a specific capability plus an action (add, remove or improve) they want performed in their repository. This keeps replies actionable and focused on the modular building blocks.

AI assistants or automation should detect the active context before copying files. For a reliable conclusion, check the repository's git URL first (for example, `git remote get-url origin`). If it points to `nhs-england-tools/repository-template`, you are working inside the upstream template and can read directly from the project root.

Use the following checks after confirming the git URL:

1. If `.github/skills/repository-template/assets/` exists and contains files, use that subtree as the source (typical in the prompt catalogue or when the assets subtree is vendor-copied).
2. If the `assets/` directory exists but is empty while template root files such as `Makefile`, `scripts/`, and `docs/` are present, you are inside the `repository-template` itself—read directly from the project root.
3. If neither case applies (for example, inside a repository that was generated from the template), treat the instructions as referring to files rooted in the current repository, because the template content has already been adopted there.

When in doubt, follow the [Updating from the template repository](./SKILL.md#updating-from-the-template-repository) workflow to pull fresh assets.

## Quick Reference

| Capability                                                         | Purpose                      | Key Files                                                                       |
| ------------------------------------------------------------------ | ---------------------------- | ------------------------------------------------------------------------------- |
| [Core Make System](#1-core-make-system)                            | Standardised task runner     | `Makefile`, `scripts/init.mk`                                                   |
| [Pre-commit Hooks](#2-pre-commit-hooks)                            | Git hooks framework          | `scripts/config/pre-commit.yaml`, `scripts/githooks/`                           |
| [Secret Scanning](#3-secret-scanning-gitleaks)                     | Prevent credential leaks     | `scripts/githooks/scan-secrets.sh`, `scripts/config/gitleaks.toml`              |
| [File Format Checking](#4-file-format-checking-editorconfig)       | Consistent file formatting   | `.editorconfig`, `scripts/githooks/check-file-format.sh`                        |
| [Markdown Linting](#5-markdown-linting)                            | Documentation quality        | `scripts/githooks/check-markdown-format.sh`, `scripts/config/markdownlint.yaml` |
| [English Prose Checking](#6-english-prose-checking-vale)           | Writing quality              | `scripts/githooks/check-english-usage.sh`, `scripts/config/vale/`               |
| [Docker Support](#7-docker-support)                                | Container build/run/lint     | `scripts/docker/`, `scripts/config/hadolint.yaml`                               |
| [Terraform Support](#8-terraform-support)                          | IaC linting and formatting   | `scripts/terraform/`, `infrastructure/`                                         |
| [Shell Script Linting](#9-shell-script-linting-shellcheck)         | Bash quality checks          | `scripts/shellscript-linter.sh`                                                 |
| [Test Framework](#10-test-framework)                               | Standardised test targets    | `scripts/tests/test.mk`                                                         |
| [GitHub Actions CI/CD](#11-github-actions-cicd)                    | Pipeline workflows           | `.github/workflows/`, `.github/actions/`                                        |
| [Local GitHub Actions Runner](#12-local-github-actions-runner-act) | Run workflows locally        | `scripts/init.mk` (runner-act target)                                           |
| [Dependency Scanning](#13-dependency-scanning-grype--syft)         | Vulnerability scanning       | `scripts/config/grype.yaml`, `scripts/reports/create-sbom-report.sh`            |
| [Lines of Code Reporting](#14-lines-of-code-reporting)             | Codebase metrics             | `scripts/reports/create-lines-of-code-report.sh`                                |
| [VS Code Integration](#15-vs-code-integration)                     | Editor configuration         | `.vscode/`, `project.code-workspace`                                            |
| [Dev Container](#16-dev-container)                                 | Containerised development    | `.devcontainer/devcontainer.json`                                               |
| [Tool Version Management](#17-tool-version-management-asdf)        | Reproducible toolchain       | `.tool-versions`                                                                |
| [GitHub Repository Templates](#18-github-repository-templates)     | Issue/PR/security templates  | `.github/ISSUE_TEMPLATE/`, `.github/PULL_REQUEST_TEMPLATE.md`                   |
| [Dependabot](#19-dependabot)                                       | Automated dependency updates | `.github/dependabot.yaml`                                                       |
| [Documentation Structure](#20-documentation-structure)             | ADRs and guides              | `docs/adr/`, `docs/user-guides/`, `docs/developer-guides/`                      |
| [Static Analysis](#21-static-analysis-sonarcloud)                  | Code quality inspection      | `scripts/reports/perform-static-analysis.sh`                                    |

---

## Capabilities

### 1. Core Make System

**Purpose**: Provides a standardised task runner with self-documenting help, common targets, and extensibility.

**Dependencies**: GNU Make 3.82+

**Source files** (in `assets/`):

- [`Makefile`](assets/Makefile) — Project-specific targets (customise this)
- [`scripts/init.mk`](assets/scripts/init.mk) — Common targets and infrastructure (do not edit)

**Key make targets**:

```bash
make help              # Show all available targets with descriptions
make config            # Configure development environment
make clean             # Remove generated files
make list-variables    # Debug: show all make variables
```

**To adopt**:

1. Copy `assets/Makefile` and `assets/scripts/init.mk` to your repository
2. Customise the `Makefile` with your project-specific targets
3. Add `@Pipeline`, `@Operations`, `@Configuration`, `@Development`, `@Testing`, `@Quality`, or `@Others` annotations to target comments for categorisation

**Verification** (run after adoption):

```bash
# Check make is available and version is 3.82+
make --version | head -1

# Verify help target works and shows categorised output
make help

# Expected: Exit code 0, output includes target names with descriptions
# Success indicator: Output contains "help" target and category headers
```

**To remove**: Delete `Makefile` and `scripts/init.mk`

---

### 2. Pre-commit Hooks

**Purpose**: Framework for running quality checks before commits using the `pre-commit` tool.

**Dependencies**: Python, pre-commit (`pip install pre-commit`)

**Source files** (in `assets/`):

- [`scripts/config/pre-commit.yaml`](assets/scripts/config/pre-commit.yaml) — Hook definitions

**Configuration**:

```bash
make githooks-config   # Install hooks
make githooks-run      # Run all hooks manually
```

**Available hooks** (each can be enabled/disabled in `pre-commit.yaml`):

- `scan-secrets` — Gitleaks secret scanning
- `check-file-format` — EditorConfig compliance
- `check-markdown-format` — Markdown linting
- `check-english-usage` — Vale prose linting
- `lint-terraform` — Terraform formatting

**To adopt**:

1. Copy `scripts/config/pre-commit.yaml`
2. Copy the corresponding `scripts/githooks/*.sh` scripts for enabled hooks
3. Add `pre-commit` to `.tool-versions` (e.g., `pre-commit 4.5.1`)
4. Run `asdf install` to install pre-commit
5. Run `make githooks-config`

**Verification** (run after adoption):

```bash
# Check pre-commit is installed
pre-commit --version

# Verify hooks are configured
test -f .git/hooks/pre-commit && echo "Hooks installed" || echo "Hooks not installed"

# Run hooks manually (should complete without errors on clean repo)
pre-commit run --config scripts/config/pre-commit.yaml --all-files

# Expected: Exit code 0 if all checks pass, non-zero if issues found
# Success indicator: "Passed" or "Skipped" for each hook
```

**To remove**:

1. Run `pre-commit uninstall`
2. Delete `scripts/config/pre-commit.yaml` and `scripts/githooks/`

---

### 3. Secret Scanning (Gitleaks)

**Purpose**: Prevent hardcoded secrets from being committed to the repository.

**Dependencies**: Gitleaks (native or Docker)

**Source files** (in `assets/`):

- [`scripts/githooks/scan-secrets.sh`](assets/scripts/githooks/scan-secrets.sh) — Scanner wrapper
- [`scripts/config/gitleaks.toml`](assets/scripts/config/gitleaks.toml) — Gitleaks configuration
- [`.gitleaksignore`](assets/.gitleaksignore) — Ignore file for false positives

**Check modes**:

```bash
check=staged-changes ./scripts/githooks/scan-secrets.sh   # Pre-commit (default)
check=branch-changes ./scripts/githooks/scan-secrets.sh   # Commits on current branch not in main (CI)
check=last-commit ./scripts/githooks/scan-secrets.sh      # Last commit only
check=whole-history ./scripts/githooks/scan-secrets.sh    # Full repository history
```

**Configuration** (`scripts/config/gitleaks.toml`):

- Extends default Gitleaks rules
- Custom IPv4 detection with private network allowlist
- Excludes lock files (`.terraform.lock.hcl`, `poetry.lock`, `yarn.lock`)

**To adopt**:

1. Copy `scripts/githooks/scan-secrets.sh`, `scripts/config/gitleaks.toml`, and `.gitleaksignore`
2. Add `gitleaks` to `.tool-versions` (e.g., `gitleaks 8.30.0`) for native execution
3. Optionally add Docker image entry to `.tool-versions` for Docker fallback:

   ```text
   # docker/ghcr.io/gitleaks/gitleaks v8.18.0@sha256:... # SEE: https://github.com/gitleaks/gitleaks/pkgs/container/gitleaks
   ```

4. Run `asdf install` to install gitleaks (if using native)
5. Add to `pre-commit.yaml` or run standalone

**Verification** (run after adoption):

```bash
# Check gitleaks is available
gitleaks version

# Run secret scan on staged changes (default mode)
./scripts/githooks/scan-secrets.sh

# Or scan the whole repository history
check=whole-history ./scripts/githooks/scan-secrets.sh

# Alternative: run gitleaks directly
gitleaks detect --config scripts/config/gitleaks.toml --source . --verbose --redact

# Expected: Exit code 0 if no secrets found
# Success indicator: "no leaks found" or empty output
```

**To remove**: Delete the files and remove from `pre-commit.yaml`

---

### 4. File Format Checking (EditorConfig)

**Purpose**: Ensure consistent file formatting (indentation, line endings, charset) across the codebase.

**Dependencies**: editorconfig-checker (native or Docker)

**Source files** (in `assets/`):

- [`.editorconfig`](assets/.editorconfig) — Format rules
- [`scripts/githooks/check-file-format.sh`](assets/scripts/githooks/check-file-format.sh) — Checker wrapper

**Default rules** (`.editorconfig`):

```ini
[*]
charset = utf-8
end_of_line = lf
indent_size = 2
indent_style = space
insert_final_newline = true
trim_trailing_whitespace = true

[*.py]
indent_size = 4

[{Makefile,*.mk}]
indent_style = tab
```

**Check modes**:

```bash
check=all ./scripts/githooks/check-file-format.sh                # All files
check=staged-changes ./scripts/githooks/check-file-format.sh     # Staged only
check=branch ./scripts/githooks/check-file-format.sh             # Changes since branching
```

**To adopt**:

1. Copy `.editorconfig` and `scripts/githooks/check-file-format.sh`
2. Add Docker image entry to `.tool-versions` for editorconfig-checker:

   ```text
   # docker/mstruebing/editorconfig-checker 2.7.1@sha256:... # SEE: https://hub.docker.com/r/mstruebing/editorconfig-checker/tags
   ```

3. Install VS Code extension `editorconfig.editorconfig`

**Verification** (run after adoption):

```bash
# Check editorconfig-checker is available
editorconfig-checker --version || ec --version

# Run format check on all files
check=all ./scripts/githooks/check-file-format.sh

# Alternative: run checker directly
editorconfig-checker -config .editorconfig

# Expected: Exit code 0 if all files comply
# Success indicator: No output (silent success) or "No issues found"
```

**To remove**: Delete the files

---

### 5. Markdown Linting

**Purpose**: Enforce consistent Markdown formatting and best practices.

**Dependencies**: markdownlint-cli (native or Docker)

**Source files** (in `assets/`):

- [`scripts/githooks/check-markdown-format.sh`](assets/scripts/githooks/check-markdown-format.sh) — Linter wrapper
- [`scripts/config/markdownlint.yaml`](assets/scripts/config/markdownlint.yaml) — Rule configuration

**Configuration** (`scripts/config/markdownlint.yaml`):

```yaml
MD010: # Allow hard tabs in code blocks for make/console
  ignore_code_languages: [make, console]
MD013: false # Disable line length
MD024: # Allow duplicate headings in siblings
  siblings_only: true
MD033: false # Allow inline HTML
```

**To adopt**:

1. Copy `scripts/githooks/check-markdown-format.sh` and `scripts/config/markdownlint.yaml`
2. Add Docker image entry to `.tool-versions` for markdownlint-cli:

   ```text
   # docker/ghcr.io/igorshubovych/markdownlint-cli v0.37.0@sha256:... # SEE: https://github.com/igorshubovych/markdownlint-cli/pkgs/container/markdownlint-cli
   ```

3. Install VS Code extension `davidanson.vscode-markdownlint`

**Verification** (run after adoption):

```bash
# Check markdownlint is available
markdownlint --version

# Run on all markdown files
check=all ./scripts/githooks/check-markdown-format.sh

# Alternative: run markdownlint directly
markdownlint --config scripts/config/markdownlint.yaml "**/*.md"

# Expected: Exit code 0 if all files pass
# Success indicator: No output (silent success)
```

**To remove**: Delete the files

---

### 6. English Prose Checking (Vale)

**Purpose**: Check documentation for writing quality, style, and consistency.

**Dependencies**: Vale (native or Docker)

**Source files** (in `assets/`):

- [`scripts/githooks/check-english-usage.sh`](assets/scripts/githooks/check-english-usage.sh) — Vale wrapper
- [`scripts/config/vale/vale.ini`](assets/scripts/config/vale/vale.ini) — Vale configuration
- [`scripts/config/vale/styles/`](assets/scripts/config/vale/styles/) — Custom style rules

**Configuration** (`scripts/config/vale/vale.ini`):

```ini
StylesPath = styles
MinAlertLevel = suggestion
Vocab = words
[*.md]
BasedOnStyles = Vale
```

**To adopt**:

1. Copy `scripts/githooks/check-english-usage.sh` and `scripts/config/vale/`
2. Add `vale` to `.tool-versions` (e.g., `vale 3.6.0`) for native execution
3. Optionally add Docker image entry to `.tool-versions` for Docker fallback:

   ```text
   # docker/jdkato/vale v3.6.0@sha256:... # SEE: https://hub.docker.com/r/jdkato/vale/tags
   ```

4. Run `asdf install` to install vale (if using native)
5. Customise vocabulary in `scripts/config/vale/styles/words/`

**Verification** (run after adoption):

```bash
# Check vale is available
vale --version

# Sync vale styles (first time)
vale sync --config scripts/config/vale/vale.ini

# Run on markdown files
check=all ./scripts/githooks/check-english-usage.sh

# Alternative: run vale directly on a file
vale --config scripts/config/vale/vale.ini README.md

# Expected: Exit code 0 if no issues, non-zero if suggestions/warnings
# Success indicator: Shows check results per file
```

**To remove**: Delete the files

---

### 7. Docker Support

**Purpose**: Build, lint, run, and manage Docker images with standardised metadata.

**Dependencies**: Docker, hadolint (for linting)

**Source files** (in `assets/`):

- [`scripts/docker/docker.mk`](assets/scripts/docker/docker.mk) — Make targets
- [`scripts/docker/docker.lib.sh`](assets/scripts/docker/docker.lib.sh) — Shell functions library
- [`scripts/docker/dockerfile-linter.sh`](assets/scripts/docker/dockerfile-linter.sh) — Hadolint wrapper
- [`scripts/docker/Dockerfile.metadata`](assets/scripts/docker/Dockerfile.metadata) — OCI label template
- [`scripts/config/hadolint.yaml`](assets/scripts/config/hadolint.yaml) — Hadolint configuration
- [`scripts/docker/dgoss.sh`](assets/scripts/docker/dgoss.sh) — Container testing with dgoss

**Make targets**:

```bash
make docker-build      # Build image with metadata
make docker-lint       # Lint Dockerfile with hadolint
make docker-push       # Push to registry
make docker-run        # Run container
```

**Features**:

- Automatic `Dockerfile.effective` generation with version baking
- OCI-compliant image labels (title, version, git info, build date)
- Trusted registry allowlist in hadolint config
- Test suite support with dgoss
- **Docker image version pinning via `.tool-versions`** — see [Tool Version Management (asdf)](#17-tool-version-management-asdf) for the extended format

**Docker image versioning**:

Docker image versions can be pinned in `.tool-versions` using an extended comment format. The `docker-get-image-version-and-pull` function in `docker.lib.sh` parses these entries, pulls images by digest for reproducibility, and tags them locally for caching.

```text
# docker/ghcr.io/gitleaks/gitleaks v8.18.0@sha256:fd2b5cab... # SEE: https://...
```

See [section 17](#17-tool-version-management-asdf) for full format documentation.

**To adopt**:

1. Copy the entire `scripts/docker/` directory
2. Copy `scripts/config/hadolint.yaml`
3. Add Docker image entry to `.tool-versions` for hadolint:

   ```text
   # docker/hadolint/hadolint 2.12.0-alpine@sha256:... # SEE: https://hub.docker.com/r/hadolint/hadolint/tags
   ```

4. Create your Dockerfile in `infrastructure/images/`
5. Optionally add additional Docker image pins to `.tool-versions`

**Verification** (run after adoption):

```bash
# Check Docker is available
docker --version

# Check hadolint is available (for Dockerfile linting)
hadolint --version || docker run --rm hadolint/hadolint hadolint --version

# Lint a Dockerfile
./scripts/docker/dockerfile-linter.sh infrastructure/images/*/Dockerfile

# Alternative: run hadolint directly
hadolint --config scripts/config/hadolint.yaml infrastructure/images/*/Dockerfile

# Verify docker make targets exist
make help | grep -E "docker-build|docker-lint|docker-push"

# Expected: Exit code 0 if Dockerfile is valid
# Success indicator: No lint errors, make targets visible in help
```

**To remove**: Delete `scripts/docker/` and remove `include scripts/docker/docker.mk` from `scripts/init.mk`

---

### 8. Terraform Support

**Purpose**: Infrastructure as Code linting, formatting, and management.

**Dependencies**: Terraform

**Source files** (in `assets/`):

- [`scripts/terraform/`](assets/scripts/terraform/) — Make targets (optional include in init.mk)
- [`scripts/githooks/check-terraform-format.sh`](assets/scripts/githooks/check-terraform-format.sh) — Format checker
- [`infrastructure/`](assets/infrastructure/) — Directory structure for Terraform code

**Directory structure**:

```text
infrastructure/
├── environments/
│   └── dev/           # Environment-specific configs
├── images/            # Docker image definitions
└── modules/           # Reusable Terraform modules
```

**Make targets**:

```bash
make terraform-fmt     # Format Terraform files
make terraform-init    # Initialise Terraform
make terraform-plan    # Plan changes
make terraform-apply   # Apply changes
```

**To adopt**:

1. Copy `scripts/githooks/check-terraform-format.sh`
2. Create `infrastructure/` directory structure
3. Add `terraform` to `.tool-versions` (e.g., `terraform 1.7.0`)
4. Optionally add Docker image entry to `.tool-versions` for Docker fallback:

   ```text
   # docker/hashicorp/terraform 1.12.2@sha256:... # SEE: https://hub.docker.com/r/hashicorp/terraform/tags
   ```

5. Run `asdf install` to install terraform

**Verification** (run after adoption):

```bash
# Check terraform is available
terraform version

# Check format on terraform files (if any exist)
check=all ./scripts/githooks/check-terraform-format.sh

# Alternative: run terraform fmt check directly
terraform fmt -check -recursive infrastructure/

# Verify infrastructure directory structure exists
test -d infrastructure/environments && echo "Structure OK" || echo "Missing structure"

# Expected: Exit code 0 if all .tf files are formatted
# Success indicator: No output from fmt -check (files are formatted)
```

**To remove**: Delete `infrastructure/`, `scripts/terraform/`, and the pre-commit hook

---

### 9. Shell Script Linting (ShellCheck)

**Purpose**: Static analysis for shell scripts to catch common bugs and enforce best practices.

**Dependencies**: ShellCheck (native or Docker)

**Source files** (in `assets/`):

- [`scripts/shellscript-linter.sh`](assets/scripts/shellscript-linter.sh) — ShellCheck wrapper

**Usage**:

```bash
file=path/to/script.sh ./scripts/shellscript-linter.sh
make shellscript-lint-all   # Lint all .sh files
```

**Verification** (run after adoption):

```bash
# Check shellcheck is available
shellcheck --version

# Run on a specific script
file=scripts/shellscript-linter.sh ./scripts/shellscript-linter.sh

# Alternative: run shellcheck directly
shellcheck scripts/*.sh

# Expected: Exit code 0 if no issues, non-zero with error details if issues found
# Success indicator: No output (silent success) or warnings/errors listed
```

**To adopt**:

1. Copy `scripts/shellscript-linter.sh`
2. Add Docker image entry to `.tool-versions` for shellcheck:

   ```text
   # docker/koalaman/shellcheck latest@sha256:... # SEE: https://hub.docker.com/r/koalaman/shellcheck/tags
   ```

**To remove**: Delete the file

---

### 10. Test Framework

**Purpose**: Standardised make targets for all test types aligned with NHS Software Engineering Quality Framework.

**Dependencies**: Test runners for your language/framework

**Source files** (in `assets/`):

- [`scripts/tests/test.mk`](assets/scripts/tests/test.mk) — Test target definitions

**Available targets**:

```bash
make test              # Run all tests
make test-unit         # Unit tests
make test-lint         # Code linting
make test-coverage     # Coverage analysis
make test-integration  # Integration tests
make test-contract     # Contract tests
make test-security     # Security tests
make test-accessibility # Accessibility tests
make test-ui           # UI tests
make test-load         # Load tests (capacity, soak, response-time)
```

**Implementation**: Create corresponding scripts in `scripts/tests/`:

- `scripts/tests/unit.sh`
- `scripts/tests/lint.sh`
- `scripts/tests/integration.sh`
- etc.

**To adopt**:

1. Copy `scripts/tests/test.mk`
2. Create test scripts for your project

**Verification** (run after adoption):

```bash
# Verify test targets exist in make
make help | grep -E "test|test-unit|test-lint|test-coverage"

# Run tests (will fail if test scripts not yet created)
make test

# Check test.mk is included
grep -l "test.mk" scripts/init.mk Makefile

# Expected: make help shows test targets
# Success indicator: Test targets visible, `make test` runs without "no rule" error
```

**To remove**: Delete `scripts/tests/` and remove include from `scripts/init.mk`

---

### 11. GitHub Actions CI/CD

**Purpose**: Multi-stage CI/CD pipeline with reusable workflows and composite actions.

**Source files** (in `assets/`):

- [`assets/.github/workflows/cicd-1-pull-request.yaml`](assets/.github/workflows/cicd-1-pull-request.yaml) — Main PR workflow
- [`assets/.github/workflows/cicd-2-publish.yaml`](assets/.github/workflows/cicd-2-publish.yaml) — Publish workflow
- [`assets/.github/workflows/cicd-3-deploy.yaml`](assets/.github/workflows/cicd-3-deploy.yaml) — Deployment workflow
- [`assets/.github/workflows/stage-1-commit.yaml`](assets/.github/workflows/stage-1-commit.yaml) — Commit stage (quality checks)
- [`assets/.github/workflows/stage-2-test.yaml`](assets/.github/workflows/stage-2-test.yaml) — Test stage
- [`assets/.github/workflows/stage-3-build.yaml`](assets/.github/workflows/stage-3-build.yaml) — Build stage
- [`assets/.github/workflows/stage-4-acceptance.yaml`](assets/.github/workflows/stage-4-acceptance.yaml) — Acceptance stage
- [`assets/.github/actions/`](assets/.github/actions/) — Composite actions for each check

**Pipeline stages**:

1. **Commit stage** (~2 min): Secret scan, file format, Markdown, English, Terraform lint, LOC report
2. **Test stage** (~5 min): Unit, lint, coverage, contract, security, accessibility
3. **Build stage** (~3 min): Docker build, publish artefacts
4. **Acceptance stage** (~10 min): Integration, performance tests

**Composite actions** (`.github/actions/`):

- `scan-secrets/`
- `check-file-format/`
- `check-markdown-format/`
- `check-english-usage/`
- `lint-terraform/`
- `create-lines-of-code-report/`
- `perform-static-analysis/`
- `scan-dependencies/`

**To adopt**:

1. Copy `.github/workflows/` and `.github/actions/`
2. Customise stages for your project
3. Configure secrets in GitHub repository settings

**Verification** (run after adoption):

```bash
# Verify workflow files exist
ls -la .github/workflows/*.yaml

# Validate YAML syntax (requires yq or python)
yq eval '.' .github/workflows/cicd-1-pull-request.yaml > /dev/null && echo "Valid YAML"

# Check for composite actions
ls -la .github/actions/

# Verify workflow references valid actions
grep -r "uses:.*\.github/actions/" .github/workflows/

# Expected: Workflow files present, valid YAML syntax
# Success indicator: Files exist, no YAML parse errors
# Note: Full verification requires pushing to GitHub and observing Actions tab
```

**To remove**: Delete `.github/workflows/` and `.github/actions/`

---

### 12. Local GitHub Actions Runner (act)

**Purpose**: Run GitHub Actions workflows locally for faster feedback and debugging before pushing to CI.

**Dependencies**: act (GitHub Actions local runner), Docker

**Source files** (in `assets/`):

- [`scripts/init.mk`](assets/scripts/init.mk) — Contains the `runner-act` make target
- [`scripts/docker/docker.lib.sh`](assets/scripts/docker/docker.lib.sh) — Provides `docker-get-image-version-and-pull` for runner image

**Make target**:

```bash
make runner-act workflow=<workflow-file> job=<job-name>
```

**Parameters**:

| Parameter  | Required | Description                                                  |
| ---------- | -------- | ------------------------------------------------------------ |
| `workflow` | Yes      | Workflow filename without path (e.g., `cicd-1-pull-request`) |
| `job`      | Yes      | Job name to execute from the workflow                        |
| `VERBOSE`  | No       | Set to `true` for verbose act output                         |

**Example usage**:

```bash
# Run the commit stage from the PR workflow
make runner-act workflow=cicd-1-pull-request job=commit-stage

# Run with verbose output
VERBOSE=true make runner-act workflow=stage-1-commit job=scan-secrets
```

**Features**:

- Uses a pinned GitHub runner image from `.tool-versions` (see [Tool Version Management](#17-tool-version-management-asdf))
- Runs with `--privileged` for Docker-in-Docker support
- Binds local directory for file access
- Reuses containers for faster subsequent runs
- Supports `linux/amd64` architecture

**Runner image**:

The runner image is pinned in `.tool-versions` using the extended Docker format:

```text
# docker/ghcr.io/nhs-england-tools/github-runner-image 20230909-321fd1e-rt@sha256:... # SEE: https://...
```

**To adopt**:

1. Ensure `scripts/init.mk` is included in your Makefile
2. Ensure `scripts/docker/docker.lib.sh` is present
3. Add the runner image to `.tool-versions` (optional, falls back to latest)
4. Install act: `brew install act` (macOS) or see [act installation](https://github.com/nektos/act#installation)

**Verification** (run after adoption):

```bash
# Check act is installed
act --version

# Check Docker is running
docker info > /dev/null && echo "Docker OK"

# Verify runner-act target exists
make help | grep runner-act

# List available workflows
ls .github/workflows/*.yaml

# Dry-run a workflow (list jobs without executing)
act --list --workflows .github/workflows/cicd-1-pull-request.yaml

# Run a specific job
make runner-act workflow=cicd-1-pull-request job=commit-stage

# Expected: Job executes locally with GitHub Actions output
# Success indicator: Job completes with exit code 0
```

**To remove**: The `runner-act` target is part of `scripts/init.mk`. To disable, remove the target from init.mk or don't use it.

---

### 13. Dependency Scanning (Grype & Syft)

**Purpose**: Vulnerability scanning and SBOM (Software Bill of Materials) generation for container images and repositories.

**Dependencies**: Grype, Syft (via Docker or native)

**Source files** (in `assets/`):

- [`scripts/config/grype.yaml`](assets/scripts/config/grype.yaml) — Grype vulnerability scanner configuration
- [`scripts/config/syft.yaml`](assets/scripts/config/syft.yaml) — Syft SBOM generator configuration
- [`scripts/reports/create-sbom-report.sh`](assets/scripts/reports/create-sbom-report.sh) — SBOM generation wrapper
- [`scripts/reports/scan-vulnerabilities.sh`](assets/scripts/reports/scan-vulnerabilities.sh) — Vulnerability scanning wrapper

**Features**:

- Automatic CPE generation when packages lack them
- Vulnerability ignore rules by CVE, package, or type
- SBOM cataloging with configurable scope
- Wrapper scripts for CI/CD integration with JSON report enrichment

**Verification** (run after adoption):

```bash
# Check grype is available
grype version

# Check syft is available
syft version

# Generate SBOM report for the repository
./scripts/reports/create-sbom-report.sh

# Scan for vulnerabilities (depends on SBOM report)
./scripts/reports/scan-vulnerabilities.sh

# Scan a Docker image (requires built image)
grype --config scripts/config/grype.yaml <image-name>

# Generate SBOM for an image
syft --config scripts/config/syft.yaml <image-name>

# Verify config files are valid YAML
yq eval '.' scripts/config/grype.yaml > /dev/null && echo "grype.yaml valid"
yq eval '.' scripts/config/syft.yaml > /dev/null && echo "syft.yaml valid"

# Expected: Tools run without config errors
# Success indicator: Vulnerability report or SBOM generated
```

**To adopt**:

1. Copy `scripts/config/grype.yaml` and `scripts/config/syft.yaml`
2. Copy `scripts/reports/create-sbom-report.sh` and `scripts/reports/scan-vulnerabilities.sh`
3. Add Docker image entries to `.tool-versions` for grype and syft:

   ```text
   # docker/ghcr.io/anchore/grype v0.92.2@sha256:... # SEE: https://github.com/anchore/grype/pkgs/container/grype
   # docker/ghcr.io/anchore/syft v0.92.0@sha256:... # SEE: https://github.com/anchore/syft/pkgs/container/syft
   ```

4. Integrate with your Docker build pipeline or CI/CD workflows

**To remove**: Delete the configuration files and scripts

---

### 14. Lines of Code Reporting

**Purpose**: Generate codebase metrics reports with git and pipeline metadata.

**Dependencies**: gocloc (native or Docker)

**Source files** (in `assets/`):

- [`scripts/reports/create-lines-of-code-report.sh`](assets/scripts/reports/create-lines-of-code-report.sh)

**Output**: `lines-of-code-report.json` with:

- Language breakdown (files, blank, comment, code lines)
- Repository metadata (URL, branch, commit, tags)
- Pipeline metadata (run ID, number, attempt)

**Usage**:

```bash
./scripts/reports/create-lines-of-code-report.sh
```

**Verification** (run after adoption):

```bash
# Check gocloc is available
gocloc --version || docker run --rm aldanial/cloc --version

# Run the report generator
./scripts/reports/create-lines-of-code-report.sh

# Check report was created
test -f lines-of-code-report.json && echo "Report created" || echo "Report missing"

# Validate JSON output
jq '.' lines-of-code-report.json > /dev/null && echo "Valid JSON"

# Expected: JSON file created with language statistics
# Success indicator: File exists, valid JSON, contains "languages" key
```

**To adopt**:

1. Copy the script
2. Add Docker image entry to `.tool-versions` for gocloc:

   ```text
   # docker/ghcr.io/make-ops-tools/gocloc latest@sha256:... # SEE: https://github.com/make-ops-tools/gocloc/pkgs/container/gocloc
   ```

**To remove**: Delete the script

---

### 15. VS Code Integration

**Purpose**: Standardised editor configuration and recommended extensions.

**Source files** (in `assets/`):

- [`.vscode/extensions.json`](assets/.vscode/extensions.json) — Recommended extensions
- [`.vscode/settings.json`](assets/.vscode/settings.json) — Workspace settings
- [`project.code-workspace`](assets/project.code-workspace) — Multi-root workspace file

**Key extensions**:

- `editorconfig.editorconfig` — EditorConfig support
- `davidanson.vscode-markdownlint` — Markdown linting
- `ms-azuretools.vscode-docker` — Docker support
- `github.vscode-github-actions` — GitHub Actions
- `eamodio.gitlens` — Git enhancements
- `hediet.vscode-drawio` — Diagram editing

**Verification** (run after adoption):

```bash
# Check VS Code config files exist
test -f .vscode/settings.json && echo "settings.json OK"
test -f .vscode/extensions.json && echo "extensions.json OK"
test -f project.code-workspace && echo "workspace file OK"

# Validate JSON syntax
jq '.' .vscode/settings.json > /dev/null && echo "settings.json valid"
jq '.' .vscode/extensions.json > /dev/null && echo "extensions.json valid"
jq '.' project.code-workspace > /dev/null && echo "workspace file valid"

# List recommended extensions
jq -r '.recommendations[]' .vscode/extensions.json

# Expected: All files exist and contain valid JSON
# Success indicator: Extension list displayed
```

**To adopt**: Copy `.vscode/` directory and `project.code-workspace`

**To remove**: Delete the files

---

### 16. Dev Container

**Purpose**: Containerised, reproducible development environment.

**Dependencies**: Docker, VS Code with Remote Containers extension

**Source files** (in `assets/`):

- [`.devcontainer/devcontainer.json`](assets/.devcontainer/devcontainer.json)

**Features**:

- Ubuntu base with Docker-in-Docker
- Go, Python, asdf pre-installed
- Zsh with Oh My Zsh and plugins
- GPG support for commit signing
- Automatic `make config` on creation

**Verification** (run after adoption):

```bash
# Check devcontainer.json exists
test -f .devcontainer/devcontainer.json && echo "devcontainer.json OK"

# Validate JSON syntax
jq '.' .devcontainer/devcontainer.json > /dev/null && echo "Valid JSON"

# Check key properties exist
jq -e '.name' .devcontainer/devcontainer.json > /dev/null && echo "Has name"
jq -e '.image // .build' .devcontainer/devcontainer.json > /dev/null && echo "Has image or build"

# Expected: File exists with valid JSON and required properties
# Success indicator: All checks pass
# Note: Full verification requires opening in VS Code with Remote Containers
```

**To adopt**:

1. Copy `.devcontainer/`
2. Open in VS Code and select "Reopen in Container"

**To remove**: Delete `.devcontainer/`

---

### 17. Tool Version Management (asdf)

**Purpose**: Pin and manage tool versions consistently across the team, including Docker images.

**Dependencies**: asdf version manager

**Source files** (in `assets/`):

- [`.tool-versions`](assets/.tool-versions) — Tool version pins (standard and Docker)

**Standard tool entries**:

```text
gitleaks 8.30.0
pre-commit 4.5.1
terraform 1.7.0
vale 3.6.0
```

**Extended format for Docker images**:

The `.tool-versions` file is extended beyond standard asdf usage to pin Docker image versions. These entries are formatted as comments (so asdf ignores them) and parsed by the `docker-get-image-version-and-pull` function in `scripts/docker/docker.lib.sh`.

```text
# docker/<registry>/<image> <tag>@<digest> # SEE: <url>
```

**Example Docker entries**:

```text
# docker/ghcr.io/gitleaks/gitleaks v8.18.0@sha256:fd2b5cab... # SEE: https://github.com/gitleaks/gitleaks/pkgs/container/gitleaks
# docker/hadolint/hadolint 2.12.0-alpine@sha256:7dba9a9f... # SEE: https://hub.docker.com/r/hadolint/hadolint/tags
# docker/hashicorp/terraform 1.12.2@sha256:b3d13c90... # SEE: https://hub.docker.com/r/hashicorp/terraform/tags
```

**Format breakdown**:

| Component            | Description                                               | Example                     |
| -------------------- | --------------------------------------------------------- | --------------------------- |
| `# docker/`          | Prefix marker (comment for asdf, parsed by docker.lib.sh) | `# docker/`                 |
| `<registry>/<image>` | Full image name                                           | `ghcr.io/gitleaks/gitleaks` |
| `<tag>`              | Version tag                                               | `v8.18.0`                   |
| `@<digest>`          | Content-addressable SHA256 digest                         | `@sha256:fd2b5cab...`       |
| `# SEE: <url>`       | Reference URL (optional, for maintainability)             | `# SEE: https://...`        |

**Why use digests?**

- **Reproducibility**: Digests are immutable; tags can be overwritten
- **Security**: Prevents supply-chain attacks via tag substitution
- **Caching**: The `docker-get-image-version-and-pull` function pulls by digest and tags locally to avoid repeated downloads

**Usage**:

```bash
make config                             # Installs all asdf tools from .tool-versions
make _install-dependency name=terraform # Install specific asdf tool

# Docker images are pulled on-demand by scripts using docker-get-image-version-and-pull
```

**To adopt**:

1. Copy `.tool-versions`
2. Adjust versions for your project
3. Run `make config`
4. For Docker images, add entries following the format above

**Verification** (run after adoption):

```bash
# Check asdf is available
asdf --version

# Check .tool-versions exists and has content
test -f .tool-versions && cat .tool-versions

# Verify asdf tools are installed at specified versions
asdf current

# Install all asdf tools (if not already installed)
asdf install

# Check a specific tool matches pinned version
asdf current terraform

# Check Docker entries exist
grep "^# docker/" .tool-versions

# Expected: All tools listed in .tool-versions are installed
# Success indicator: `asdf current` shows all tools with matching versions
# Docker images are pulled automatically when scripts invoke docker-get-image-version-and-pull
```

**To remove**: Delete `.tool-versions`

---

### 18. GitHub Repository Templates

**Purpose**: Standardised templates for issues, pull requests, and security policies to ensure consistent contributor experience.

**Source files** (in `assets/`):

- [`.github/ISSUE_TEMPLATE/`](assets/.github/ISSUE_TEMPLATE/) — Issue form templates
- [`.github/PULL_REQUEST_TEMPLATE.md`](assets/.github/PULL_REQUEST_TEMPLATE.md) — PR description template
- [`.github/SECURITY.md`](assets/.github/SECURITY.md) — Security vulnerability reporting policy

**Issue templates**:

- `1_support_request.yaml` — Support and help requests
- `2_feature_request.yaml` — New feature proposals
- `3_bug_report.yaml` — Bug reports with reproduction steps

**PR template contents**:

- Description section
- Context/problem statement
- Type of changes checklist (refactoring, feature, breaking change, bug fix)
- Contributor checklist (code style, tests, documentation, pair programming)

**Security policy**:

- NHS England security contact information
- Vulnerability reporting procedures via email
- NCSC (National Cyber Security Centre) reporting option

**To adopt**:

1. Copy `.github/ISSUE_TEMPLATE/` directory
2. Copy `.github/PULL_REQUEST_TEMPLATE.md`
3. Copy `.github/SECURITY.md` and customise contact details

**Verification** (run after adoption):

```bash
# Check templates exist
ls -la .github/ISSUE_TEMPLATE/
test -f .github/PULL_REQUEST_TEMPLATE.md && echo "PR template OK"
test -f .github/SECURITY.md && echo "Security policy OK"

# Validate YAML syntax for issue templates
for f in .github/ISSUE_TEMPLATE/*.yaml; do
  yq eval '.' "$f" > /dev/null && echo "$f valid"
done

# Expected: All template files present
# Success indicator: Templates appear in GitHub UI when creating issues/PRs
# Note: Full verification requires creating a test issue/PR on GitHub
```

**To remove**: Delete the template files

---

### 19. Dependabot

**Purpose**: Automated dependency update pull requests for multiple package ecosystems.

**Source files** (in `assets/`):

- [`.github/dependabot.yaml`](assets/.github/dependabot.yaml) — Dependabot configuration

**Configured ecosystems**:

| Ecosystem        | Schedule | Purpose                     |
| ---------------- | -------- | --------------------------- |
| `docker`         | Daily    | Base image updates          |
| `github-actions` | Daily    | Action version updates      |
| `npm`            | Daily    | Node.js dependency updates  |
| `pip`            | Daily    | Python dependency updates   |
| `terraform`      | Daily    | Provider and module updates |

**Features**:

- Daily update checks for all ecosystems
- Automatic PR creation for outdated dependencies
- Security vulnerability alerts and fixes

**To adopt**:

1. Copy `.github/dependabot.yaml`
2. Remove ecosystems not used by your project
3. Adjust schedule frequency if needed (daily, weekly, monthly)

**Verification** (run after adoption):

```bash
# Check dependabot config exists
test -f .github/dependabot.yaml && echo "Dependabot config OK"

# Validate YAML syntax
yq eval '.' .github/dependabot.yaml > /dev/null && echo "Valid YAML"

# Check configured ecosystems
yq eval '.updates[].package-ecosystem' .github/dependabot.yaml

# Expected: File exists with valid YAML
# Success indicator: Dependabot PRs appear in repository after enabling
# Note: Full verification requires pushing to GitHub and checking Insights > Dependency graph
```

**To remove**: Delete `.github/dependabot.yaml`

---

### 20. Documentation Structure

**Purpose**: Standardised documentation layout with Architecture Decision Records (ADRs), developer guides, and user guides.

**Source files** (in `assets/`):

- [`docs/adr/`](assets/docs/adr/) — Architecture Decision Records
- [`docs/developer-guides/`](assets/docs/developer-guides/) — Technical documentation for developers
- [`docs/user-guides/`](assets/docs/user-guides/) — End-user documentation
- [`docs/diagrams/`](assets/docs/diagrams/) — Draw.io diagrams

**ADR structure** (`docs/adr/`):

- `ADR-nnn_Any_Decision_Record_Template.md` — Template for new ADRs
- Example ADRs covering EditorConfig, secret scanning, GitHub auth

**ADR template fields**:

| Field        | Description                                               |
| ------------ | --------------------------------------------------------- |
| Date         | When decision was last updated                            |
| Status       | RFC, Proposed, Accepted, Deprecated, Superseded, etc.     |
| Deciders     | Stakeholder groups involved                               |
| Significance | Structure, non-functional, dependencies, interfaces, etc. |
| Owners       | Decision owners                                           |

**Developer guides**:

- `Bash_and_Make.md` — Shell scripting and Make conventions
- `Scripting_Docker.md` — Docker patterns and practices
- `Scripting_Terraform.md` — Terraform conventions

**User guides**:

- `Perform_static_analysis.md`
- `Run_Git_hooks_on_commit.md`
- `Scan_dependencies.md`
- `Scan_secrets.md`
- `Sign_Git_commits.md`
- `Test_GitHub_Actions_locally.md`

**To adopt**:

1. Copy `docs/` directory structure
2. Customise ADR template for your organisation
3. Remove example ADRs and guides not applicable
4. Add project-specific documentation

**Verification** (run after adoption):

```bash
# Check documentation structure exists
test -d docs/adr && echo "ADR directory OK"
test -d docs/developer-guides && echo "Developer guides OK"
test -d docs/user-guides && echo "User guides OK"

# Check ADR template exists
test -f docs/adr/ADR-nnn_Any_Decision_Record_Template.md && echo "ADR template OK"

# List documentation files
find docs -name "*.md" -type f

# Expected: Documentation directories with markdown files
# Success indicator: Organised documentation visible in repository
```

**To remove**: Delete `docs/` directory or specific subdirectories

---

### 21. Static Analysis (SonarCloud)

**Purpose**: Continuous code quality inspection and security analysis with SonarCloud integration.

**Dependencies**: sonar-scanner (native or Docker), SonarCloud account

**Source files** (in `assets/`):

- [`scripts/reports/perform-static-analysis.sh`](assets/scripts/reports/perform-static-analysis.sh) — SonarCloud scanner wrapper
- [`scripts/config/sonar-scanner.properties`](assets/scripts/config/sonar-scanner.properties) — Scanner configuration shared by native and Docker execution

**Required environment variables**:

| Variable                 | Description                     |
| ------------------------ | ------------------------------- |
| `BRANCH_NAME`            | Branch being analysed           |
| `SONAR_ORGANISATION_KEY` | SonarCloud organisation key     |
| `SONAR_PROJECT_KEY`      | SonarCloud project key          |
| `SONAR_TOKEN`            | SonarCloud authentication token |

**Features**:

- Automatic native or Docker execution mode
- Branch-aware analysis for PR feedback
- Quality gate status badges
- Integration with GitHub Actions CI/CD

**To adopt**:

1. Copy `scripts/reports/perform-static-analysis.sh` and `scripts/config/sonar-scanner.properties`
2. Add Docker image entry to `.tool-versions` for sonar-scanner:

   ```text
   # docker/sonarsource/sonar-scanner-cli 10.0@sha256:... # SEE: https://hub.docker.com/r/sonarsource/sonar-scanner-cli/tags
   ```

3. Create a SonarCloud account and project at [sonarcloud.io](https://sonarcloud.io)
4. Add `SONAR_TOKEN` to repository secrets
5. Configure the workflow to run the script with required environment variables

**Verification** (run after adoption):

```bash
# Check sonar-scanner is available
sonar-scanner --version || docker run --rm sonarsource/sonar-scanner-cli --version

# Verify script exists and is executable
test -x scripts/reports/perform-static-analysis.sh && echo "Script OK"

# Verify sonar-scanner configuration exists
test -f scripts/config/sonar-scanner.properties && echo "Config OK"

# Run static analysis (requires SonarCloud credentials)
BRANCH_NAME=$(git branch --show-current) \
SONAR_ORGANISATION_KEY=your-org \
SONAR_PROJECT_KEY=your-project \
SONAR_TOKEN=$SONAR_TOKEN \
./scripts/reports/perform-static-analysis.sh

# Expected: Analysis uploaded to SonarCloud
# Success indicator: Quality gate status visible on SonarCloud dashboard
# Note: Full verification requires SonarCloud account configuration
```

**To remove**: Delete the script and remove from CI/CD workflows

---

## Adoption Patterns

### Full Template Adoption

To adopt the complete template directly from GitHub:

```bash
git clone https://github.com/nhs-england-tools/repository-template.git my-project
cd my-project
rm -rf .git
git init
make config
```

Or copy from the local `assets/` directory:

```bash
cp -r .github/skills/repository-template/assets/* my-project/
cd my-project
make config
```

### Selective Capability Adoption

To add a single capability to an existing repository:

1. Identify the capability from the table above
2. Copy the required files from [`assets/`](assets/) to your repository root
3. Update any include statements in `Makefile` or `scripts/init.mk`
4. Run `make config` if using pre-commit hooks

### Capability Removal

To remove a capability:

1. Delete the associated files
2. Remove any `include` statements referencing the capability
3. Remove from `scripts/config/pre-commit.yaml` if applicable
4. Remove from `.github/workflows/` if applicable

---

## File Reference

All source files are located in the [`assets/`](assets/) directory. Copy them to your repository root (or the equivalent path).

### Root Files

| File                                                             | Purpose                | Capability              |
| ---------------------------------------------------------------- | ---------------------- | ----------------------- |
| [`assets/.editorconfig`](assets/.editorconfig)                   | File formatting rules  | File Format Checking    |
| [`assets/.gitattributes`](assets/.gitattributes)                 | Git file handling      | Core                    |
| [`assets/.gitignore`](assets/.gitignore)                         | Git ignore patterns    | Core                    |
| [`assets/.gitleaksignore`](assets/.gitleaksignore)               | False positive ignores | Secret Scanning         |
| [`assets/.tool-versions`](assets/.tool-versions)                 | Tool version pins      | Tool Version Management |
| [`assets/LICENCE.md`](assets/LICENCE.md)                         | MIT licence            | Core                    |
| [`assets/Makefile`](assets/Makefile)                             | Project make targets   | Core Make System        |
| [`assets/project.code-workspace`](assets/project.code-workspace) | VS Code workspace      | VS Code Integration     |
| [`assets/VERSION`](assets/VERSION)                               | Project version        | Core                    |

### Documentation Directory

| Path                                                                                                                 | Purpose                       |
| -------------------------------------------------------------------------------------------------------------------- | ----------------------------- |
| [`assets/docs/adr/`](assets/docs/adr/)                                                                               | Architecture Decision Records |
| [`assets/docs/adr/ADR-nnn_Any_Decision_Record_Template.md`](assets/docs/adr/ADR-nnn_Any_Decision_Record_Template.md) | ADR template                  |
| [`assets/docs/developer-guides/`](assets/docs/developer-guides/)                                                     | Technical documentation       |
| [`assets/docs/user-guides/`](assets/docs/user-guides/)                                                               | End-user guides               |
| [`assets/docs/diagrams/`](assets/docs/diagrams/)                                                                     | Draw.io diagrams              |

### Scripts Directory

| Path                                                                           | Purpose                  |
| ------------------------------------------------------------------------------ | ------------------------ |
| [`assets/scripts/init.mk`](assets/scripts/init.mk)                             | Core make infrastructure |
| [`assets/scripts/shellscript-linter.sh`](assets/scripts/shellscript-linter.sh) | ShellCheck wrapper       |
| [`assets/scripts/config/`](assets/scripts/config/)                             | Tool configurations      |
| [`assets/scripts/docker/`](assets/scripts/docker/)                             | Docker support           |
| [`assets/scripts/githooks/`](assets/scripts/githooks/)                         | Pre-commit hook scripts  |
| [`assets/scripts/reports/`](assets/scripts/reports/)                           | Reporting scripts        |
| [`assets/scripts/terraform/`](assets/scripts/terraform/)                       | Terraform support        |
| [`assets/scripts/tests/`](assets/scripts/tests/)                               | Test framework           |

### GitHub Directory

| Path                                                                                 | Purpose                  |
| ------------------------------------------------------------------------------------ | ------------------------ |
| [`assets/.github/workflows/`](assets/.github/workflows/)                             | CI/CD pipeline workflows |
| [`assets/.github/actions/`](assets/.github/actions/)                                 | Composite actions        |
| [`assets/.github/ISSUE_TEMPLATE/`](assets/.github/ISSUE_TEMPLATE/)                   | Issue templates          |
| [`assets/.github/PULL_REQUEST_TEMPLATE.md`](assets/.github/PULL_REQUEST_TEMPLATE.md) | PR template              |
| [`assets/.github/SECURITY.md`](assets/.github/SECURITY.md)                           | Security policy          |
| [`assets/.github/dependabot.yaml`](assets/.github/dependabot.yaml)                   | Dependency updates       |

---

## Updating from the template repository

To pull updates from the upstream run the following command:

```bash
.github/skills/repository-template/scripts/git-clone-repository-template.sh
```

Then selectively copy relevant files to your repository.

---

> **Version**: 1.0.1
> **Last Amended**: 2026-01-15
