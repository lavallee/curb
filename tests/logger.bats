#!/usr/bin/env bats

# Test suite for lib/logger.sh

# Load the test helper
load test_helper

# Setup function runs before each test
setup() {
    # Source the logger library
    source "${PROJECT_ROOT}/lib/logger.sh"

    # Create temp directory for test logs
    TEST_LOGS_DIR="${BATS_TMPDIR}/logs_test_$$"
    mkdir -p "$TEST_LOGS_DIR"

    # Override curb_logs_dir to use test directory
    curb_logs_dir() {
        echo "$TEST_LOGS_DIR"
    }

    # Clear logger state before each test
    logger_clear
}

# Teardown function runs after each test
teardown() {
    # Clean up test directories
    rm -rf "$TEST_LOGS_DIR" 2>/dev/null || true
}

# ============================================================================
# logger_init tests
# ============================================================================

@test "logger_init creates log directory structure" {
    logger_init "testproject" "session123"

    # Verify project directory was created
    [[ -d "${TEST_LOGS_DIR}/testproject" ]]
}

@test "logger_init creates log file" {
    logger_init "testproject" "session123"

    # Verify log file was created
    [[ -f "${TEST_LOGS_DIR}/testproject/session123.jsonl" ]]
}

@test "logger_init sets _LOG_FILE variable" {
    logger_init "testproject" "session123"

    local log_file
    log_file=$(logger_get_file)

    [[ "$log_file" == "${TEST_LOGS_DIR}/testproject/session123.jsonl" ]]
}

@test "logger_init fails without project_name" {
    run logger_init "" "session123"

    [[ "$status" -eq 1 ]]
    [[ "$output" =~ "ERROR: project_name is required" ]]
}

@test "logger_init fails without session_id" {
    run logger_init "testproject" ""

    [[ "$status" -eq 1 ]]
    [[ "$output" =~ "ERROR: session_id is required" ]]
}

@test "logger_init creates nested project directories" {
    logger_init "nested/project/path" "session123"

    # Verify nested directory was created
    [[ -d "${TEST_LOGS_DIR}/nested/project/path" ]]
    [[ -f "${TEST_LOGS_DIR}/nested/project/path/session123.jsonl" ]]
}

# ============================================================================
# logger_write tests
# ============================================================================

@test "logger_write fails if logger not initialized" {
    run logger_write "test_event" '{}'

    [[ "$status" -eq 1 ]]
    [[ "$output" =~ "ERROR: Logger not initialized" ]]
}

@test "logger_write fails without event_type" {
    logger_init "testproject" "session123"

    run logger_write "" '{}'

    [[ "$status" -eq 1 ]]
    [[ "$output" =~ "ERROR: event_type is required" ]]
}

@test "logger_write creates valid JSON line" {
    logger_init "testproject" "session123"
    logger_write "test_event" '{"key": "value"}'

    local log_file
    log_file=$(logger_get_file)

    # Verify file has content
    [[ -s "$log_file" ]]

    # Verify it's valid JSON
    run jq -e '.' "$log_file"
    [[ "$status" -eq 0 ]]
}

@test "logger_write includes timestamp in ISO 8601 format" {
    logger_init "testproject" "session123"
    logger_write "test_event" '{"key": "value"}'

    local log_file
    log_file=$(logger_get_file)

    # Extract timestamp and verify format (YYYY-MM-DDTHH:MM:SSZ)
    local timestamp
    timestamp=$(jq -r '.timestamp' "$log_file")

    # Check ISO 8601 format with regex
    [[ "$timestamp" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]
}

@test "logger_write includes event_type field" {
    logger_init "testproject" "session123"
    logger_write "task_start" '{"task_id": "123"}'

    local log_file
    log_file=$(logger_get_file)

    # Extract event_type
    local event_type
    event_type=$(jq -r '.event_type' "$log_file")

    [[ "$event_type" == "task_start" ]]
}

@test "logger_write includes data field" {
    logger_init "testproject" "session123"
    logger_write "test_event" '{"key": "value", "number": 42}'

    local log_file
    log_file=$(logger_get_file)

    # Extract and verify data
    local key
    local number
    key=$(jq -r '.data.key' "$log_file")
    number=$(jq -r '.data.number' "$log_file")

    [[ "$key" == "value" ]]
    [[ "$number" == "42" ]]
}

@test "logger_write handles empty data (defaults to {})" {
    logger_init "testproject" "session123"
    logger_write "test_event"

    local log_file
    log_file=$(logger_get_file)

    # Verify data is empty object
    local data
    data=$(jq -c '.data' "$log_file")

    [[ "$data" == "{}" ]]
}

@test "logger_write appends multiple entries" {
    logger_init "testproject" "session123"

    logger_write "event1" '{"msg": "first"}'
    logger_write "event2" '{"msg": "second"}'
    logger_write "event3" '{"msg": "third"}'

    local log_file
    log_file=$(logger_get_file)

    # Count lines (should be 3)
    local line_count
    line_count=$(wc -l < "$log_file" | tr -d ' ')

    [[ "$line_count" == "3" ]]
}

@test "logger_write preserves existing log entries" {
    logger_init "testproject" "session123"

    logger_write "event1" '{"msg": "first"}'
    logger_write "event2" '{"msg": "second"}'

    local log_file
    log_file=$(logger_get_file)

    # Verify both entries exist
    local event1_msg
    local event2_msg
    event1_msg=$(sed -n '1p' "$log_file" | jq -r '.data.msg')
    event2_msg=$(sed -n '2p' "$log_file" | jq -r '.data.msg')

    [[ "$event1_msg" == "first" ]]
    [[ "$event2_msg" == "second" ]]
}

@test "logger_write handles complex nested JSON data" {
    logger_init "testproject" "session123"

    logger_write "complex_event" '{
        "nested": {
            "array": [1, 2, 3],
            "object": {"key": "value"}
        },
        "string": "test"
    }'

    local log_file
    log_file=$(logger_get_file)

    # Verify nested structure is preserved
    local array_val
    local obj_val
    array_val=$(jq -c '.data.nested.array' "$log_file")
    obj_val=$(jq -r '.data.nested.object.key' "$log_file")

    [[ "$array_val" == "[1,2,3]" ]]
    [[ "$obj_val" == "value" ]]
}

