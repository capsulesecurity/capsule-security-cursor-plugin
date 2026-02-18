# Capsule Security

Real-time observability and security monitoring for AI agents in Cursor. Capsule Security captures every agent interaction — prompts, responses, tool calls, MCP executions, and shell commands — and streams them to the [Capsule Security](https://capsulesecurity.dev) platform for analysis, audit, and threat detection.

## How it works

The plugin installs a set of hooks that fire at key points in the agent lifecycle. Each hook forwards the event payload to the Capsule Security API where it is analyzed in real time.

| Hook | What it captures |
|:-----|:-----------------|
| `sessionStart` | New session metadata and MCP server configurations from the workspace |
| `beforeSubmitPrompt` | Every prompt before it reaches the agent |
| `afterAgentResponse` | Agent responses as they are produced |
| `afterAgentThought` | Internal agent reasoning steps |
| `afterMCPExecution` | MCP tool invocations and their results |
| `afterShellExecution` | Shell commands executed by the agent |

On session start, the plugin also scans `.cursor/projects/` for MCP configuration files and uploads them for security review.

## Installation

```
/add-plugin capsule-security
```

## Configuration

Two environment variables control the plugin:

| Variable | Required | Description |
|:---------|:---------|:------------|
| `CAPSULE_SECURITY_JWT` | Yes | Bearer token for authenticating with the Capsule Security API |
| `CAPSULE_SECURITY_DOMAIN` | No | API domain. Defaults to `agentsecurity.dev-eu-west1.capsulesecurity.dev` |

Set them in your shell profile (`~/.zshrc`, `~/.bashrc`) or in your CI environment:

```bash
export CAPSULE_SECURITY_JWT="your-token-here"
# Optional — override the default API domain
# export CAPSULE_SECURITY_DOMAIN="custom.capsulesecurity.dev"
```

## What you get

- **Full session audit trail** — every prompt, response, and tool call is recorded
- **MCP configuration monitoring** — detects changes to MCP server setups across workspaces
- **Shell command visibility** — tracks every command the agent executes in your terminal
- **Real-time threat detection** — Capsule Security analyzes events as they stream in, flagging prompt injection attempts, suspicious tool usage, and policy violations

## Requirements

- Python 3 (used by the `sessionStart` hook to collect MCP configurations)
- `curl` (used by all other hooks to forward events)
- A valid Capsule Security account and JWT token

## License

MIT
