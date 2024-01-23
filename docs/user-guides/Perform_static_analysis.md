# Guide: Perform static analysis

- [Guide: Perform static analysis](#guide-perform-static-analysis)
  - [Overview](#overview)
  - [Key files](#key-files)
  - [Setup](#setup)
  - [Testing](#testing)
  - [Configuration checklist](#configuration-checklist)

## Overview

Static code analysis is an essential part of modern software development. It provides automatic checks on your codebase to identify potential bugs, code smells, security vulnerabilities, and maintainability issues.

[SonarCloud](https://sonarcloud.io), an online service for continuous code quality inspection and static analysis, can be easily integrated with a GitHub repository. This repository template includes all the necessary setup for minimal configuration on your part, facilitating smooth integration with this SaaS offering.

## Key files

- [perform-static-analysis.sh](../../scripts/reports/perform-static-analysis.sh): A shell script that performs analysis
- [sonar-scanner.properties](../../scripts/config/sonar-scanner.properties): A configuration file that includes the project details
- [perform-static-analysis/action.yaml](../../.github/actions/perform-static-analysis/action.yaml): GitHub action to run the script as part of the CI/CD pipeline
- [.gitignore](../../.gitignore): Excludes the `.scannerwork` temporary directory created during the process

## Setup

Contact the GitHub Admins via their mailbox to have your [SonarCloud](https://sonarcloud.io) access set up.

## Testing

You can run and test static analysis locally on a developer's workstation using the following command

```shell
export SONAR_ORGANISATION_KEY=nhs-england-tools # Replace with your organisation key
export SONAR_PROJECT_KEY=repository-template # Replace with your project key
export SONAR_TOKEN=[replace-with-your-sonar-token]
./scripts/reports/perform-static-analysis.sh
```

## Configuration checklist

> [!WARNING]<br>
> This section is to be used by the GitHub Admins.

The list demonstrates the manual way of configuring a project, however our aim is to automate all the activities below.

- Create a Sonar project within the organisation space:
  - Navigate to `+ > Analyze new project > create a project manually`
  - Choose the appropriate organisation
  - Set "Display name"
  - Set "Project key" (it should be populated automatically)
  - Set project visibility to "Public"
  - After clicking the 'Next' button, set "The new code for this project will be based on" to "Previous version"
  - Click "Create project"
- Add two new groups under `Administration > Groups`:
  - `[Programme Name]`, all members of the project
  - `[Programme Name] Admins`, who will the project's quality gates and quality profiles
- Assign members to the above groups accordingly
- Set group permissions under `Administration > Permissions`:
  - For the `[Programme Name] Admins` group, assign:
    - "Quality Gates"
    - "Quality Profiles"
- Manage project permissions, navigate to `Administration > Projects Management` and select the project you created
  - Click on `Edit Permissions`
  - Search for `[Programme Name] Admins` group and assign the following:
    - "Administer Issues"
    - "Administer Security Hotspots"
    - "Administer"
    - Ensure that other groups do not have unnecessary permissions to administer this project
- Navigate to project `Administration > Analysis Method > Manually` and select `Other (for JS, TS, Go, Python, PHP, ...)`
- In the [sonar-scanner.properties](../../scripts/config/sonar-scanner.properties) file in your repository, set the following properties according to the information provided above
  - Set `sonar.[language].[coverage-tool].reportPaths` to ensure the unit test coverage is reported back to Sonar
  - Do not set the `sonar.organization` and `sonar.projectKey` properties in this file; do the next step instead

- Use the Sonar token owned by the "SonarCloud Token GitHub Admins" service user. There is an existing token named "Scan all"

> [!NOTE]<br>
> For an advance configuration create a bot account for your service. For more details, please see this [note](../../docs/adr/ADR-003_Acceptable_use_of_GitHub_PAT_and_Apps_for_authN_and_authZ.md#recommendation-for-github-admins). This account should be given access to your project and must own the `SONAR_TOKEN` for security reasons.

- Follow the documentation on [creating encrypted secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets) to add the `SONAR_TOKEN` secret to your repository. The GitHub action is already configured to fetch that secret and pass it as a variable. In addition to that:
  - Add `SONAR_ORGANISATION_KEY` variable (not a secret)
  - Add `SONAR_PROJECT_KEY` variable (not a secret)
- Navigate to project `Administration > Analysis Method` and turn off the `Automatic Analysis` option
- Please refrain from adding your repository to the GitHub SonarCloud App, as this app should not be used. Doing so will duplicate reports and initiate them outside the primary pipeline workflow
- Confirm that the _"Perform static analysis"_ GitHub action is part of your GitHub CI/CD workflow and enforces the _"Sonar Way"_ quality gates. You can find more information about this in the [NHSE Software Engineering Quality Framework](https://github.com/NHSDigital/software-engineering-quality-framework/blob/main/tools/sonarqube.md)
