# Inventory Queries

Tenant-scoped lookups. `query_graphql` is already scoped to the current tenant; there is no tenant
argument. Every `reputation` field below is `null` for artifacts the reputation service has not
assessed yet.

## MCP server by name, with its reputation

`search` is a case-insensitive substring match. Prefer it over `name: { in: [...] }`, which needs the
exact stored name.

```graphql
query {
  mcpServers(filter: { search: "github" }, first: 5) {
    totalCount
    nodes {
      id
      name
      version
      protocol
      publisher {
        name
        verified
      }
      reputation {
        riskLevel
        summary
        signature
        assessedAt
        behaviors {
          behavior
        }
      }
    }
  }
}
```

If `totalCount` is 0, the artifact is not in this tenant's inventory. Fall back to the catalog
(`references/queries/catalog.md`) and tell the user it is not installed here.

## Riskiest MCP servers in the inventory

There is no server-side ordering by reputation. Fetch a page ordered by severity or findings, then
sort by `reputation.riskLevel` yourself (MALICIOUS > SUSPICIOUS > UNKNOWN > BENIGN > TRUSTED > null).

```graphql
query {
  mcpServers(orderBy: [{ field: FINDINGS_COUNT, direction: DESC }], first: 25) {
    totalCount
    nodes {
      id
      name
      severity
      flagged
      reputation {
        riskLevel
        signature
      }
    }
  }
}
```

State how many you inspected out of `totalCount`; do not claim the whole inventory was ranked.

## Impact: which agents depend on a server

Agents relate to a server through the tools they call, so filter agents by the tool's server name. Use
the exact `name` returned by the lookup above; `serverName.in` is an exact match, not a search.

```graphql
query {
  agents(filter: { tools: { mcpServer: { serverName: { in: ["MCP_SERVER_NAME"] } } } }, first: 10) {
    totalCount
    nodes {
      id
      name
      severity
      environment {
        name
      }
    }
  }
}
```

Report `totalCount` and the first names; link to `/inventory/mcp-server/<id>` for the rest. For the server's own
findings count, select `findings { totalCount }` on the `mcpServer(id)` node (it takes no arguments).

## Evidence for a specific behavior

Only when the user asks "show me why" or "where did you see that". Quotes are long; fetch one server
at a time.

```graphql
query {
  mcpServer(id: "MCP_SERVER_ID") {
    name
    reputation {
      riskLevel
      behaviors {
        behavior
        evidence {
          quote
          location
        }
      }
    }
  }
}
```

## Skills

`reputation` is exposed on the graph `Skill` node, not on the flat inventory skill list. For a skill by
name, use the catalog with `filter: { nodeType: [SKILL], search: "<name>" }`
(`references/queries/catalog.md`), then mention whether the skill appears in `/inventory/skill`.
