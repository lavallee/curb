#!/usr/bin/env bash
#
# artifacts.sh - Artifact directory management
#
# Provides functions for managing artifact bundles that provide
# observability into each task's execution. Artifacts are stored
# in .curb/runs/{session-id}/tasks/{task-id}/ structure.
#
# Functions:
#   artifacts_get_run_dir() - Get the directory for the current run
#   artifacts_get_task_dir(task_id) - Get the directory for a specific task
#   artifacts_ensure_dirs(task_id) - Ensure directory structure exists
#   artifacts_init_run() - Initialize run-level artifacts and create run.json
#   artifacts_start_task(task_id, task_title, priority) - Start task and create task.json
#   artifacts_capture_plan(task_id, plan_content) - Write plan.md for a task
#   artifacts_capture_command(task_id, cmd, exit_code, output, duration) - Append to commands.jsonl
#   artifacts_capture_diff(task_id) - Capture git diff to changes.patch
#

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/session.sh"
source "${SCRIPT_DIR}/xdg.sh"

# Base directory for artifacts (relative to project root)
_ARTIFACTS_BASE_DIR=".curb/runs"

# Get the directory for the current run
# Returns: path to run directory (.curb/runs/{session-id})
#
# Returns:
#   Path to run directory on success, error on failure
#
# Example:
#   run_dir=$(artifacts_get_run_dir)
artifacts_get_run_dir() {
    # Check if session is initialized
    if ! session_is_initialized; then
        echo "ERROR: Session not initialized. Call session_init first." >&2
        return 1
    fi

    # Get session ID
    local session_id
    session_id=$(session_get_id)
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    # Return the run directory path
    echo "${_ARTIFACTS_BASE_DIR}/${session_id}"
    return 0
}

# Get the directory for a specific task
# Returns: path to task directory (.curb/runs/{session-id}/tasks/{task-id})
#
# Args:
#   $1 - task_id: The task identifier (e.g., "curb-123")
#
# Returns:
#   Path to task directory on success, error on failure
#
# Example:
#   task_dir=$(artifacts_get_task_dir "curb-123")
artifacts_get_task_dir() {
    local task_id="$1"

    # Validate task_id
    if [[ -z "$task_id" ]]; then
        echo "ERROR: task_id is required" >&2
        return 1
    fi

    # Get run directory
    local run_dir
    run_dir=$(artifacts_get_run_dir)
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    # Return the task directory path
    echo "${run_dir}/tasks/${task_id}"
    return 0
}

# Ensure artifact directory structure exists for a task
# Creates the full directory hierarchy with secure permissions (700)
#
# Args:
#   $1 - task_id: The task identifier (e.g., "curb-123")
#
# Returns:
#   0 on success, 1 on failure
#
# Example:
#   artifacts_ensure_dirs "curb-123"
artifacts_ensure_dirs() {
    local task_id="$1"

    # Validate task_id
    if [[ -z "$task_id" ]]; then
        echo "ERROR: task_id is required" >&2
        return 1
    fi

    # Get task directory path
    local task_dir
    task_dir=$(artifacts_get_task_dir "$task_id")
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    # Create directory structure with secure permissions (700)
    # Using -p to create parent directories, -m to set permissions
    mkdir -p -m 700 "$task_dir"

    if [[ $? -ne 0 ]]; then
        echo "ERROR: Failed to create directory: $task_dir" >&2
        return 1
    fi

    return 0
}

