# ADR-000: Third-party tooling, installation approaches and template defaults 🧰

> |              |                                                                                                   |
> | ------------ | ------------------------------------------------------------------------------------------------- |
> | Date         | `2026-10-08`                                                                                      |
> | Status       | `Proposed`                                                                                        |
> | Significance | `Security & privacy, Dependencies, Delivery & build, Governance & compliance, Quality attributes` |

---

- [ADR-000: Third-party tooling, installation approaches and template defaults 🧰](#adr-000-third-party-tooling-installation-approaches-and-template-defaults-)
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

This repository is the NHS England repository template. Teams create new
repositories from it with GitHub's "Use this template" feature, or adopt single
capabilities through the `repository-template` Copilot skill. That skill is
mirrored in the shared Copilot prompt catalogue, in the upstream template and in
every repository created from it. Each adoption copies the files once. From then
on, each repository owns its copy, and template changes reach it only when its
team pulls them in.

This adoption model sets the scale of the decision. Every tool, installation
method and default chosen here is copied into many repositories, onto many
developer machines and into many CI pipelines. A sound default improves all of
them at once. A weak default, or a compromised tool, reaches all of them at
once, and copies that have drifted are hard to fix centrally.

**Problem statement**

The template installs and runs a growing set of third-party tools. This ADR owns
three concerns about them:

- **Installation trust.** Some tools are installed by scripts fetched from
  external URLs, for example mise from `https://mise.run`.
- **Maintenance burden.** Each tool must be chosen, pinned, updated and
  supported, and the toolset keeps growing.
- **Value of the checks.** Each check in
  [scripts/quality](../../scripts/quality) costs developer time and adds attack
  surface, so each must justify its place.

Every tool except Prettier is pinned by version, every image by tag and digest
and every GitHub Action by commit SHA. Pinning does not show whether each tool
is needed, how it is obtained or who keeps it current.

Most of the attack surface is what the tools depend on. The wrappers run each
tool natively or in a container. A compromised release or dependency therefore
runs with a developer's or a CI runner's access. That access covers source code,
local secrets such as `.env` files and, in CI, the workflow token.

This ADR answers four questions:

1. Which checks are worth shipping by default, and which could become optional.
2. How each tool should be obtained and verified.
3. Which controls reduce which supply-chain risks, and what each control costs
   developers.
4. Who keeps the toolchain current, and how.

**Current state**

The template ships the following third-party components.

| Component              | Purpose                             | Obtained from                                          |
| ---------------------- | ----------------------------------- | ------------------------------------------------------ |
| `mise`                 | Toolchain manager                   | Install script fetched from `https://mise.run`         |
| `gitleaks`             | Secret scanning                     | mise (release binary), pinned image fallback           |
| `editorconfig-checker` | File format check                   | mise (release binary), pinned image fallback           |
| `markdownlint-cli`     | Markdown format check               | mise `npm:` backend on Node, pinned image fallback     |
| `lychee`               | Markdown link check                 | mise (release binary), pinned image fallback           |
| `shellcheck`           | Shell lint                          | mise (release binary), pinned image fallback           |
| `hadolint`             | Dockerfile lint                     | mise (release binary), pinned image fallback           |
| Prettier               | Markdown table formatting           | `npx --yes prettier@3` on Node, floating major version |
| `pre-commit`           | Git hook runner                     | mise (PyPI package) on Python                          |
| `node`, `python`       | Runtimes for the npm and PyPI tools | mise                                                   |
| `jq`, `yq`             | JSON and YAML processing in scripts | mise (release binary)                                  |
| GNU tools and Bash 5.2 | Portable script behaviour on macOS  | Homebrew, through `make toolchain-install-gnu-macos`   |

- [mise.toml](../../mise.toml) pins 11 tools. Seven Docker fallback images are
  pinned by version tag and digest in its `[_.docker]` table. GitHub Actions are
  pinned by commit SHA.
- No `mise.lock` is committed, so the transitive dependencies of the npm and
  PyPI tools are not fixed.
- Dependabot covers `docker`, `github-actions`, `npm` and `pip`. It cannot
  update `mise.toml`, so tool and image pins are refreshed by hand. No
  `cooldown` is set.
- All seven image wrappers run
  `docker run --rm --platform linux/amd64 --volume "$PWD…"` with no network,
  filesystem or privilege restrictions. A compromised image can read untracked
  files, change tracked files and reach the network. Native tools run with the
  developer's full privileges.
- Commit-stage CI runs secret scanning and the file format, Markdown format and
  Markdown link checks. Shell lint is advisory today and runs in neither CI nor
  pre-commit. Changes under review make it a failing gate and add it to
  commit-stage CI.
- All four hooks in [pre-commit.yaml](../../scripts/config/pre-commit.yaml) are
  `repo: local` and call `make`.

**Relationship to other decisions**

- **Toolchain manager.** The NHS England Tech Radar places `mise` in Mainstream
  and `asdf` in Contain. The NHSE Engineering Board approved the migration to
  mise. This ADR builds on that and does not reopen it.
- **Commercial suppliers.** A separate maintainer decision on commercial
  suppliers is pending. The recommended position is that a supplier such as
  Chainguard may be at most an optional overlay. An adopting team would switch
  it on with its own entitlement, and it would never be a default. A default
  would need every adopting team to hold an entitlement and a CI credential.
  This ADR treats that position as a constraint unless the maintainers decide
  otherwise.
- **Copilot Stop hook.** Whether the template ships an active Copilot Stop hook
  is a separate open question. VS Code runs tracked hook files in every trusted
  workspace, so a shipped hook would run the checks at the end of every agent
  session in every adopting repository. The answer changes how often the checks
  run and so how much their speed matters.
- **Shell lint.** Changes under review turn shell lint from an advisory check
  into a failing gate in commit-stage CI. This ADR assesses shell lint on that
  basis.

**Constraints**

- Technology choices must align with the Tech Radar. Any deviation needs
  explicit justification in this ADR and approval by the Engineering Board.
- Only organisation-approved products may be recommended. Aikido Safe Chain and
  Socket Firewall, both package-install firewalls, are not approved. The
  approval status of any other new supplier must be confirmed before a spike.
  Candidates include rumdl (a single-binary Markdown linter and formatter), prek
  (a single-binary replacement for pre-commit) and StepSecurity Harden-Runner
  (CI network egress control).
- Defaults must not need a paid entitlement or a CI secret. Workflows triggered
  from forks cannot read CI secrets by default.
- Supported platforms are macOS, Linux and Windows through WSL2. GNU Make 3.82
  or later and Bash 5.2 or later are prerequisites.
- Native and Docker runs, selected with `FORCE_USE_DOCKER`, must give identical
  results.
- Existing configuration must keep working. That covers `gitleaks.toml`,
  `.gitleaksignore` and the lychee and markdownlint configuration.

**Scope**

In scope are the tools, images and installation methods used by the template's
own quality checks, Git hooks and CI, and the defaults the template ships. Out
of scope are the language stack tools for product code, which the Tech Radar
defines per stack, and the build, publish and deploy steps that the `Makefile`
leaves to each team.

**Evidence**

There is no defect-catch history for this repository. Each claim in this ADR is
labelled _measured_, _cited_ or _judgement_. A cited claim is stated in full
here and names its source so it can be checked. The number of commits that
mention a tool is not used as evidence. Tool versions, vendor offers and
approval statuses change over time and must be rechecked when this ADR is
revisited.

## Decision ✅

### Assumptions 🧩

- **Adoption is copy-once.** Repositories do not receive template changes
  automatically. A fix shipped here reaches an existing repository only when its
  team compares and copies the changed files. _Judgement, based on the
  template's manual upgrade path._
- **The number of adopting repositories is a known unknown.** The decision
  assumes many teams and many repositories, so any per-repository cost or risk
  is multiplied. _Judgement._
- **Teams differ in platform capacity.** Many teams have no dedicated platform
  engineer and keep the defaults as shipped. The defaults are therefore the
  controls most repositories actually run. _Judgement._
- **Repository visibility varies.** The NHS Service Standard asks teams to make
  new source code open, so many adopters are public. Some are private, and the
  split is not known. This matters for free tiers that cover only public
  repositories. _Cited for the standard, judgement for the split._
- **CI runs mainly on GitHub-hosted runners with open internet access.**
  Self-hosted runners, restricted egress and air-gapped use exist but are edge
  cases. _Not verified._
- **Developers mostly use managed Macs, many on Apple silicon.** The pinned
  images are `linux/amd64` and run under emulation there. Linux and WSL2 are
  also in use. _Judgement._
- **A Docker-compatible runtime is present**, Docker or Podman, as the README
  requires.
- **No commercial entitlement is assumed.** This follows the commercial supplier
  position under Context.
- **No organisation-wide artefact mirror is assumed for every team.** Whether
  one exists and the template can rely on it is a known unknown. Any mirroring
  option depends on the answer.
- **Supply-chain attacks on developer tooling will continue.** Two recent
  examples are the March 2025 `tj-actions/changed-files` compromise, where the
  action's tags were moved to code that printed CI secrets into build logs, and
  the March 2026 LiteLLM release. The LiteLLM release passed pip hash checks
  because it carried legitimate credentials, and it was live for about three
  hours. Hashes and lockfiles do not stop a bad new release. _Cited._
- **mise stays in Mainstream on the Tech Radar** for the life of this decision.
  Its lockfile, release-age and verification features keep their documented
  behaviour. _Assumption to recheck on revisit._
- **Upstream tool projects stay maintained.** Pre-1.0 tools may make breaking
  changes between minor releases.
- **AI agents make a growing share of changes.** Fast, deterministic local
  checks give agents the same feedback as humans. No study tests
  repository-level lint enforcement against agent outcomes, so the effect is not
  proven. _Judgement._ Adjacent studies point both ways. _Cited:_
  - Deterministic feedback helps. SWE-agent resolved 18.0% of SWE-bench Lite
    with edit-time linting and 15.0% without (arXiv 2405.15793). Ten rounds of
    Bandit and Pylint feedback cut GPT-4o's security issues from over 40% to 13%
    on small snippets (arXiv 2508.14419). Unguided LLM "improvement" rounds
    raised critical vulnerabilities by 37.6% after five rounds (arXiv
    2506.11022).
  - Formatting does not help comprehension. Removing indentation, whitespace and
    newlines changed Pass@1 by at most 4.2%, not significantly, across ten LLMs
    (arXiv 2508.13666). The format checks therefore cannot be justified as
    helping agents understand code.
  - Agents follow instructions they are given, but context files add over 20%
    cost without generally raising success (arXiv 2602.11988). Encoding
    conventions in lint configuration may beat prose instructions. _Judgement._
- **Developer time is the main cost.** A check that adds seconds to the edit
  loop is paid many times a day in every adopting repository. _Judgement._

### Drivers 🎯

- **DR1, supply-chain integrity at organisational scale.** Reduce the chance
  that a malicious, tampered or vulnerable tool reaches developer machines and
  CI, and limit what it can do if it does. Four threats frame this driver: a
  malicious new release, a tampered artefact or registry, a vulnerable
  dependency and a compromised tool at run time.
- **DR2, secure and working by default for every team.** The defaults must work
  without a paid entitlement, a CI secret or a dedicated platform team. That
  includes pull requests from forks.
- **DR3, low and owned maintenance.** Keep the toolset small. Keep pins current
  through an automated path with a cooldown that never delays urgent security
  fixes. Name an owner for each update path. Today `mise.toml` pins are
  refreshed by hand.
- **DR4, value proportional to cost.** Each check earns its place.
  - Secret scanning is a non-negotiable default. 23.8 million new hardcoded
    secrets reached public GitHub in 2024, up 25%. 70% of secrets leaked in 2022
    were still valid. 58% of leaks were generic credentials, which push
    protection struggles to detect. A local scan stops a secret before it enters
    history. _Cited, GitGuardian State of Secrets Sprawl 2025._
  - Shell lint catches real defect classes, such as an unquoted
    `rm -rf "$VAR/"*`, exit codes masked by `export VAR=$(cmd)` and assignments
    lost in subshells. _Cited, ShellCheck rule catalogue._
  - Markdown link checks catch broken documentation links. _Judgement._
  - File format, Markdown format and table formatting checks bring consistency
    and smaller diffs, not security. They are the first candidates for an
    optional tier. _Judgement._
- **DR5, developer experience.** Set up with one command, `make config`. Run
  checks in seconds inside the edit loop. Give the same result natively, in
  Docker, in Git hooks and in CI, on every supported platform.
- **DR6, consistency for humans and AI agents.** Shared configuration run by the
  same wrappers gives every developer and agent one deterministic result. Editor
  settings differ per developer and are the source of the noise. _Judgement._
- **DR7, policy alignment.** Follow the Tech Radar, recommend only approved
  suppliers and seek Engineering Board approval for any deviation.
- **DR8, modularity and reversibility.** Teams can adopt, opt into or remove
  each capability on its own, as the template's modular capabilities already
  allow. Avoid lock-in to a single supplier or image publisher.
- **DR9, central ownership over per-team effort.** When each team chooses,
  installs and pins its own tools, integrity controls are not shared and effort
  moves away from business value. Central controls are applied and reviewed
  once. _Judgement._

DR1 and DR2 are the proposed top criteria for weighting the options.

The current state carries these risks, which motivate the decision:

- mise is installed by piping a script from the internet into a shell.
- Prettier resolves to the latest `3.x` release at run time, outside every pin
  and review.
- The transitive dependencies of the npm and PyPI tools are not locked.
- Container wrappers give each image network access and write access to the
  whole working tree.
- Pins in `mise.toml` and `[_.docker]` drift unless someone refreshes them by
  hand.
- Fixes to the template do not reach repositories that have already copied it.

### Options 🔀

Consider a comprehensive set of alternative options. Always use weighted
scoring. Identify the top one or two criteria for this decision context and
weight them higher than the rest. State the weighting method once and apply it
consistently across all options.

#### Option A: {Descriptive name} (Selected) ✅

**Top criteria**: {Criterion 1, Criterion 2}

**Weighted option score**: {0.0 to 5.0} (define the formula; use weights)

Summarise the core idea behind the selected option, including how it works at a
high level and any critical constraints or prerequisites.

| Criteria (example) | Weight | Score/Notes                                   |
| ------------------ | ------ | --------------------------------------------- |
| Criterion 1        | {1-5}  | ⭐⭐⭐ {reasoning for score}                  |
| Criterion 2        | {1-5}  | ⭐⭐ {reasoning for score}                    |
| Criterion 3        | {1-5}  | ⭐⭐⭐ {reasoning for score}                  |
| Criterion 4        | {1-5}  | ⭐⭐ {reasoning for score}                    |
| Effort             | {1-5}  | {T-shirt size or estimate with justification} |
| Total score        |        | {0.0 to 5.0}                                  |

#### Option B: {Descriptive name}

**Top criteria**: {Criterion 1, Criterion 2}

**Weighted option score**: {0.0 to 5.0} (define the formula; use weights)

Describe the second viable option, including the mechanisms involved and notable
strengths/weaknesses.

| Criteria (example) | Weight | Score/Notes                                   |
| ------------------ | ------ | --------------------------------------------- |
| Criterion 1        | {1-5}  | ⭐⭐ {reasoning for score}                    |
| Criterion 2        | {1-5}  | ⭐⭐ {reasoning for score}                    |
| Criterion 3        | {1-5}  | ⭐ {reasoning for score}                      |
| Criterion 4        | {1-5}  | ⭐⭐⭐ {reasoning for score}                  |
| Effort             | {1-5}  | {T-shirt size or estimate with justification} |
| Total score        |        | {0.0 to 5.0}                                  |

**Why not chosen**: Capture the concrete reasons this option was rejected.
Reference measurable risks, constraints, or trade-offs evidenced in the codebase
or architecture.

#### Option C: {Descriptive name}

**Top criteria**: {Criterion 1, Criterion 2}

**Weighted option score**: {0.0 to 5.0} (define the formula; use weights)

Describe the third option (or more if needed) with enough detail for readers to
evaluate it at a glance.

| Criteria (example) | Weight | Score/Notes                                   |
| ------------------ | ------ | --------------------------------------------- |
| Criterion 1        | {1-5}  | ⭐⭐ {reasoning for score}                    |
| Criterion 2        | {1-5}  | ⭐ {reasoning for score}                      |
| Criterion 3        | {1-5}  | ⭐ {reasoning for score}                      |
| Criterion 4        | {1-5}  | ⭐⭐ {reasoning for score}                    |
| Effort             | {1-5}  | {T-shirt size or estimate with justification} |
| Total score        |        | {0.0 to 5.0}                                  |

**Why not chosen**: Explain the specific drawbacks, blockers, or context
conflicts that ruled out this option.

### Outcome 🏁

State the decision outcome, based on the information above. State whether the
decision is reversible or irreversible, and what would trigger revisiting it.

### Rationale 🧠

Provide a rationale for the decision based on weighing the options, so the same
questions do not need to be answered repeatedly unless the decision is
superseded.

For non-trivial decisions, a comparison table can be useful: decision criteria
down one side, options across the top. The criteria will often come from the
Drivers section above. Effort is commonly a key driver; consider T-shirt sizing
the effort for each option to make trade-offs explicit.

## Consequences ⚖️

Describe the resulting context after applying the decision. List all identified
consequences, not just the positive ones. Any decision comes with trade-offs.
For example, it may introduce the need for further decisions due to
cross-cutting concerns; it may impact structure, operational characteristics, or
quality attributes; as a result, some things may become easier or more
difficult.

State the conditions under which this decision no longer applies or becomes
irrelevant.

## Compliance 📏

Define how compliance with this decision will be measured and validated. Where
possible, specify **deterministic, testable** criteria.

Compliance checks can be manual or automated using a fitness function. If
automated, specify:

- Where it runs (for example CI, pre-merge, scheduled job)
- What it evaluates (inputs/outputs, constraints, thresholds)
- What evidence it produces (logs, reports, artefacts)
- What changes are needed in the repository to support the measurement
- A command or script Copilot can run locally to assert compliance automatically
  when reading this ADR; update the ADR whenever that command changes so
  automation stays accurate.

## Notes 🔗

Link to related **features**, **specifications**, **functional requirements**,
**success criteria**, other ADRs, risks, policies, and any relevant repository
artefacts (for example configuration, schemas, contracts, or code entry points).

If the decision is tactical, sub-optimal, or misaligned with strategic
direction, identify and articulate the associated risk clearly. Where
appropriate, create a Tech Debt record on the backlog and link it here.

## Actions ✅

- [x] name, date by, action
- [ ] name, date by, action

## Tags 🏷️

`#security|#compliance|#maintainability|#simplicity|#consistency|#portability|#modularity|#usability|#cost`
