# club_sdk task runner.
#
# Unit tests need nothing but dart. Integration tests run against a fresh,
# isolated club_server stack started by native_deploy's background_server.sh
# (expected on PATH). The stack is described by a conf in this repo:
# sdk_test.conf (optional modules off) or sdk_test_modules.conf (credits,
# evaluations, event marketing on). Each conf clones the server's main branch
# from git; override with SDK_CONF / SDK_MODULES_CONF.

SDK_CONF         := env_var_or_default('SDK_CONF', 'sdk_test.conf')
SDK_MODULES_CONF := env_var_or_default('SDK_MODULES_CONF', 'sdk_test_modules.conf')
SDK_TEST_TIMEOUT := "600"

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

# Internal: start a fresh stack from CONF, run `dart test <TARGET>` against
# it, and clean up on exit (unless `keep` is non-empty).
_run TARGET keep="" conf=SDK_CONF:
    #!/usr/bin/env bash
    set -euo pipefail
    json=$(background_server.sh {{conf}} start --auto-ports)
    base=$(printf '%s' "$json" | jq -r .base_url)
    port=$(printf '%s' "$json" | jq -r .server_port)
    db_port=$(printf '%s' "$json" | jq -r .db_port)
    if [ -n "{{keep}}" ]; then
        trap 'echo "==> keeping server $base (stop: just stop-test-server '"$port"' '"$db_port"' {{conf}})" >&2' EXIT
    else
        trap 'background_server.sh {{conf}} cleanup port='"$port"' db_port='"$db_port" EXIT
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

#   just test-modules                       # the module suites, modules on
#   just test-modules s11_credits_test.dart
# Run integration tests against a stack with the optional modules on.
[group('tests')]
test-modules FILE="" keep="": (_run ("test/integration/" + FILE) keep SDK_MODULES_CONF)

# Prints one JSON line (name, base_url, server_port, db_port, run_dir,
# tmux_session, server_log). Watch logs: tmux attach -t <tmux_session>
# Start a fresh isolated test server (postgres + API) in a tmux session.
[group('test server')]
start-test-server CONF=SDK_CONF:
    background_server.sh {{CONF}} start --auto-ports

# Pass the server_port and db_port that `start-test-server` printed.
# Stop an isolated test server and remove its run directory.
[group('test server')]
stop-test-server PORT DB_PORT CONF=SDK_CONF:
    background_server.sh {{CONF}} cleanup port={{PORT}} db_port={{DB_PORT}}
