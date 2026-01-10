# OpenCode CLI Research Spike

**Date:** 2026-01-10
**Version Tested:** 1.0.220
**Purpose:** Understand OpenCode CLI interface for curb harness implementation

## Executive Summary

OpenCode is an open-source AI coding agent built for the terminal. It's installed via npm/homebrew and provides both interactive TUI and non-interactive CLI modes. The CLI differs from Claude Code and Gemini in its interaction model - it uses a `run` subcommand for automation and provides excellent token/cost reporting through JSON events. It has strong agent configuration capabilities and built-in support for custom system prompts.

## Installation

### Methods Available
1. **Install Script** (Recommended): `curl -fsSL https://opencode.ai/install | bash`
2. **NPM Global**: `npm i -g opencode-ai@latest`
3. **Homebrew**: `brew install anomalyco/tap/opencode` or `brew install opencode` (macOS/Linux)
4. **Windows Scoop**: `scoop bucket add extras; scoop install extras/opencode`
5. **Windows Chocolatey**: `choco install opencode`
6. **Arch Linux**: `paru -S opencode-bin`
7. **mise**: `mise use -g opencode`
8. **Nix**: `nix run nixpkgs#opencode`

### Current Installation Status
```bash
$ which opencode
/opt/homebrew/bin/opencode

$ opencode --version
1.0.220
```

## Basic Invocation

### Command Pattern
```bash
# Interactive TUI (default)
opencode

# Non-interactive mode (for automation)
opencode run "prompt text"
echo "prompt text" | opencode run
```

### Example
```bash
$ opencode run "What is 2+2? Answer in one sentence only."
2+2 equals 4.

$ echo "What is 3+3? One sentence." | opencode run
3 + 3 equals 6.
```

## Key Flags Mapped to Curb Needs

### Auto Mode (Non-Interactive)
- **Command**: `opencode run [message..]`
- **Description**: Run in non-interactive mode with auto-approved permissions
- **Curb Requirement**: ✅ CRITICAL - Required for autonomous operation
- **Note**: All permissions are automatically approved in run mode
- **Example**:
  ```bash
  $ opencode run "Calculate 5+5"
  10
  ```

### Model Selection
- **Flag**: `-m` or `--model`
- **Default**: Provider-dependent (e.g., `anthropic/claude-sonnet-4-20250514`)
- **Format**: `provider/model` (e.g., `openai/gpt-4o`, `anthropic/claude-sonnet-4`)
- **Description**: Specify which AI model to use
- **Curb Requirement**: ✅ Useful for model switching
- **Example**: `opencode run -m openai/gpt-4o "test prompt"`

### Debug Mode
- **Flag**: `--print-logs` and `--log-level`
- **Default**: `false` / `INFO`
- **Description**: Output logs to stderr, set verbosity level
- **Curb Requirement**: ✅ Needed for troubleshooting
- **Example**: `opencode run --print-logs --log-level DEBUG "test"`

### Output Format
- **Flag**: `--format`
- **Choices**: `default` (formatted text), `json` (raw JSON events)
- **Default**: `default`
- **Description**: Control output format for parsing
- **Curb Requirement**: ✅ CRITICAL - Needed for token extraction
- **Example**:
  ```bash
  $ opencode run --format json "What is 3+3? One sentence."
  {"type":"step_start","timestamp":1768040090820,"sessionID":"ses_...","part":{...}}
  {"type":"text","timestamp":1768040091415,"sessionID":"ses_...","part":{...,"text":"3+3 equals 6."}}
  {"type":"step_finish","timestamp":1768040091548,"sessionID":"ses_...","part":{...,"cost":0.021049,"tokens":{"input":11940,"output":11,"reasoning":0,"cache":{"read":0,"write":0}}}}
  ```

### Session Management
- **Flag**: `-c` or `--continue` - Continue last session
- **Flag**: `-s` or `--session <id>` - Continue specific session
- **Flag**: `--share` - Share the session
- **Flag**: `--title <name>` - Custom session name
- **Curb Requirement**: ⚠️ Potentially useful for conversation continuity

### File Attachments
- **Flag**: `-f` or `--file <path>`
- **Description**: Attach file(s) to message
- **Curb Requirement**: ⚠️ Could be useful for context injection
- **Example**: `opencode run -f ./context.md "analyze this"`

