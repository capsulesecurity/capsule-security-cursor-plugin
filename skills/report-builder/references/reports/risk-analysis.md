# Risk Analysis Report

A security-posture report over a time window: the threat landscape, highest-risk
violations, a deep dive into the evidence behind every critical violation, real-time
blocks, and a
watch-list of what needs follow-up. This is the portal equivalent of the daily
detection report, sourced live through `query_graphql` instead of a warehouse export.

## When to use

The user asks for a "risk analysis", "security posture", "detection digest", "daily
detection report", or a period report ("what happened this week / last 30 days").
Ask for the time window if it isn't given; default to the last 7 days. "Daily" or
"yesterday" means the previous calendar day, midnight to midnight UTC.

## Scope & constraints (read first - these shape what the report can say)

- **Single tenant, always.** `query_graphql` is scoped to the current tenant by the
  server; there is no tenant parameter and no cross-tenant query. So there is **no
  by-tenant breakdown** and **no internal-tenant exclusion** to do - the report is
  one tenant's data by construction.
- **"Issue" is a `Violation` here.** The violation surface (`violations`,
  `violation(id)`, `Violation`) is the issue-centric core of the report.
- **Raw signals vs. violations.** A detection (runtime) or finding (posture) becomes a
  violation only when a policy matches it, and the policy sets the severity. The two
  are different counts: one signal can match several policies and produce several
  violations, and one violation can aggregate several signals. Report both and label
  them; never present a raw count as a violation count, and do not reconcile them.
- **Aggregate-first.** `query_graphql` returns pre-computed aggregations on fixed
  dimensions only - there is no generic `GROUP BY`. Response is capped (~16 KB, truncated lists carry a __truncated marker). Build the report from counts and the top-N
  slices below; do not attempt an exhaustive per-record table.
- **Severity focus (high + critical).** `PolicySeverity` is `LOW|MEDIUM|HIGH|CRITICAL`.
  Severity lives on `Violation`/`Policy`, not on `Detection`/`Finding` (those aggregate
  by _type_ only). Filter violations with `severity: { in: [HIGH, CRITICAL] }`.
- **Volume over time is approximate.** There is no daily `GROUP BY DATE`. Use
  `activitiesTimelineChart` bins for a trend line.
- **Mask PII at assembly.** If you surface any evidence text (violation reasoning,
  detection descriptions, activity messages), redact emails, tokens/secrets, card
  numbers, and long digit runs before putting them in a block. Only leaked-value
  evidence `text` is redacted by the backend; citation text, reasoning and activity
  messages are not.
- **A failed query is a missing section, not zero.** If a query errors or hits the
  call budget, say which section is missing. Never fill it with 0 or "none found".
  Zero violations from a successful query is a valid, normal result - say so plainly.
- **Report, don't re-judge.** Describe each violation from its own `reasoning` and
  evidence. Do not rule on whether it is a true or false positive; the report surfaces
  the evidence so the reader can decide.

## Report structure

Emit `{ title, blocks: [...] }`. Recommended block order:

### 1. Executive summary - `summary` block

Prose headline: raw detections and findings in the window, high/critical violations
(split runtime vs. posture), how many were blocked by a PREVENTION policy, how many
critical violations are untriaged, and the single most notable signal. Derive from
the queries below; do not invent numbers.

### 2. Critical violations - deep dive - `section` per violation

Every critical violation in the window, with the evidence that triggered it. Put this
near the top: it is the part a reader acts on.

```graphql
query ($after: DateTime, $before: DateTime) {
  violations(
    first: 5
    orderBy: { field: CREATED_AT, direction: DESC }
    filter: { severity: { in: [CRITICAL] }, dateRange: { from: $after, to: $before } }
  ) {
    totalCount
    nodes {
      id
      name
      reasoning
      triageVerdict
      policy {
        name
        mode
      }
      agent {
        name
      }
      detections {
        type
        description
        session {
          id
        }
        evidence {
          ... on CitationEvidence {
            text
          }
          ... on LeakedValueEvidence {
            text
          }
        }
        evidenceUnavailable {
          reason
        }
        activities {
          message
        }
      }
      findings(first: 3) {
        nodes {
          type
          evidence {
            ... on CitationEvidence {
              text
            }
            ... on LeakedValueEvidence {
              text
            }
            ... on VulnerabilityEvidence {
              description
            }
          }
          evidenceUnavailable {
            reason
          }
        }
      }
    }
  }
}
```

If the response is truncated, fetch the remaining criticals one at a time with
`violation(id)`. If `totalCount` exceeds what the call budget allows, cover the ones you
fetched and state how many were left out.

Write each as a `section` headed by the violation name, containing:

- Policy, agent, detection/finding type, and the violation id prefix plus session id.
- A sanitized "what happened", from the violation's `reasoning` and the triggering
  activity messages.
