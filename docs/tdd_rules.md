# Test-Driven Development

Every change to this package is test-driven: the test is written first, fails
for the right reason, and then the code is written to make it pass. A bug fix
starts with a test that reproduces the bug.

Tests use [`package:test`](https://pub.dev/packages/test) and follow the usual
Dart conventions. This file records the conventions specific to this package.
`CLAUDE.md` ("Integration Test Guidelines") covers how the integration stack is
started.

## Layout

```
test/
  unit/            # no server
    models/        # one file per model in lib/sdk/models/
    sources/       # Remote*Source request/response, via MockClient
    endpoints/     # endpoint wrappers, via MockClient
    http/          # error mapping
    utils/         # one file per helper in lib/sdk/utils/
  integration/     # against a real club_server stack
  utils/           # shared test helpers (not tests)
```

- Test files end in `_test.dart` and are named after the file they test:
  `lib/sdk/models/venue.dart` → `test/unit/models/venue_test.dart`.
- Integration files are named by scope:
    - `sNN_<area>_test.dart` for an API area (`s09_enrollments_test.dart`)
    - `workflow_<name>_test.dart` for an end-to-end user flow
    - `issue_<n>_<topic>_test.dart` / `bug_<n>_<topic>_test.dart` for work
      driven by an issue
- Helpers in `test/utils/` are libraries, not tests, and never end in
  `_test.dart`.

## Writing tests

- Use `group` for the unit under test (a class, a method or a requirement) and
  `test` for one behaviour. Each description is a plain sentence that reads on
  from the group:
  `group('Venue', …)` → `test('fromMap handles null address', …)`.
- One behaviour per `test`. Do not group several requirements into one test,
  so a failure names the requirement that broke.
- When a test covers an issue or a numbered case, put the reference first:
  `test('Issue 30: a coach may read the counts', …)`,
  `group('10.18: Pre-occurrence attendance gate', …)`.
- Every step is followed by an `expect`. After a mutation (create, update,
  delete, enroll, mark …), read the state back and assert it.
- Use specific matchers: `expect(e.status, EnrollmentStatus.accepted)` rather
  than `isNotNull`. For failures, use `throwsA(isA<ServerException>())` or the
  specific `SdkException` subclass, never `throwsA(anything)`.
- A new `*Source` method is added to the interface first, and its `Remote*`
  implementation throws `UnimplementedError` until the test is in place.

## Which layer to test at

| Change | Test |
|---|---|
| Model | Unit: `fromMap`/`toMap` round-trip, parsing a realistic server payload (including `null` and missing optional fields), `copyWith` (including clearing a nullable field through `ValueGetter`), `==`/`hashCode`, and enum wire values in both directions |
| `Remote*Source` / endpoint | Unit, with `MockClient` from `package:http/testing.dart`: the method, path, query and body the SDK sends, and how it parses the response and errors. Plus an integration test that the server accepts the request and the outcome is right |
| Helper in `lib/sdk/utils/` | Unit. If it mirrors a server rule (e.g. the action gates), also an integration test that the server enforces the same rule |
| Business rule | Both paths: success, and failure with the mapped exception |

## Integration tests

- Run them with `just test`, `just test-one <file>` or `just test-modules`. Each
  run starts its own server and stops it afterwards. Never run them against a
  shared server.
- Each file is self-contained and must pass on its own with `just test-one`.
  It creates what it needs in `setUpAll` and does not depend on other files or
  on run order.
- New files do not use `createTestClient()` or `seed()`. Create a bare client
  with `createRemoteSecureClient(baseUrl: baseUrl)`, call `clearTestArtifacts`,
  then create only the entities the file needs. Some older files still seed
  globally; move them off it when you next change them.
- Prefix test data with `testPrefix` so `clearTestArtifacts` can remove it.
- Create one client per role (`adminClient`, `coachClient`, `memberClient`) in
  `setUpAll`, and check `getCurrentUser()` after logging in.
- For a change that more than one role can see, verify it from each role's
  side: the admin's list and the member's view.
- Test each operation for every role that can reach it, covering both the
  allowed and the forbidden cases.
- The optional modules (credits, evaluations, marketing) run against both
  stacks. Use `module_gate.dart`: assert the 503 when a module is off and the
  behaviour when it is on.
- Delete lifecycles follow `CLAUDE.md`: soft-delete before hard-delete, and
  check both the active and the deleted listings.

## Before opening a PR

- `just unit-test`, `just test` and `just lint` pass.
- Break each new test once on purpose (change the expected value) and see it
  fail. A test that cannot fail is not a test.
- A `skip:` names an open issue (`skip: 'club_server#293 — Messaging API not
  implemented'`). If the server turns out not to enforce an expected rule, skip
  the test with an issue reference rather than changing the assertion to match
  what the server does.
- Nothing names a real club or product: examples use `api.myexampleclub.com`
  and env vars use `MYCLUB_*`. This repository is public.