### Agent Selection
- **Flag**: `--agent <name>`
- **Description**: Choose which agent to use
- **Available Agents**: build (primary), compaction (primary), explore (subagent), general (subagent), plan (primary), summary (primary), title (primary)
- **Curb Requirement**: ⚠️ Could optimize task execution
- **Example**: `opencode run --agent build "implement feature"`

### Other Notable Flags
- `--port <number>`: Port for local server (defaults to random)
- `--attach <url>`: Attach to a running opencode server
- `--command <cmd>`: The command to run (uses message for args)

## System Prompt

### Agent Configuration
OpenCode has comprehensive support for custom system prompts through multiple mechanisms:

#### 1. AGENTS.md File (Recommended for Curb)
- **Location**: Project root or `~/.config/opencode/AGENTS.md`
- **Purpose**: Project-specific or global custom instructions
- **Precedence**: Local files override global
- **Multiple files**: Combine together when both exist
- **Example**:
  ```markdown
  # Project Instructions

  You are working in a bash-based CLI project called Curb.
  Follow these guidelines:
  - Use bash 3.2 compatible syntax
  - All functions should have clear comments
  - Run tests with BATS before committing
  ```

#### 2. Agent JSON Configuration
Agents can be defined in `opencode.json`:
```json
{
  "agent": {
    "curb-worker": {
      "description": "Autonomous coding agent for Curb project",
      "mode": "primary",
      "model": "anthropic/claude-sonnet-4-20250514",
      "temperature": 0.1,
      "tools": { "write": true, "edit": true, "bash": true },
      "permissions": { "edit": "allow", "bash": "allow" },
      "prompt": "{file:./system-prompt.md}"
    }
  }
}
```

#### 3. Agent Markdown Files
Create agent files in `~/.config/opencode/agent/` or `.opencode/agent/`:
```markdown
---
description: Code review agent
mode: subagent
temperature: 0.1
---
You are a code reviewer focusing on quality and security.
```

#### 4. External File References
Reference additional context files in `opencode.json`:
```json
{
  "instructions": ["docs/guidelines.md", "packages/*/AGENTS.md"]
}
```

### Implementation Strategy for Curb

**Option A**: Use AGENTS.md file (simplest)
- Create `.opencode/AGENTS.md` in project root
- Write system prompt directly in the file
- OpenCode automatically includes it in context
- **Pros**: No CLI flags needed, persistent across invocations
- **Cons**: File-based, requires setup step

**Option B**: Use custom agent with prompt file
- Create custom agent in `opencode.json`
- Reference system prompt file with `{file:./path}`
- Invoke with `--agent curb-worker`
- **Pros**: Explicit control, can configure tools/permissions
- **Cons**: More complex setup, requires agent flag

**Option C**: Prepend to task prompt
- Concatenate system prompt + task prompt
- Pass combined prompt to `opencode run`
- Same pattern as Gemini/Codex harnesses
- **Pros**: Simple, no setup required
- **Cons**: Wastes tokens, no caching benefits

**Recommended**: Option A (AGENTS.md) for production, Option C for quick prototyping

## Streaming

### Available Options
- **Flag**: `--format json`
- **Status**: ✅ AVAILABLE - Raw JSON events streamed
- **Description**: Newline-delimited JSON events with real-time updates
- **Event Types**: `step_start`, `text`, `step_finish`, `content_block_start`, `content_block_delta`, etc.

### Testing Results
```bash
$ opencode run --format json "What is 3+3? One sentence."
{"type":"step_start","timestamp":1768040090820,"sessionID":"ses_458993782ffeGEefMnw5yg5mhJ","part":{...}}
{"type":"text","timestamp":1768040091415,"sessionID":"ses_458993782ffeGEefMnw5yg5mhJ","part":{...,"text":"3+3 equals 6."}}
{"type":"step_finish","timestamp":1768040091548,"sessionID":"ses_458993782ffeGEefMnw5yg5mhJ","part":{...,"cost":0.021049,"tokens":{"input":11940,"output":11,"reasoning":0,"cache":{"read":0,"write":0}}}}
```

### Conclusion
- ✅ **Streaming fully supported via `--format json`**
- JSON events provide structured output for parsing
- Token usage available in `step_finish` events
- Similar to Claude Code's `--output-format stream-json`

