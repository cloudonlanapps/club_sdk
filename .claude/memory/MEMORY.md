## How to work

- [explain-one-by-one-plainly](explain-one-by-one-plainly.md) — When reviewing a list of findings with the user, take one point at a time in plain terms, define terms, and weigh how often a case really happens
- [answer-point-by-point](answer-point-by-point.md) — Answer each question separately and in order; never bury a contradiction in prose
- [reply-format-numbered-items](reply-format-numbered-items.md) — User wants brief replies as numbered, tagged items ([Info]/[DECIDE]), max 2 sentences or 30 words each, grouped when more than 5
- [worktrees-and-stacked-prs](worktrees-and-stacked-prs.md) — Do code work in git worktrees, never the main checkout; split multi-part work into stacked PRs rather than parallel ones off main
- [corner-cases-as-failing-tests](corner-cases-as-failing-tests.md) — Don't over-engineer server fixes for rare corner cases; prefer a UI guard, and record a thought-up scenario as a failing test rather than prose.
- [scope-test-runs](scope-test-runs.md) — Run only the test files a change touches; keep the full or module-wide suite for before a PR
