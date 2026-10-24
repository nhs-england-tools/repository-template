# Technology Recommendations 📡

This is a local list of technology recommendations for repositories based on
this template, not the NHS Tech Radar. It does not grant technology approval.
Consult the current internal NHS Tech Radar for approval status and requirements
before selecting a tool.

Python and TypeScript are Engineering-approved Mainstream languages on the NHS
Tech Radar. [Django], [FastAPI] and [React] are also approved. Teams are asked
to use [OpenFeature] for feature toggling. The remaining tools below are
provisional suggestions, not ratified defaults.

## Python ecosystem 🐍

| Area                   | Practical recommendation                                                 |
| ---------------------- | ------------------------------------------------------------------------ |
| Dependencies           | [uv]                                                                     |
| Web frameworks         | [Django] or [FastAPI]                                                    |
| Linting and formatting | [Ruff]                                                                   |
| Type checking          | [mypy] or [Pyright] according to the project's typing needs              |
| Testing                | [pytest] with [Hypothesis] where property-based tests add value          |
| API functional testing | [pytest] + [Requests] or a framework test client for HTTP behaviour      |
| Logging                | [structlog] for structured logs or [Powertools for AWS Lambda] on Lambda |
| CLI argument parsing   | [Typer] with optional [Rich] for styled output, tables or progress       |
| TUI framework          | [Textual] for interactive terminal applications, not simple prompts      |

## TypeScript ecosystem 🟦

| Area                     | Practical recommendation                                                                                 |
| ------------------------ | -------------------------------------------------------------------------------------------------------- |
| Runtime and dependencies | [Node.js] + [pnpm]                                                                                       |
| Web UI                   | [React]                                                                                                  |
| Linting and formatting   | [Biome], use [ESLint]/[Prettier] if needed                                                               |
| Type checking            | [tsc]                                                                                                    |
| Testing                  | [Vitest] for [Vite] projects or [Jest] elsewhere, with [fast-check] where property-based tests add value |
| API functional testing   | [supertest] with the project's test runner, including [Jest]                                             |
| Logging                  | [winston] for custom transports or [Powertools for AWS Lambda] on Lambda                                 |
| CLI argument parsing     | [Commander.js] with optional [Chalk] for colour or text emphasis                                         |
| TUI framework            | [Ink] for React-based interactive terminal applications, not simple prompts                              |

## Shared tooling and standards 🔗

| Area                         | Practical recommendation                                                |
| ---------------------------- | ----------------------------------------------------------------------- |
| OpenAPI schema testing       | [Schemathesis] for generated cases when an OpenAPI specification exists |
| OpenAPI mocking / validation | [Prism] for specification-driven simulation and validation              |
| Consumer-driven contracts    | [Pact] when services are developed or deployed independently            |
| Downstream HTTP stubs        | [WireMock] for controlled responses, timeouts and failures              |
| Exploratory API testing      | [Bruno] for version-controlled collections and cross-system journeys    |
| Feature toggling             | Use [OpenFeature] for vendor-neutral feature flag evaluation            |

Record tool choices and alternatives in an ADR using the [ADR template].

[uv]: https://docs.astral.sh/uv/
[Django]: https://www.djangoproject.com/
[FastAPI]: https://fastapi.tiangolo.com/
[Ruff]: https://docs.astral.sh/ruff/
[mypy]: https://mypy.readthedocs.io/
[Pyright]: https://microsoft.github.io/pyright/
[pytest]: https://pytest.org/
[Hypothesis]: https://hypothesis.readthedocs.io/en/latest/
[Requests]: https://requests.readthedocs.io/en/latest/
[structlog]: https://www.structlog.org/en/stable/
[Powertools for AWS Lambda]: https://docs.aws.amazon.com/powertools/
[Typer]: https://typer.tiangolo.com/
[Rich]: https://rich.readthedocs.io/en/stable/
[Textual]: https://textual.textualize.io/
[Node.js]: https://nodejs.org/en
[pnpm]: https://pnpm.io/
[React]: https://react.dev/
[Biome]: https://biomejs.dev/
[ESLint]: https://eslint.org/
[Prettier]: https://prettier.io/
[tsc]: https://www.typescriptlang.org/
[Vitest]: https://vitest.dev/
[Vite]: https://vite.dev/
[Jest]: https://jestjs.io/
[fast-check]: https://fast-check.dev/
[supertest]: https://github.com/forwardemail/supertest
[winston]: https://github.com/winstonjs/winston
[Commander.js]: https://github.com/tj/commander.js
[Chalk]: https://github.com/chalk/chalk
[Ink]: https://github.com/vadimdemedes/ink
[Schemathesis]: https://schemathesis.io/
[Prism]: https://github.com/stoplightio/prism
[Pact]: https://pact.io/
[WireMock]: https://wiremock.org/
[Bruno]: https://www.usebruno.com/
[OpenFeature]: https://openfeature.dev/
[ADR template]: ./ADR-nnn_Any_Decision_Record_Template.md