## Token and Usage Reporting

### Real-Time Reporting (JSON Events)

Token usage is reported in `step_finish` events:
```json
{
  "type": "step_finish",
  "timestamp": 1768040091548,
  "sessionID": "ses_458993782ffeGEefMnw5yg5mhJ",
  "part": {
    "id": "prt_ba766cf98001DC1zW2zlfvgBqw",
    "sessionID": "ses_458993782ffeGEefMnw5yg5mhJ",
    "messageID": "msg_ba766c897001c93kEb30T1U5VD",
    "type": "step-finish",
    "reason": "stop",
    "cost": 0.021049,
    "tokens": {
      "input": 11940,
      "output": 11,
      "reasoning": 0,
      "cache": {
        "read": 0,
        "write": 0
      }
    }
  }
}
```

### Usage Statistics Command

The `opencode stats` command provides comprehensive usage analytics:
```bash
$ opencode stats
┌────────────────────────────────────────────────────────┐
│                       OVERVIEW                         │
├────────────────────────────────────────────────────────┤
│Sessions                                              3 │
│Messages                                              6 │
│Days                                                  1 │
└────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────┐
│                    COST & TOKENS                       │
├────────────────────────────────────────────────────────┤
│Total Cost                                        $0.04 │
│Avg Cost/Day                                      $0.04 │
│Avg Tokens/Session                                 8.0K │
│Median Tokens/Session                             12.0K │
│Input                                             24.0K │
│Output                                               34 │
│Cache Read                                        11.8K │
│Cache Write                                           0 │
└────────────────────────────────────────────────────────┘
```

Flags for stats command:
- `--days <n>`: Show stats for last N days
- `--project <name>`: Filter by project
- `--models`: Show model-specific statistics
- `--tools <n>`: Number of tools to show

### Session Export

Export session data as JSON for offline analysis:
```bash
$ opencode export <sessionID>
# Returns full JSON with all messages, tools used, and token usage
```

### Conclusion for Curb
- ✅ **EXCELLENT token reporting via `--format json`**
- ✅ Real-time usage extraction from `step_finish` events
- ✅ Cost reporting included (USD)
- ✅ Cache read/write tokens tracked separately
- ✅ Reasoning tokens reported (for o1-style models)
- **Best-in-class** compared to Claude Code, Codex, and Gemini

## Significant Differences from Claude/Codex/Gemini

### 1. Command Structure
- **OpenCode**: `opencode run [message]` for automation
- **Claude Code**: `claude -p "prompt"` direct invocation
- **Codex**: `codex exec -` for stdin
- **Gemini**: `gemini -p "prompt"` direct invocation
- **Impact**: Different invocation pattern, extra `run` subcommand

### 2. Auto Mode
- **OpenCode**: Automatic in `opencode run` mode (no flag needed)
- **Claude Code**: `--dangerously-skip-permissions` required
- **Codex**: `--full-auto` required
- **Gemini**: `-y` (YOLO) required
- **Impact**: Simpler - auto mode is the default for run command

### 3. System Prompt Support
- **OpenCode**: Multiple methods (AGENTS.md, agent config, prompt concatenation)
- **Claude Code**: `--append-system-prompt "..."`
- **Codex**: Concatenate prompts
- **Gemini**: Concatenate prompts or GEMINI.md file
- **Impact**: Most flexible, but also most complex

### 4. Token Reporting
- **OpenCode**: ✅ Excellent - JSON events with full breakdown
- **Claude Code**: ✅ Good - JSON events with usage object
- **Codex**: ❌ None available in stdout
- **Gemini**: ❌ None available in stdout (only /stats in interactive)
- **Impact**: Best-in-class usage tracking

### 5. Output Formats
- **OpenCode**: `--format default|json` with structured events
- **Claude Code**: `--output-format json|stream-json`
- **Codex**: Plain text only
- **Gemini**: Plain text only (--output-format not available in v0.1.9)
- **Impact**: Similar to Claude Code, good for parsing

### 6. Agent System
- **OpenCode**: Built-in agent types (primary/subagent), custom agents
- **Claude Code**: No agent concept
- **Codex**: No agent concept
- **Gemini**: No agent concept
- **Impact**: Unique feature for task-specific optimization

