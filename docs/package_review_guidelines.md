# Package Review Guidelines

A repeatable checklist for the **final review of a workspace package**, distilled from the `cl_member_onboarding` review (tracker: see umbrella tracker issue created for that review).

Use this when a package is "stable" enough to be audited end-to-end. Each step produces findings; findings either land in a single package-scoped tracker issue or, if workspace-wide, are filed as standalone issues and linked under an umbrella tracker.

## Inputs

Before starting, locate and skim:

- The package's `pubspec.yaml` and `lib/` tree.
- The package's `CLAUDE.md` (if absent, that itself is a finding).
- The workspace root `CLAUDE.md`.
- `docs/coding_rules.md` and `docs/dart-data-class.md`.
- The package's existing tests in `test/`, plus any related workflow tests in `app/integration_test/`.

## Outputs

- One **tracker issue** per reviewed package, titled `<package> final review: cleanup findings`. Numbered findings appended as the review progresses.
- **Standalone issues** for anything that is not package-local (workspace conventions, shared libraries, security gaps, cross-cutting refactors).
- An **umbrella tracker** issue that links every child issue as GitHub sub-issues (`POST /repos/<owner>/<repo>/issues/<umbrella>/sub_issues` with the child's internal id).

## The seven steps

Each step is an independent audit. Run them in order — later steps depend on context surfaced by earlier ones.

### 1. Dependencies vs actual usage

Goal: catch declared deps that are never imported.

```bash
python3 <<'PY'
import os, yaml
pkg = '<package>'
with open(f'{pkg}/pubspec.yaml') as f: data = yaml.safe_load(f)
deps = list((data.get('dependencies') or {}).keys())
SKIP = {'flutter','flutter_test','flutter_web_plugins','sdk'}
src = ''
for r in ['lib','bin','test','example']:
    d = f'{pkg}/{r}'
    if os.path.isdir(d):
        for root,_,fs in os.walk(d):
            for fn in fs:
                if fn.endswith('.dart'):
                    src += open(os.path.join(root,fn),errors='ignore').read()
for d in deps:
    if d in SKIP: continue
    if f'package:{d}/' not in src: print(d)
PY
```

For each unused dep, decide: drop, or keep (native-plugin activation deps like `media_kit_libs_video` have no Dart imports by design — note them in the package CLAUDE.md so a future reviewer doesn't re-flag).

### 2. Public API surface (barrel exports)

Rule: **a package's `lib/<package>.dart` exports Screens and Shells only.** Views, widgets, providers, and models stay internal. Re-export from the barrel only if a separate package needs the symbol.

```bash
# What does the barrel export?
sed -n '/^export /p' <package>/lib/<package>.dart

# For each exported symbol, who consumes it externally?
grep -rn '<SymbolName>' \
  app cl_club_* cl_member_* cl_remote_store cl_server_config ui_lib \
  --include='*.dart' | grep -v <package>
```

Anything exported but not consumed externally is a finding.

### 3. Coding standards (`docs/coding_rules.md`)

Run each check; record violations.

```bash
P=<package>/lib

# File sizes (rule 13: max 400 / rule 14: max 200 per widget)
find $P -name '*.dart' -exec wc -l {} + | sort -rn | head -10

# Private declarations anywhere in lib (rule 1)
grep -rEn '^\s*(class|abstract class|mixin|enum) _[A-Z]|^\s*(static\s+)?[A-Za-z<>?,\[\]\s]+\s+_[a-z]|^\s*final\s+[A-Za-z<>?,\[\]\s]+\s+_[A-Z]' $P --include='*.dart'

# snake_case (rule 17) — flag anything in CamelCase or kebab-case
find $P -name '*.dart' | grep -E '[A-Z]|-'

# Magic-number duplication (rule 20) — pick the suspects from review context
grep -rEn 'width < 600|maxWidth: 480|Duration\(milliseconds:' $P --include='*.dart'

# Missing /// docs on public symbols (rule 19)
grep -rEn '^class [A-Z]' $P --include='*.dart' | while read line; do
  f=$(echo "$line" | cut -d: -f1); n=$(echo "$line" | cut -d: -f2)
  prev=$((n-1)); h=$(sed -n "${prev}p" "$f")
  [[ "$h" =~ ^/// ]] || echo "$line  (no /// above)"
done
```

Folder conventions: each file should be in the right folder for its content type. Mixed `widgets/` + `views/` + `screens/` is OK; mismatches are findings.

### 4. Package `CLAUDE.md` vs current code

Read the package `CLAUDE.md` end-to-end. For each statement, verify against current code:

- Routes / shell / screens described **match what's mounted in `app/lib/router.dart`**.
- Allowed-dep list matches `pubspec.yaml` exactly.
- Forbidden-dep list still excludes what it should.
- Any "the X widget does Y" sentence — open X and confirm it still does Y.

A common drift pattern after refactors: package CLAUDE.md still describes the old architecture (e.g., "shell owns the gate" after the gate moved into screens). These are doc fixes, not code fixes.

### 5. Workspace `CLAUDE.md` rules

Walk the root `CLAUDE.md` section-by-section and verify the package complies. Common pitfalls:

| Rule | Check command |
|---|---|
| **No hardcoded routes** | `grep -rn 'context\.(go\|push\|pop)\\|GoRouter\.of\\|Navigator\.of' <pkg>/lib --include='*.dart'` |
| **SDK access boundary** | `grep -rn 'clientProvider\\|secureClientProvider' <pkg>/lib --include='*.dart'` (only `cl_remote_store` and `cl_member_auth` should match) |
| **Server config** | `grep -rn 'http\(s\)\?://' <pkg>/lib --include='*.dart'` (any hardcoded base URL is a finding) |
| **Auth boundary** | `grep -rn 'AuthSession\\|AuthSource' <pkg>/lib --include='*.dart'` (auth logic should live only in `cl_member_auth`) |
| **Color coding / chips** | `grep -rn 'Color(0x\\|Colors\.\\|backgroundColor:\\|ShadBadge' <pkg>/lib --include='*.dart'` |
| **Views own permission checks** | open each `views/` file, confirm role/status conditionals exist where the screen passed in a `currentUser` |

When a violation looks deeper than the current package (e.g., a security gap surfaced because `Image.network` can't authenticate), split into:

1. A package-local fix (in the tracker issue).
2. A workspace-level enabling issue (separate issue).
3. (If applicable) a server-side issue in `icehockey_mh_server`.

### 6. Test coverage

Apply the testing philosophy:

- **Workflow tests** in `app/integration_test/` cover the user-facing flows against a live server.
- **Widget tests** in `<pkg>/test/` confirm presence of specific widgets/items.
- **Unit tests** only for non-trivial logic (provider derivations, parsers, etc.).
- **Visual audit** via `<pkg>/example/`.

```bash
# What workflow tests touch this package's surface?
grep -lir '<feature-keyword>' app/integration_test/

# What's in the package's own test/?
find <pkg>/test -name '*_test.dart'

# Is the example app compiling?
cd <pkg>/example && flutter pub get && dart analyze
```

Findings:

- Missing workflow test → file in `app` (workflow naming per `app/CLAUDE.md`).
- Missing widget tests for surfaces that have branching UI → append to tracker.
- Missing unit tests for logic providers → append to tracker.
- Broken example app → standalone issue (it's a separate deliverable).

### 7. Package `CLAUDE.md` doc completeness

After steps 1–6 you know exactly what the package is. The package `CLAUDE.md` should reflect that. Verify it contains:

- **Intro** — one or two sentences naming the package's role.
- **Routes / public surface** — what the package exposes.
- **Internal structure** — short tree of `lib/src/<folder>/` with a one-line purpose per folder.
- **Allowed / forbidden dependencies.**
- **Pointers** to root `CLAUDE.md`, `docs/coding_rules.md`, `docs/dart-data-class.md` (the last with an "N/A — no domain models in this package" note if applicable).
- **Testing** — what's covered locally vs via `app/integration_test/`.
- **Example** — what it demonstrates and how to run it.

Each missing section is a finding.

## Priority labelling

After all findings are filed, label every issue. Customer-facing or security: `priority:high`. Robustness, missing coverage on a sensitive flow, in-flight refactors that unblock high-priority work: `priority:medium`. Cosmetic, doc, naming, workspace cleanups with no behavioral impact: `priority:low`.

## Umbrella tracker

Create one umbrella tracker per review. Body groups child issues by theme (package cleanup / workspace follow-ups / security / testing). Attach each child as a real GitHub sub-issue:

```bash
# Get the child's internal id (not the issue number)
gh api /repos/<owner>/<repo>/issues/<child-number> -q .id

# Attach
gh api -X POST /repos/<owner>/<repo>/issues/<umbrella>/sub_issues \
  -F sub_issue_id=<internal-id>
```

This makes progress visible in GitHub's sub-issue UI rather than just as a Markdown link list.

## When to stop

Stop adding findings when you have completed the seven steps. Further polish ideas should go to an issue without blocking review closure.

## Closing the review

The review is closed when:

1. Every finding is filed in either the tracker issue or a standalone issue.
2. Every standalone issue is linked as a sub-issue under the umbrella tracker.
3. Priority labels are applied on all of them.

The review itself does not block on **fixing** anything — that work is now tracked and scheduled normally.
