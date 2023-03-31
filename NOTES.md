# ENG-276: Git hook to check .editorconfig compliance

## Requirements

- cross-platform portable (systems: macOS, Linux (Ubuntu), Windows WSL)
- run only on changed files
- option to not run it
  - case by case basis - e.g. file
  - turn it off completly
- document it e.g. contributing.md

# What do we do?

Options 1

- https://pre-commit.com/
  - PROS
    - Python is installed on most if not all platforms
    - pythonist friendly
    - well documentd
    - can pass git diff files only
  - CONS
    - Dependency on Python even for non-Python tech stack
    - Versioning issue, python runtime and libraries compatibility
    - Lack of process isolation
    - Cannot execute code outside of the framework
    - dependency on multipel parties

Option 2

- Shell script
  - PROS
    - installed everywhere, multiplatform, no setup
    - simple
    - easy to maintain
  - CONS
    - more coding in shell potentially
    - testing that code

Decisions: Option 2

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