- The evidence excerpts: leaked-value text verbatim (already redacted); citation and
  vulnerability text masked as above before quoting.
- If `evidenceUnavailable` is set on a detection or finding, say why (retention
  expired vs. never captured) instead of the excerpts.
- The human `triageVerdict` when one is set; otherwise "untriaged".

If there are no critical violations, say so in one line and skip the section.

**Go deeper.** When the reader wants more on one side than this digest gives, open
`findings-posture.md` (posture) or `detections-runtime.md` (runtime) and follow that reference's deep dive instead of expanding this one.

### 3. Threat landscape - `threats` block + a `chart`

Raw volume: every detection and finding in the window, whether or not it became a
violation. Pass the `byType` aggregations straight into a `threats` block (type code +
count rows), and optionally a bar `chart` of the same data. Scope them to the
reporting period with `filter.activityWindow`; omit it and the counts are tenant-wide,
which you should say rather than attributing them to the requested period.

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

Call out a type with a large raw count but few or no violations: that volume is
being detected but no policy promotes it, which is a coverage question for the reader.

### 4. Highest-risk violations - `section` + `chart`

The core "issues" list: high and critical only, severity first. The `groups` field on
the same connection gives the severity split over the full filtered set, not just
the returned page.

```graphql
query ($after: DateTime, $before: DateTime) {
  violations(
    first: 10
    orderBy: { field: SEVERITY, direction: DESC }
    filter: { severity: { in: [HIGH, CRITICAL] }, dateRange: { from: $after, to: $before } }
  ) {
    totalCount
    groups(grouping: { key: SEVERITY }, filter: { severity: { in: [HIGH, CRITICAL] }, dateRange: { from: $after, to: $before } }) {
      nodes {
        groupValue
        totalCount
      }
    }
    nodes {
      id
      name
      severity
      detectedAt
      reasoning
      triageVerdict
      policy {
        name
        mode
      }
      agent {
        name
      }
      detections {
        type
        session {
          id
        }
      }
      findings(first: 3) {
        nodes {
          type
        }
      }
    }
  }
}
```

Render the severity groups as a chart. Summarize each violation in a sentence from its
own `reasoning` (masked), tagged runtime (has detections) or posture (has findings).
Reference violations by the first 8 characters of `id`, plus the session id for
runtime ones, so a reader can find them in the portal.

### 5. Real-time blocks - `section` + `chart`

A violation is blocked when its policy is in PREVENTION mode; MONITORING and WARNING
record but allow. Policy mode is read as it is today, not as it was when the violation
fired, so label this section "under current PREVENTION policies" rather than as
blocks at the time. Count in two steps: fetch the PREVENTION policy ids, then count
violations against them.

```graphql
query {
  policies(filter: { mode: { in: [PREVENTION] } }) {
    nodes {
      id
    }
  }
  byMode: policyCountsByMode {
    mode
    count
  }
}
```

```graphql
query ($after: DateTime, $before: DateTime, $preventionPolicyIds: [String!]) {
  blocked: violations(first: 5, filter: { policy: { id: { in: $preventionPolicyIds } }, dateRange: { from: $after, to: $before } }) {
    totalCount
    nodes {
      name
      policy {
        name
      }
      agent {
        name
      }
    }
  }
}
```

Report the blocked count against the total violation count, and render `byMode` as a
doughnut/bar chart of policy coverage. If no policy is in PREVENTION mode, say that
nothing is being blocked in real time; that is a finding in itself.

### 6. Volume over time - `chart`

Approximate daily trend. Choose `binCount` for the window (e.g. ~1 bin/day).

```graphql
query ($after: DateTime!, $before: DateTime!) {
  activitiesTimelineChart(input: { binCount: 60, timeRange: { after: $after, before: $before } }) {
    totalActivities
    bins {
      timestamp
      count
    }
  }
}
```

Render `bins` as a line chart. Note in prose that bins approximate days. Skip this
section for a single-day report.

### 7. Top exposed agents / owners - `section` or `chart`

```graphql
query ($after: DateTime!, $before: DateTime!) {
  topAgentCountByOwner(after: $after, before: $before, limit: 5) {
    owner {
      name
    }
    count
  }
  topAgentCountByFindingType(after: $after, before: $before, limit: 5) {
    findingType
    count
  }
}
```

### 8. Watch-list - `section`

Close with a short list of what needs a human next, derived from the data above. Only
include items that are present; an empty watch-list is a fine outcome. Candidates:

- Critical violations that are still untriaged.
- Violations whose evidence is unavailable, so they cannot be verified.
- A detection type with high raw volume but no violations (no policy covers it).
- An agent or owner that dominates the violation count.

Each item: one line, the violation id prefix or type, and why it is on the list.
