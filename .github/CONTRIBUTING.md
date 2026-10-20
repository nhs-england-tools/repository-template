# Contributing

Thank you for helping improve this project. This repository template provides a starting point, not a complete contribution process for every NHS project. Project maintainers should tailor the guidance below to the adopted repository before inviting contributions.

## Before you contribute

- Read the [Code of Conduct](CODE_OF_CONDUCT.md).
- Check the repository's GitHub Issues for an existing report or discussion before opening a new one. Use the issue forms for support, bugs, and feature requests.
- Report suspected security vulnerabilities through the private route in [SECURITY.md](SECURITY.md). Do not disclose vulnerabilities in public issues or pull requests.
- Follow the project's documented requirements for approvals, accessibility, information governance, security, and clinical safety where they apply.

## Protect sensitive information

Do not add patient information, personal data, credentials, security-sensitive details, or other confidential information to issues, pull requests, source code, test fixtures, logs, or screenshots. Use synthetic or properly anonymised examples. Review output before sharing it, and follow the applicable [NHS data safety guidance](https://digital.nhs.uk/data-and-information/keeping-data-safe-and-benefitting-the-public) and your organisation's policies.

## Set up your environment

Start with the prerequisites and setup steps in the [README](../README.md). In this template, configure the development tools from the repository root with:

```shell
make config
```

If the adopted project needs additional dependencies or setup, document and maintain those steps in its README and Makefile.

## Make a focused change

- Keep each change focused on one problem or outcome.
- Discuss larger or breaking changes with the maintainers before investing in implementation.
- Add or update tests and documentation when behaviour or instructions change.
- Follow the conventions already used in the repository. Use approved dependencies and follow the project's licensing and supply-chain requirements.
- Keep changes reviewable. Do not include generated files or unrelated clean-up unless the project requires them.

## Run checks

Run the available checks from the repository root before opening a pull request:

```shell
make lint
make test
```

`make lint` checks file formats, Markdown formatting and links, and shell scripts. `make test` runs this template's own script test suites. Some integration tests require a running Docker daemon. These checks do not replace tests for an adopted project's application. Extend the Makefile and CI workflow to run the project's build, tests, type checks, security checks, and other required quality gates.

## Open a pull request

Use the [pull request template](PULL_REQUEST_TEMPLATE.md) and:

- Explain what changed and why. Link the related issue or decision where relevant.
- List the commands you ran and their results. If a check could not run, say why.
- Describe relevant risks, compatibility effects, data handling, and deployment or operational changes.
- Update documentation when setup, behaviour, or support routes change.
- Complete the checklist accurately, including its sensitive-information declaration.

Maintainers apply the project's review, approval, and protected-branch rules. These rules should be documented by the project team after adopting this template.

## Tailor this guide when adopting the template

Before accepting contributions to an NHS project created from this template, maintainers should:

- Replace the `nhs-england-tools/repository-template` URLs with the adopted repository's URLs. GitHub requires absolute URLs in the Code of Conduct links of the [issue forms](ISSUE_TEMPLATE/), the security link in [ISSUE_TEMPLATE/config.yml](ISSUE_TEMPLATE/config.yml), and the support link in the [README](../README.md). Also review the remaining support contacts.
- Set a monitored private contact for conduct concerns in the [Code of Conduct](CODE_OF_CONDUCT.md), and confirm the security-reporting route in [SECURITY.md](SECURITY.md).
- Document the project's development setup, test commands, review requirements, and release process.
- Record applicable information governance, accessibility, security, and clinical safety requirements in the project documentation.
- Remove or resolve template TODOs and verify that links and contact routes point to the adopted project.
