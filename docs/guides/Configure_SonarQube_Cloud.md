# Configure SonarQube Cloud

- [Configure SonarQube Cloud](#configure-sonarqube-cloud)
  - [Overview](#overview)
  - [Configure workflow credentials](#configure-workflow-credentials)
  - [SonarQube Cloud integration](#sonarqube-cloud-integration)
  - [Disable automatic analysis](#disable-automatic-analysis)
  - [Configure branch protection](#configure-branch-protection)
  - [Verify the integration](#verify-the-integration)

## Overview

The [test workflow](../../.github/workflows/stage-2-test.yaml) runs a SonarQube
Cloud scan when the token and both project variables are available. The
`Perform static analysis` job reports success when the scan is not configured.
When configured, it waits for the quality gate and fails if the gate fails.

## Configure workflow credentials

> [!IMPORTANT]
>
> Request SonarQube Cloud setup and integration for this repository from the NHS
> Engineering Admins. Below, they are referred to as the admins.

In GitHub, open the repository's **Settings > Secrets and variables > Actions**.
Set the project variables at repository level, or use organisation-level
variables that are available to this repository. Use the keys provided by the
admins. Otherwise, both keys are shown on the project's **Information** page in
SonarQube Cloud, for example
[nhs-england-tools_repository-template](https://sonarcloud.io/project/information?id=nhs-england-tools_repository-template).

| Name                     | GitHub setting                | Value                                                      |
| ------------------------ | ----------------------------- | ---------------------------------------------------------- |
| `SONAR_TOKEN`            | Actions and Dependabot secret | Scoped organisation token, issued and stored by the admins |
| `SONAR_ORGANISATION_KEY` | Variable                      | The SonarQube Cloud organisation key                       |
| `SONAR_PROJECT_KEY`      | Variable                      | The SonarQube Cloud project key                            |

The workflow skips the scan if any of these values is missing. Pull requests
from forks do not receive repository secrets, so their scan is skipped as well.

## SonarQube Cloud integration

The admins manage the SonarQube Cloud integration for the organisation.
Repository owners do not need SonarQube Cloud administrative access to set it
up. As part of the request, the admins check that the organisation's GitHub
integration includes this repository. The GitHub App may already be installed
and configured to include all repositories in the organisation.

The admins import or bind the SonarQube Cloud project to this GitHub repository.
This connection enables pull request decoration. They also give the team access
to the project in SonarQube Cloud and provide the organisation and project keys
for the workflow variables.

The `SONAR_TOKEN` secret holds a scoped organisation token. It has only the
**Execute analysis** permission on the projects it is issued for. The admins
also store it as a Dependabot secret, because Dependabot pull requests cannot
read GitHub Actions secrets. Before the token expires, the admins replace it,
check that analysis still passes, then revoke the old token. Repository owners
do not need to do anything.

## Disable automatic analysis

This repository uses CI-based analysis, which cannot run while **Automatic
Analysis** is enabled. Ask the admins to check the project's **Administration >
Analysis Method** setting and turn off Automatic Analysis if it is enabled.

## Configure branch protection

Require the **Test stage / Perform static analysis** check in the branch
protection rules for the default branch. Do not require SonarQube Cloud's
**SonarCloud Code Analysis** check. That check may not report for unconfigured
projects or fork pull requests, which can block merges.

Requiring this check does not by itself guarantee that a scan ran. The check
also succeeds when configuration is missing, so make sure all three values are
available wherever scans are expected. Fork pull requests are an expected
exception because GitHub withholds secrets from them.

## Verify the integration

Open a pull request from a branch in the repository and confirm that **Test
stage / Perform static analysis** runs the scan, reports the quality gate, and
publishes pull request decoration. If the job says SonarQube Cloud is not
configured, check the token and both variables. If the scan fails because
Automatic Analysis is enabled, ask the admins to turn it off as described above.

Project teams maintain any project-specific coverage report paths and source
exclusions in the scan arguments in
[stage-2-test.yaml](../../.github/workflows/stage-2-test.yaml).
