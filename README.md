# Capsule Security

Real-time observability and security for AI agents in Cursor. Capsule Security captures every agent interaction — prompts, responses, tool calls, MCP executions, and shell commands — and streams them to the [Capsule Security](https://capsule.security) platform for behavioral analysis, threat prevention, and audit.

- **Behavioral analysis** — builds a baseline of normal agent activity and detects anomalous patterns across sessions, tools, and commands
- **Prevention, not just detection** — intercepts risky actions before they execute, blocking prompt injection, unauthorized tool use, and policy violations in real time
- **Low latency** — hooks stream events asynchronously with sub-millisecond overhead; agent workflows run at full speed with no perceptible delay
- **High accuracy** — purpose-built detection models tuned for AI agent threat patterns, minimizing false positives so your team stays focused on real risks
- **Enterprise ready** — SOC 2 compliant, supports SSO, role-based access, workspace-level policies, and centralized dashboard for security teams managing fleets of developer agents

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

- **Full session audit trail** — every prompt, response, and tool call is recorded with tamper-proof logging
- **Behavioral baselines** — learns normal agent patterns per workspace and alerts on deviations
- **Active prevention** — blocks prompt injection, data exfiltration, and unauthorized tool access before damage is done
- **MCP configuration monitoring** — detects changes to MCP server setups across workspaces and flags misconfigurations
- **Shell command visibility** — tracks every command the agent executes and enforces command-level policies
- **Centralized dashboard** — unified view across teams, workspaces, and agents for security and compliance teams

## Requirements

- Python 3 (used by the `sessionStart` hook to collect MCP configurations)
- `curl` (used by all other hooks to forward events)
- A valid Capsule Security account and JWT token

## License

MIT
