# Curb

**C**laude **U**nder **R**alph + **B**eads

An autonomous AI coding agent harness that drives Claude Code in a loop to build software from a structured task backlog.

Combines the [Ralph Wiggum technique](https://ghuntley.com/ralph/) (running an AI agent in a while loop) with [beads-style](https://github.com/steveyegge/beads) task numbering (hash IDs, P0-P4 priorities, dependency tracking).

## Overview

Curb takes a PRD (Product Requirements Document) in beads-style JSON format and autonomously works through tasks until completion. It:

1. Reads `prd.json` to find ready tasks (unblocked, status=open)
2. Generates a focused prompt for the current task
3. Runs Claude Code with that prompt
4. Tracks progress and detects completion
5. Loops until all tasks reach status="closed"

## Prerequisites

- [Claude Code CLI](https://github.com/anthropics/claude-code) (`claude`)
- [jq](https://jqlang.github.io/jq/) for JSON processing
- Bash 4+

## Installation

```bash
# Clone or copy curb to your tools directory
git clone <this-repo> ~/tools/curb

# Add to PATH
export PATH="$PATH:$HOME/tools/curb"

# Or symlink
ln -s ~/tools/curb/curb /usr/local/bin/curb
ln -s ~/tools/curb/curb-init /usr/local/bin/curb-init
```

## Quick Start

```bash
# Initialize a new project
cd my-project
curb-init

# Edit prd.json with your tasks (or paste ChatPRD output)
# Add specifications to specs/
# Update AGENT.md with build instructions

# Check status
curb --status

# Run the autonomous loop
curb
```

## Usage

```bash
curb              # Run loop until all tasks complete
curb --once       # Run single iteration
curb --status     # Show current task status
curb --ready      # Show ready (unblocked) tasks
curb --plan       # Run planning mode (analyze & update fix_plan.md)
curb --help       # Show help
```

## Project Structure

After running `curb-init`, your project will have:

```
my-project/
├── prd.json        # Task backlog (beads-style format)
├── PROMPT.md       # Loop prompt template
├── AGENT.md        # Build/run instructions for the agent
├── progress.txt    # Session learnings (agent appends)
├── fix_plan.md     # Discovered issues and plans
└── specs/          # Detailed specifications
```

## prd.json Format

Curb uses beads-style task numbering:

```json
{
  "projectName": "my-project",
  "prefix": "myproj",
  "tasks": [
    {
      "id": "myproj-a1b2",
      "type": "feature",
      "title": "User authentication",
      "description": "As a user, I want to log in so that I can access my data",
      "acceptanceCriteria": [
        "Login form renders",
        "Valid credentials grant access",
        "Invalid credentials show error",
        "typecheck passes",
        "tests pass"
      ],
      "priority": "P1",
      "status": "open",
      "dependsOn": [],
      "notes": ""
    }
  ]
}
```

### Task Fields

| Field | Description |
|-------|-------------|
| `id` | Unique identifier (prefix + hash, e.g., `prd-a1b2`) |
| `type` | `epic`, `feature`, `task`, `bug`, `chore` |
| `title` | Short description |
| `description` | Full details, can use user story format |
| `acceptanceCriteria` | Array of verifiable conditions |
| `priority` | P0 (critical) to P4 (backlog) |
| `status` | `open`, `in_progress`, `closed` |
| `dependsOn` | Array of task IDs that must be closed first |
| `parent` | (Optional) Parent epic ID |
| `notes` | Agent-maintained notes |

### Task Selection

Curb picks tasks using this algorithm:
1. Find tasks where `status == "open"`
2. Filter to tasks where all `dependsOn` items are `closed`
3. Sort by priority (P0 first)
4. Pick the first one

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `CURB_PROJECT_DIR` | `$(pwd)` | Project directory |
| `CURB_MAX_ITERATIONS` | `100` | Max loop iterations |

## Creating a PRD

Use the Curb PRD template with ChatPRD to generate a properly structured `prd.json`. The template produces:

- Vision and problem statement
- Detailed specifications
- Tasks in beads-style format
- Technical architecture guidance
- Feedback loop requirements
- The loop prompt itself

## How It Works

### The Loop

```
 ┌──────────────────────────────────────────┐
 │                 curb                      │
 │                                           │
 │  prd.json ──▶ Find Ready Task            │
 │                     │                     │
 │                     ▼                     │
 │              Generate Prompt              │
 │                     │                     │
 │                     ▼                     │
 │               Claude Code                 │
 │                     │                     │
 │                     ▼                     │
 │              Task Complete?               │
 │                /        \                 │
 │               ▼          ▼                │
 │            Loop        Done               │
 └──────────────────────────────────────────┘
```

### Feedback Loops

The agent runs these before committing:
1. Type checking (tsc, mypy, etc.)
2. Tests (jest, pytest, etc.)
3. Linting (eslint, ruff, etc.)
4. Build (if applicable)

If any fail, the agent must fix before proceeding.

### Completion Signal

When all tasks have `status: "closed"`, the agent outputs:

```
<promise>COMPLETE</promise>
```

This signals curb to exit the loop.

## Tips

### Task Sizing
Keep tasks small enough to complete in one iteration (~one context window). If a task feels big, break it into subtasks.

### Specifications
The more detailed your specs, the better the output. Put them in `specs/` and reference them in task descriptions.

### Progress Memory
The agent appends to `progress.txt` after each task. This creates memory across iterations - patterns discovered, gotchas encountered.

### Recovery
If the codebase gets into a broken state:
```bash
git reset --hard HEAD~1  # Undo last commit
curb                      # Restart loop
```

### Planning Mode
Use `curb --plan` periodically to have the agent analyze the codebase and update `fix_plan.md` with discovered issues.

## Integration with Beads

Curb's prd.json format is compatible with the [beads](https://github.com/steveyegge/beads) CLI. To migrate:

```bash
# Initialize beads
bd init

# Then use bd for task management instead of prd.json
bd ready
bd update <id> --status=in_progress
bd close <id> --reason="completed"
```

## License

MIT