# Initialize run-level artifacts
# Creates the run directory and run.json with initial metadata
# Includes config snapshot from config_dump if available
#
# Returns:
#   0 on success, 1 on failure
#
# Example:
#   artifacts_init_run
artifacts_init_run() {
    # Check if session is initialized
    if ! session_is_initialized; then
        echo "ERROR: Session not initialized. Call session_init first." >&2
        return 1
    fi

    # Get run directory path
    local run_dir
    run_dir=$(artifacts_get_run_dir)
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    # Create run directory with secure permissions (700)
    mkdir -p -m 700 "$run_dir"
    if [[ $? -ne 0 ]]; then
        echo "ERROR: Failed to create run directory: $run_dir" >&2
        return 1
    fi

    # Get session metadata
    local run_id
    local session_name
    local started_at
    run_id=$(session_get_id)
    session_name=$(session_get_name)
    started_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Get config snapshot if config.sh is available
    local config_snapshot="{}"
    if type config_dump &>/dev/null; then
        # Source config.sh if not already loaded
        if [[ -z "$(type -t config_dump)" ]]; then
            source "${SCRIPT_DIR}/config.sh" 2>/dev/null || true
        fi
        # Try to get config dump
        if type config_dump &>/dev/null; then
            config_snapshot=$(config_dump 2>/dev/null) || config_snapshot="{}"
        fi
    fi

    # Validate config_snapshot is valid JSON, fallback to empty object if not
    if ! echo "$config_snapshot" | jq empty 2>/dev/null; then
        config_snapshot="{}"
    fi

    # Create run.json using jq
    local run_json
    run_json=$(jq -n \
        --arg run_id "$run_id" \
        --arg session_name "$session_name" \
        --arg started_at "$started_at" \
        --arg status "in_progress" \
        --argjson config "$config_snapshot" \
        '{
            run_id: $run_id,
            session_name: $session_name,
            started_at: $started_at,
            status: $status,
            config: $config
        }')

    if [[ $? -ne 0 ]]; then
        echo "ERROR: Failed to create run.json metadata" >&2
        return 1
    fi

    # Write run.json to file
    echo "$run_json" > "${run_dir}/run.json"
    if [[ $? -ne 0 ]]; then
        echo "ERROR: Failed to write run.json to ${run_dir}/run.json" >&2
        return 1
    fi

    return 0
}

# Start a task and create task-level artifacts
# Creates the task directory and task.json with initial metadata
#
# Args:
#   $1 - task_id: The task identifier (e.g., "curb-123")
#   $2 - task_title: The task title/description
#   $3 - priority: Task priority (optional, defaults to "normal")
#
# Returns:
#   0 on success, 1 on failure
#
# Example:
#   artifacts_start_task "curb-123" "Implement feature X" "high"
artifacts_start_task() {
    local task_id="$1"
    local task_title="$2"
    local priority="${3:-normal}"

    # Validate required arguments
    if [[ -z "$task_id" ]]; then
        echo "ERROR: task_id is required" >&2
        return 1
    fi

    if [[ -z "$task_title" ]]; then
        echo "ERROR: task_title is required" >&2
        return 1
    fi

    # Ensure task directory exists
    artifacts_ensure_dirs "$task_id"
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    # Get task directory path
    local task_dir
    task_dir=$(artifacts_get_task_dir "$task_id")
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    # Get current timestamp in ISO 8601 format
    local started_at
    started_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Create task.json using jq
    local task_json
    task_json=$(jq -n \
        --arg task_id "$task_id" \
        --arg title "$task_title" \
        --arg priority "$priority" \
        --arg status "in_progress" \
        --arg started_at "$started_at" \
        --argjson iterations 0 \
        '{
            task_id: $task_id,
            title: $title,
            priority: $priority,
            status: $status,
            started_at: $started_at,
            iterations: $iterations
        }')

    if [[ $? -ne 0 ]]; then
        echo "ERROR: Failed to create task.json metadata" >&2
        return 1
    fi

    # Write task.json to file
    echo "$task_json" > "${task_dir}/task.json"
    if [[ $? -ne 0 ]]; then
        echo "ERROR: Failed to write task.json to ${task_dir}/task.json" >&2
        return 1
    fi

    return 0
}

# Capture the plan for a task
# Writes plan content to plan.md in the task directory
#
# Args:
#   $1 - task_id: The task identifier (e.g., "curb-123")
#   $2 - plan_content: The plan content to write (markdown)
#
# Returns:
#   0 on success, 1 on failure
#
# Example:
#   artifacts_capture_plan "curb-123" "## Plan\n1. Step one\n2. Step two"
artifacts_capture_plan() {
    local task_id="$1"
    local plan_content="$2"

    # Validate required arguments
    if [[ -z "$task_id" ]]; then
        echo "ERROR: task_id is required" >&2
        return 1
    fi

    if [[ -z "$plan_content" ]]; then
        echo "ERROR: plan_content is required" >&2
        return 1
    fi

    # Ensure task directory exists
    artifacts_ensure_dirs "$task_id"
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    # Get task directory path
    local task_dir
    task_dir=$(artifacts_get_task_dir "$task_id")
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    # Write plan content to plan.md
    echo "$plan_content" > "${task_dir}/plan.md"
    if [[ $? -ne 0 ]]; then
        echo "ERROR: Failed to write plan.md to ${task_dir}/plan.md" >&2
        return 1
    fi

    # Set file permissions to 600 (owner read/write only)
    chmod 600 "${task_dir}/plan.md"
    if [[ $? -ne 0 ]]; then
        echo "ERROR: Failed to set permissions on ${task_dir}/plan.md" >&2
        return 1
    fi

    return 0
}

