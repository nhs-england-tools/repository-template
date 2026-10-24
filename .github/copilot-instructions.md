# GitHub Copilot Instructions 🤖

## Implementation discipline 🛠️

- Do not invent requirements or widen scope.
- Keep outputs deterministic, make side effects explicit, and surface errors.
- Follow execution or call-flow order where it improves clarity. Group widely
  shared utilities.

## Specification and testing 🧪

- When code and specification diverge, assess both. Fix incorrect code and
  revise wrong or impractical specifications with rationale and impact
  assessment. Align code and tests with the result. Never justify accidental
  behaviour by rewriting the specification.
- For behavioural changes, follow `Red -> Green -> Refactor`.
- Use property-based testing where it adds value.

## Repository verification policy 🔍

Run failing tests and focused checks while working. The Stop hook runs
`make lint` and `make test` after edits. Do not repeat those full gates manually
unless diagnosing a failure or the hook is unavailable.

## Communication style 💬

- Use British English.
- Keep language simple, direct, and active.
- Do not use em dashes or semicolons in prose.
- Write short sentences and prefer intention-revealing wording.
- Update existing documentation or comments in place. Avoid competing
  explanations of the same topic.

## Documentation ADRs 🧾

Record significant technical decisions and technology choices in
[docs/adr](../docs/adr). Consult the current internal NHS Tech Radar for
approval status first, then the local
[Technology Recommendations](../docs/adr/Technology_Recommendations.md) for
candidate tools. Even a default choice needs an ADR comparing alternatives using
the [ADR template](../docs/adr/ADR-nnn_Any_Decision_Record_Template.md).

## Toolchain version 🔧

Use the newest eligible stable language, runtime and framework versions that
meet project constraints, including the cooldown in
[Update Dependencies](../docs/guides/Update_Dependencies.md).
