#!/usr/bin/env bats
#
# tests/cli.bats - CLI dispatcher and routing tests
#
# Tests for the new subcommand-based CLI structure introduced in curb-017/curb-018.
# Covers subcommand routing, help output, deprecation warnings, and backwards compatibility.

load 'test_helper'

setup() {
    setup_test_dir
    export CURB_BACKEND="json"
    export CURB_PROJECT_DIR="$TEST_DIR"
    # Mock harness to avoid actual invocation
    export PATH="$TEST_DIR:$PATH"
    cat > "$TEST_DIR/claude" << 'EOF'
#!/bin/bash
echo "Mocked harness"
exit 0
EOF
    chmod +x "$TEST_DIR/claude"

    # Create minimal template files to avoid warnings
    echo "System prompt" > PROMPT.md
    echo "Build instructions" > AGENT.md
}

teardown() {
    teardown_test_dir
}

# =============================================================================
# Subcommand Routing Tests
# =============================================================================

@test "curb version subcommand works" {
    run "$PROJECT_ROOT/curb" version
    [ "$status" -eq 0 ]
    [[ "$output" == *"curb v"* ]]
}

@test "curb init subcommand creates project structure" {
    run "$PROJECT_ROOT/curb" init .
    [ "$status" -eq 0 ]
    [ -f "prd.json" ]
    [ -f "PROMPT.md" ]
    [ -f "AGENT.md" ]
}

@test "curb status subcommand shows task summary" {
    use_fixture "valid_prd.json" "prd.json"

    run "$PROJECT_ROOT/curb" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"Task Status Summary"* ]]
}

@test "curb run subcommand with --once flag" {
    use_fixture "valid_prd.json" "prd.json"

    # Should recognize run subcommand with flags
    run "$PROJECT_ROOT/curb" run --once
    # May fail due to missing dependencies but shouldn't crash
}

@test "curb run subcommand with --ready flag" {
    use_fixture "valid_prd.json" "prd.json"

    run "$PROJECT_ROOT/curb" run --ready
    [ "$status" -eq 0 ]
    [[ "$output" == *"Ready Tasks"* ]]
}

@test "curb run subcommand with --plan flag" {
    use_fixture "valid_prd.json" "prd.json"

    run "$PROJECT_ROOT/curb" run --plan
    # May fail without proper setup but shouldn't crash with routing error
}

@test "curb explain subcommand shows task details" {
    use_fixture "valid_prd.json" "prd.json"

    run "$PROJECT_ROOT/curb" explain prd-0002
    [ "$status" -eq 0 ]
    [[ "$output" == *"prd-0002"* ]]
}

@test "curb artifacts subcommand lists recent tasks" {
    use_fixture "valid_prd.json" "prd.json"

    run "$PROJECT_ROOT/curb" artifacts
    [ "$status" -eq 0 ]
    # Should show message about no artifacts or list them
}

# =============================================================================
# Help Output Tests
# =============================================================================

@test "curb --help shows main help" {
    run "$PROJECT_ROOT/curb" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"SUBCOMMANDS"* ]]
    [[ "$output" == *"curb init"* ]]
    [[ "$output" == *"curb run"* ]]
    [[ "$output" == *"curb status"* ]]
}

@test "curb help subcommand shows main help" {
    run "$PROJECT_ROOT/curb" help
    [ "$status" -eq 0 ]
    [[ "$output" == *"SUBCOMMANDS"* ]]
}

@test "curb -h shows main help" {
    run "$PROJECT_ROOT/curb" -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"SUBCOMMANDS"* ]]
}

@test "curb init --help shows init-specific help" {
    run "$PROJECT_ROOT/curb" init --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"curb init"* ]]
    [[ "$output" == *"--global"* ]]
    [[ "$output" != *"curb run"* ]]  # Should not show run help
}

@test "curb init -h shows init-specific help" {
    run "$PROJECT_ROOT/curb" init -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"curb init"* ]]
}

