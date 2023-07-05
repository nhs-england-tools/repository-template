# ADR-002: Scan repository for hardcoded secrets

>|              |                                                               |
>| ------------ | ------------------------------------------------------------- |
>| Date         | `05/06/2023`                                                  |
>| Status       | `RFC`                                                         |
>| Deciders     | `Engineering`                                                 |
>| Significance | `Construction techniques`                                     |
>| Owners       | `Dan Stefaniuk, Jon Pearce, Tamara Goldschmidt, Tim Rickwood` |

---

- [ADR-002: Scan repository for hardcoded secrets](#adr-002-scan-repository-for-hardcoded-secrets)
  - [Context](#context)
  - [Decision](#decision)
    - [Assumptions](#assumptions)
    - [Drivers](#drivers)
    - [Options](#options)
    - [Outcome](#outcome)
    - [Rationale](#rationale)
  - [Consequences](#consequences)
  - [Compliance](#compliance)
  - [Notes](#notes)
  - [Actions](#actions)
  - [Tags](#tags)

## Context

To safeguard sensitive details like passwords, API keys etc. from being incorporated into code repositories, it is imperative that we employ secret scanning of the code. This safeguarding process should be conducted in two key areas. Firstly, on the developer's machine, we utilise a git pre-commit hook to halt the inclusion of any secrets within the committed code. Secondly, as a safety net, a similar scan should be integrated into the CI/CD pipeline. Should a secret be detected within this pipeline, it is crucial that the pipeline serves as a gate to fail the build, subsequently blocking any related pull requests.

## Decision

### Assumptions

There is already a well-known and fit-for-purpose tool `git-secrets` in use that was selected as the outcome of a decision made around 4 years ago. The purpose of this document is to review that decision.

### Drivers

Within NHS England, we are observing an adoption of the `gitleaks` tool, which is an alternative to `git-secrets`.

### Options

There are three options presented in this decision record.

1. [git-secrets](https://github.com/awslabs/git-secrets)

   - Repository metadata
     - Contributions
       - Number of contributors: **28**
       - Number of commits: **110**
       - Commit dates / frequency: **last commit more than a half a year ago, very low frequency**
       - Number of Stars & Forks: **11.1k & 1.1k**
     - Implementation technologies: **Shell script**
     - Licence: **[Apache-2.0](https://choosealicense.com/licenses/apache-2.0/)**
   - Features
     - [x] Scan whole history
     - [x] Scan single commit
     - [ ] Predefined set of rules: _A very limited number of rules_
     - [x] Definition of custom rules
     - [x] Definition of custom exclusions patterns
     - [ ] Entropy detection
     - [ ] Pre-backed Docker image

   - Pros
     - A well-known tool that has been around for a while
   - Cons
     - Rules and exclusion patterns are not easy to manage as no comments or metadata are allowed in the definition
     - No pre-backed Docker image
     - Activity of the repo has dropped (last commit a while ago)

2. [trufflehog](https://github.com/trufflesecurity/trufflehog)

   - Repository metadata
     - Contributions
       - Number of contributors: **69**
       - Number of commits: **2050**
       - Commit dates / frequency: **last commit today, high frequency**
       - Number of Stars & Forks: **11.3k & 1.3k**
     - Implementation technologies: **Go language**
     - Licence: **[AGPL-3.0](https://choosealicense.com/licenses/agpl-3.0/)**
   - Features
     - [x] Scan whole history
     - [x] Scan single commit
     - [ ] Predefined set of rules
     - [x] Definition of custom rules
     - [x] Definition of custom exclusions patterns: _Only whole files_
     - [x] Entropy detection
     - [x] Pre-backed Docker image

   - Pros
     - Entropy detection
     - Fast to scan the whole history
   - Cons
     - [AGPL-3.0](https://choosealicense.com/licenses/agpl-3.0/) licence comes with conditions

3. [gitleaks](https://github.com/gitleaks/gitleaks)

   - Repository metadata

     - Contributions
       - Number of contributors: **135**
       - Number of commits: **929**
       - Commit dates / frequency: **last commit three days ago, medium frequency**
       - Number of Stars & Forks: **13k & 1.2k**
     - Implementation technologies: **Go language**
     - Licence: **[MIT](https://choosealicense.com/licenses/mit/)**
   - Features
     - [x] Scan whole history
     - [x] Scan single commit
     - [x] Predefined set of rules
     - [x] Definition of custom rules
     - [x] Definition of custom exclusions patterns
     - [x] Entropy detection: _Set against a rule_
     - [x] Pre-backed Docker image

   - Pros
     - Ease of managing rules and exclusion patterns as the configuration file uses the `toml` format
     - Entropy detection at a rule level
     - Fast to scan the whole history
   - Cons
     - No full entropy detection as an option

### Outcome

The decision is to support Option 3 and endorse the usage of the `gitleaks` tool. This decision is reversible, and the state of secret scan tooling will be monitored by means of the NHS England Tech Radar.

### Rationale

This decision was made with the understanding that the chosen tool must support the NHS England  [Coding in the Open](https://github.com/nhsx/open-source-policy) initiative/policy and also be compatible with usage in private repositories.

## Consequences

As a result of this decision, any new repository created from the repository template should contain a secret scanning implementation based on `gitleaks` provided as a GitHub Action.

## Compliance

Compliance will be checked by the [GitHub Scanning Tool](https://github.com/NHSDigital/github-scanning-utils).

## Notes

This is an addition to the [GitHub Secret Scanning](https://docs.github.com/en/code-security/secret-scanning/about-secret-scanning) feature that should be considered to be turned on for any public repository within the NHS England GitHub subscription.

## Actions

- [ ] Update the NHS England [Software Engineering Quality Framework](https://github.com/NHSDigital/software-engineering-quality-framework) accordingly

## Tags

`#maintainability, #testability, #simplicity, #security`
