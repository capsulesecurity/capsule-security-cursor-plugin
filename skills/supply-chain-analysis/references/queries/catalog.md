# Catalog Queries

The global reputation catalog: every artifact the reputation service has assessed, whether or not this
tenant has it installed. Roughly two thousand entries; pages are capped at 100.

## Artifact by name

```graphql
query {
  reputations(filter: { search: "stripe" }, first: 5) {
    totalCount
    nodes {
      __typename
      id
      name
      nodeType
      riskLevel
      summary
      signature
      version
      publisher {
        name
        verified
      }
      sourceUrl
      assessedAt
    }
  }
}
```

- `search` is a case-insensitive substring match. Several results usually means variants or forks;
  show them all with their publishers and let the user pick, or match on `publisher.name` when the
  user named one.
- `totalCount` 0 means the service has not assessed it. Say so and point to the Supply Chain page.
- `__typename` tells you the kind: `McpReputationAssessment` or `SkillReputationAssessment`.

## Restrict to skills or MCP servers

```graphql
query {
  reputations(filter: { nodeType: [SKILL], search: "browser" }, first: 5) {
    totalCount
    nodes {
      name
      riskLevel
      summary
      publisher {
        name
        verified
      }
    }
  }
}
```

`nodeType` accepts `MCP` and `SKILL`.

## Riskiest assessed artifacts

Omit `search`; `RISK_LEVEL DESC` puts malicious first. Without `orderBy` the catalog sorts the same
way (risk desc, then name).

```graphql
query {
  reputations(orderBy: [{ field: RISK_LEVEL, direction: DESC }], first: 10) {
    totalCount
    nodes {
      name
      nodeType
      riskLevel
      publisher {
        name
        verified
      }
    }
  }
}
```

## MCP-specific detail

Only MCP assessments carry `sourceType` (`MCP_SERVER`, `CONNECTOR`, `PLUGIN`). Use an inline fragment.

```graphql
query {
  reputation(id: "ASSESSMENT_ID") {
    name
    riskLevel
    summary
    signature
    behaviors {
      behavior
    }
    ... on McpReputationAssessment {
      sourceType
    }
  }
}
```

## Older backends

If `graphql_introspection` `describe` `ReputationFilter` shows no `search` field, the backend predates the name filter. Page
by name (`orderBy: [{ field: NAME, direction: ASC }]`, `first: 100`) and tell the user which range
you covered rather than paging blindly through the whole catalog.
