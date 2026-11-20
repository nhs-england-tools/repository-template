# Set up a new repository 🧰

- [Set up a new repository 🧰](#set-up-a-new-repository-)
  - [Create and prepare the repository 📦](#create-and-prepare-the-repository-)
  - [Tailor the repository 🧩](#tailor-the-repository-)
  - [Verify and close ✅](#verify-and-close-)

## Create and prepare the repository 📦

1. On GitHub, choose **New repository**. If this repository template is not the
   default template in your organisation, use **Choose a template** to select
   the
   [repository template](https://github.com/nhs-england-tools/repository-template).
   Choose the owner, name and visibility, then create the repository from the
   template.
2. In the new repository, copy its HTTPS URL from **Code** and clone it. Replace
   `OWNER` and `REPOSITORY` below with your new repository's details:

   ```shell
   git clone https://github.com/OWNER/REPOSITORY.git
   cd REPOSITORY
   ```

3. Check the [prerequisites](../../../README.md#prerequisites) and review
   [`mise.toml`](../../../mise.toml). From the new repository, run:

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

1. Replace template URLs and support links in the
   [root README](../../../README.md) and
   [issue forms](../../../.github/ISSUE_TEMPLATE/), including the
   [issue form configuration](../../../.github/ISSUE_TEMPLATE/config.yml).
   Update the README with the project's configuration and contribution workflow,
   and tailor the [contributing guide](../../../.github/CONTRIBUTING.md) to
   cover setup, tests, review rules and releases.
2. Confirm reporting routes with the relevant owners. In the
   [Code of Conduct](../../../.github/CODE_OF_CONDUCT.md), set a monitored
   private route, an alternative for conflicts of interest and the approved
   escalation process. In the [security policy](../../../.github/SECURITY.md),
   define the project's scope, supported versions, private reporting route,
   response process and security update policy. Verify published contacts and
   links before inviting reports.
3. Configure [CODEOWNERS](../../../.github/CODEOWNERS) for the adopting team.
   Each owner needs write access to the repository, and the rules must cover
   every file, including the workflows. The central security readiness checks
   read the file from the default branch and expect:
   - **Review date:** a comment on its own line in the exact format
     `# Review-by: YYYY-MM-DD`. The check fails once the date has passed, so
     review the owners and renew the date before it expires.
   - **Owning team:** at least one team from the repository's own GitHub
     organisation, for example `* @nhs-england-tools/engineering-experience`.
     Replace the example with your team's organisation and slug. Individual
     owners and teams from other organisations can be added, but they do not
     count towards the check.
   - **Visible teams:** every team from that organisation mentioned in the file,
     including in comments, must exist and be visible rather than secret.
   - **At least two members:** those teams must have at least two members
     between them, so ownership does not rest with one person.

4. Enable the following GitHub security settings. Template files do not enable
   them. The central checks require them for public repositories and report them
   as not applicable to private and internal repositories:
   - **Secret scanning:** GitHub scans the repository for exposed credentials
     and secrets.
   - **Push protection:** GitHub blocks pushes that contain detected secrets.
   - **Security advisories:** maintainers can privately discuss, fix and publish
     a vulnerability from the repository's **Security** tab.
   - **Private vulnerability reporting:** people can report a vulnerability to
     maintainers without disclosing it in a public issue.

   Check them in the repository's **Settings** under **Advanced Security**. On a
   private or internal repository, secret scanning and push protection need
   GitHub Secret Protection, so enable them where the organisation's licence
   allows and before the repository is made public. The central checks count a
   permissions error as a failure, and it is not evidence that a setting is
   enabled. If one is reported, ask the repository or organisation administrator
   to grant the access the checks need.

5. Protect the default branch with a ruleset, so that the code owner review and
   CI checks are enforced. The central checks do not inspect rulesets, so ask
   the repository or organisation administrator to confirm that it meets these
   criteria:
   - **Pull requests only:** changes reach the default branch through a pull
     request.
   - **Code owner approval:** a pull request needs approval from a code owner.
     Naming a team in CODEOWNERS does not require its approval on its own.
   - **Required checks:** the template's CI checks must pass before merging.
     Follow the
     [SonarQube Cloud branch protection instructions](Configure_SonarQube_Cloud.md#configure-branch-protection-)
     when choosing them.
   - **Reviewed bypass list:** only the people and apps that need it can bypass
     the ruleset.

   [Harden repository security](Harden_repository_security.md#limits-and-responsibilities-)
   explains why these controls matter.

6. Document the project's applicable information governance, accessibility,
   security and clinical safety requirements. Assign the appropriate owners and
   link to approved processes rather than publishing sensitive details.
7. Implement every TODO-marked recipe in the [Makefile](../../../Makefile)
   without renaming its targets. Add the project's checks to `lint` and
   `typecheck`, and its fast project and system tests, such as unit tests, to
   `test` alongside the template's Bash tests. Keep slower test tiers separate,
   and keep `check` running the project's format, lint, type and quick-feedback
   test targets. Follow
   [Use Bash and Make](Use_Bash_and_Make.md#compose-with-root-lifecycle-targets)
   for extension patterns. Run `make help` to inspect the available targets.
8. Review dependency sources, the
   [Dependabot configuration](../../../.github/dependabot.yaml), the update
   cooldown and who owns updates. Check pinned tools and images in
   [`mise.toml`](../../../mise.toml), then record project-specific decisions and
   changes using [Update Dependencies](Update_Dependencies.md).
9. Configure [SonarQube Cloud](Configure_SonarQube_Cloud.md) with the NHS
   Engineering Admins. Set `SONAR_TOKEN` as an Actions and Dependabot secret and
   `SONAR_ORGANISATION_KEY` and `SONAR_PROJECT_KEY` as variables.
10. [Configure pipeline notifications](Configure_pipeline_notifications.md) for
    the team's Microsoft Teams channel, so the team is told when `main` breaks,
    when it is green again, and when a release is published or deployed. Follow
    the guide's Power Automate setup, card mapping, co-owner and delivery
    verification steps. Set the flow's webhook URL as the
    `TEAMS_NOTIFICATION_WEBHOOK_URL` Actions secret. Without it, a reportable
    run writes its summary and warns that the team was not notified.

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
4. Check CODEOWNERS, the security settings and the ruleset against the criteria
   above. Use a test pull request to confirm that the ruleset blocks merging
   while a required check fails or code-owner approval is missing. Record the
   results in the setup pull request without secrets or sensitive settings.
5. Add the setup pull request link to the issue. Keep the issue open until a
   project maintainer and the relevant security or policy owner approve the pull
   request.

Setup is complete when the local checks pass, published contact routes and the
SonarQube Cloud scan have been verified, and the CODEOWNERS, security settings
and ruleset results and both approvals are recorded on the linked pull request.
Only then close the issue and accept contributions.