### 7. Session Management
- **OpenCode**: Full session tracking, export, import, list
- **Claude Code**: Session continuation support
- **Codex**: No session management
- **Gemini**: Session tracking via /stats (interactive only)
- **Impact**: Best session management capabilities

### 8. Model Selection
- **OpenCode**: `-m provider/model` format (e.g., `anthropic/claude-sonnet-4`)
- **Claude Code**: `--model sonnet` (short names)
- **Codex**: Environment variable based
- **Gemini**: `-m model-name`
- **Impact**: Different format, requires provider prefix

### 9. Cost Reporting
- **OpenCode**: ✅ Real-time USD cost in JSON events
- **Claude Code**: ✅ Cost in some events
- **Codex**: ❌ No cost reporting
- **Gemini**: ❌ No cost reporting in CLI
- **Impact**: Excellent for budget tracking

### 10. Configuration Files
- **OpenCode**: `opencode.json` + AGENTS.md + agent files
- **Claude Code**: `.claude` directory
- **Codex**: `.codex` directory
- **Gemini**: GEMINI.md file
- **Impact**: Most comprehensive configuration system

## Recommendations for Curb Harness Implementation

### Minimum Viable Implementation

```bash
opencode_invoke() {
    local system_prompt="$1"
    local task_prompt="$2"
    local debug="${3:-false}"

    # Clear previous usage
    harness_clear_usage

    # Option 1: Simple concatenation (like Gemini/Codex)
    local combined_prompt="${system_prompt}

---

${task_prompt}"

    local flags=""
    [[ "$debug" == "true" ]] && flags="$flags --print-logs --log-level DEBUG"

    # Add model flag if specified (requires provider prefix)
    if [[ -n "${CURB_MODEL:-}" ]]; then
        # If model doesn't contain '/', assume anthropic provider
        if [[ "$CURB_MODEL" != */* ]]; then
            flags="$flags -m anthropic/$CURB_MODEL"
        else
            flags="$flags -m $CURB_MODEL"
        fi
    fi

    # Invoke with combined prompt (stdin not needed, use positional args)
    opencode run $flags "$combined_prompt"
}

opencode_invoke_streaming() {
    local system_prompt="$1"
    local task_prompt="$2"
    local debug="${3:-false}"

    # Clear previous usage
    harness_clear_usage

    local combined_prompt="${system_prompt}

---

${task_prompt}"

    local flags="--format json"
    [[ "$debug" == "true" ]] && flags="$flags --print-logs --log-level DEBUG"

    # Add model flag if specified
    if [[ -n "${CURB_MODEL:-}" ]]; then
        if [[ "$CURB_MODEL" != */* ]]; then
            flags="$flags -m anthropic/$CURB_MODEL"
        else
            flags="$flags -m $CURB_MODEL"
        fi
    fi

    # Pipe to parser for token extraction
    opencode run $flags "$combined_prompt" | opencode_parse_stream
    return ${PIPESTATUS[0]}
}

opencode_parse_stream() {
    # Clear previous usage before parsing new stream
    harness_clear_usage

    local total_input=0
    local total_output=0
    local total_cache_read=0
    local total_cache_write=0
    local total_reasoning=0
    local final_cost=""

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue

        local msg_type=$(echo "$line" | jq -r '.type // empty' 2>/dev/null)

        case "$msg_type" in
            "text")
                # Extract and display text content
                local text=$(echo "$line" | jq -r '.part.text // empty' 2>/dev/null)
                [[ -n "$text" ]] && echo "$text"
                ;;
            "step_finish")
                # Extract token usage
                local input=$(echo "$line" | jq -r '.part.tokens.input // 0' 2>/dev/null)
                local output=$(echo "$line" | jq -r '.part.tokens.output // 0' 2>/dev/null)
                local reasoning=$(echo "$line" | jq -r '.part.tokens.reasoning // 0' 2>/dev/null)
                local cache_read=$(echo "$line" | jq -r '.part.tokens.cache.read // 0' 2>/dev/null)
                local cache_write=$(echo "$line" | jq -r '.part.tokens.cache.write // 0' 2>/dev/null)
                local cost=$(echo "$line" | jq -r '.part.cost // empty' 2>/dev/null)

                # Accumulate (multiple steps possible)
                total_input=$((total_input + input))
                total_output=$((total_output + output))
                total_reasoning=$((total_reasoning + reasoning))
                total_cache_read=$((total_cache_read + cache_read))
                total_cache_write=$((total_cache_write + cache_write))
                [[ -n "$cost" && "$cost" != "null" ]] && final_cost="$cost"
                ;;
        esac
    done

    # Store accumulated usage
    # Note: OpenCode reports cache.write, harness.sh expects cache_creation_tokens
    _harness_store_usage "$total_input" "$total_output" "$total_cache_read" "$total_cache_write" "$final_cost"
}
```

