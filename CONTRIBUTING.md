# Contributing to club_sdk

This project is **stable**. To keep it that way, all changes must be tracked through GitHub Issues. There are no exceptions — even small fixes get an issue.

## The golden rule

> **No code change without an issue. No merge without a PR linked to that issue.**

This applies to bugs, features, refactors, docs, dependency bumps, test changes — everything.

**Exception:** Edits to `CLAUDE.md`, to `CONTRIBUTING.md`, or to files in `docs/` do not require an issue. These are process / config / documentation files, not product code — commit directly to `main`.

---

## Workflow

```
1. Open issue (bug / feature / task)
   ↓
2. Triage: scope it, and give it a priority
   ↓
3. Create branch from main
   ↓
4. Implement + test locally (test first)
   ↓
5. Open PR linked to the issue ("Fixes #N")
   ↓
6. Review → merge to main
```

**Testing locally (step 4):** the `justfile` is the task runner (`just --list` for the menu). Every change is test-driven: write the failing test first (see [`docs/tdd_rules.md`](docs/tdd_rules.md)).

```bash
just lint                         # dart analyze + format check
just unit-test                    # unit tests, no server
just test-one <file>              # one integration file, e.g. s23_broadcasts_test.dart
just test                         # the whole integration suite
just test-modules [<file>]        # the same with credits, evaluations and marketing on
```

Each integration recipe starts its own isolated club_server stack and tears it down on exit, so runs never collide. Pass `keep=1` to leave the server up for debugging. Details are in [`CLAUDE.md`](CLAUDE.md) ("Integration Test Guidelines").

## 1. Open an issue

Open an issue at <https://github.com/cloudonlanapps/club_sdk/issues/new>. Say which kind it is:

| Kind | When to use |
|---|---|
| **Bug** | Something is broken or behaving incorrectly |
| **Feature** | New capability or enhancement |
| **Task** | Refactor, docs, tooling, dependency bump, tests |

When the change follows a club_server change, link the server issue (`club_server#N`).

## 2. Triage

Triage means:

1. Verify it is reproducible / well-scoped
2. Decide its priority. **Priority and order of work are not GitHub labels**:
   they are tracked outside GitHub. SDK work is high priority, and a task that
   must wait for another names it.
3. Move its status label to `status:ready` once the scope is agreed (see
   [Labels](#labels))
4. Optionally assign to a person

### Labels

This section is the single source for labels on this repo.

**Status — required.** Every open issue carries exactly one `status:*` label.
Closed issues carry **none**: closing is the terminal state, so the label is
removed at close, not replaced (there is no `status:done`).

| From | To | When |
|---|---|---|
| (none) | `status:triage` | When the issue is filed |
| `status:triage` | `status:ready` | Triage done; scope agreed |
| `status:ready` | `status:in-progress` | The feature branch is created and work starts |
| `status:in-progress` | `status:blocked` | Waiting on an external dependency or decision (often a club_server change) |
| `status:in-progress` | `status:needs-info` | Waiting on the reporter or user for an answer |
| `status:blocked` / `status:needs-info` | `status:in-progress` | Unblocked; work resumed |
| any open `status:*` | `status:deferred` | Parked for an unknown future; the issue stays **open** |
| `status:deferred` | `status:triage` / `status:ready` | Picked up again |
| any `status:*` | (removed) | The PR merges and closes the issue, or the issue is closed by hand |

Change a status by removing the old label and adding the new one in one call:

```bash
gh issue edit N --remove-label "status:ready" --add-label "status:in-progress"
gh issue edit N --remove-label "status:in-progress"   # after the merge closes N
```

**Deferring is not closing.** `status:deferred` parks an issue nobody plans to
work on yet. It stays open, keeps its history, and is listed with
`gh issue list --label status:deferred`. Leave a comment saying why it was
deferred. Close it only when it is done, or when it is dropped on purpose.

**Kind — optional.** `bug`, `enhancement`, `documentation` and the other
GitHub defaults say what kind of change an issue is. Use them when they help;
nothing depends on them.

**Priority — not a label.** Priority and order of work are tracked outside
GitHub (step 2 above).

## 3. Branch naming

Branches must include the issue number:

```
<type>/<issue-number>-<short-slug>
```

Examples:

```
bug/42-token-refresh-loop
feature/57-credit-statement
task/61-bump-http
```

Always branch **from `main`**. Do the work in a git worktree, not the main checkout. When work splits into several PRs, stack them: base each branch on the previous one, point each PR at the previous branch, and merge bottom-up.

## 4. Commits

- Write commits in the imperative mood: *"fix token refresh"*, not *"fixed token refresh"*
- Reference the issue in the body when context helps: `Refs #42`
- Keep commits focused; squash trivial fixups before opening the PR

## 5. Pull requests

- **Title:** clear, < 70 characters
- **Body:** must include `Fixes #N` (or `Closes #N` / `Refs #N`) so GitHub auto-links and auto-closes
- **Target branch:** `main` (or the previous branch of a stack)
- **One issue per PR** when possible. Bundling is OK only if issues are tightly related.
- `just lint`, `just unit-test` and the integration files the change touches must pass before merge; run the full `just test` (and `just test-modules` when a module is involved) before the PR
- At least one human review for non-trivial changes

## 6. Merging

- Merge to `main` is human-gated — no auto-merge
- **Default: squash merge.** `gh pr merge <num> --squash`. Only the PR's own diff lands, as one commit.
- **Use `--rebase` only for an intentional, individually-meaningful commit series.** Default to squash unless you specifically curated the commits and want each preserved on `main`.
- **Never `--merge`.** The repo setting blocks merge commits.
- **Do not delete the feature branch on merge.** Branches stay on the remote so the PR's commits remain reachable for archaeology.
- Never push directly to `main`
- **This package is not tagged.** Release tags are cut in club_server and club_client only. Consumers (club_client's packages) take the SDK as a git dependency pinned by SHA, so a merge reaches them only when they bump the `ref:`.

## 7. Closing issues

- An issue is closed automatically when a PR with `Fixes #N` is merged; then remove its `status:*` label (see [Labels](#labels))
- If an issue is invalid or won't be done, close it with a comment explaining why, remove its `status:*` label, and apply `wontfix` if appropriate

---

## Working with Claude Code

This repo uses [Claude Code](https://claude.com/claude-code) locally as part of the development workflow. Claude is invoked from a developer's terminal and uses the `gh` CLI to interact with issues and pull requests.

A typical Claude-assisted session looks like:

```
You: "implement issue #42"
Claude:
  → gh issue view 42
  → creates a worktree on branch bug/42-...
  → writes a failing test, then the fix; runs the tests
  → commits
  → confirms with you
  → pushes branch
  → gh pr create --title ... --body "Fixes #42"
```

Conventions Claude must follow on this repo:

1. **Always work from an issue.** If asked to make a change without an issue, Claude should propose creating one first.
2. **Always branch from `main`**, in a worktree.
3. **Never push, open PRs, or merge without explicit user confirmation.**
4. **Always link PRs to their issue** with `Fixes #N` in the PR body.
