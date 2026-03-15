# Claude Code Unlimited — CLAUDE.md Instruction Snippet

Paste this into your project's CLAUDE.md or ~/.claude/CLAUDE.md to activate
the one-read-one-write workflow after CCU ingests your project.

```markdown
## CCU: One-Read-One-Write Protocol

At session start, CCU ingests the full project into context with line numbers.
After ingestion, every file is in your context as `path:linenum: content`.

Rules:
- DO NOT re-read files that were ingested. They are already in your context window.
- DO NOT use grep/search tools on the project. Search your context instead.
- EDIT DIRECTLY using the line numbers from ingestion (e.g., old_lines: "45-52").
- Files that were skipped (too large or over budget) can still be read normally.
- One read (at session start) + one write (per edit). No extra reads ever.

This works because the 1M token context window can hold entire codebases.
CCU ingests up to 800k tokens of source code with line-numbered output,
leaving ~200k tokens for conversation, system prompts, and tool results.
```

## Hook Setup

Add this to your `~/.claude/settings.json` hooks to wire up the Read interceptor:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Read",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/smart-read-interceptor.sh"
          }
        ]
      }
    ]
  }
}
```

Note: The interceptor is disabled by default in v2 (1M context makes file size
gating unnecessary). It exits immediately. If you're on a smaller context model,
remove the `exit 0` on line 3 of `hooks/smart-read-interceptor.sh` to re-enable.

## Session Start Hook (Optional)

To auto-ingest on every new session, add a SessionStart hook:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "type": "command",
        "command": "~/.claude/cache/ccu-ingest.sh"
      }
    ]
  }
}
```

This runs `ccu-ingest.sh` at session start, writes the full context file to
`~/.claude/cache/ccu-context.txt`, and prints a system message telling Claude
to read it as the first tool call. After that single read, no re-reads needed.
