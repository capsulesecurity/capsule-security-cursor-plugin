# Executive AI Risk Report

A board- and regulator-oriented posture summary for the CISO. Clarity over density:
every number carries business or regulatory context, and the report is meant to be
skimmed in minutes and pasted into a leadership deck. This is **not** a triage lane
(see `analyst.md`) and **not** fleet wiring (see `ai-engineer.md`). This is the portal
equivalent of the customer security report, sourced live through `query_graphql`.

## When to use

The user asks for a "CISO report", "executive summary", "board report",
"board-ready report", "customer security report", "compliance posture", "AI risk
posture for leadership", or a "shadow AI report". Weekly strategic horizon - default
to the last 7 days, but support 30/90-day windows for board cadence. Ask for the window
if it isn't given. The prior period is the window of the same length ending where this
one starts.

## Scope & constraints (read first - these shape what the report can honestly say)

- **Single tenant, server-scoped.** No tenant parameter, no cross-tenant query - the
  report is one organization's posture by construction.
- **Aggregate-first.** No generic `GROUP BY`; pre-computed aggregations only, response
  capped (~16 KB, truncated lists carry a __truncated marker). Build from counts and
  top-N slices; do not attempt exhaustive per-record tables. The queries below fit the
  budget when combined two per call; if one is skipped, say which section is missing.
- **Raw signals vs. violations.** Detections (runtime) and findings (posture) become
  violations only when a policy matches them. Report both and label them; never
  present a raw count as a violation count, and do not reconcile them.
- **Period-over-period, both values.** State every comparison as "N this period vs. M
  the prior period", never as a bare percentage or arrow. If the prior value is 0, say
  "new this period" instead of a percentage.
- **Compliance framing is _derived_, never certified.** `controlBreakdown` gives the
  framework controls the violations map to; it is exposure, not a control score.
  State plainly that "framework alignment is derived from posture signals, not a
  certified control assessment." Never fabricate a compliance percentage.
- **Shadow AI is _inferred_, not a flag.** There is no certified "registered vs. shadow"
  field. Express the gap as "discovered AI footprint (by resource type) against the
  governed inventory" and flag it as an estimate.
- **Mask PII at assembly.** Only leaked-value evidence `text` is redacted by the
  backend. Redact emails, tokens/secrets, card numbers, and long digit runs from any
  surfaced owner, reasoning, citation or activity text before putting it in a block.
- **Report, don't re-judge.** Describe each example from its own reasoning and
  evidence. Do not rule on whether it is a true or false positive; the human
  `triageVerdict` is the only verdict the report shows.

## Report structure

Emit `{ title, blocks: [...] }`. Keep this section order every time, so a reader
comparing two reports finds the same thing in the same place. Skip a section only when
its data is empty, and say so in one line.

### 1. Executive summary - `summary` block

One calm paragraph - the only thing the CISO is guaranteed to read. Total AI footprint
(agents, models and MCP servers from section 4), high/critical violations this period vs. the prior
period, prevention coverage, and the single biggest strategic risk. Derive from the
sections below; do not invent numbers.

### 2. Period at a glance - KPI `section` + `chart`

The KPI row of the customer report: detections, findings, runtime violations and
posture violations, each with this period's value and the prior period's. The
findings figures here are agent-anchored findings updated in each period; label them
"agent findings". Tenant-wide posture across every resource type is a current
snapshot, not a period count: take it from `findings-posture.md` section 2 when the
reader needs it.

```graphql
query ($after: DateTime!, $before: DateTime!, $prevAfter: DateTime!, $prevBefore: DateTime!) {
  current: agents(filter: { activityWindow: { after: $after, before: $before } }) {
    aggregations {
      detections {
        total
      }
      findings {
        total
      }
    }
  }
  prior: agents(filter: { activityWindow: { after: $prevAfter, before: $prevBefore } }) {
    aggregations {
      detections {
        total
      }
      findings {
        total
      }
    }
  }
  runtimeNow: violations(
    first: 1
    filter: { severity: { in: [HIGH, CRITICAL] }, policy: { triggerType: { in: [RUNTIME] } }, dateRange: { from: $after, to: $before } }
  ) {
    totalCount
  }
  runtimePrior: violations(
    first: 1
    filter: {
      severity: { in: [HIGH, CRITICAL] }
      policy: { triggerType: { in: [RUNTIME] } }
      dateRange: { from: $prevAfter, to: $prevBefore }
    }
  ) {
    totalCount
  }
  postureNow: violations(
    first: 1
    filter: { severity: { in: [HIGH, CRITICAL] }, policy: { triggerType: { in: [POSTURE] } }, dateRange: { from: $after, to: $before } }
  ) {
    totalCount
  }
  posturePrior: violations(
    first: 1
    filter: {
      severity: { in: [HIGH, CRITICAL] }
      policy: { triggerType: { in: [POSTURE] } }
      dateRange: { from: $prevAfter, to: $prevBefore }
    }
  ) {
    totalCount
  }
}
```

