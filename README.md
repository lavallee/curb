# Curb

**C**laude **U**nder **R**alph + **B**eads

An autonomous AI coding agent harness that drives AI coding CLIs in a loop to build software from a structured task backlog.

Combines the [Ralph Wiggum technique](https://ghuntley.com/ralph/) (running an AI agent in a while loop) with [beads-style](https://github.com/steveyegge/beads) task numbering (hash IDs, P0-P4 priorities, dependency tracking).

## Features

- **Multi-Harness Support**: Works with Claude Code or OpenAI Codex CLI
- **Dual Task Backend**: Use beads CLI or simple prd.json for task management
- **Autonomous Loop**: Runs until all tasks are complete
- **Dependency Tracking**: Respects task dependencies, picks ready tasks
- **Priority Scheduling**: P0-P4 priority-based task selection
- **Planning Mode**: Analyze codebase and generate fix plans
- **Streaming Output**: Watch agent activity in real-time
- **Migration Tools**: Convert between prd.json and beads formats

## Prerequisites

- **Required**: [jq](https://jqlang.github.io/jq/) for JSON processing
- **Required**: Bash 4+
- **Harness** (at least one):
  - [Claude Code CLI](https://github.com/anthropics/claude-code) (`claude`) - Recommended
  - [OpenAI Codex CLI](https://github.com/openai/codex) (`codex`)
- **Task Backend** (optional):
  - [beads CLI](https://github.com/steveyegge/beads) (`bd`) - For advanced task management

## Installation

```bash
# Clone curb to your tools directory
git clone https://github.com/lavallee/curb ~/tools/curb

# Add to PATH (add to ~/.bashrc or ~/.zshrc)
export PATH="$PATH:$HOME/tools/curb"

# Or create symlinks
ln -s ~/tools/curb/curb /usr/local/bin/curb
ln -s ~/tools/curb/curb-init /usr/local/bin/curb-init
```

## Quick Start

```bash
# Initialize a new project
cd my-project
curb-init

# Edit prd.json with your tasks
# Add specifications to specs/
# Update AGENT.md with build instructions

# Check status
curb --status

# Run the autonomous loop
curb
```

## Usage

```bash
# Core commands
curb              # Run loop until all tasks complete
curb --once       # Run single iteration
curb --status     # Show current task status
curb --ready      # Show ready (unblocked) tasks
curb --plan       # Run planning mode

# Harness selection
curb --harness claude    # Use Claude Code (default)
curb --harness codex     # Use OpenAI Codex CLI

# Output modes
curb --stream     # Stream harness activity in real-time
curb --debug      # Enable verbose debug logging

# Migration tools
curb --migrate-to-beads          # Migrate prd.json to beads
curb --migrate-to-beads-dry-run  # Preview migration

# Debugging
curb --test          # Test harness invocation
curb --dump-prompt   # Save prompts to files for inspection
curb --help          # Show help
```

## Project Structure

After running `curb-init`, your project will have:

```
my-project/
├── prd.json        # Task backlog (beads-style format)
├── PROMPT.md       # Loop prompt template (system instructions)
├── AGENT.md        # Build/run instructions for the agent
├── AGENTS.md       # Symlink to AGENT.md (for Codex compatibility)
├── progress.txt    # Session learnings (agent appends)
├── fix_plan.md     # Discovered issues and plans
└── specs/          # Detailed specifications
```

## Task Backends

Curb supports two task management backends:

### JSON Backend (Default)

Simple file-based task management using `prd.json`:

```json
{
  "projectName": "my-project",
  "prefix": "myproj",
  "tasks": [
    {
      "id": "myproj-a1b2",
      "type": "feature",
      "title": "User authentication",
      "description": "Implement login functionality",
      "acceptanceCriteria": ["Login form renders", "Tests pass"],
      "priority": "P1",
      "status": "open",
      "dependsOn": [],
      "notes": ""
    }
  ]
}
```

### Beads Backend

For projects using the [beads](https://github.com/steveyegge/beads) CLI:

```bash
# Install beads
brew install steveyegge/beads/bd

# Initialize in project
bd init

# Curb auto-detects .beads/ directory
curb --status  # Uses beads backend automatically
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

### Task Selection Algorithm

1. Find tasks where `status == "open"`
2. Filter to tasks where all `dependsOn` items are `closed`
3. Sort by priority (P0 first)
4. Pick the first one

## AI Harnesses

Curb abstracts the AI coding CLI into a "harness" layer, supporting multiple backends:

### Claude Code (Default)

```bash
curb --harness claude
# or
export HARNESS=claude
```

Uses Claude Code's `--append-system-prompt` for clean prompt separation.

### OpenAI Codex

```bash
curb --harness codex
# or
export HARNESS=codex
```

Uses Codex's `--full-auto` mode with combined prompts.

### Auto-Detection

By default, curb auto-detects available harnesses:
1. Prefers `claude` if installed
2. Falls back to `codex` if claude unavailable

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `CURB_PROJECT_DIR` | `$(pwd)` | Project directory |
| `CURB_MAX_ITERATIONS` | `100` | Max loop iterations |
| `CURB_DEBUG` | `false` | Enable debug mode |
| `CURB_STREAM` | `false` | Enable streaming output |
| `CURB_BACKEND` | `auto` | Task backend: `auto`, `beads`, `json` |
| `HARNESS` | `auto` | AI harness: `auto`, `claude`, `codex` |
| `CLAUDE_FLAGS` | | Extra flags for Claude Code |
| `CODEX_FLAGS` | | Extra flags for Codex CLI |

## How It Works

### The Loop

```
┌──────────────────────────────────────────┐
│                 curb                      │
│                                           │
│  Tasks ────▶ Find Ready Task             │
│                     │                     │
│                     ▼                     │
│              Generate Prompt              │
│                     │                     │
│                     ▼                     │
│           AI Harness (claude/codex)       │
│                     │                     │
│                     ▼                     │
│              Task Complete?               │
│                /        \                 │
│               ▼          ▼                │
│            Loop        Done               │
└──────────────────────────────────────────┘
```

### Prompt Structure

Curb generates two prompts for each iteration:

1. **System Prompt** (from `PROMPT.md`): Static instructions about workflow, rules, and completion signals
2. **Task Prompt**: Current task details including ID, description, and acceptance criteria

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

## Advanced Usage

### Streaming Mode

Watch agent activity in real-time:

```bash
curb --stream
```

Shows tool calls, responses, and costs as they happen.

### Debug Mode

Get verbose output for troubleshooting:

```bash
curb --debug --once
```

Includes:
- Full prompts being sent
- Task selection details
- Timing information
- Saves prompts to temp files

### Planning Mode

Analyze codebase and update fix_plan.md:

```bash
curb --plan
```

Uses parallel subagents to study code, find TODOs, and document issues.

### Migrating to Beads

Convert existing prd.json to beads format:

```bash
# Preview what would happen
curb --migrate-to-beads-dry-run

# Perform migration
curb --migrate-to-beads
```

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

### Choosing a Harness

| Harness | Best For |
|---------|----------|
| Claude Code | General coding, complex refactoring, multi-file changes |
| Codex | Quick fixes, OpenAI ecosystem projects |

## Files Reference

| File | Purpose |
|------|---------|
| `curb` | Main script - the autonomous loop |
| `curb-init` | Project initialization |
| `lib/harness.sh` | AI harness abstraction (claude/codex) |
| `lib/tasks.sh` | Task backend abstraction (beads/json) |
| `templates/PROMPT.md` | Default system prompt |
| `templates/AGENT.md` | Default agent instructions |

## License

MIT
