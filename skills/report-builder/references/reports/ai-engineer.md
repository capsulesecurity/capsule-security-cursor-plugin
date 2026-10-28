# AI Engineer Report — AI Plumbing

For the AI engineer who owns the agent fleet's wiring. Explains and shows the
**relationships** — agents ↔ models ↔ tools ↔ MCP servers ↔ data sources — then surfaces
**bad practices and posture risks** in that plumbing. Ends with small **callouts worth
noticing** (e.g. unused Skills / MCP servers).

## When to use

The user asks for an "AI engineer report", "engineer report", "AI plumbing",
"supply-chain / MCP posture", "how are my agents wired", or "what's risky in the setup".
No time window is required — this is an inventory-and-posture view, not a period digest.

## Scope & constraints (read first)

- **Single tenant, server-scoped.** No tenant parameter, no cross-tenant query.
- **Aggregate-first.** No generic `GROUP BY`; response capped (~16 KB, truncated lists carry a __truncated marker). Show the top-N wired agents and top risk types, not the whole
  fleet; say so when the list is truncated.
- **Inventory lists return `Inventory*ListItem`**, not the graph `Agent`/`Tool`/`Skill`
  node — select fields off the list-item shape.
- **"Unused" is inferred**, not a flag: read `enabled` and `executionsSummary` (a `count`
  of 0 or a stale `lastExecutedAt`) — there is no `unused: true` field.

## Report structure

Emit `{ title, blocks: [...] }`.

### 1. Inventory scale — `summary` block

Headline the fleet size across resource types.

```graphql
query {
  agents {
    totalCount
  }
  tools {
    totalCount
  }
  skills {
    totalCount
  }
  models {
    totalCount
  }
  dataSources {
    totalCount
  }
  mcpServers {
    totalCount
  }
}
```

### 2. The plumbing — `section` (+ optional `chart` of tool protocols)

Show how the highest-severity agents are wired: their model, the tools they call, and the
MCP servers they consume. Describe the relationships in prose. `agents` is a cursor
connection and orders by name only, so pick the risky set with a severity filter rather
than an `orderBy`.

```graphql
query {
  agents(filter: { severity: { in: [CRITICAL, HIGH] } }, first: 10) {
    nodes {
      name
      severity
      owner {
        name
      }
      model {
        type
      }
      tools {
        name
        protocol
        mcpServer {
          name
        }
      }
      mcpServers {
        totalCount
        nodes {
          name
          protocol
        }
      }
    }
  }
}
```

### 3. Posture risks & bad practices — `threats` block + `section`

The finding types most concentrated across agents are the bad practices to call out
(e.g. `EXCESSIVE_PERMISSIONS`, `UNTRUSTED_CONTENT_INGESTION`, `HARDCODED_SECRETS`,
`AGENT_WITHOUT_OWNER`, `KNOWN_VULNERABILITY`, `UNUSED_TOOL`). Pass these into a
`threats` block and expand the top few in a `section`.

```graphql
query ($after: DateTime!, $before: DateTime!) {
  topAgentCountByFindingType(after: $after, before: $before, limit: 10) {
    findingType
    count
  }
}
```

### 4. Callouts worth noticing — `section`

Small, specific things the engineer should act on. **Unused skills**: `enabled: false` or
`executionsSummary.count` of 0.

```graphql
query {
  skills(first: 25) {
    totalCount
    nodes {
      name
      enabled
      executionsSummary {
        count
        lastExecutedAt
      }
      findings {
        nodes {
          type
        }
      }
    }
  }
}
```

**MCP servers** — flag high-severity servers, servers exposing tools but carrying findings,
or stale ones (`lastSeenAt`).

```graphql
query {
  mcpServers(first: 25) {
    totalCount
    nodes {
      name
      protocol
      severity
      lastSeenAt
      tools {
        totalCount
      }
      findings {
        totalCount
      }
    }
  }
}
```
