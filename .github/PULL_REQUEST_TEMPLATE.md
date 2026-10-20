<!-- markdownlint-disable-file first-line-heading -->

## Summary

<!--
Write 1-3 sentences that stand alone in notifications and history. State what
changed and the value or problem it addresses. Keep this short. The sections
below provide the supporting detail.

When preparing this description at the end of a work session, use the current
diff, linked issues or design documents, and command output as evidence. Do not
infer or invent details. Say when something is unknown or has not been verified.
-->

## Context and approach

<!--
Explain the problem and why this approach was chosen. Include only context a
reviewer or future maintainer needs beyond the summary.

Link the related issue, specification, ADR, or discussion where available. Add
enough explanation for a reader who cannot access a linked internal source.
If there is no related work item, say so rather than inventing an identifier.
-->

## Changes and impact

<!--
Expand on the summary with the substantive changes, grouped by area or file.
Link repository files where useful, and explain why each change matters.

Record relevant design decisions, alternatives, limitations, deferred work, and
effects on compatibility, security, privacy, accessibility, deployment, or
operations. State when an area was not assessed or is not applicable.
-->

## Validation

<!--
List the checks actually run and the observed result. Do not report a check as
passing unless it was run. For each relevant behaviour, give a reproducible
command and its result. Summarise useful output rather than pasting long logs.
For docs-only or configuration-only changes, say what checks were run and why
runtime testing does not apply. List checks not run and the reason.

For CLI checks, use this structure when it helps a reviewer reproduce the result:

Test 1: Name the behaviour being checked.
Prerequisites: Only what is needed to repeat the check.
Command: The exact command run, in a fenced shell block.
Observed result: What happened, including any failure or skipped step.
Clean up: Only if the check created artefacts. Never discard pre-existing work.

Number additional checks in the order they should be run. Omit fields that do
not apply rather than filling them with boilerplate.
-->

## Type of changes

<!-- What types of changes does your code introduce? Put an `x` in all the boxes that apply. -->

- [ ] Refactoring (non-breaking change)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would change existing functionality)
- [ ] Bug fix (non-breaking change which fixes an issue)

## Checklist

<!-- Go over all the following points, and put an `x` in all the boxes that apply. -->

- [ ] I am familiar with the [contributing guidelines](./CONTRIBUTING.md)
- [ ] I have followed the code style of the project
- [ ] I have added or updated tests, or explained why tests are not applicable
- [ ] I have updated the documentation accordingly
- [ ] I have described the validation performed above
- [ ] This PR is a result of pair or mob programming
- [ ] This PR is a result of AI-assisted development sessions

---

## Sensitive information

Please do not include credentials, PII/PID, or other sensitive data. See [NHS data safety guidance](https://digital.nhs.uk/data-and-information/keeping-data-safe-and-benefitting-the-public). Check the PR description, commits, code changes, logs, screenshots, and test fixtures. If sensitive information has already been shared, follow the project's approved incident or information governance process and contact maintainers privately.

- [ ] I confirm this pull request does not include PII/PID or sensitive data.
