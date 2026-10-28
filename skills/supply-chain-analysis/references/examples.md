# Worked Examples

Each example lists the tool calls and the shape of the final answer. Values are illustrative.

## 1. Tenant-scoped hit

**User:** "Is our GitHub MCP server safe?"

1. `graphql_introspection` `describe` `McpServerFilter`, `ReputationAssessment`.
2. `query_graphql` inventory lookup with `filter: { search: "github" }` (see `queries/inventory.md`).
3. `reputation.riskLevel` is `SUSPICIOUS`; behaviors `RUNS_SHELL_COMMANDS`, `READS_WRITES_FILES`.

**Answer:**

> **Rating:** SUSPICIOUS - published by `github` (verified), signed, assessed 2026-08-18.
> **Why:** <summary>.
> **Behaviors:** runs git commands with file paths interpolated into the shell; reads and writes files
> in the working directory.
> **Recommendation:** review. These are the product's capabilities, so allow it for coding agents and
> keep it away from agents that only need read access. Want me to list the agents that use it?

## 2. Not installed, found in catalog

**User:** "Is `bonero-miner` trustworthy?"

1. Inventory lookup returns `totalCount: 0`.
2. Catalog lookup `reputations(filter: { search: "bonero" })` returns a `SkillReputationAssessment`,
   `SUSPICIOUS`, behaviors `SUSPICIOUS_DOWNLOAD`, `MODIFIES_SYSTEM_SERVICES`.

**Answer:**

> Not installed in this tenant. In the catalog it is rated **SUSPICIOUS** - published by
> `kbarbel640-del` (unverified), signature unknown.
> **Why:** the skill instructs the agent to pipe a remote install script to bash and run a Monero-fork
> miner on the host CPU.
> **Recommendation:** block if anyone requests it; nothing to remediate today.

## 3. Unassessed artifact

**User:** "Is `internal-hr-mcp` safe?"

1. Inventory lookup finds it; `reputation` is `null`.
2. Catalog lookup returns `totalCount: 0`.

**Answer:**

> `internal-hr-mcp` is in the inventory but the reputation service has not assessed it, so there is no
> rating to report. What I can see: publisher `acme-internal` (unverified), unsigned, 3 agents use it.
> Check the Supply Chain page for assessment status; until then treat it as unreviewed rather than safe.

## 4. Several matches

**User:** "Is `autocad-mcp` safe?"

Catalog lookup returns two: `autocad-mcp` by `puran-water` and `autocad-mcp-server` by `zh19980811`.

**Answer:**

> Two assessed artifacts match. Which one do you mean?
>
> - `autocad-mcp` (puran-water, unverified, unsigned) - SUSPICIOUS: runs arbitrary AutoLISP from callers.
> - `autocad-mcp-server` (zh19980811, unverified, signed) - SUSPICIOUS: passes caller SQL to SQLite
>   unparameterised.
>
> Neither is installed here.

## 5. Riskiest in the inventory

**User:** "Which of my MCP servers should I worry about?"

1. Inventory page ordered by `FINDINGS_COUNT DESC`, `first: 25`, selecting `reputation.riskLevel`.
2. Sort client-side: MALICIOUS, then SUSPICIOUS, then unassessed.

**Answer:**

> Of the 25 servers with the most findings (out of 41 in the inventory), none are MALICIOUS, 9 are
> SUSPICIOUS, 6 are unassessed. Top three to review:
>
> 1. `chatwithcloud-mcp` - runs agent-supplied JavaScript against your AWS account with local
>    credentials.
> 2. `codex-as-mcp` - launches Codex with sandboxing and approvals disabled.
> 3. `apple-mcp` - interpolates tool arguments into AppleScript.
>
> I ranked the top 25 by findings, not the whole inventory. Want the rest?

## 6. Impact question

**User:** "Who is using `agent-mcp-node`?"

1. Inventory lookup by name to get the exact `name`, `id`, and rating.
2. `agents(filter: { tools: { mcpServer: { serverName: { in: ["agent-mcp-node"] } } } }, first: 10)`.

**Answer:**

> `agent-mcp-node` is SUSPICIOUS (interpolates unvalidated arguments into tmux shell commands, exposes
> stored tokens through tools). 4 agents depend on it: `deploy-bot`, `infra-assistant` (production),
> `dev-helper`, `sandbox-agent` (development). Full list: /inventory/mcp-server/<id>.
