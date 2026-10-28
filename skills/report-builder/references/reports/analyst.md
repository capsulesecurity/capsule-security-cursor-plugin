# Analyst Report

A SOC-analyst digest: what detections and findings were discovered in the window,
**who owns** the affected agents, and **who responded and how** — triage verdicts and
policy enforcement (e.g. a policy that blocked the activity). Optimized for fast triage,
not executive summary.

## When to use

The user asks for an "analyst report", "triage summary", "what did we catch and how did
we respond", or an ownership/response breakdown. Ask for the window if not given; default
to the last 7 days.

## Scope & constraints (read first)

- **Single tenant, server-scoped.** No tenant parameter, no cross-tenant query.
- **Aggregate-first.** No generic `GROUP BY`; pre-computed aggregations only, response
  capped (~16 KB, truncated lists carry a __truncated marker). For the triage breakdown
  there is **no server-side group-by verdict** — fetch violation nodes and count verdicts
  yourself from the returned page; say so if the page is truncated.
- **"Issue" is a `Violation`.** Policy enforcement surfaces through `violations`
  (ordered by severity) and `policy.mode` (PREVENTION = blocked).
- **Triage verdict** is `TRUE_POSITIVE | FALSE_POSITIVE | IGNORED`, or null when untriaged.
- **Mask PII at assembly** — redact emails/tokens/long digit runs from any surfaced
  detection title or owner detail before putting it in a block.

## Report structure

Emit `{ title, blocks: [...] }`.

### 1. Summary — `summary` block

Headline: how many detections and findings were discovered, how many were triaged vs
untriaged, and how many were blocked by a prevention policy. Derive from the aggregates
below.

### 2. Discovered — `threats` block + optional `chart`

Pass the `byType` aggregations into a `threats` block. Scope them to the reporting period
with `filter.activityWindow`; omit it and the counts are tenant-wide, which you should say
rather than attributing them to the requested period.

```graphql
query ($after: DateTime!, $before: DateTime!) {
  agents(filter: { activityWindow: { after: $after, before: $before } }) {
    aggregations {
      detections {
        total
        byType {
          type
          count
        }
      }
      findings {
        total
        byType {
          type
          count
        }
      }
    }
  }
}
```

### 3. Ownership — `section` or `chart`

Who owns the affected agents.

```graphql
query ($after: DateTime!, $before: DateTime!) {
  topAgentCountByOwner(after: $after, before: $before, limit: 10) {
    owner {
      name
      email
    }
    count
  }
}
```

### 4. Response & triage — `section`

Pull recent violations and read their verdict + who owns them. Count verdicts
(TRUE_POSITIVE / FALSE_POSITIVE / IGNORED / untriaged) client-side from the returned page.

```graphql
query ($after: DateTime!, $before: DateTime!) {
  violations(first: 25, filter: { dateRange: { from: $after, to: $before } }, orderBy: { field: CREATED_AT, direction: DESC }) {
    totalCount
    nodes {
      name
      triageVerdict
      triagedAt
      agent {
        name
        owner {
          name
        }
      }
      detections {
        title
        type
      }
    }
  }
}
```

### 5. Enforcement — `section`

How the platform responded. `policy.mode = PREVENTION` means the activity was blocked;
MONITORING/WARNING means it was recorded but allowed.

```graphql
query ($after: DateTime, $before: DateTime) {
  violations(first: 10, orderBy: { field: SEVERITY, direction: DESC }, filter: { dateRange: { from: $after, to: $before } }) {
    nodes {
      name
      detectedAt
      policy {
        name
        mode
        severity
      }
      agent {
        name
        owner {
          name
        }
      }
    }
  }
}
```
