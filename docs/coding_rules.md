# Coding Standards & Practices

## File Organization

1. **One class/provider per file. No private declarations in `lib/`.**

   - No monolithic files with multiple providers or classes packed together.
   - No `_`-prefixed classes, methods (on any class, including Widget/State), top-level functions, or top-level constants in any package's `lib/` source. Encapsulation is enforced by the package barrel, not by Dart's `_` mechanism.
   - *Exception 1:* Riverpod provider declarations and their notifier classes may be kept together (e.g., `eventNotifierProvider` + `EventNotifier` in the same file) since they are tightly coupled.
   - *Exception 2:* A Riverpod notifier may keep `_`-prefixed instance fields for internal state that genuinely has no place in the public API (e.g., a mutex). When in doubt, make it public.

2. **Folder names indicate purpose** - No redundant suffixes in file names (e.g., files in `providers/` don't need `_provider` suffix, files in `widgets/` don't need `_widget` suffix).

3. **Correct folder for content type**:
   - `providers/` - Riverpod providers and notifiers only.
   - `builders/` - Widgets with builder callbacks that watch providers.
   - `widgets/` - Reusable UI components (StatelessWidget, StatefulWidget) and the per-domain shell.
   - `models/` - Typedefs, data classes, enums.
   - `screens/` - Per-route entry widgets. Watch `authStateProvider`, evaluate gates, render `AccessDeniedView` / `ErrorView` on failure, and wrap a same-named view from `views/`. Scaffold lives in the shell, not the screen.
   - `views/` - Presentational route bodies. Take `required UserPrivate currentUser` and navigation callbacks; never watch auth. Branch on `currentUser` state where needed and `assert(...)` their preconditions per the workspace `CLAUDE.md` "Views assert their preconditions" rule.
   - `utils/` - Utility functions and helpers.

4. **Meaningful naming** - File and class names should clearly reflect their purpose and content.

---

## Module Boundaries

5. **Barrel files export only external API** - Don't export everything; only symbols actually used outside the module.

6. **Keep implementation details internal** - Don't expose internal providers or helpers just for workarounds.

7. **Test/example data stays outside library** - Mock data generators, dummy data, and test utilities belong in test code or example apps, not in the library itself.

8. **Avoid leaky abstractions** - Handle caching, state management, and lifecycle internally rather than requiring external code to manage it.

---

## Code Patterns

9. **Avoid `_build*` method proliferation** - Convert private build methods to separate StatelessWidgets. Avoid having many methods in a widget that build parts of it.

10. **Use existing models directly** - Don't create redundant wrapper classes when existing models (e.g., SDK models) suffice.

11. **Avoid naming conflicts** - Prefix with context when a generic name might conflict with similar providers/classes in other modules.

---

## Separation of Concerns

12. **UI components in appropriate locations** - Settings belong in settings screens, not embedded in feature screens. Keep widgets focused on their primary responsibility.

---

## File Size Limits

13. **Maximum 400 lines per file** - Split into multiple files if exceeding this limit.

14. **Maximum 200 lines per widget** - Extract sub-widgets if a widget file exceeds 200 lines.

---

## Code Formatting

15. **Dart formatting** - Run `dart format` before every commit.

16. **Zero warnings** - `flutter_lints`. Zero warnings allowed.

17. **File naming** - `snake_case` for all Dart files.

18. **Import order** - core → Flutter → packages → project (relative within package).

19. **Documentation** - Public APIs must have `///` doc comments. No commented-out code.

20. **No magic values** - No magic numbers or strings. Define in a constants file or enum.

---

## Git & Workflow

21. **Commit message format** - `type: description` (e.g., `feat: add member groups`, `fix: enrollment race condition`, `test: attendance integration tests`).

22. **One logical change per commit** - Do not mix unrelated changes.

23. **PR reviews** - Every PR must be reviewed before merge.

24. **Branch strategy** - One branch per phase, merge to `main` only after phase completion and testing.
