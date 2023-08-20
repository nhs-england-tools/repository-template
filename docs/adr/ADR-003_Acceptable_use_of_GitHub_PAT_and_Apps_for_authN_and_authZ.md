# ADR-003: Acceptable use of GitHub authentication and authorisation mechanisms

>|              | |
>| ------------ | --- |
>| Date         | `20/08/2023` |
>| Status       | `RFC` |
>| Deciders     | `Engineering` |
>| Significance | `Construction techniques` |
>| Owners       | `Dan Stefaniuk, ?` |

---

- [ADR-003: Acceptable use of GitHub authentication and authorisation mechanisms](#adr-003-acceptable-use-of-github-authentication-and-authorisation-mechanisms)
  - [Context](#context)
  - [Decision](#decision)
    - [Assumptions](#assumptions)
    - [Drivers](#drivers)
    - [Options](#options)
    - [Outcome](#outcome)
      - [Built-in authentication using `GITHUB_TOKEN` secret](#built-in-authentication-using-github_token-secret)
      - [GitHub PAT (Personal Access Token)](#github-pat-personal-access-token)
      - [GitHub App](#github-app)
    - [Rationale](#rationale)
  - [GitHub App notes](#github-app-notes)
    - [Limits](#limits)
    - [Setup](#setup)
    - [Examples of acquiring the GitHub App access token](#examples-of-acquiring-the-github-app-access-token)
      - [Bash](#bash)
      - [Python](#python)
      - [Golang](#golang)
      - [Node.js (TypeScript)](#nodejs-typescript)
  - [Tags](#tags)

## Context

TODO: Context, e.g. it is not clear when to use which mechanism and how

## Decision

### Assumptions

_A **GitHub App** is a type of integration that you can build to interact with and extend the functionality of GitHub. You can build a GitHub App to provide flexibility and reduce friction in your processes, without needing to sign in a user or create a service account._

_**Personal access tokens** are an alternative to using passwords for authentication to GitHub when using the GitHub API or the command line. Personal access tokens are intended to access GitHub resources on behalf of yourself._

_When you enable GitHub Actions, GitHub installs a GitHub App on your repository. The **GITHUB_TOKEN** secret is a GitHub App installation access token. You can use the installation access token to authenticate on behalf of the GitHub App installed on your repository._

### Drivers

The aim of this decision record, or more precisely, this guide, is to provide clear guidelines on the appropriate use of GitHub's authentication and authorisation mechanisms. Our objective is to ensure that any automated process utilises correct authentication when executing GitHub actions and workflows. These processes underpin the implementation of the CI/CD pipeline. By adhering to these guidelines, we can maintain robust, secure and effective operations.

### Options

There are three options available to support automated GitHub Action and Workflow authentication processes:

1. [Built-in authentication](https://docs.github.com/en/actions/security-guides/automatic-token-authentication) using `GITHUB_TOKEN` secret

   - ➕ **No set-up required**. It works effortlessly, even for forked repositories.
   - ➕ **The token can only access the repository containing the workflow file**. This token cannot be used to access other private repositories.
   - ➖ **The token can only access a repository containing the workflow file**. If you need to access other private repositories or require write access to other public repositories this token will not be sufficient.
   - ➖ **The token cannot trigger other workflows**. If you have a workflow that creates a release and another workflow that runs when someone creates a release, the first workflow will not trigger the second workflow if it utilises this token based mechanism for authentication.

2. [GitHub PAT](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens) (Personal Access Token)

   - ➕ **Simple to set up**. You can create a [fine-grained personal access token](https://github.com/settings/tokens?type=beta) with a repository scope or a [classic personal access token](https://github.com/settings/tokens) with a wider permission model that extends beyond a single repository.
   - ➕ **The token can trigger other workflows**.
   - ➕ **It can access all repositories you have access to** (using a classic PAT). This is convenient because you can access other repositories without any additional setup.
   - ➖ **It can access all your repositories you have access to** (using a classic PAT). You do not have fine-grained control over which repositories this token can access because this token represents you.
   - ➖ **It is bound to a person**. The owner of the token leaving the organisation can cause your workflow to break.

3. [GitHub App](https://docs.github.com/en/apps/creating-github-apps/about-creating-github-apps/about-creating-github-apps)

   - ➕ **You can control which repositories your token has access to** by installing the GitHub App to selected repositories.
   - ➕ **An organisation can own multiple GitHub Apps** and they do not consume a team seat.
   - ➕ **GitHub App provides a more fine-grained permission model**.
   - ➕ **The token can trigger other workflows**.
   - ➖ **Not very well documented**.
   - ➖ **The setup is a bit more complicated**.

### Outcome

#### Built-in authentication using `GITHUB_TOKEN` secret

A `GITHUB_TOKEN` is automatically generated and used within GitHub Action and Workflow for tasks related to the current repository such as creating or updating issues, pushing commits, etc.

- **Scope**: The `GITHUB_TOKEN` is automatically created by GitHub in each run of a GitHub Action and Workflow, with its scope restricted to the repository initiating the workflow. The permissions of the `GITHUB_TOKEN` are limited to read and write access to the repository.
- **Life Span**: The `GITHUB_TOKEN` has a temporary lifespan automatically expiring after the completion of the job that initiated its creation.

#### GitHub PAT (Personal Access Token)

Use personal access token when:

- **Scripted access**: When you are writing scripts that automate tasks related to your repositories, PATs can be an excellent choice. These tokens can authenticate your script with GitHub allowing it to perform various operations like cloning repositories, creating issues, or fetching data from the API. Since PATs can act with nearly all the same scopes as a user, they can be a versatile tool for script-based interactions with your repositories.

- **Command-line access**: If you are directly using the GitHub API from the command-line (e.g. with `curl`), PATs provide a convenient way to authenticate. They allow you to perform a wide range of actions, including getting the number of stars on a repository, posting a comment on an issue or triggering a new build or deployment. In this use case a common task that a contributor has to perform daily can be automated using a PAT generated with a scope specifically for it.

- **Two-Factor Authentication (2FA)**: If you have enabled 2FA for added account security, performing `https` Git operations like clone, fetch, pull or push will require a PAT instead of a password. This helps ensure that operations remain secure even from the command-line.

Do not use it when:

- **Sharing your account**: PATs should never be used to provide access to your GitHub account to others. Instead, use GitHub's built-in features for collaboration and access management, such as adding collaborators to repositories or using organisations and teams.

- **Public repositories or code**: PATs provide broad access to your account, so you should never embed them in your code, especially if that code is public. This could allow someone to take control of your account, modify your repositories or steal your data. The [secret scan pre-commit hook](../../scripts/githooks/secret-scan-pre-commit.sh) that is part of this repository template should prevent you from doing so anyway.

- **Broad permissions**: While PATs can have broad permissions, you should aim to restrict each token's scope to what is necessary for its purpose. For instance, a token used only for reading repository metadata does not need write or admin access.

- **Long-term usage without rotation**: To limit potential exposure of your PAT, it is recommended to periodically change or "rotate" your tokens. This is a common security best practice for all kinds of secret keys or tokens.

#### GitHub App

Use app when:

- **Acting on behalf of a user or an organisation**: GitHub Apps can be installed directly onto an organisation or a user account and can access specific repositories. They act as separate entities and do not need a specific user to authenticate actions, thus separating the app's actions from individual users and preventing user-related issues (like a user leaving the organisation) from disrupting the app's operation. In this model, a GitHub App can act on behalf of a user to perform actions that the user has permissions for. For example, if a GitHub App is used to manage issues in a repository, it can act on behalf of a user to open, close, or comment on issues. The actions the app can perform are determined by the user's permissions and the permissions granted to the app during its installation.

- **When you need fine-grained permissions**: GitHub Apps provide more detailed control over permissions than PATs. You can set access permissions on a per-resource basis (issues, pull requests, repositories, etc.). This allows you to follow the principle of least privilege, granting your app only the permissions it absolutely needs.

- **Webhook events**: GitHub Apps can be configured to receive a variety of webhook events. Unlike personal tokens, apps can receive granular event data and respond accordingly. For instance, an app can listen for `push` events to trigger a CI/CD pipeline or `issue_comment` events to moderate comments.

- **Server-to-server communication**: Unlike users, GitHub Apps have their own identities and can perform actions directly on a repository without a user action triggering them. They are associated with the GitHub account (individual or organisation) that owns the app, not necessarily the account that installed the app. In this model the GitHub App can perform actions based on the permissions it was given during setup. These permissions are separate from any user permissions and allow the app to interact with the GitHub API directly. For example, an app might be set up to automatically run a test suite whenever code is pushed to a repository. This action would happen regardless of which user pushed the code.

### Rationale

This guide describes the essence of the fundamental aspects of GitHub authentication and authorisation mechanisms along with the common use cases.

## GitHub App notes

### Limits

- Only 100 app registrations are allowed per user or organisation, but there is [no limit on the number of installed apps](https://docs.github.com/en/apps/creating-github-apps/registering-a-github-app/registering-a-github-app#about-registering-github-apps)
- The app name cannot exceed 34 character
- [Access rate limits apply](https://docs.github.com/en/apps/creating-github-apps/registering-a-github-app/rate-limits-for-github-apps) depending on the number of repositories or users within organisation

### Setup

To be executed by a GitHub Administrator:

- Identify the GitHub repository name for which the team has requested a GitHub App integration
- Create a shared email address [england.[repository-name]-app@nhs.net](england.[repository-name]-app@nhs.net)
  - Delegate access to this mailbox for the GitHub organisation owners, administrators and the engineering team
- Create a GitHub bot account named `[repository-name]-app` using the email address mentioned above
- Register a GitHub App under the `[repository-name]-app` bot account with the name `[Team] [Repository Name] [Purpose]`
  - Set the relevant permissions based on the team's requirements

To be executed by a GitHub organisation owner:

- Install the `[Team] [Repository Name] [Purpose]` app and set repository access to the `[repository-name]`

### Examples of acquiring the GitHub App access token

#### Bash

Dependencies are `openssl`, `curl`, `jq` and `gh`.

```bash
export GITHUB_APP_ID=...
export GITHUB_APP_PK_FILE=...
export GITHUB_ORG="nhs-england-tools"
```

[script.sh](./assets/ADR-003/examples/bash/script.sh)

```bash
$ cd docs/adr/ADR-003/examples/bash
$ ./script.sh
GITHUB_TOKEN=ghs_...
```

```bash
$ GITHUB_TOKEN=ghs_...; echo "$GITHUB_TOKEN" | gh auth login --with-token
$ gh auth status
github.com
  ✓ Logged in to github.com as nhs-england-update-from-template[bot] (keyring)
  ✓ Git operations for github.com configured to use https protocol.
  ✓ Token: ghs_************************************
```

#### Python

Dependencies are listed in the `requirements.txt` file.

```bash
export GITHUB_APP_ID=...
export GITHUB_APP_PK_FILE=...
export GITHUB_ORG="nhs-england-tools"
```

[main.py](./assets/ADR-003/examples/python/main.py)

```bash
$ cd docs/adr/ADR-003/examples/python
$ pip install -r requirements.txt
$ python main.py
GITHUB_TOKEN=ghs_...
```

```bash
$ GITHUB_TOKEN=ghs_...;; echo "$GITHUB_TOKEN" | gh auth login --with-token
$ gh auth status
github.com
  ✓ Logged in to github.com as nhs-england-update-from-template[bot] (keyring)
  ✓ Git operations for github.com configured to use https protocol.
  ✓ Token: ghs_************************************
```

#### Golang

Dependencies are listed in the `go.mod` file.

```bash
export GITHUB_APP_ID=...
export GITHUB_APP_PK_FILE=...
export GITHUB_ORG="nhs-england-tools"
```

[main.go](./assets/ADR-003/examples/golang/main.go)

```bash
$ cd docs/adr/ADR-003/examples/golang
$ go run main.go
GITHUB_TOKEN=ghs_...
```

```bash
$ GITHUB_TOKEN=ghs_...; echo "$GITHUB_TOKEN" | gh auth login --with-token
$ gh auth status
github.com
  ✓ Logged in to github.com as nhs-england-update-from-template[bot] (keyring)
  ✓ Git operations for github.com configured to use https protocol.
  ✓ Token: ghs_************************************
```

#### Node.js (TypeScript)

Dependencies are listed in the `package.json` file.

```bash
export GITHUB_APP_ID=...
export GITHUB_APP_PK_FILE=...
export GITHUB_ORG="nhs-england-tools"
```

[main.ts](./assets/ADR-003/examples/nodejs/main.ts)

```bash
$ cd docs/adr/ADR-003/examples/nodejs
$ npm install
$ npm start -s
GITHUB_TOKEN=ghs_...
```

```bash
$ GITHUB_TOKEN=ghs_...; echo "$GITHUB_TOKEN" | gh auth login --with-token
$ gh auth status
github.com
  ✓ Logged in to github.com as nhs-england-update-from-template[bot] (keyring)
  ✓ Git operations for github.com configured to use https protocol.
  ✓ Token: ghs_************************************
```

## Tags

`#maintainability, #security`
