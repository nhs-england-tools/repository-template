# Technology Recommendations 📡

This is a local list of technology recommendations for repositories based on
this template, not the NHS Tech Radar. It does not grant technology approval.
Consult the current internal NHS Tech Radar for approval status and requirements
before selecting a tool.

Python and TypeScript are orgnaisation-approved Mainstream languages on the NHS
Tech Radar. PostgreSQL is an orgnaisation-approved Mainstream database. [Django],
[FastAPI] and [React] are also approved. Teams are asked to use [OpenFeature] for
feature toggling. The remaining tools below are provisional suggestions, not
ratified defaults.

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

## Persistence 🗄️

Use [PostgreSQL] for production-grade persistence and [SQLite] as a supporting
in-memory database.

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

[ADR template]: ./ADR-nnn_Any_Decision_Record_Template.md
[Biome]: https://biomejs.dev/
[Bruno]: https://www.usebruno.com/
[Chalk]: https://github.com/chalk/chalk
[Commander.js]: https://github.com/tj/commander.js
[Django]: https://www.djangoproject.com/
[ESLint]: https://eslint.org/
[fast-check]: https://fast-check.dev/
[FastAPI]: https://fastapi.tiangolo.com/
[Hypothesis]: https://hypothesis.readthedocs.io/en/latest/
[Ink]: https://github.com/vadimdemedes/ink
[Jest]: https://jestjs.io/
[mypy]: https://mypy.readthedocs.io/
[Node.js]: https://nodejs.org/en
[OpenFeature]: https://openfeature.dev/
[Pact]: https://pact.io/
[pnpm]: https://pnpm.io/
[PostgreSQL]: https://www.postgresql.org/
[Powertools for AWS Lambda]: https://docs.aws.amazon.com/powertools/
[Prettier]: https://prettier.io/
[Prism]: https://github.com/stoplightio/prism
[Pyright]: https://microsoft.github.io/pyright/
[pytest]: https://pytest.org/
[React]: https://react.dev/
[Requests]: https://requests.readthedocs.io/en/latest/
[Rich]: https://rich.readthedocs.io/en/stable/
[Ruff]: https://docs.astral.sh/ruff/
[Schemathesis]: https://schemathesis.io/
[SQLite]: https://www.sqlite.org/
[structlog]: https://www.structlog.org/en/stable/
[supertest]: https://github.com/forwardemail/supertest
[Textual]: https://textual.textualize.io/
[tsc]: https://www.typescriptlang.org/
[Typer]: https://typer.tiangolo.com/
[uv]: https://docs.astral.sh/uv/
[Vite]: https://vite.dev/
[Vitest]: https://vitest.dev/
[winston]: https://github.com/winstonjs/winston
[WireMock]: https://wiremock.org/