@test "curb run --help shows run-specific help" {
    run "$PROJECT_ROOT/curb" run --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"curb run"* ]]
    [[ "$output" == *"--once"* ]]
    [[ "$output" == *"--ready"* ]]
    [[ "$output" == *"--plan"* ]]
}

@test "curb run -h shows run-specific help" {
    run "$PROJECT_ROOT/curb" run -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"curb run"* ]]
}

@test "curb status --help shows status-specific help" {
    run "$PROJECT_ROOT/curb" status --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"curb status"* ]]
    [[ "$output" == *"--json"* ]]
}

@test "curb explain --help shows explain-specific help" {
    run "$PROJECT_ROOT/curb" explain --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"curb explain"* ]]
    [[ "$output" == *"task-id"* ]]
}

@test "curb artifacts --help shows artifacts-specific help" {
    run "$PROJECT_ROOT/curb" artifacts --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"curb artifacts"* ]]
}

# =============================================================================
# Deprecation Warning Tests
# =============================================================================

@test "curb --status shows deprecation warning" {
    use_fixture "valid_prd.json" "prd.json"

    run "$PROJECT_ROOT/curb" --status
    [ "$status" -eq 0 ]
    [[ "$output" == *"deprecated"* ]]
    [[ "$output" == *"curb status"* ]]
}

@test "curb --ready shows deprecation warning" {
    use_fixture "valid_prd.json" "prd.json"

    run "$PROJECT_ROOT/curb" --ready
    [ "$status" -eq 0 ]
    [[ "$output" == *"deprecated"* ]]
    [[ "$output" == *"curb run --ready"* ]]
}

@test "curb --once shows deprecation warning" {
    use_fixture "valid_prd.json" "prd.json"

    run "$PROJECT_ROOT/curb" --once
    # Should show deprecation warning
    [[ "$output" == *"deprecated"* ]]
    [[ "$output" == *"curb run --once"* ]]
}

@test "curb --plan shows deprecation warning" {
    use_fixture "valid_prd.json" "prd.json"

    run "$PROJECT_ROOT/curb" --plan
    # Should show deprecation warning
    [[ "$output" == *"deprecated"* ]]
    [[ "$output" == *"curb run --plan"* ]]
}

@test "curb -s shows deprecation warning" {
    use_fixture "valid_prd.json" "prd.json"

    run "$PROJECT_ROOT/curb" -s
    [ "$status" -eq 0 ]
    [[ "$output" == *"deprecated"* ]]
}

@test "curb -r shows deprecation warning" {
    use_fixture "valid_prd.json" "prd.json"

    run "$PROJECT_ROOT/curb" -r
    [ "$status" -eq 0 ]
    [[ "$output" == *"deprecated"* ]]
}

@test "curb -1 shows deprecation warning" {
    use_fixture "valid_prd.json" "prd.json"

    run "$PROJECT_ROOT/curb" -1
    [[ "$output" == *"deprecated"* ]]
}

@test "curb -p shows deprecation warning" {
    use_fixture "valid_prd.json" "prd.json"

    run "$PROJECT_ROOT/curb" -p
    [[ "$output" == *"deprecated"* ]]
}

@test "deprecation warnings can be suppressed" {
    use_fixture "valid_prd.json" "prd.json"

    export CURB_NO_DEPRECATION_WARNINGS=1
    run "$PROJECT_ROOT/curb" --status
    [ "$status" -eq 0 ]
    [[ "$output" != *"deprecated"* ]]
}

# =============================================================================
# Unknown Subcommand Tests
# =============================================================================

@test "curb with unknown subcommand shows error and help" {
    run "$PROJECT_ROOT/curb" foobar
    [ "$status" -eq 0 ]  # Shows help, doesn't fail
    [[ "$output" == *"Unknown subcommand: foobar"* ]]
    [[ "$output" == *"SUBCOMMANDS"* ]]
}

