<p align="center">
  <img src="https://cdn.capsulesecurity.io/logo.svg" alt="Capsule Security" width="400">
</p>

# Capsule Security Plugin for Cursor

Real-time observability and security for AI agents in Cursor. Capsule Security captures every agent interaction — prompts, responses, tool calls, MCP executions, and shell commands — and streams them to the [Capsule Security](https://capsule.security) platform for behavioral analysis, threat prevention, and audit.

It also ships the **Capsule MCP server** and **Capsule skills**, so you can ask the agent about your AI inventory, vet MCP servers and skills for supply-chain risk, and generate branded risk reports without leaving the editor.

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
| `beforeSubmitPrompt` | Every prompt before it reaches the agent — can block prompt injection |
| `afterAgentResponse` | Agent responses as they are produced |
| `afterAgentThought` | Internal agent reasoning steps |
| `afterMCPExecution` | MCP tool invocations and their results |
| `afterShellExecution` | Shell commands executed by the agent |
| `beforeShellExecution` | Shell commands before execution — can block dangerous commands |
| `beforeMCPExecution` | MCP tool calls before execution — can block unauthorized or risky tool use |

On session start, the plugin also scans `.cursor/projects/` for MCP configuration files and uploads them for security review.

## Capsule MCP server

The plugin registers the [Capsule MCP server](https://www.npmjs.com/package/@capsulesecurity/capsule-mcp-server) (`@capsulesecurity/capsule-mcp-server`, run locally over stdio via `npx`), so the agent can query your Capsule tenant directly instead of guessing. Access is **read-only** and scoped to the single tenant that owns the service account.

| Tool | Purpose |
|:-----|:--------|
| `graphql_introspection` | Search and describe the Capsule schema, and diagnose a query before it runs |
| `query_graphql` | Run a read-only GraphQL query against your tenant |
| `generate_report` | Render content blocks (summary, threats, sections, charts) into a branded PDF |
| `export_csv` | Export query results as a CSV |

Try asking:

- "Using Capsule, list our AI agents and how many policy violations each had in the last 7 days."
- "Which of our MCP servers are rated high risk, and which agents depend on them?"
- "Build a CISO report of this month's detections and findings."

## Skills

| Skill | What it does |
|:------|:-------------|
| `report-builder` | Builds a downloadable PDF risk digest from live Capsule data, with audience-specific layouts (risk analysis, posture findings, runtime detections, SOC analyst, AI engineer, CISO, executive briefing) |
| `supply-chain-analysis` | Assesses whether an MCP server, skill, connector, or plugin is safe to trust, using Capsule's reputation assessments, and recommends block / review / allow |
| `capsule-brand` | Capsule brand guidelines (palette, typography, tone) used when producing reports |

The skills are generated from the Capsule monorepo. To refresh them, run `node scripts/sync-skills.mjs [path-to-capsule3]`.

## Installation

```
/add-plugin capsule-security
```

## Configuration

The plugin is configured through environment variables:

| Variable | Used by | Required | Description |
|:---------|:--------|:---------|:------------|
| `CAPSULE_SECURITY_JWT` | Hooks | Yes | Bearer token for authenticating with the Capsule Security API |
| `CAPSULE_SECURITY_DOMAIN` | Hooks | No | API domain. Defaults to `agentsecurity.us-east1.capsulesecurity.io` |
| `CAPSULE_CLIENT_ID` | MCP server | Yes | Client ID of a Capsule service account (**Settings → Service Accounts** in the portal) |
| `CAPSULE_CLIENT_SECRET` | MCP server | Yes | Client secret of that service account (shown only once, at creation time) |
| `CAPSULE_API_URL` | MCP server | No | Regional API. Defaults to US (`https://portal.us-east1.capsulesecurity.io/api`); EU tenants use `https://portal.eu-west4.capsulesecurity.io/api` |

Set them in your shell profile (`~/.zshrc`, `~/.bashrc`) or in your CI environment, then restart Cursor:

```bash
export CAPSULE_SECURITY_JWT="your-token-here"
# Optional — override the default API domain
# export CAPSULE_SECURITY_DOMAIN="custom.capsulesecurity.dev"

# Capsule MCP server
export CAPSULE_CLIENT_ID="your-client-id"
export CAPSULE_CLIENT_SECRET="your-client-secret"
# EU tenants only
# export CAPSULE_API_URL="https://portal.eu-west4.capsulesecurity.io/api"
```

Give each user their own service account: requests are rate limited to 60 per minute per service account.

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
- Node.js 20 or later (used to run the Capsule MCP server)
- A valid Capsule Security account, JWT token, and service account

## License

MIT
