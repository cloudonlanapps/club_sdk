# club_sdk task runner.
#
# Unit tests need nothing but dart. Integration tests run against a fresh,
# isolated club_server stack started by native_deploy's background_server.sh.
# native_deploy is cloned from git into .native_deploy/ (gitignored), pulled on
# every run and run from there, so the stacks' run directories
# (.native_deploy/deployed/) stay inside this checkout too. The stack is
# described by a conf in this repo, one of the two stacks club_client tests on
# (#86):
#   sdk_test_server1.conf          identity verification, the extended profile and
#                          applications on; credits, evaluations and event
#                          marketing off
#   sdk_test_server2.conf  credits, evaluations and event marketing on;
#                          identity verification, the extended profile and
#                          applications off
# Every integration file runs on both: a case that needs a feature skips on
# the stack without it, and the feature-off cases (503, verification off)
# run there. Each conf clones the server's main branch from git; override
# with SDK_SERVER1_CONF / SDK_SERVER2_CONF.

SDK_SERVER1_CONF := env_var_or_default('SDK_SERVER1_CONF', 'sdk_test_server1.conf')
SDK_SERVER2_CONF := env_var_or_default('SDK_SERVER2_CONF', 'sdk_test_server2.conf')
SDK_TEST_TIMEOUT := "600"
NATIVE_DEPLOY_URL := env_var_or_default('NATIVE_DEPLOY_URL', 'https://github.com/cloudonlanapps/native_deploy.git')
NATIVE_DEPLOY_REF := env_var_or_default('NATIVE_DEPLOY_REF', 'main')
NATIVE_DEPLOY_DIR := justfile_directory() / ".native_deploy"
BACKGROUND_SERVER := NATIVE_DEPLOY_DIR / "background_server.sh"

default:
    @just --list

# Run the unit tests (no server required).
[group('tests')]
unit-test:
    dart test test/unit/ -j 1 --timeout=60s

# Analyze and check formatting.
[group('tests')]
lint:
    dart analyze
    dart format --output=none --set-exit-if-changed lib test

# Internal: clone native_deploy into .native_deploy/ on first use, then bring
# it to NATIVE_DEPLOY_REF (a branch is taken at its remote head, so every run
# pulls). Says what it did on stderr only: start-test-server's stdout is its
# JSON.
_native-deploy:
    #!/usr/bin/env bash
    set -euo pipefail
    dir="{{NATIVE_DEPLOY_DIR}}"
    if [ ! -d "$dir/.git" ]; then
        # Clone beside the target and rename, so concurrent runs never see a
        # half-written clone; the loser of the rename drops its copy.
        tmp=$(mktemp -d "$dir.XXXXXX")
        trap 'rm -rf "$tmp"' EXIT
        echo "==> cloning {{NATIVE_DEPLOY_URL}} into $dir" >&2
        git clone --quiet "{{NATIVE_DEPLOY_URL}}" "$tmp/clone" >&2
        mv -T "$tmp/clone" "$dir" 2>/dev/null || [ -d "$dir/.git" ]
    fi
    git -C "$dir" remote set-url origin "{{NATIVE_DEPLOY_URL}}"
    git -C "$dir" fetch --quiet --prune origin >&2
    want=$(git -C "$dir" rev-parse --verify --quiet "origin/{{NATIVE_DEPLOY_REF}}^{commit}") \
        || want=$(git -C "$dir" rev-parse --verify "{{NATIVE_DEPLOY_REF}}^{commit}")
    if [ "$(git -C "$dir" rev-parse HEAD)" != "$want" ]; then
        git -C "$dir" checkout --quiet --detach "$want" >&2
        echo "==> native_deploy at $(git -C "$dir" rev-parse --short HEAD) ({{NATIVE_DEPLOY_REF}})" >&2
    fi
    [ -x "{{BACKGROUND_SERVER}}" ] || { echo "ERROR: {{BACKGROUND_SERVER}} is missing." >&2; exit 1; }

# Internal: start a fresh stack from CONF, run `dart test <TARGET>` against
# it, and clean up on exit (unless `keep` is non-empty).
_run TARGET keep="" conf=SDK_SERVER1_CONF: _native-deploy
    #!/usr/bin/env bash
    set -euo pipefail
    json=$("{{BACKGROUND_SERVER}}" {{conf}} start --auto-ports)
    base=$(printf '%s' "$json" | jq -r .base_url)
    port=$(printf '%s' "$json" | jq -r .server_port)
    db_port=$(printf '%s' "$json" | jq -r .db_port)
    if [ -n "{{keep}}" ]; then
        trap 'echo "==> keeping server $base (stop: just stop-test-server '"$port"' '"$db_port"' {{conf}})" >&2' EXIT
    else
        trap '"{{BACKGROUND_SERVER}}" {{conf}} cleanup port='"$port"' db_port='"$db_port" EXIT
    fi
    echo "==> SDK integration tests against $base ({{conf}})"
    MYCLUB_API_BASE_URL="$base" \
    MYCLUB_SUDO_USERNAME=sudo \
    MYCLUB_SUDO_PASSWORD=testboot \
    dart test {{TARGET}} -j 1 --timeout={{SDK_TEST_TIMEOUT}}s

#   just test            # run, then auto-teardown
#   just test keep=1     # leave the server up for debugging
# Run the integration suite against a fresh isolated server.
[group('tests')]
test keep="": (_run "test/integration/" keep)

#   just test-one s23_broadcasts_test.dart [keep=1]
# Run one integration test file against a fresh isolated server.
[group('tests')]
test-one FILE keep="": (_run ("test/integration/" + FILE) keep)

#   just test-server2                       # the WHOLE suite on server2
#   just test-server2 issue_14_credits_test.dart
# With no FILE this runs every integration file, not only the module ones:
# every suite runs on both stacks, each case on the one with its features
# (e.g. credit-gated enrolment, sign-up with verification off), so a server2
# run is a full second pass. The suites of its modules are issue_14_credits,
# issue_15_evaluations, issue_22_public_catalogue, issue_33_credit_rules,
# issue_54_evaluation_lifecycle and issue_57_restore_renames; the extended
# profile and application suites (issue_66_*, issue_69, issue_72, issue_76,
# issue_77, issue_81) belong to `just test`. Run one by name.
# Run the whole integration suite (or FILE) on sdk_test_server2.conf.
[group('tests')]
test-server2 FILE="" keep="": (_run ("test/integration/" + FILE) keep SDK_SERVER2_CONF)

# Prints one JSON line (name, base_url, server_port, db_port, run_dir,
# tmux_session, server_log). Watch logs: tmux attach -t <tmux_session>
# Start a fresh isolated test server (postgres + API) in a tmux session.
[group('test server')]
start-test-server CONF=SDK_SERVER1_CONF: _native-deploy
    "{{BACKGROUND_SERVER}}" {{CONF}} start --auto-ports

# Pass the server_port and db_port that `start-test-server` printed.
# Stop an isolated test server and remove its run directory.
[group('test server')]
stop-test-server PORT DB_PORT CONF=SDK_SERVER1_CONF: _native-deploy
    "{{BACKGROUND_SERVER}}" {{CONF}} cleanup port={{PORT}} db_port={{DB_PORT}}
