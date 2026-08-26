<!-- markdownlint-disable-file first-line-heading -->

## Description

<!--
Describe WHAT changed and WHY, so a reviewer understands the PR without reading
every line. Aim for the depth of a good commit body.

Please include:
  1. A short summary (1-3 sentences): what this PR does and the value it delivers.
  2. A file-by-file bulleted list of the substantive changes, each linking the
     file with a repository-relative path. For example:
       - [scripts/quality/check-file-format.sh](scripts/quality/check-file-format.sh): what changed and why
  3. Any notable implementation details, follow-ups, or explicitly out-of-scope items.
-->

## Context

<!--
Explain the background and motivation so the change is justified and can be
revisited later.

Please answer:
  - Why is this change required? What problem, risk, or friction does it solve?
  - What was the previous behaviour, and why was it inadequate (bug, gap, overhead)?
  - What alternatives or trade-offs were considered, and why this approach?
  - Link any related issue, ADR, or discussion.
-->

## How to test it

<!--
Give the reviewer a repeatable way to verify the change; prefer concrete commands
over prose. For docs-only or config-only changes, state that and why no manual
test applies.

Recommended structure:
  - "Prerequisites:" — any setup or install commands (for example: make config).
  - One numbered test per behaviour ("Test 1: ...", "Test 2: ..."), each with:
      * the exact command(s) to run, inside a fenced bash code block;
      * an "Expected:" line describing the correct result;
      * a "Clean up:" step when the test changes the working tree
        (for example: git checkout -- <file>).
-->

## Type of changes

<!-- What types of changes does your code introduce? Put an `x` in all the boxes that apply. -->

- [ ] Refactoring (non-breaking change)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would change existing functionality)
- [ ] Bug fix (non-breaking change which fixes an issue)

## Checklist

<!-- Go over all the following points, and put an `x` in all the boxes that apply. -->

- [ ] I am familiar with the [contributing guidelines](./contributing.md)
- [ ] I have followed the code style of the project
- [ ] I have added tests to cover my changes
- [ ] I have updated the documentation accordingly
- [ ] I have described how to test these changes in the section above
- [ ] This PR is a result of pair or mob programming
- [ ] This PR is a result of AI-assisted development sessions

---

## Sensitive Information Declaration

To ensure the utmost confidentiality and protect your and others privacy, we kindly ask you to NOT including [PII (Personal Identifiable Information) / PID (Personal Identifiable Data)](https://digital.nhs.uk/data-and-information/keeping-data-safe-and-benefitting-the-public) or any other sensitive data in this PR (Pull Request) and the codebase changes. We will remove any PR that do contain any sensitive information. We really appreciate your cooperation in this matter.

- [ ] I confirm that neither PII/PID nor sensitive data are included in this PR and the codebase changes.
