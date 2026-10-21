Training material. Invented data.

# Gain sheet: Claude Code on the tasks of today

Figures are left empty on purpose: fill them in. Time in minutes of elapsed work for the task,
from first prompt to the definition of done (`CLAUDE.md` section 4). "Without" is the estimate
of the same task done by hand, written before looking at the "with" figure.

| Task | Time with Claude Code (min) | Estimate without (min) | Defects found by the tests (count, one line each) |
|---|---|---|---|
| Feature (instant transfer fee) | | | |
| Contract (CLAUDE.md, working contract) | | | |
| Docs (component page, diagram) | | | |
| Tests (unit, contract, e2e) | | | |
| Triage (GDPR request intake, by hand or by the agent) | | | |
| Agent (`privacy-agent/agent.py`, `SCOPE.md`) | | | |

Defects: count only what a test or check caught (pytest, behave, ruff, the agent's policy gate),
whoever wrote the code. Note the check that caught each one.

## How the team could measure this on real work, without tracking people

1. Measure the work item, not the person: lead time from ticket opened to merged, taken from the tracker and the pipeline, reported per team and per sprint, never per developer.
2. Compare like with like: tag finished items "with Claude Code" or "without" at the team's choice, compare items of the same type and size, and show medians with the number of items.
3. Count quality from the checks, not from people: defects caught by tests before merge, plus defects found after release and the review rework per item, all read from CI and the incident log with no names.
