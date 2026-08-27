---
description: Check for open Dependabot PRs (labelled dependencies), cherry-pick them onto a new branch, verify the code, push, and raise a consolidated PR with the dependencies label.
---

# Dependabot Consolidation

Your task is to consolidate open Dependabot pull requests into a single branch and raise a new PR.

## Steps

1. **Discover open Dependabot Pull Requests**
   - Use the GitHub search tool to list all open Pull Requests in this repository that have the label `dependencies`.
   - Confirm the list with the user before proceeding.

2. **Create a new branch**
   - From the latest `main`, create a new branch named `chore/Dependabot-consolidation-<YYYY-MM-DD>` (use today's date).

3. **Cherry-pick each Pull Request's commits**
   - For each Dependabot Pull Request (oldest merge commit first), cherry-pick its commits onto the new branch.
   - If a cherry-pick conflict occurs, surface the conflict details, ask the user how to resolve it, and continue once resolved.

4. **Verify the code**
   - Run `make build` to ensure the project builds cleanly.
   - Run `make test` to run the full test suite (lint, coverage, contract, security, integration, load).
   - Fix any failures before continuing — do not proceed to push with a broken build.

5. **Push the branch**
   - Push the new branch to `origin`.

6. **Create a pull request**
   - Title: `chore: consolidate Dependabot updates (<YYYY-MM-DD>)`
   - Body: list each cherry-picked Pull Request number and its title.
   - Add the label `dependencies` to the PR.
   - Set the base branch to `main`.

## Notes

- Do not merge any of the original Dependabot Pull Requests — leave them open until this consolidated Pull Request is reviewed and merged.
- If any individual cherry-pick cannot be applied cleanly, skip it, note it in the Pull Request description, and continue with the rest.
- The branch name and Pull Request title must use today's date in `YYYY-MM-DD` format.