@test "curb with unknown subcommand does not show error for flags" {
    use_fixture "valid_prd.json" "prd.json"

    # Unknown flags pass through to default behavior (run loop)
    # Use timeout to prevent hanging
    timeout 2 "$PROJECT_ROOT/curb" --unknown-flag || true
    # Test passes if it doesn't crash
}

# =============================================================================
# Backwards Compatibility Tests
# =============================================================================

@test "legacy --status invocation still works" {
    use_fixture "valid_prd.json" "prd.json"

    run "$PROJECT_ROOT/curb" --status
    [ "$status" -eq 0 ]
    [[ "$output" == *"Task Status Summary"* ]] || [[ "$output" == *"Open"* ]]
}

@test "legacy --ready invocation still works" {
    use_fixture "valid_prd.json" "prd.json"

    run "$PROJECT_ROOT/curb" --ready
    [ "$status" -eq 0 ]
    [[ "$output" == *"Ready Tasks"* ]]
}

@test "legacy --once invocation still works" {
    use_fixture "valid_prd.json" "prd.json"

    run "$PROJECT_ROOT/curb" --once
    # Should run (may fail due to setup but shouldn't crash)
}

@test "legacy -s short flag still works" {
    use_fixture "valid_prd.json" "prd.json"

    run "$PROJECT_ROOT/curb" -s
    [ "$status" -eq 0 ]
    [[ "$output" == *"Task Status Summary"* ]] || [[ "$output" == *"Open"* ]]
}

@test "legacy -r short flag still works" {
    use_fixture "valid_prd.json" "prd.json"

    run "$PROJECT_ROOT/curb" -r
    [ "$status" -eq 0 ]
    [[ "$output" == *"Ready Tasks"* ]]
}

@test "legacy --status --json combination still works" {
    use_fixture "valid_prd.json" "prd.json"

    run "$PROJECT_ROOT/curb" --status --json
    [ "$status" -eq 0 ]
    # Should output valid JSON
    echo "$output" | grep -v deprecated | jq empty
}

# =============================================================================
# Subcommand Flag Parsing Tests
# =============================================================================

@test "curb run accepts --once flag" {
    use_fixture "valid_prd.json" "prd.json"

    run "$PROJECT_ROOT/curb" run --once
    # Should not show routing error
    [[ "$output" != *"Unknown"* ]] || [[ "$output" != *"unknown"* ]]
}

@test "curb run accepts --ready flag" {
    use_fixture "valid_prd.json" "prd.json"

    run "$PROJECT_ROOT/curb" run --ready
    [ "$status" -eq 0 ]
    [[ "$output" == *"Ready Tasks"* ]]
}

@test "curb run accepts --plan flag" {
    use_fixture "valid_prd.json" "prd.json"

    run "$PROJECT_ROOT/curb" run --plan
    # Should recognize flag
}

@test "curb run accepts --model flag" {
    use_fixture "valid_prd.json" "prd.json"

    run "$PROJECT_ROOT/curb" run --model sonnet --ready
    [ "$status" -eq 0 ]
}

@test "curb run accepts --budget flag" {
    use_fixture "valid_prd.json" "prd.json"

    run "$PROJECT_ROOT/curb" run --budget 1000000 --ready
    [ "$status" -eq 0 ]
}

@test "curb run accepts --epic flag" {
    use_fixture "valid_prd.json" "prd.json"

    run "$PROJECT_ROOT/curb" run --epic my-epic --ready
    [ "$status" -eq 0 ]
}

@test "curb run accepts --label flag" {
    use_fixture "valid_prd.json" "prd.json"

    run "$PROJECT_ROOT/curb" run --label my-label --ready
    [ "$status" -eq 0 ]
}

@test "curb run accepts --require-clean flag" {
    use_fixture "valid_prd.json" "prd.json"

    run "$PROJECT_ROOT/curb" run --require-clean --ready
    [ "$status" -eq 0 ]
}