Render as a grouped bar chart (this period vs. prior, one group per KPI). Then the
activity trend. Each bin counts distinct sessions plus finding and issue events, not
messages, so label it "activity" (the customer report's messages-per-day chart has no
exact equivalent):

```graphql
query ($after: DateTime!, $before: DateTime!) {
  activitiesTimelineChart(input: { binCount: 30, timeRange: { after: $after, before: $before } }) {
    totalActivities
    bins {
      timestamp
      count
    }
  }
  byMode: policyCountsByMode {
    mode
    count
  }
}
```

Render `bins` as a line chart (bins approximate days). Prevention coverage = the
PREVENTION share of `byMode`, read as policies are configured today.

### 3. AI footprint - `chart` + short `section`

What is running and where: the customer report's agents-by-platform and
agents-by-accessibility charts.

```graphql
query ($after: DateTime!, $before: DateTime!) {
  agents {
    totalCount
  }
  byPlatform: topAgentCountByPlatform(after: $after, before: $before, limit: 10) {
    platform {
      name
    }
    count
  }
  byAccessibility: topAgentCountByAccessibility(after: $after, before: $before, limit: 5) {
    accessibility
    count
  }
}
```

Bar chart for platforms, doughnut for accessibility. Call out public or org-wide
agents: they widen the blast radius of every runtime detection.

### 4. Shadow AI vs. governed inventory - `section` + `chart` (the signature CISO section)

How much AI is running that leadership didn't register. Use the discovery footprint by
resource type as the discovered surface, and the governed inventory totals as the
managed baseline.

```graphql
query {
  discover(first: 200) {
    totalCount
    aggregations {
      byNodeType {
        type
        count
      }
    }
  }
  agents {
    totalCount
  }
  mcpServers {
    totalCount
  }
}
```

Frame prose as: discovered footprint (N resources across agents / models / MCP / tools,
from `byNodeType`) against the governed agent and MCP server inventory, and state that the shadow delta is an estimate derived
from discovery coverage, not a certified registration flag. Render as a stacked bar of
governed vs. discovered for agents and MCP servers only, the two types with a governed
total; give model and tool discovery counts in prose.

### 5. Security summary - `threats` block + `chart`s

The customer report's detection-type and finding-type distributions, plus the
severity split of the violations they produced. The finding-type split below is
agent-anchored; say so, or use the `discover { aggregations { byFindings } }`
snapshot from `findings-posture.md` for every resource type.

```graphql
query ($after: DateTime!, $before: DateTime!) {
  agents(filter: { activityWindow: { after: $after, before: $before } }) {
    aggregations {
      detections {
        byType {
          type
          count
        }
      }
      findings {
        byType {
          type
          count
        }
      }
    }
  }
}
```

```graphql
query ($after: DateTime, $before: DateTime) {
  runtime: violations(first: 1, filter: { policy: { triggerType: { in: [RUNTIME] } }, dateRange: { from: $after, to: $before } }) {
    totalCount
    bySeverity: groups(
      grouping: { key: SEVERITY }
      filter: { policy: { triggerType: { in: [RUNTIME] } }, dateRange: { from: $after, to: $before } }
    ) {
      nodes {
        groupValue
        totalCount
      }
    }
    byPolicy: groups(
      grouping: { key: POLICY, orderBy: COUNT }
      filter: { policy: { triggerType: { in: [RUNTIME] } }, dateRange: { from: $after, to: $before } }
      first: 10
    ) {
      nodes {
        label
        totalCount
      }
    }
  }
  posture: violations(first: 1, filter: { policy: { triggerType: { in: [POSTURE] } }, dateRange: { from: $after, to: $before } }) {
    totalCount
    bySeverity: groups(
      grouping: { key: SEVERITY }
      filter: { policy: { triggerType: { in: [POSTURE] } }, dateRange: { from: $after, to: $before } }
    ) {
      nodes {
        groupValue
        totalCount
      }
    }
    byPolicy: groups(
      grouping: { key: POLICY, orderBy: COUNT }
      filter: { policy: { triggerType: { in: [POSTURE] } }, dateRange: { from: $after, to: $before } }
      first: 10
    ) {
      nodes {
        label
        totalCount
      }
    }
  }
}
```