# Capture a command execution
# Appends command metadata to commands.jsonl in the task directory
#
# Args:
#   $1 - task_id: The task identifier (e.g., "curb-123")
#   $2 - cmd: The command that was executed
#   $3 - exit_code: The exit code of the command
#   $4 - output: The command output (optional, can be empty)
#   $5 - duration: Duration in seconds (optional)
#
# Returns:
#   0 on success, 1 on failure
#
# Example:
#   artifacts_capture_command "curb-123" "npm test" "0" "All tests passed" "5.2"
artifacts_capture_command() {
    local task_id="$1"
    local cmd="$2"
    local exit_code="$3"
    local output="$4"
    local duration="${5:-0}"

    # Validate required arguments
    if [[ -z "$task_id" ]]; then
        echo "ERROR: task_id is required" >&2
        return 1
    fi

    if [[ -z "$cmd" ]]; then
        echo "ERROR: cmd is required" >&2
        return 1
    fi

    if [[ -z "$exit_code" ]]; then
        echo "ERROR: exit_code is required" >&2
        return 1
    fi

    # Ensure task directory exists
    artifacts_ensure_dirs "$task_id"
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    # Get task directory path
    local task_dir
    task_dir=$(artifacts_get_task_dir "$task_id")
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    # Get current timestamp in ISO 8601 format
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Create command entry using jq (-c for compact/single-line output)
    local command_json
    command_json=$(jq -n -c \
        --arg timestamp "$timestamp" \
        --arg cmd "$cmd" \
        --argjson exit_code "$exit_code" \
        --arg output "$output" \
        --argjson duration "$duration" \
        '{
            timestamp: $timestamp,
            command: $cmd,
            exit_code: $exit_code,
            output: $output,
            duration: $duration
        }')

    if [[ $? -ne 0 ]]; then
        echo "ERROR: Failed to create command JSON" >&2
        return 1
    fi

    # Append to commands.jsonl (create if doesn't exist)
    local commands_file="${task_dir}/commands.jsonl"
    echo "$command_json" >> "$commands_file"
    if [[ $? -ne 0 ]]; then
        echo "ERROR: Failed to append to ${commands_file}" >&2
        return 1
    fi

    # Set file permissions to 600 (owner read/write only)
    chmod 600 "$commands_file"
    if [[ $? -ne 0 ]]; then
        echo "ERROR: Failed to set permissions on ${commands_file}" >&2
        return 1
    fi

    return 0
}

# Capture git diff for a task
# Runs git diff HEAD to capture all uncommitted changes and writes to changes.patch
# Handles case where HEAD doesn't exist (fresh repo) by using git diff
#
# Args:
#   $1 - task_id: The task identifier (e.g., "curb-123")
#
# Returns:
#   0 on success, 1 on failure
#
# Example:
#   artifacts_capture_diff "curb-123"
artifacts_capture_diff() {
    local task_id="$1"

    # Validate required arguments
    if [[ -z "$task_id" ]]; then
        echo "ERROR: task_id is required" >&2
        return 1
    fi

    # Ensure task directory exists
    artifacts_ensure_dirs "$task_id"
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    # Get task directory path
    local task_dir
    task_dir=$(artifacts_get_task_dir "$task_id")
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    # Try git diff HEAD first (captures staged + unstaged changes)
    # If HEAD doesn't exist (fresh repo), fall back to git diff (unstaged only)
    local diff_output
    diff_output=$(git diff HEAD 2>/dev/null)
    local git_exit_code=$?

    # If HEAD doesn't exist, try without HEAD
    if [[ $git_exit_code -ne 0 ]]; then
        diff_output=$(git diff 2>&1)
        git_exit_code=$?
    fi

    # If git still failed (not in a git repo, etc.), report error
    if [[ $git_exit_code -ne 0 ]]; then
        echo "ERROR: git diff failed: $diff_output" >&2
        return 1
    fi

    # Write diff to changes.patch (even if empty)
    local patch_file="${task_dir}/changes.patch"
    echo "$diff_output" > "$patch_file"
    if [[ $? -ne 0 ]]; then
        echo "ERROR: Failed to write changes.patch to ${patch_file}" >&2
        return 1
    fi

    # Set file permissions to 600 (owner read/write only)
    chmod 600 "$patch_file"
    if [[ $? -ne 0 ]]; then
        echo "ERROR: Failed to set permissions on ${patch_file}" >&2
        return 1
    fi

    return 0
}
