# ADR-003: Acceptable use of GitHub PAT (Personal Access Token) and GitHub Apps for authentication and authorisation

>|              | |
>| ------------ | --- |
>| Date         | `07/06/2023` |
>| Status       | `RFC` |
>| Deciders     | `Engineering` |
>| Significance | `Dependencies, Interfaces` |
>| Owners       | `Dan Stefaniuk, ?` |

---

- [ADR-003: Acceptable use of GitHub PAT (Personal Access Token) and GitHub Apps for authentication and authorisation](#adr-003-acceptable-use-of-github-pat-personal-access-token-and-github-apps-for-authentication-and-authorisation)
  - [Context](#context)
  - [Decision](#decision)
    - [Assumptions](#assumptions)
    - [Drivers](#drivers)
    - [Options](#options)
      - [GitHub Personal Access Tokens (PATs)](#github-personal-access-tokens-pats)
      - [GitHub Apps](#github-apps)
    - [Outcome](#outcome)
    - [Rationale](#rationale)
  - [Compliance](#compliance)
  - [Notes](#notes)
  - [Tags](#tags)

## Context

TODO: Context, e.g. it is not clear when to use which

## Decision

### Assumptions

Quoted directly from the GitHub documentation:

- _**Personal access tokens** are an alternative to using passwords for authentication to GitHub when using the GitHub API or the command line. Personal access tokens are intended to access GitHub resources on behalf of yourself. To access resources on behalf of an organisation, or for long-lived integrations, you should use a GitHub App._
- _A **GitHub App** is a type of integration that you can build to interact with and extend the functionality of GitHub. You can build a GitHub App to provide flexibility and reduce friction in your processes, without needing to sign in a user or create a service account._

### Drivers

The purpose of this decision record or more accurately, this guide, is to provide clear guidelines on the appropriate use of both GitHub Personal Access Tokens (PATs) and GitHub Apps. Our goal is to ensure that any automated processes employ the correct mechanisms for authentication and authorisation when executing GitHub actions and workflows. These processes form the backbone of your CI/CD pipeline implementation. By adhering to these guidelines we can maintain robust, secure and effective automation processes.

### Options

There are two complementary options for automated GitHub action and workflow authentication and authorisation processes:

- [GitHub PATs](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens)
- [GitHub Apps](https://docs.github.com/en/apps/creating-github-apps/about-creating-github-apps/about-creating-github-apps)

#### GitHub Personal Access Tokens (PATs)

Use PATs when:

1. **Scripted access**: When you are writing scripts that automate tasks related to your repositories, PATs can be an excellent choice. These tokens can authenticate your script with GitHub allowing it to perform various operations like cloning repositories, creating issues, or fetching data from the API. Since PATs can act with nearly all the same scopes as a user, they can be a versatile tool for script-based interactions with your repositories.

2. **Command-line access**: If you are directly using the GitHub API from the command-line (e.g. with `curl`), PATs provide a convenient way to authenticate. They allow you to perform a wide range of actions, including getting the number of stars on a repository, posting a comment on an issue or triggering a new build or deployment. In this use case a common task that a contributor has to perform daily can be automated using a PAT generated with a scope specifically for it.

3. **Two-Factor Authentication (2FA)**: If you have enabled 2FA for added account security, performing `https` Git operations like clone, fetch, pull or push will require a PAT instead of a password. This helps ensure that operations remain secure even from the command-line.

4. **3rd-party applications and services**: When using services that need to integrate with your GitHub account, PATs can be a good solution. You can limit the scope of each token to what the service specifically needs (like only read access to repositories), providing a measure of security and control. This use case would rather fit a personal repository project to provide time-bound access to a 3rd-part service to, for example give feedback on the state of the codebase or your commits.

Do not use PATs when:

1. **Sharing your account**: PATs should never be used to provide access to your GitHub account to others. Instead, use GitHub's built-in features for collaboration and access management, such as adding collaborators to repositories or using organisations and teams.

2. **Public repositories or code**: PATs provide broad access to your account, so you should never embed them in your code, especially if that code is public. This could allow someone to take control of your account, modify your repositories or steal your data. The [secret scan pre-commit hook](../../scripts/githooks/secret-scan-pre-commit.sh) that is part of this repository template should prevent you from doing so anyway.

3. **Broad permissions**: While PATs can have broad permissions, you should aim to restrict each token's scope to what is necessary for its purpose. For instance, a token used only for reading repository metadata does not need write or admin access.

4. **Long-term usage without rotation**: To limit potential exposure of your PAT, it is recommended to periodically change or "rotate" your tokens. This is a common security best practice for all kinds of secret keys or tokens.

#### GitHub Apps

Use Apps when:

1. **Acting on behalf of a user or an organisation**: GitHub Apps can be installed directly onto an organisation or a user account and can access specific repositories. They act as separate entities and do not need a specific user to authenticate actions, thus separating the app's actions from individual users and preventing user-related issues (like a user leaving the organisation) from disrupting the app's operation. In this model, a GitHub App can act on behalf of a user to perform actions that the user has permissions for. For example, if a GitHub App is used to manage issues in a repository, it can act on behalf of a user to open, close, or comment on issues. The actions the app can perform are determined by the user's permissions and the permissions granted to the app during its installation.

2. **When you need fine-grained permissions**: GitHub Apps provide more detailed control over permissions than PATs. You can set access permissions on a per-resource basis (issues, pull requests, repositories, etc.). This allows you to follow the principle of least privilege, granting your app only the permissions it absolutely needs.

3. **Webhook events**: GitHub Apps can be configured to receive a variety of webhook events. Unlike personal tokens, apps can receive granular event data and respond accordingly. For instance, an app can listen for `push` events to trigger a CI/CD pipeline or `issue_comment` events to moderate comments.

4. **Server-to-server communication**: Unlike users, GitHub Apps have their own identities and can perform actions directly on a repository without a user action triggering them. They are associated with the GitHub account (individual or organisation) that owns the app, not necessarily the account that installed the app. In this model the GitHub App can perform actions based on the permissions it was given during setup. These permissions are separate from any user permissions and allow the app to interact with the GitHub API directly. For example, an app might be set up to automatically run a test suite whenever code is pushed to a repository. This action would happen regardless of which user pushed the code.

### Outcome

Prefer to use GitHub Apps for any automation processes.

### Rationale

TODO: Explain...

## Compliance

TODO: How can we check for compliance?

## Notes

TODO: Demonstrate a sample setup

## Tags

`#maintainability, #security`