### Advanced Implementation (Optional)

For production use, consider:

1. **Setup AGENTS.md file** in project root:
   ```bash
   opencode_setup_project() {
       local system_prompt="$1"
       local agents_file=".opencode/AGENTS.md"
       mkdir -p .opencode
       echo "$system_prompt" > "$agents_file"
       echo "Created $agents_file with system prompt"
   }
   ```

2. **Use custom agent** for optimized performance:
   ```bash
   # Create opencode.json with custom agent
   cat > opencode.json <<EOF
   {
     "agent": {
       "curb": {
         "description": "Autonomous coding agent for Curb",
         "mode": "primary",
         "model": "anthropic/claude-sonnet-4-20250514",
         "permissions": { "edit": "allow", "bash": "allow" },
         "prompt": "{file:./.opencode/AGENTS.md}"
       }
     }
   }
   EOF

   # Then invoke with --agent curb
   opencode run --agent curb "$task_prompt"
   ```

### Challenges to Address

1. **Command Structure**:
   - Must use `opencode run` instead of direct invocation
   - Solution: Include `run` in all invocation commands

2. **Model Format**:
   - Requires `provider/model` format
   - Solution: Auto-prepend `anthropic/` if no `/` in model name
   - Test with different providers (OpenAI, etc.)

3. **Token Field Names**:
   - OpenCode uses `cache.read` and `cache.write`
   - harness.sh expects `cache_read_tokens` and `cache_creation_tokens`
   - Solution: Map `cache.write` to `cache_creation_tokens`

4. **Reasoning Tokens**:
   - OpenCode reports separate `reasoning` tokens (for o1 models)
   - harness.sh doesn't track reasoning tokens separately
   - Solution: Could add to `output_tokens` or ignore for now

5. **System Prompt Strategy**:
   - Multiple options available (concatenation, AGENTS.md, agent config)
   - Solution: Start with concatenation for MVP, offer AGENTS.md setup command
   - Document trade-offs in code comments

### Future Enhancements

1. **Agent Selection**: Allow `CURB_AGENT` env var to specify agent
2. **Session Continuity**: Use `--continue` for conversation continuity
3. **Stats Integration**: Parse `opencode stats` for budget tracking
4. **File Attachments**: Support `-f` flag for context files
5. **Custom Agent Creation**: `curb-init` could create custom OpenCode agent

## Testing Checklist

- [x] Installation method documented (Homebrew + others)
- [x] Basic invocation working (`opencode run`)
- [x] Flags mapped to curb needs (--format json, -m, --print-logs)
- [x] Token reporting capability assessed (EXCELLENT - full JSON events)
- [x] Findings written to .chopshop/spikes/opencode.md

## References

- [OpenCode CLI Documentation](https://opencode.ai/docs/cli/)
- [OpenCode Agents Documentation](https://opencode.ai/docs/agents/)
- [OpenCode Rules Documentation](https://opencode.ai/docs/rules/)
- [OpenCode Config Documentation](https://opencode.ai/docs/config/)
- [GitHub: opencode-ai/opencode](https://github.com/opencode-ai/opencode)
- [GitHub: anomalyco/opencode](https://github.com/sst/opencode)

## Next Steps

Task curb-lop (Implement OpenCode harness) can proceed with:
1. Basic implementation following Claude/Gemini patterns
2. Use `opencode run` command with `--format json` for streaming
3. Parse `step_finish` events for token usage extraction
4. Map `cache.read` → `cache_read_tokens`, `cache.write` → `cache_creation_tokens`
5. Handle `provider/model` format for model selection
6. Consider AGENTS.md setup for production use
7. Document reasoning token handling (currently not tracked)
