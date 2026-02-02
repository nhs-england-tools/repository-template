# ADR-nnn: Any Decision Record Template 🧾

> |              |                                                                                                                                                                |
> | ------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
> | Date         | `YYYY-MM-DD` _when the decision was last updated_                                                                                                              |
> | Status       | `RFC by dd/mm/YYYY, Proposed, In Discussion, Pending Approval, Withdrawn, Rejected, Accepted, Deprecated, Superseded by ADR-XXX, Supersedes ADR-XXX`           |
> | Significance | `Architecture, Quality attributes, Data, Interfaces & contracts, Dependencies, Delivery & build, Operations, Security & privacy, Governance & compliance,` ... |

---

- [ADR-nnn: Any Decision Record Template 🧾](#adr-nnn-any-decision-record-template-)
  - [Context 🧭](#context-)
  - [Decision ✅](#decision-)
    - [Assumptions 🧩](#assumptions-)
    - [Drivers 🎯](#drivers-)
    - [Options 🔀](#options-)
      - [Option A: {Descriptive name} (Selected) ✅](#option-a-descriptive-name-selected-)
      - [Option B: {Descriptive name}](#option-b-descriptive-name)
      - [Option C: {Descriptive name}](#option-c-descriptive-name)
    - [Outcome 🏁](#outcome-)
    - [Rationale 🧠](#rationale-)
  - [Consequences ⚖️](#consequences-️)
  - [Compliance 📏](#compliance-)
  - [Notes 🔗](#notes-)
  - [Actions ✅](#actions-)
  - [Tags 🏷️](#tags-️)

## Context 🧭

Describe the context and the problem statement. Is there a relationship to other decisions already recorded? Which **feature**, **specification**, **functional requirements**, or **success criteria** does this decision relate to? Are there any dependencies and/or constraints within which the decision must be made? Do any of these need to be reviewed or validated?

Note that environmental limitations or restrictions (for example accepted technology standards, commonly recognised patterns, engineering and architecture principles, organisational policies, and governance) may narrow the options. This must be explicitly documented. This is a point-in-time decision, recorded so it can be understood, justified, and revisited when needed.

## Decision ✅

### Assumptions 🧩

Summarise the underlying assumptions in the environment in which you are making the decision. This could relate to technology changes, forecasts of monetary and non-monetary costs, delivery commitments, impactful external drivers, and any known unknowns that translate into risks.

### Drivers 🎯

List the decision drivers that motivate this decision or course of action. This may include risks and residual risks after applying the decision.

### Options 🔀

Consider a comprehensive set of alternative options. Include weighting or scoring if it improves clarity.

#### Option A: {Descriptive name} (Selected) ✅

Summarise the core idea behind the selected option, including how it works at a high level and any critical constraints or prerequisites.

| Criteria (example) | Score/Notes                                   |
| ------------------ | --------------------------------------------- |
| Criterion 1        | ⭐⭐⭐ {reasoning for score}                  |
| Criterion 2        | ⭐⭐ {reasoning for score}                    |
| Criterion 3        | ⭐⭐⭐ {reasoning for score}                  |
| Criterion 4        | ⭐⭐ {reasoning for score}                    |
| Effort             | {T-shirt size or estimate with justification} |

#### Option B: {Descriptive name}

Describe the second viable option, including the mechanisms involved and notable strengths/weaknesses.

| Criteria (example) | Score/Notes                                   |
| ------------------ | --------------------------------------------- |
| Criterion 1        | ⭐⭐ {reasoning for score}                    |
| Criterion 2        | ⭐⭐ {reasoning for score}                    |
| Criterion 3        | ⭐ {reasoning for score}                      |
| Criterion 4        | ⭐⭐⭐ {reasoning for score}                  |
| Effort             | {T-shirt size or estimate with justification} |

**Why not chosen**: Capture the concrete reasons this option was rejected. Reference measurable risks, constraints, or trade-offs evidenced in the codebase or architecture.

#### Option C: {Descriptive name}

Describe the third option (or more if needed) with enough detail for readers to evaluate it at a glance.

| Criteria (example) | Score/Notes                                   |
| ------------------ | --------------------------------------------- |
| Criterion 1        | ⭐⭐ {reasoning for score}                    |
| Criterion 2        | ⭐ {reasoning for score}                      |
| Criterion 3        | ⭐ {reasoning for score}                      |
| Criterion 4        | ⭐⭐ {reasoning for score}                    |
| Effort             | {T-shirt size or estimate with justification} |

**Why not chosen**: Explain the specific drawbacks, blockers, or context conflicts that ruled out this option.

### Outcome 🏁

State the decision outcome, based on the information above. State whether the decision is reversible or irreversible, and what would trigger revisiting it.

### Rationale 🧠

Provide a rationale for the decision based on weighing the options, so the same questions do not need to be answered repeatedly unless the decision is superseded.

For non-trivial decisions, a comparison table can be useful: decision criteria down one side, options across the top. The criteria will often come from the Drivers section above. Effort is commonly a key driver; consider T-shirt sizing the effort for each option to make trade-offs explicit.

## Consequences ⚖️

Describe the resulting context after applying the decision. List all identified consequences, not just the positive ones. Any decision comes with trade-offs. For example, it may introduce the need for further decisions due to cross-cutting concerns; it may impact structure, operational characteristics, or quality attributes; as a result, some things may become easier or more difficult.

State the conditions under which this decision no longer applies or becomes irrelevant.

## Compliance 📏

Define how compliance with this decision will be measured and validated. Where possible, specify **deterministic, testable** criteria.

Compliance checks can be manual or automated using a fitness function. If automated, specify:

- Where it runs (for example CI, pre-merge, scheduled job)
- What it evaluates (inputs/outputs, constraints, thresholds)
- What evidence it produces (logs, reports, artefacts)
- What changes are needed in the repository to support the measurement
- A command or script Copilot can run locally to assert compliance automatically when reading this ADR; update the ADR whenever that command changes so automation stays accurate.

## Notes 🔗

Link to related **features**, **specifications**, **functional requirements**, **success criteria**, other ADRs, risks, policies, and any relevant repository artefacts (for example configuration, schemas, contracts, or code entry points).

If the decision is tactical, sub-optimal, or misaligned with strategic direction, identify and articulate the associated risk clearly. Where appropriate, create a Tech Debt record on the backlog and link it here.

## Actions ✅

- [x] name, date by, action
- [ ] name, date by, action

## Tags 🏷️

Use tags to link related ADRs by cross-cutting concern and quality attribute. Prefer a small, consistent set.

`#availability|#reliability|#resilience|#recoverability|#scalability|#performance|#latency|#throughput|#efficiency|#cost|#security|#privacy|#compliance|#auditability|#observability|#operability|#maintainability|#testability|#deployability|#portability|#interoperability|#compatibility|#usability|#accessibility|#simplicity|#modularity|#extensibility|#data-integrity|#data-quality|#data-retention|#data-lineage|#idempotency|#consistency|…`