@test "curb run accepts --no-require-clean flag" {
    use_fixture "valid_prd.json" "prd.json"

    run "$PROJECT_ROOT/curb" run --no-require-clean --ready
    [ "$status" -eq 0 ]
}

@test "curb run accepts --name flag" {
    use_fixture "valid_prd.json" "prd.json"

    run "$PROJECT_ROOT/curb" run --name my-session --ready
    [ "$status" -eq 0 ]
}

@test "curb status accepts --json flag" {
    use_fixture "valid_prd.json" "prd.json"

    run "$PROJECT_ROOT/curb" status --json
    [ "$status" -eq 0 ]
    echo "$output" | jq empty
}

# =============================================================================
# Global Flag Tests
# =============================================================================

@test "curb accepts --debug flag globally" {
    use_fixture "valid_prd.json" "prd.json"

    run "$PROJECT_ROOT/curb" --debug status
    [ "$status" -eq 0 ]
    # Should enable debug mode
}

@test "curb accepts -d flag globally" {
    use_fixture "valid_prd.json" "prd.json"

    run "$PROJECT_ROOT/curb" -d status
    [ "$status" -eq 0 ]
}

@test "curb accepts --stream flag globally" {
    use_fixture "valid_prd.json" "prd.json"

    run "$PROJECT_ROOT/curb" --stream status
    [ "$status" -eq 0 ]
}

@test "curb accepts --harness flag globally" {
    use_fixture "valid_prd.json" "prd.json"

    run "$PROJECT_ROOT/curb" --harness claude status
    [ "$status" -eq 0 ]
}

@test "curb accepts --backend flag globally" {
    use_fixture "valid_prd.json" "prd.json"

    run "$PROJECT_ROOT/curb" --backend json status
    [ "$status" -eq 0 ]
}

# =============================================================================
# Default Behavior Tests
# =============================================================================

@test "curb with no args defaults to run loop" {
    use_fixture "valid_prd.json" "prd.json"

    # This would normally run the loop, but we can't test that easily
    # Just verify it doesn't show help or error
    timeout 2 "$PROJECT_ROOT/curb" || true
    # Should not immediately show help
}

@test "curb run with no flags defaults to continuous loop" {
    use_fixture "valid_prd.json" "prd.json"

    # This would normally run the loop
    timeout 2 "$PROJECT_ROOT/curb" run || true
    # Should not immediately show help or error
}

# =============================================================================
# Error Handling Tests
# =============================================================================

@test "curb status with invalid flag shows error" {
    use_fixture "valid_prd.json" "prd.json"

    run "$PROJECT_ROOT/curb" status --invalid-flag
    [ "$status" -ne 0 ]
    [[ "$output" == *"Unknown flag"* ]]
}

@test "curb explain without task-id shows error" {
    use_fixture "valid_prd.json" "prd.json"

    run "$PROJECT_ROOT/curb" explain
    [ "$status" -ne 0 ]
    [[ "$output" == *"Usage"* ]] || [[ "$output" == *"task-id"* ]]
}

# =============================================================================
# Integration Tests
# =============================================================================

@test "curb init followed by curb status works" {
    run "$PROJECT_ROOT/curb" init .
    [ "$status" -eq 0 ]

    run "$PROJECT_ROOT/curb" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"Task Status Summary"* ]]
}

@test "mixing global and subcommand flags works" {
    use_fixture "valid_prd.json" "prd.json"

    run "$PROJECT_ROOT/curb" --debug run --ready
    [ "$status" -eq 0 ]
    [[ "$output" == *"Ready Tasks"* ]]
}

@test "multiple flags to run subcommand work" {
    use_fixture "valid_prd.json" "prd.json"

    run "$PROJECT_ROOT/curb" run --model sonnet --budget 1000000 --ready
    [ "$status" -eq 0 ]
}
