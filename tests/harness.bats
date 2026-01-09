#!/usr/bin/env bats
#
# tests/harness.bats - Tests for lib/harness.sh
#

load 'test_helper'

setup() {
    setup_test_dir

    # Reset harness cache
    export _HARNESS=""
    unset HARNESS
    unset CLAUDE_FLAGS
    unset CODEX_FLAGS

    # Source the library under test
    source "$LIB_DIR/harness.sh"
}

teardown() {
    teardown_test_dir
}

# =============================================================================
# Harness Detection Tests
# =============================================================================

@test "harness_detect respects explicit HARNESS setting" {
    export HARNESS="codex"
    run harness_detect
    [ "$status" -eq 0 ]
    [ "$output" = "codex" ]
}

@test "harness_detect ignores HARNESS=auto" {
    export HARNESS="auto"
    run harness_detect
    # Should fall through to auto-detection
    [ "$status" -eq 0 ]
    # Output will be whatever is installed (claude, codex, or empty)
}

@test "harness_get caches detected harness" {
    _HARNESS="claude"
    run harness_get
    [ "$output" = "claude" ]
}

# =============================================================================
# Harness Availability Tests
# =============================================================================

@test "harness_available returns true when specified harness exists" {
    # Test with a command we know exists
    run harness_available "bash"
    [ "$status" -eq 0 ]
}

@test "harness_available returns false when specified harness missing" {
    run harness_available "nonexistent_harness_xyz"
    [ "$status" -ne 0 ]
}

# =============================================================================
# Harness Version Tests
# =============================================================================

@test "harness_version returns value for installed harness" {
    # If claude or codex is installed, version should return something
    # If neither is installed, it returns "no harness"
    run harness_version
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

# =============================================================================
# Claude Stream Parsing Tests
# =============================================================================

@test "claude_parse_stream extracts text from assistant message" {
    local json='{"type":"assistant","message":{"content":[{"type":"text","text":"Hello world"}]}}'
    result=$(echo "$json" | claude_parse_stream)
    [[ "$result" == *"Hello world"* ]]
}

@test "claude_parse_stream handles content_block_delta text" {
    local json='{"type":"content_block_delta","delta":{"type":"text_delta","text":"streaming text"}}'
    result=$(echo "$json" | claude_parse_stream)
    [[ "$result" == *"streaming text"* ]]
}

@test "claude_parse_stream skips empty lines gracefully" {
    result=$(echo "" | claude_parse_stream)
    [ -z "$result" ]
}

@test "claude_parse_stream handles result messages" {
    local json='{"type":"result","result":"Task completed successfully","cost_usd":"0.05"}'
    result=$(echo "$json" | claude_parse_stream)
    [[ "$result" == *"Result"* ]] || [[ "$result" == *"Task completed"* ]]
}

@test "claude_parse_stream shows tool use in content_block_start" {
    local json='{"type":"content_block_start","content_block":{"type":"tool_use","name":"Read"}}'
    result=$(echo "$json" | claude_parse_stream)
    [[ "$result" == *"Read"* ]]
}

# =============================================================================
# Harness Invoke Tests
# =============================================================================

@test "harness_invoke dispatches to correct harness" {
    # Set harness explicitly to a value
    _HARNESS="nonexistent"
    # Since nonexistent harness doesn't match claude or codex case,
    # it should hit the error case
    run harness_invoke "system prompt" "task prompt"
    [ "$status" -ne 0 ]
    [[ "$output" == *"No harness available"* ]]
}

@test "harness_invoke_streaming fails gracefully for unknown harness" {
    _HARNESS="unknown"
    run harness_invoke_streaming "system prompt" "task prompt"
    [ "$status" -ne 0 ]
    [[ "$output" == *"No harness available"* ]]
}

# =============================================================================
# Flag Handling Tests
# =============================================================================

@test "CLAUDE_FLAGS environment variable is accessible" {
    export CLAUDE_FLAGS="--max-turns 5"
    [ "$CLAUDE_FLAGS" = "--max-turns 5" ]
}

@test "CODEX_FLAGS environment variable is accessible" {
    export CODEX_FLAGS="--model gpt-4"
    [ "$CODEX_FLAGS" = "--model gpt-4" ]
}

# =============================================================================
# Integration Tests (only run if harness installed)
# =============================================================================

@test "harness_detect finds claude when installed" {
    if ! command -v claude >/dev/null 2>&1; then
        skip "claude not installed"
    fi
    unset HARNESS
    _HARNESS=""
    run harness_detect
    [ "$output" = "claude" ]
}

@test "harness_available returns true for any installed harness" {
    run harness_available
    # Should succeed if either claude or codex is installed
    if command -v claude >/dev/null 2>&1 || command -v codex >/dev/null 2>&1; then
        [ "$status" -eq 0 ]
    else
        [ "$status" -ne 0 ]
    fi
}
