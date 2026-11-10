# Set up a new repository 🧰

- [Set up a new repository 🧰](#set-up-a-new-repository-)
  - [Create and prepare the repository 📦](#create-and-prepare-the-repository-)
  - [Tailor the repository 🧩](#tailor-the-repository-)
  - [Verify and close ✅](#verify-and-close-)

## Create and prepare the repository 📦

1. On GitHub, choose **New repository**. In **Choose a template**, select the
   [repository template](https://github.com/nhs-england-tools/repository-template).
   Choose the owner, name and visibility, then create the repository.
2. In the new repository, copy its HTTPS URL from **Code** and clone it. Replace
   `OWNER` and `REPOSITORY` below with your new repository's details:

   ```shell
   git clone https://github.com/OWNER/REPOSITORY.git
   cd REPOSITORY
   ```

3. Check the [prerequisites](../../README.md#prerequisites) and review
   [`mise.toml`](../../mise.toml). From the new repository, run:

   ```shell
   mise trust mise.toml
   make toolchain-verify-gnu
   make config
   ```

   If the verifier reports missing tools, install them before `make config`.

4. In the new repository, choose **Issues > New issue > New repository setup**
   and assign the issue to a maintainer. Do not include private reports,
   personal data or sensitive contact details in the issue.

You are ready to tailor the repository when the prerequisites pass,
`make config` has installed the pinned tools and the setup issue has an owner.
Complete its checklist in an initial setup pull request before accepting
contributions. Record approved exceptions in the pull request, not in the issue.

## Tailor the repository 🧩

Make these changes on a branch for the initial setup pull request:

1. Replace template URLs and support links in the [root README](../../README.md)
   and [issue forms](../../.github/ISSUE_TEMPLATE/), including the
   [issue form configuration](../../.github/ISSUE_TEMPLATE/config.yml). Update
   the README with the project's configuration and contribution workflow, and
   tailor the [contributing guide](../../.github/CONTRIBUTING.md) to cover
   setup, tests, review rules and releases.
2. Confirm reporting routes with the relevant owners. In the
   [Code of Conduct](../../.github/CODE_OF_CONDUCT.md), set a monitored private
   route, an alternative for conflicts of interest and the approved escalation
   process. In the [security policy](../../.github/SECURITY.md), define the
   project's scope, supported versions, private reporting route, response
   process and security update policy. Verify published contacts and links
   before inviting reports.
3. Document the project's applicable information governance, accessibility,
   security and clinical safety requirements. Assign the appropriate owners and
   link to approved processes rather than publishing sensitive details.
4. Implement every TODO-marked recipe in the [Makefile](../../Makefile) without
   renaming its targets. Add the project's checks to `lint` and `typecheck`, and
   its fast project and system tests, such as unit tests, to `test` alongside
   the template's Bash tests. Keep slower test tiers separate, and keep `check`
   running the project's format, lint, type and quick-feedback test targets. Follow
   [Use Bash and Make](Use_Bash_and_Make.md#compose-with-root-lifecycle-targets)
   for extension patterns. Run `make help` to inspect the available targets.
5. Review dependency sources, the
   [Dependabot configuration](../../.github/dependabot.yaml), the update
   cooldown and who owns updates. Check pinned tools and images in
   [`mise.toml`](../../mise.toml), then record project-specific decisions and
   changes using [Update Dependencies](Update_Dependencies.md).
6. Configure [SonarQube Cloud](Configure_SonarQube_Cloud.md) with the NHS
   Engineering Admins. Set `SONAR_TOKEN` as an Actions and Dependabot secret and
   `SONAR_ORGANISATION_KEY` and `SONAR_PROJECT_KEY` as variables.

You are ready to verify when the setup branch contains the project's updated
documentation, policies, Make targets and dependency decisions, and the required
repository settings are in place. Keep tokens and private contact details out of
the pull request.

## Verify and close ✅

1. Open the initial setup pull request from your branch. Resolve documentation
   TODOs and check for remaining template URLs in the README, issue forms and
   policies.
2. Verify local links with `make lint-markdown-links` and check published
   contact routes separately. Stage newly created files so the file checks
   include them. Run `make lint`, `make typecheck` and `make test` after
   tailoring the targets.
3. On the pull request from a branch in the repository, confirm that the static
   analysis job actually runs a scan, reports the quality gate and decorates the
   pull request. A successful job alone does not prove a scan ran when settings
   are missing.
4. Add the setup pull request link to the issue. Keep the issue open until a
   project maintainer and the relevant security or policy owner approve the pull
   request.

Setup is complete when the local checks pass, published contact routes and the
SonarQube Cloud scan have been verified, and both approvals are recorded on the
linked pull request. Only then close the issue and accept contributions.
