# Developer guides 📚

Use these guides to configure a repository from this template and work with its
tooling. To create a repository, start with
[Set up a new repository](Set_up_a_new_repository.md). For day-to-day work,
follow the onboarding order below. The capability table shows what the template
provides and where each feature starts. The task index links to how-to guides.

## Recommended onboarding order 🧭

1. Complete the [repository quick start](../../../README.md#quick-start-):
   review and trust `mise.toml`, verify GNU prerequisites with
   `make toolchain-verify-gnu`, then run `make config`.
2. Read [Use Bash and Make](Use_Bash_and_Make.md) for command conventions and
   extension points. Run `make help` to see the available targets.
3. Use [Run and configure quality checks](Run_and_configure_quality_checks.md)
   to validate changes. Read
   [Run Git hooks on commit](Run_Git_hooks_on_commit.md) to understand the
   checks installed by `make config`, and [Scan secrets](Scan_secrets.md) for
   additional scan modes.
4. When changing repository scripts, use
   [Write and run Bash tests](Write_and_run_Bash_tests.md). Run the relevant
   suite during development and the full suite when its prerequisites are
   available.

## Template capabilities 🧩

This is the full list of template capabilities, including tools, integrations
and guidance. Each entry point links to the main file or directory for that
capability. The guides explain how to use or configure it.

Project environment setup, dependency installation, type checking, artefact
builds and deployment remain placeholders. The CI/CD workflows provide the stage
structure, not a working application delivery pipeline. SonarQube Cloud and
Teams delivery need configuration. Signing commits is guidance, not an installed
signing service. The technology recommendations do not install application
frameworks or grant technology approval.

| Capability                                    | Tool                               | Run it                                                                                                 | Entry point                                                                         | Guide                                                                          |
| --------------------------------------------- | ---------------------------------- | ------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| Make lifecycle and extensions                 | GNU Make                           | `make help`, `make check`                                                                              | [Makefile](../../../Makefile)                                                       | [Use Bash and Make]                                                            |
| Toolchain pinning and upgrades                | mise                               | `make config`, `make toolchain-upgrade`                                                                | [mise.toml](../../../mise.toml)                                                     | [Update Dependencies]                                                          |
| GNU prerequisites                             | Bash and Homebrew                  | `make toolchain-verify-gnu`, `make toolchain-install-gnu-macos`                                        | [verify-gnu.sh](../../../scripts/toolchain/verify-gnu.sh)                           | [Quick start](../../../README.md#quick-start-)                                 |
| Git hooks                                     | pre-commit                         | On commit after `make config`, or `make githooks-run`                                                  | [pre-commit.yaml](../../../scripts/config/pre-commit.yaml)                          | [Run Git hooks on commit](Run_Git_hooks_on_commit.md)                          |
| Secret scanning                               | gitleaks                           | `make scan-secrets`                                                                                    | [scan-secrets.sh](../../../scripts/quality/scan-secrets.sh)                         | [Scan secrets](Scan_secrets.md)                                                |
| File format                                   | editorconfig-checker               | `make lint-file-format`                                                                                | [check-file-format.sh](../../../scripts/quality/check-file-format.sh)               | [Quality checks]                                                               |
| Markdown lint                                 | markdownlint                       | `make lint-markdown-format`                                                                            | [check-markdown-format.sh](../../../scripts/quality/check-markdown-format.sh)       | [Quality checks]                                                               |
| Markdown formatting                           | Prettier                           | `make format`                                                                                          | [format-markdown.sh](../../../scripts/quality/format-markdown.sh)                   | [Quality checks]                                                               |
| Markdown links                                | lychee                             | `make lint-markdown-links`                                                                             | [check-markdown-links.sh](../../../scripts/quality/check-markdown-links.sh)         | [Quality checks]                                                               |
| Shell lint and comment length                 | ShellCheck and built-in checks     | `make lint-shell`                                                                                      | [check-shell-lint.sh](../../../scripts/quality/check-shell-lint.sh)                 | [Quality checks]                                                               |
| Pipeline contract                             | Bash, yq and jq                    | `make lint-pipeline-contract`                                                                          | [check-pipeline-contract.sh](../../../scripts/quality/check-pipeline-contract.sh)   | [Quality checks]                                                               |
| Security readiness                            | Bash, yq and jq                    | `make lint-security-readiness`                                                                         | [check-security-readiness.sh](../../../scripts/quality/check-security-readiness.sh) | [Harden repository security]                                                   |
| Check scopes and PR base detection            | Git and Bash                       | `check=all`, `check=staged-changes`, `check=working-tree-changes`, `check=branch` on file checks       | [git-base.lib.sh](../../../scripts/quality/git-base.lib.sh)                         | [Quality checks]                                                               |
| Agent quality gate                            | GitHub Copilot hooks               | When a local agent stops, or `make quality-gate`                                                       | [quality-gates.yaml](../../../scripts/config/quality-gates.yaml)                    | [Run the quality gate when the agent stops](Run_quality_gate_on_agent_stop.md) |
| Bash test harness                             | Bash                               | `make test`                                                                                            | [run-test-suites.sh](../../../scripts/tests/run-test-suites.sh)                     | [Write and run Bash tests](Write_and_run_Bash_tests.md)                        |
| Docker image lifecycle and metadata           | Docker or Podman                   | `make docker-build`, `make docker-run`, `make docker-push` for a project image                         | [docker.mk](../../../scripts/docker/docker.mk)                                      | [Build Docker images]                                                          |
| Dockerfile lint                               | Hadolint                           | `make docker-lint`, also required by `make docker-build`                                               | [dockerfile-linter.sh](../../../scripts/docker/dockerfile-linter.sh)                | [Build Docker images]                                                          |
| Compose services                              | Docker Compose                     | `make docker-compose-up`, `make docker-compose-status`, `make docker-compose-logs` for a project stack | [docker.mk](../../../scripts/docker/docker.mk)                                      | [Run services with Docker Compose](Run_Docker_Compose_services.md)             |
| Effective version files                       | Bash                               | `make version-create-effective-file`                                                                   | [docker.lib.sh](../../../scripts/docker/docker.lib.sh)                              | [Versioning](Build_Docker_images.md#versioning)                                |
| CI/CD stage structure and release workflow    | GitHub Actions                     | Pushes and pull requests, publication on merge to `main`, deployment by tag on manual dispatch         | [workflows](../../../.github/workflows/)                                            | [Workflow controls](Harden_repository_security.md#github-actions-)             |
| Static analysis                               | SonarQube Cloud                    | CI test stage when the token and project variables are set                                             | [stage-2-test.yaml](../../../.github/workflows/stage-2-test.yaml)                   | [Configure SonarQube Cloud](Configure_SonarQube_Cloud.md)                      |
| Pipeline notifications                        | Microsoft Teams and Power Automate | `main` failure and recovery, publish and deploy outcomes                                               | [notify-pipeline-status.sh](../../../scripts/cicd/notify-pipeline-status.sh)        | [Configure pipeline notifications](Configure_pipeline_notifications.md)        |
| Dependency update PRs                         | Dependabot                         | Daily checks for Docker, GitHub Actions, npm and uv, with a seven-day cooldown                         | [dependabot.yaml](../../../.github/dependabot.yaml)                                 | [Update Dependencies]                                                          |
| File and Docker resource cleanup              | Git and Docker helpers             | `make clean` previews Git cleanup and removes Docker build artefacts                                   | [init.mk](../../../scripts/init.mk)                                                 | [Cleanup options](Use_Bash_and_Make.md#clean-up-files-and-docker-resources-)   |
| Commit signing guidance                       | GPG or SSH                         | Follow the guide to configure signing                                                                  | [Sign_Git_commits.md](Sign_Git_commits.md)                                          | [Sign Git commits](Sign_Git_commits.md)                                        |
| Community policies, ownership and issue forms | GitHub                             | Configure during repository setup, use when contributing and reporting                                 | [CONTRIBUTING.md](../../../.github/CONTRIBUTING.md)                                 | [Set up a new repository](Set_up_a_new_repository.md)                          |
| Copilot engineering instructions              | GitHub Copilot                     | Loaded by supported Copilot clients                                                                    | [copilot-instructions.md](../../../.github/copilot-instructions.md)                 | No separate guide                                                              |
| Editor settings and extension recommendations | VS Code                            | Open the repository in VS Code                                                                         | [settings.json](../../../.vscode/settings.json)                                     | No separate guide                                                              |
| Architecture Decision Records                 | Markdown template                  | Copy the template to record a decision and compare alternatives                                        | [ADR template](../../adr/ADR-nnn_Any_Decision_Record_Template.md)                   | [Technology Recommendations]                                                   |
| Technology recommendations                    | Reference guidance                 | Consult the NHS Tech Radar before selecting a tool                                                     | [Technology_Recommendations.md](../../adr/Technology_Recommendations.md)            | No separate guide                                                              |
| Team-owned guide area                         | Markdown                           | Add project guides under `docs/guides/`, outside `template/`                                           | [guides/README.md](../README.md)                                                    | No separate guide                                                              |

[Use Bash and Make]: Use_Bash_and_Make.md
[Update Dependencies]: Update_Dependencies.md
[Quality checks]: Run_and_configure_quality_checks.md
[Harden repository security]: Harden_repository_security.md
[Build Docker images]: Build_Docker_images.md
[Technology Recommendations]: ../../adr/Technology_Recommendations.md

## Find a guide by task 🔎

| I want to…                                                | Guide                                                                          |
| --------------------------------------------------------- | ------------------------------------------------------------------------------ |
| Set up a new repository                                   | [Set up a new repository](Set_up_a_new_repository.md)                          |
| Set up the development tools                              | [Quick start](../../../README.md#quick-start-)                                 |
| Add a Make target or script                               | [Use Bash and Make](Use_Bash_and_Make.md)                                      |
| Remove generated files or local Docker resources          | [Cleanup options](Use_Bash_and_Make.md#clean-up-files-and-docker-resources-)   |
| Run linters, format Markdown or configure exclusions      | [Run and configure quality checks](Run_and_configure_quality_checks.md)        |
| Write or debug a shell test suite                         | [Write and run Bash tests](Write_and_run_Bash_tests.md)                        |
| Build, tag and run a Docker image                         | [Build Docker images](Build_Docker_images.md)                                  |
| Start and inspect a local service stack                   | [Run services with Docker Compose](Run_Docker_Compose_services.md)             |
| Understand the checks that run on commit                  | [Run Git hooks on commit](Run_Git_hooks_on_commit.md)                          |
| Configure checks when a Copilot agent finishes            | [Run the quality gate when the agent stops](Run_quality_gate_on_agent_stop.md) |
| Scan for committed or uncommitted secrets                 | [Scan secrets](Scan_secrets.md)                                                |
| Sign commits with GPG or SSH                              | [Sign Git commits](Sign_Git_commits.md)                                        |
| Review workflow permissions and security controls         | [Harden repository security](Harden_repository_security.md)                    |
| Connect SonarQube Cloud analysis                          | [Configure SonarQube Cloud](Configure_SonarQube_Cloud.md)                      |
| Send pipeline notifications to a Teams channel            | [Configure pipeline notifications](Configure_pipeline_notifications.md)        |
| Update tools, images, actions or application dependencies | [Update Dependencies](Update_Dependencies.md)                                  |

## Related documentation 🔗

- [Contributing](../../../.github/CONTRIBUTING.md) describes preparing a change
  and opening a pull request.
- [Technology Recommendations](../../adr/Technology_Recommendations.md) provides
  candidate tools to compare when making a technology decision.
- The [ADR template](../../adr/ADR-nnn_Any_Decision_Record_Template.md) provides
  a structure for recording the decision and its alternatives.
