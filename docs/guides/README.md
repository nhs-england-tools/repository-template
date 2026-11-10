# Developer guides 📚

Use these guides to configure a repository from this template and work with its
tooling. To create a repository, start with
[Set up a new repository](Set_up_a_new_repository.md). For day-to-day work,
follow the onboarding order below or find a guide for your task.

## Recommended onboarding order 🧭

1. Complete the [repository quick start](../../README.md#quick-start-): review
   and trust `mise.toml`, verify GNU prerequisites with
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

## Find a guide by task 🔎

| I want to…                                                | Guide                                                                          |
| --------------------------------------------------------- | ------------------------------------------------------------------------------ |
| Set up a new repository                                   | [Set up a new repository](Set_up_a_new_repository.md)                          |
| Set up the development tools                              | [Quick start](../../README.md#quick-start-)                                    |
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
| Update tools, images, actions or application dependencies | [Update Dependencies](Update_Dependencies.md)                                  |

## Related documentation 🔗

- [Contributing](../../.github/CONTRIBUTING.md) describes preparing a change and
  opening a pull request.
- [Technology Recommendations](../adr/Technology_Recommendations.md) provides
  candidate tools to compare when making a technology decision.
- The [ADR template](../adr/ADR-nnn_Any_Decision_Record_Template.md) provides a
  structure for recording the decision and its alternatives.