# ============================================================================
# logger_get_file tests
# ============================================================================

@test "logger_get_file returns empty string when not initialized" {
    local log_file
    log_file=$(logger_get_file)

    [[ -z "$log_file" ]]
}

@test "logger_get_file returns correct path after init" {
    logger_init "testproject" "session123"

    local log_file
    log_file=$(logger_get_file)

    [[ "$log_file" == "${TEST_LOGS_DIR}/testproject/session123.jsonl" ]]
}

# ============================================================================
# logger_clear tests
# ============================================================================

@test "logger_clear resets logger state" {
    logger_init "testproject" "session123"

    # Verify it's initialized
    local log_file_before
    log_file_before=$(logger_get_file)
    [[ -n "$log_file_before" ]]

    # Clear and verify
    logger_clear

    local log_file_after
    log_file_after=$(logger_get_file)
    [[ -z "$log_file_after" ]]
}

# ============================================================================
# Integration tests
# ============================================================================

@test "full logger workflow: init, write multiple events, verify output" {
    logger_init "integration_test" "20260109-123456"

    # Write various event types
    logger_write "session_start" '{"user": "testuser"}'
    logger_write "task_start" '{"task_id": "curb-123", "name": "test task"}'
    logger_write "info" '{"message": "processing..."}'
    logger_write "task_complete" '{"task_id": "curb-123", "status": "success"}'
    logger_write "session_end" '{}'

    local log_file
    log_file=$(logger_get_file)

    # Verify file structure
    [[ -f "$log_file" ]]

    # Verify line count
    local line_count
    line_count=$(wc -l < "$log_file" | tr -d ' ')
    [[ "$line_count" == "5" ]]

    # Verify all lines are valid JSON
    while IFS= read -r line; do
        echo "$line" | jq -e '.' > /dev/null
    done < "$log_file"

    # Verify specific events
    local session_start_user
    local task_start_id
    session_start_user=$(sed -n '1p' "$log_file" | jq -r '.data.user')
    task_start_id=$(sed -n '2p' "$log_file" | jq -r '.data.task_id')

    [[ "$session_start_user" == "testuser" ]]
    [[ "$task_start_id" == "curb-123" ]]
}

@test "acceptance: log file created at correct XDG path" {
    # Note: In real usage, curb_logs_dir returns ~/.local/share/curb/logs
    # In tests, it returns our test directory
    logger_init "myproject" "mysession"

    local log_file
    log_file=$(logger_get_file)

    # Verify path structure
    [[ "$log_file" =~ /myproject/mysession\.jsonl$ ]]
}

@test "acceptance: each line is valid JSON" {
    logger_init "testproject" "session123"

    logger_write "event1" '{"test": 1}'
    logger_write "event2" '{"test": 2}'

    local log_file
    log_file=$(logger_get_file)

    # Validate each line individually
    while IFS= read -r line; do
        echo "$line" | jq -e '.' > /dev/null || exit 1
    done < "$log_file"
}

@test "acceptance: timestamps in ISO 8601 format" {
    logger_init "testproject" "session123"

    logger_write "test_event" '{}'

    local log_file
    log_file=$(logger_get_file)

    local timestamp
    timestamp=$(jq -r '.timestamp' "$log_file")

    # ISO 8601 format: YYYY-MM-DDTHH:MM:SSZ
    [[ "$timestamp" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]
}

@test "acceptance: log file is append-only" {
    logger_init "testproject" "session123"

    logger_write "event1" '{"msg": "first"}'
    logger_write "event2" '{"msg": "second"}'

    local log_file
    log_file=$(logger_get_file)

    # Verify first event is still present after second write
    local first_msg
    first_msg=$(sed -n '1p' "$log_file" | jq -r '.data.msg')

    [[ "$first_msg" == "first" ]]
}