Put the combined `byType` rows in the `threats` block. Charts: detection types (bar),
finding types (bar), severity per side (doughnut), top policies per side (horizontal
bar). In prose, keep runtime ("what agents did") and posture ("how agents are built")
separate, and translate type codes into business impact: credential or PII exposure,
manipulation of an agent, destructive actions.

### 6. Notable examples - `section` per example

A handful of concrete violations that make the numbers real. Fetch high and critical
active violations, severity first:

```graphql
query ($after: DateTime, $before: DateTime) {
  violations(
    first: 15
    orderBy: { field: SEVERITY, direction: DESC }
    filter: { severity: { in: [HIGH, CRITICAL] }, status: { in: [ACTIVE, RESOLVED] }, dateRange: { from: $after, to: $before } }
  ) {
    totalCount
    nodes {
      id
      name
      severity
      status
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
        evidence {
          ... on LeakedValueEvidence {
            text
          }
        }
      }
      findings(first: 2) {
        nodes {
          type
        }
      }
    }
  }
}
```

Selection rules, in order:

1. Skip any violation with `triageVerdict: FALSE_POSITIVE` or `status: SUPPRESSED`.
2. Highest severity first (CRITICAL before HIGH).
3. Within a severity, prefer human-triaged `TRUE_POSITIVE` violations over untriaged
   ones.
4. One example per detection or finding type, so the set shows the breadth of risk.
5. Prefer violations with evidence or a specific `reasoning` over thin ones.
6. Stop at five. Fewer is fine; never pad.

Each `section`, headed by the violation name: severity, runtime or posture, the
type(s), the policy, a two-sentence masked summary of what happened and why it
matters, a one-line remediation, and the reference: violation id prefix (first 8
characters of `id`) plus session id for runtime ones. For credential or PII exposure,
name the kind of value ("cloud access key", "customer email addresses"), never the
value. Show the `triageVerdict` when set; otherwise "untriaged". If nothing qualifies,
say so in one line.

### 7. Governance & ownership gaps - `threats` block + `section`

The regulator's first question is "who owns this and what does it touch."

```graphql
query ($after: DateTime!, $before: DateTime!) {
  topAgentCountByFindingType(after: $after, before: $before, limit: 10) {
    findingType
    count
  }
  topAgentCountByOwner(after: $after, before: $before, limit: 10) {
    owner {
      name
    }
    count
  }
}
```

Frame as accountability gaps (e.g. `AGENT_WITHOUT_OWNER`), not engineering bugs.

### 8. Compliance exposure - `section` (derived, clearly labeled)

Framework exposure from the violations themselves:

```graphql
query ($after: DateTime, $before: DateTime) {
  violations(first: 1, filter: { status: { in: [ACTIVE] }, dateRange: { from: $after, to: $before } }) {
    totalCount
    controlBreakdown {
      buckets {
        key
        label
      }
      series {
        key
        data
      }
      omittedBucketCount
    }
  }
}
```

One paragraph: which frameworks the active violations touch and the most-hit controls,
with the "derived, not certified" disclaimer. If `controlBreakdown` is empty, fall back
to reinterpreting sections 2-7: NIST AI RMF (inventory coverage, prevention-mode
enforcement), EU AI Act (high-risk agents, human oversight), OCC / model risk
(ownership, the discovered unregistered footprint).

### 9. Board-ready bottom line - `summary` block

A three-point close the CISO can paste verbatim: (a) posture trend with both values
(this period vs. prior), (b) the one thing that needs a decision or budget, (c) the
regulatory exposure if left unaddressed.
