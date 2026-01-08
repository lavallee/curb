#!/usr/bin/env bash
#
# tasks.sh - Task management functions for ralph
#
# Uses jq for JSON parsing of prd.json
#

# Get all ready tasks (status=open, all dependencies closed)
# Returns JSON array sorted by priority
get_ready_tasks() {
    local prd="$1"

    jq '
        # Build a set of closed task IDs
        (.tasks | map(select(.status == "closed") | .id)) as $closed |

        # Filter to open tasks where all dependencies are satisfied
        [
            .tasks[]
            | select(.status == "open")
            | select(
                (.dependsOn // []) | all(. as $dep | $closed | contains([$dep]))
            )
        ]
        # Sort by priority (P0 < P1 < P2 < P3 < P4)
        | sort_by(.priority)
    ' "$prd"
}

# Get a specific task by ID
get_task() {
    local prd="$1"
    local task_id="$2"

    jq --arg id "$task_id" '.tasks[] | select(.id == $id)' "$prd"
}

# Update task status
update_task_status() {
    local prd="$1"
    local task_id="$2"
    local new_status="$3"

    local tmp=$(mktemp)

    jq --arg id "$task_id" --arg status "$new_status" '
        .tasks = [
            .tasks[] |
            if .id == $id then
                .status = $status
            else
                .
            end
        ]
    ' "$prd" > "$tmp" && mv "$tmp" "$prd"
}

# Add a note to a task
add_task_note() {
    local prd="$1"
    local task_id="$2"
    local note="$3"

    local tmp=$(mktemp)
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    jq --arg id "$task_id" --arg note "$note" --arg ts "$timestamp" '
        .tasks = [
            .tasks[] |
            if .id == $id then
                .notes = ((.notes // "") + "\n[" + $ts + "] " + $note)
            else
                .
            end
        ]
    ' "$prd" > "$tmp" && mv "$tmp" "$prd"
}

# Create a new task
create_task() {
    local prd="$1"
    local task_json="$2"

    local tmp=$(mktemp)

    jq --argjson task "$task_json" '.tasks += [$task]' "$prd" > "$tmp" && mv "$tmp" "$prd"
}

# Generate a new task ID with the project prefix
generate_task_id() {
    local prd="$1"

    local prefix=$(jq -r '.prefix // "prd"' "$prd")
    local hash=$(head -c 100 /dev/urandom | shasum | head -c 4)

    echo "${prefix}-${hash}"
}

# Get task counts by status
get_task_counts() {
    local prd="$1"

    jq '{
        total: (.tasks | length),
        open: ([.tasks[] | select(.status == "open")] | length),
        in_progress: ([.tasks[] | select(.status == "in_progress")] | length),
        closed: ([.tasks[] | select(.status == "closed")] | length)
    }' "$prd"
}

# Check if all tasks are complete
all_tasks_complete() {
    local prd="$1"

    local remaining=$(jq '[.tasks[] | select(.status != "closed")] | length' "$prd")
    [[ "$remaining" -eq 0 ]]
}

# Get blocked tasks (dependencies not satisfied)
get_blocked_tasks() {
    local prd="$1"

    jq '
        (.tasks | map(select(.status == "closed") | .id)) as $closed |
        [
            .tasks[]
            | select(.status == "open")
            | select(
                (.dependsOn // []) | any(. as $dep | $closed | contains([$dep]) | not)
            )
        ]
    ' "$prd"
}

# Validate prd.json structure
validate_prd() {
    local prd="$1"

    # Check required fields
    if ! jq -e '.tasks' "$prd" >/dev/null 2>&1; then
        echo "ERROR: prd.json missing 'tasks' array"
        return 1
    fi

    # Check each task has required fields
    local invalid
    invalid=$(jq '[.tasks[] | select(.id == null or .title == null or .status == null)] | length' "$prd")

    if [[ "$invalid" -gt 0 ]]; then
        echo "ERROR: ${invalid} tasks missing required fields (id, title, status)"
        return 1
    fi

    # Check for duplicate IDs
    local total=$(jq '.tasks | length' "$prd")
    local unique=$(jq '.tasks | map(.id) | unique | length' "$prd")

    if [[ "$total" -ne "$unique" ]]; then
        echo "ERROR: Duplicate task IDs found"
        return 1
    fi

    # Check dependency references
    local bad_deps
    bad_deps=$(jq '
        (.tasks | map(.id)) as $all_ids |
        [
            .tasks[]
            | .id as $tid
            | (.dependsOn // [])[]
            | select(. as $dep | $all_ids | contains([$dep]) | not)
        ]
    ' "$prd")

    if [[ "$bad_deps" != "[]" ]]; then
        echo "ERROR: Invalid dependency references: $bad_deps"
        return 1
    fi

    echo "OK"
    return 0
}

# Export task to beads CLI format
export_to_beads() {
    local prd="$1"
    local task_id="$2"

    local task
    task=$(get_task "$prd" "$task_id")

    if [[ -z "$task" || "$task" == "null" ]]; then
        echo "Task not found: $task_id"
        return 1
    fi

    local title=$(echo "$task" | jq -r '.title')
    local type=$(echo "$task" | jq -r '.type // "task"')
    local priority=$(echo "$task" | jq -r '.priority // "P2"')
    local desc=$(echo "$task" | jq -r '.description // ""')

    echo "bd create --title=\"${title}\" --type=${type} --priority=${priority} --description=\"${desc}\""
}
