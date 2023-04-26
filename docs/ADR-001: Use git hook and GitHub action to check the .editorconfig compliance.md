# ADR-001: Use git hook and GitHub action to check the `.editorconfig` compliance

>|              | |
>| ------------ | --- |
>| Date         | `26/04/2023` |
>| Status       | `RFC` |
>| Deciders     | `Engineering` |
>| Significance | `Construction techniques` |
>| Owners       | `Daniel Stefaniuk`, `Amaan Ibn-Nasar` |

---

- [ADR-001: Use git hook and GitHub action to check the `.editorconfig` compliance](#adr-001-use-git-hook-and-github-action-to-check-the-editorconfig-compliance)
  - [Context](#context)
  - [Decision](#decision)
    - [Assumptions](#assumptions)
    - [Drivers](#drivers)
    - [Options](#options)
      - [Options 1: The pre-commit project](#options-1-the-pre-commit-project)
      - [Options 2: A shell script](#options-2-a-shell-script)
    - [Outcome](#outcome)
- [How?](#how)
  - [GitHub actions](#github-actions)

## Context

A need for a simple and generic text formatting feature has been identified that would make a part of the Repository Template project.

## Decision

### Assumptions

This decision is made base on the following assumptions that would be used to form a set of general requirements.

- Cross-platform and portable, i.e. supporting systems like macOS, Windows WSL (Ubuntu), Linux (Ubuntu) and potentially other compatible *NIX distributions
- Runs only on changed files
- With option to
  - run it on a case by case basis - e.g. a file or a directory
  - turn it off completely
- It is well document it, e.g. in the [CONTRIBUTING.md](./CONTRIBUTING.md) file

### Drivers

This should help with any potential debate or discussion, removing personal preferences and opinions from it and enabling teams instead to focus on delivering value to the product they work on.

### Options

#### Options 1: The [pre-commit](pre-commit) project

- Pros
  - Python is installed on most if not all platforms
  - A pythonist friendly tool
  - Well-documented
  - Can pass git diff files only
- Cons
  - Dependency on Python even for non-Python tech stack
  - Versioning issue, python runtime and libraries compatibility
  - Lack of process isolation
  - Cannot execute code outside of the framework
  - dependency on multipel parties

#### Options 2: A shell script

- Pros
  - installed everywhere, multiplatform, no setup
  - simple
  - easy to maintain
- Cons
  - more coding in shell potentially
  - testing that code

### Outcome

The decision is to implement Option 2.

How to run `editorconfi` without dependency on platform?
We will go with Docker
Why?

- docker is crossplatofrm
- strategic aligment (this dependency is ok)
- CONS: layers of abstraction is the downside - not everyone is confident with docker

# How?

- bash script
  - where should it live - `scripts/githooks`
    - Makefile - config -> githooks-install
  - what's the name (naming convention)
    - `pre-commit` runner
    - `editorconfig-pre-commit.sh` our script
- Docker

## GitHub actions

do stuff for GitHub in yml

1. same as for the githook
2. proper github action

What is the purpouse? Whet else do we want from it on top of githook?

- stoping point if someone did not have githook
- same gate
- therefore we want to run exactly the same thing
- they must not differ in configuration

Option 1

- no effort duplication
- reuse
- future -> github action implementation should be portable e.g. can we be certain that it will run on our configuration
