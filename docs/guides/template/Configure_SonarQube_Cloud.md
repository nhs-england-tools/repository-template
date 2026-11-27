# Configure SonarQube Cloud 📊

- [Configure SonarQube Cloud 📊](#configure-sonarqube-cloud-)
  - [Overview 🧭](#overview-)
  - [Configure workflow credentials 🔐](#configure-workflow-credentials-)
  - [SonarQube Cloud integration 🔗](#sonarqube-cloud-integration-)
  - [Disable automatic analysis 🛑](#disable-automatic-analysis-)
  - [Configure branch protection 🔒](#configure-branch-protection-)
  - [Disable analysis across the organisation 🔌](#disable-analysis-across-the-organisation-)
  - [Verify the integration ✅](#verify-the-integration-)

## Overview 🧭

The [test workflow](../../../.github/workflows/stage-2-test.yaml) runs a
SonarQube Cloud scan when the token and both variables are available. The
`🔬 Perform static analysis` job reports success when the scan is not
configured. When configured, it waits for the quality gate and fails if the gate
fails.

The scan runs on pull requests, which adds pull request decoration, and on
pushes to `main`, which updates the `main` branch analysis. It does not run for
other branches, and it is skipped in the merge queue because the pull request
has already been analysed. Organisation admins can also
[disable analysis across the organisation](#disable-analysis-across-the-organisation-).

## Configure workflow credentials 🔐

> [!IMPORTANT]
>
> Request SonarQube Cloud setup and integration for this repository from the NHS
> Engineering Admins.

In GitHub, open the repository's **Settings > Secrets and variables > Actions**.
Set the project variables at repository level, or use organisation-level
variables that are available to this repository. Use the keys provided by the
admins. Otherwise, both keys are shown on the project's **Information** page in
SonarQube Cloud, for example
[nhs-england-tools_repository-template](https://sonarcloud.io/project/information?id=nhs-england-tools_repository-template).

| Name                     | GitHub setting                | Value                                                      |
| ------------------------ | ----------------------------- | ---------------------------------------------------------- |
| `SONAR_TOKEN`            | Actions and Dependabot secret | Scoped organisation token, issued and stored by the admins |
| `SONAR_PROJECT_KEY`      | Variable                      | The SonarQube Cloud project key                            |
| `SONAR_ORGANISATION_KEY` | Variable                      | The SonarQube Cloud organisation key                       |

`SONAR_ORGANISATION_KEY` is shared by all repositories in a GitHub
organisation, so admins will most likely provide it as an organisation-level
Actions variable. If it is available to this repository, there is no need to
set a duplicate repository-level variable.

`SONAR_PROJECT_KEY` must follow SonarQube Cloud's default project-key pattern
for GitHub repositories: `<GitHub organisation name>_<GitHub repository
name>`. The first part is the GitHub organisation name from the repository URL.
Both parts must match their GitHub names exactly, including case. For example,
this repository's key is `nhs-england-tools_repository-template`.

> [!WARNING]
>
> If the repository is renamed in GitHub, rename the corresponding SonarQube
> Cloud project key to use the new repository name and update
> `SONAR_PROJECT_KEY` to match.

The workflow skips the scan if any of these values is missing. Pull requests
from forks do not receive repository secrets, so their scan is skipped as well.

## SonarQube Cloud integration 🔗

The admins manage the SonarQube Cloud integration for the organisation.
Repository owners do not need SonarQube Cloud administrative access to set it
up. As part of the request, the admins check that the organisation's GitHub
integration includes this repository. The GitHub App may already be installed
and configured to include all repositories in the organisation.

The admins import or bind the SonarQube Cloud project to this GitHub repository
to enable pull request decoration. They also give the team access to the project
and set the organisation and project keys as GitHub Actions variables at the
appropriate repository or organisation level.

The `SONAR_TOKEN` secret holds a scoped organisation token. It has only the
**Execute analysis** permission on the projects it is issued for. The admins
also store it as a Dependabot secret, because Dependabot pull requests cannot
read GitHub Actions secrets. Before the token expires, the admins replace it,
check that analysis still passes, then revoke the old token. Repository owners
do not need to do anything.

## Disable automatic analysis 🛑

This repository uses CI-based analysis, which cannot run while **Automatic
Analysis** is enabled. Ask the admins to check the project's **Administration >
Analysis Method** setting and turn off Automatic Analysis if it is enabled.

## Configure branch protection 🔒

Require the **🧪 Test stage / 🔬 Perform static analysis** check in the branch
protection rules for the default branch. Do not require SonarQube Cloud's
**SonarCloud Code Analysis** check. That check may not report for unconfigured
projects or fork pull requests, which can block merges.

Requiring this check does not by itself guarantee that a scan ran. The check
also succeeds when configuration is missing or analysis is disabled across the
organisation, so make sure all three values are available wherever scans are
expected. Fork pull requests are an expected exception because GitHub withholds
secrets from them.

## Disable analysis across the organisation 🔌

If the SonarQube Cloud subscription is suspended every configured scan fails and
blocks merges. Organisation admins can switch analysis off for all repositories
that use this workflow without changing their code.

| Name             | GitHub setting                                         | Value                                        |
| ---------------- | ------------------------------------------------------ | -------------------------------------------- |
| `SONAR_DISABLED` | Organisation Actions variable, all repositories access | `true` disables analysis, `false` enables it |

The variable is optional. When it is absent, or holds any value other than
`true`, analysis runs as normal. GitHub compares the value without regard to
case.

To disable analysis, an organisation owner opens **Settings**, then **Secrets
and variables**, **Actions** and **Variables** for the organisation. They create
or edit `SONAR_DISABLED` with the value `true` and **All repositories** access.
With the GitHub CLI and the `admin:org` scope, run:

```bash
gh variable set SONAR_DISABLED --org <organisation> --visibility all --body true
```

To restore analysis once the subscription is active again, set the value to
`false` or delete the variable:

```bash
gh variable set SONAR_DISABLED --org <organisation> --visibility all --body false
```

While analysis is disabled, the **🔬 Perform static analysis** job still runs
and passes, so required checks do not block merges. It skips the scan and shows
the warning `Sonar is disabled by the SONAR_DISABLED variable`. Other jobs are
not affected. The change applies to workflow runs that start after it. Re-run
failed jobs to pick it up.

> [!WARNING]
>
> A repository-level variable overrides an organisation variable with the same
> name. Do not set `SONAR_DISABLED` in a repository, otherwise that repository
> ignores the organisation switch. Each GitHub organisation needs its own
> variable.

## Verify the integration ✅

Open a pull request from a branch in the repository and confirm that **🧪 Test
stage / 🔬 Perform static analysis** runs the scan, reports the quality gate,
and publishes pull request decoration. If the job says SonarQube Cloud is not
configured, check the token and both variables. If the scan fails because
Automatic Analysis is enabled, ask the admins to turn it off as described above.

Project teams maintain any project-specific coverage report paths and source
exclusions in the scan arguments in
[stage-2-test.yaml](../../../.github/workflows/stage-2-test.yaml). The template
excludes its own Node.js scripts, `scripts/**/*.mjs`, from coverage, because the
Bash suites test them in a way SonarQube Cloud cannot measure. Keep that
exclusion when you add your own.
