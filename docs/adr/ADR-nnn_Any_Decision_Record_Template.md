# ADR-nnn: Any Decision Record Template 🧾

> |              |                                                                                                                                                                |
> | ------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
> | Date         | `YYYY-MM-DD` _when this ADR was last updated_                                                                                                                  |
> | Status       | `RFC until YYYY-MM-DD, Proposed, In Discussion, Withdrawn, Rejected, Accepted, Deprecated, Superseded by ADR-XXX`                                              |
> | Significance | `Architecture, Quality attributes, Data, Interfaces & contracts, Dependencies, Delivery & build, Operations, Security & privacy, Governance & compliance,` ... |

---

- [ADR-nnn: Any Decision Record Template 🧾](#adr-nnn-any-decision-record-template-)
  - [Context 🧭](#context-)
  - [Decision ✅](#decision-)
    - [Assumptions 🧩](#assumptions-)
    - [Drivers 🎯](#drivers-)
    - [Options 🔀](#options-)
      - [Option A: {Descriptive name} (Recommended) ✅](#option-a-descriptive-name-recommended-)
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

Describe the context and the problem statement. Is there a relationship to other
decisions already recorded? Which **feature**, **specification**, **functional
requirements**, or **success criteria** does this decision relate to? Are there
any dependencies and/or constraints within which the decision must be made? Do
any of these need to be reviewed or validated?

Note that environmental limitations or restrictions (for example accepted
technology standards, commonly recognised patterns, engineering and architecture
principles, organisational policies, and governance) may narrow the options.
This must be explicitly documented. This is a point-in-time decision, recorded
so it can be understood, justified, and revisited when needed.

Technology choices must align with the current internal NHS Tech Radar, which is
the authority for approval status. The local
[Technology Recommendations](./Technology_Recommendations.md) suggest candidates
for comparison, not approved defaults. Compare alternatives in this ADR.

The team maintains ADRs in this repository as a decision log. Accepted means the
team has adopted the decision, not that an external body has approved it. Where
separate approval is required, follow that body's process in its specified
format and link to its record in Notes. This ADR does not replace that process.

## Decision ✅

### Assumptions 🧩

Summarise the underlying assumptions in the environment in which you are making
the decision. This could relate to technology changes, forecasts of monetary and
non-monetary costs, delivery commitments, impactful external drivers, and any
known unknowns that translate into risks.

### Drivers 🎯

List the decision drivers that motivate this decision or course of action. This
may include risks and residual risks after applying the decision.

### Options 🔀

Consider a comprehensive set of alternative options. Place the recommended
option first and label it `(Recommended) ✅`. If the recommendation changes,
reorder the options and update the contents list. Always use weighted scoring.
Identify the top one or two criteria for this decision context and weight them
higher than the rest. Use the same criteria and weights for every option. Rate
each criterion from one star (weakest fit) to five stars (strongest fit) and
explain the rating. Calculate the weighted score out of five as the sum of each
weight multiplied by its star count, divided by the sum of the weights, rounded
to one decimal place. For example, ratings of ⭐⭐⭐⭐ and ⭐⭐⭐ with weights
of 5 and 3 score (5 × 4 + 3 × 3) / (5 + 3) = 3.6/5. If effort is a criterion,
keep the T-shirt estimate visible and map sizes to stars consistently across
options (for example XS=5, S=4, M=3, L=2, XL=1). Otherwise, omit the effort row.
The score informs the recommendation but does not decide it.

#### Option A: {Descriptive name} (Recommended) ✅

**Top criteria**: {Criterion 1, Criterion 2}

**Weighted option score**: {1.0 to 5.0}

Summarise the core idea behind this option, including how it works at a high
level and any critical constraints or prerequisites.

| Criteria (example) | Weight | Score/Notes                             |
| ------------------ | ------ | --------------------------------------- |
| Criterion 1        | {1-5}  | ⭐⭐⭐ {reasoning for score}            |
| Criterion 2        | {1-5}  | ⭐⭐ {reasoning for score}              |
| Criterion 3        | {1-5}  | ⭐⭐⭐ {reasoning for score}            |
| Criterion 4        | {1-5}  | ⭐⭐ {reasoning for score}              |
| Effort             | {1-5}  | ⭐⭐⭐ {T-shirt size and justification} |
| Total score        |        | {1.0 to 5.0}                            |

#### Option B: {Descriptive name}

**Top criteria**: {Criterion 1, Criterion 2}

**Weighted option score**: {1.0 to 5.0}

Describe the second viable option, including the mechanisms involved and notable
strengths/weaknesses.

| Criteria (example) | Weight | Score/Notes                             |
| ------------------ | ------ | --------------------------------------- |
| Criterion 1        | {1-5}  | ⭐⭐ {reasoning for score}              |
| Criterion 2        | {1-5}  | ⭐⭐ {reasoning for score}              |
| Criterion 3        | {1-5}  | ⭐ {reasoning for score}                |
| Criterion 4        | {1-5}  | ⭐⭐⭐ {reasoning for score}            |
| Effort             | {1-5}  | ⭐⭐⭐ {T-shirt size and justification} |
| Total score        |        | {1.0 to 5.0}                            |

**Trade-offs**: Explain why this option is not recommended over the first
option, including its strengths, risks, and constraints, with evidence from the
codebase or architecture where relevant.

#### Option C: {Descriptive name}

**Top criteria**: {Criterion 1, Criterion 2}

**Weighted option score**: {1.0 to 5.0}

Describe the third option (or more if needed) with enough detail for readers to
evaluate it at a glance.

| Criteria (example) | Weight | Score/Notes                             |
| ------------------ | ------ | --------------------------------------- |
| Criterion 1        | {1-5}  | ⭐⭐ {reasoning for score}              |
| Criterion 2        | {1-5}  | ⭐ {reasoning for score}                |
| Criterion 3        | {1-5}  | ⭐ {reasoning for score}                |
| Criterion 4        | {1-5}  | ⭐⭐ {reasoning for score}              |
| Effort             | {1-5}  | ⭐⭐⭐ {T-shirt size and justification} |
| Total score        |        | {1.0 to 5.0}                            |

**Trade-offs**: Explain why this option is not recommended over the first
option, including its strengths, drawbacks, blockers, and context conflicts.

### Outcome 🏁

For a proposed ADR, state the recommended option and why it is recommended,
making clear that the team has not yet decided. Once the team adopts a decision,
record the chosen option and decision date. State whether the decision is
reversible or irreversible, and what would trigger revisiting it.

### Rationale 🧠

Provide a rationale for the recommendation or adopted decision based on weighing
the options, including trade-offs beyond the indicative scores, so the same
questions do not need to be answered repeatedly unless the decision is
superseded. For an accepted ADR, explain why the alternatives were not chosen.

For non-trivial decisions, a comparison table can be useful: decision criteria
down one side, options across the top. The criteria will often come from the
Drivers section above. Effort is commonly a key driver, consider T-shirt sizing
the effort for each option to make trade-offs explicit.

## Consequences ⚖️

Describe the expected context if the recommendation is adopted, or the resulting
context after an accepted decision is applied. List all identified consequences,
not just the positive ones. Any decision comes with trade-offs. For example, it
may introduce the need for further decisions due to cross-cutting concerns, it
may impact structure, operational characteristics, or quality attributes, as a
result, some things may become easier or more difficult.

State the conditions under which this decision no longer applies or becomes
irrelevant.

## Compliance 📏

Recommend automated fitness criteria for assessing whether an accepted decision
is being followed. Define **deterministic, testable** pass/fail conditions.
These are proposed checks, not evidence that automation exists or that the
system is compliant.

For each proposed fitness function, specify:

- What rule it evaluates (inputs, constraints, thresholds, expected pass/fail
  outcome)
- Where and when it should run (for example CI, pre-merge, scheduled job)
- What evidence it should produce (logs, reports, artefacts)
- What changes are needed in the repository to implement it
- If implemented, a link to its script, test, or CI job and a command where
  available. Update the reference when the check changes.

An agent may propose implementing these checks in Actions, but must not assess
compliance as part of drafting the ADR.

## Notes 🔗

Link to related **features**, **specifications**, **functional requirements**,
**success criteria**, other ADRs, risks, policies, and any relevant repository
artefacts (for example configuration, schemas, contracts, or code entry points).

If the decision is tactical, sub-optimal, or misaligned with strategic
direction, identify and articulate the associated risk clearly. Where
appropriate, create a Tech Debt record on the backlog and link it here.

## Actions ✅

- [ ] name, date by, action
- [ ] name, date by, action

## Tags 🏷️

Use tags to link related ADRs by cross-cutting concern and quality attribute.
Prefer a small, consistent set.

`#availability|#reliability|#resilience|#recoverability|#scalability|#performance|#latency|#throughput|#efficiency|#cost|#security|#privacy|#compliance|#auditability|#observability|#operability|#maintainability|#testability|#deployability|#portability|#interoperability|#compatibility|#usability|#accessibility|#simplicity|#modularity|#extensibility|#data-integrity|#data-quality|#data-retention|#data-lineage|#idempotency|#consistency|…`
