# Findings Posture Report

A posture report over a time window: what the static scans found in agent
configuration (tools, instructions, knowledge sources, MCP servers, skills,
packages), which findings a posture policy promoted to a violation, the evidence
behind every critical posture violation, and a watch-list. This is the portal
equivalent of the findings analysis, sourced live through `query_graphql` instead of
a warehouse export.

## When to use

The user asks for a "posture report", "findings report", "configuration risk", or
"what did the scans find". Ask for the time window if it isn't given; default to the
last 30 days (posture changes slower than runtime). For a runtime or mixed digest use
`risk-analysis.md` instead.

## Scope & constraints (read first - these shape what the report can say)

- **Single tenant, always.** `query_graphql` is scoped to the current tenant by the
  server; there is no tenant parameter and no cross-tenant query.
- **Findings vs. posture violations.** A finding is a raw scan result on a resource.
  It becomes a violation only when a POSTURE policy matches it, and the policy sets
  the severity. Report both counts and label them; never present one as the other,
  and do not reconcile them.
- **Aggregate-first.** `query_graphql` returns pre-computed aggregations on fixed
  dimensions only - there is no generic `GROUP BY`. Response is capped (~16 KB, truncated lists carry a __truncated marker). Build the report from counts and the top-N
  slices below; do not attempt an exhaustive per-finding table.
- **Severity lives on the violation.** Findings aggregate by _type_ only. Filter
  violations with `severity: { in: [HIGH, CRITICAL] }`.
- **Mask PII at assembly.** Only leaked-value evidence `text` is redacted by the
  backend. Citation text, vulnerability descriptions, finding titles and violation
  reasoning are not: redact emails, tokens/secrets, card numbers, and long digit runs
  before putting them in a block. A `HARDCODED_SECRETS` citation can quote the
  secret itself.
- **A failed query is a missing section, not zero.** If a query errors or hits the
  call budget, say which section is missing. Never fill it with 0 or "none found".
  Zero findings from a successful query is a valid result - say so plainly.
- **Report, don't re-judge.** Describe each finding from its own title and evidence.
  Do not rule on whether it is a true or false positive. Show the human
  `triageVerdict` when set, otherwise "untriaged". The FP patterns below are things
  to call out as worth a human look, never a verdict.

## Finding types

Pass type codes through verbatim; `generate_report` resolves each to its title. Use
the `FindingType` enum as the source of truth. What the common ones mean, and what
makes one worth a human look:

| Type                                                | Means                                                                                                                  | Worth a human look when                                                                                                      |
| --------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `EXCESSIVE_PERMISSIONS`                             | A tool, skill, MCP server or agent can act beyond what its purpose needs (drop, delete, unrestricted SQL, admin scope) | The tool sits in a coding agent, the breadth is the stated purpose, or the platform enforces read-only connections (BI tool) |
| `PROMPT_INJECTION`                                  | A tool, skill, MCP description or agent rules/memory file carries instructions that hijack the agent                   | The quoted text is documentation, an example, or broad wording rather than an explicit payload                               |
| `UNUSED_TOOL`                                       | A tool is disabled or unrelated to the agent's purpose                                                                 | It is a required system tool, a skill catalog tool, or lives in a coding agent                                               |
| `UNBOUNDED_EGRESS`                                  | A tool or MCP server can send data to arbitrary destinations or recipients                                             | The recipient or host is actually fixed or domain-restricted elsewhere in the config                                         |
| `HARDCODED_SECRETS`                                 | A secret is present in configuration, a skill, an MCP server or a data source                                          | The value looks like a placeholder, sample, or test fixture                                                                  |
| `SENSITIVE_DATA_EXPOSURE`, `DATA_ISOLATION_RISK`    | Sensitive data or cross-boundary data is reachable by the agent                                                        | The data source is internal-only or already access-scoped                                                                    |
| `INSTRUCTIONS_NOT_CLEAR`                            | Agent instructions are too vague to bound behavior                                                                     | The instructions are short but adequate for a narrow use case                                                                |
| `EXPERIMENTAL_MODEL`                                | The agent runs on a preview or experimental model                                                                      | The model may have since become GA                                                                                           |
| `KNOWN_VULNERABILITY`                               | A package in use has a published advisory                                                                              | The installed version is already at or past `fixedIn`                                                                        |
| `MALICIOUS_CODE`, `DATA_EXFILTRATION`               | A skill, tool, MCP server or agent carries malicious code or an exfiltration path                                      | The quoted text is documentation or an example, not an executed directive                                                    |
| `AGENT_WITHOUT_OWNER`, `UNRESTRICTED_PUBLIC_ACCESS` | Governance gaps: no owner, or open to anyone                                                                           | Rarely an FP; worth checking ownership sync before chasing                                                                   |

Other enum values (`NAME_SQUATTING`, `UNTRUSTED_CONTENT_INGESTION`, `PERSONAL_ACCOUNT`,
`REPUTATION_MALICIOUS`, ...) are reported the same way, from their own evidence.

## Report structure

Emit `{ title, blocks: [...] }`. Recommended block order:

### 1. Executive summary - `summary` block

Prose headline: open findings across every resource type, the top finding type,
posture violations (high/critical) in the window, how many critical ones are
untriaged, and the single most notable signal. Derive from the queries below; do not invent numbers.

### 2. Findings by type - `threats` block + a `chart`

Current posture: every open finding, whether or not a policy promoted it, across all
resource types (agents, tools, skills, MCP servers, data sources and the rest). Use the
discovery aggregation, not `agents { aggregations }`, which counts agent-anchored
findings only. Posture is state, not events, so this is a snapshot of today, not the
window; say so.

```graphql
query {
  discover(first: 1) {
    aggregations {
      byFindings {
        total
        byType {
          type
          count
        }
      }
    }
  }
  topAgentCountByFindingType(limit: 10) {
    findingType
    count
  }
}
```

`byFindings` is volume across all resources. `topAgentCountByFindingType` is breadth
over agents only (how many agents carry the type), taken over the same current
snapshot (no `after`/`before`, which would scope agents by activity rather than
findings by date). Report breadth as "on N agents"; do not derive a ratio from the two,
since they count different resource sets.

### 3. Posture funnel - `chart`

How much of the inventory carries findings, and how much of that a policy turned into
a violation.

```graphql
query ($after: DateTime, $before: DateTime) {
  violations(first: 1, filter: { policy: { triggerType: { in: [POSTURE] } }, dateRange: { from: $after, to: $before } }) {
    totalCount
    funnel(
      stages: [RESOURCES, FINDINGS, VIOLATIONS, CRITICAL_VIOLATIONS]
      filter: { policy: { triggerType: { in: [POSTURE] } }, dateRange: { from: $after, to: $before } }
    ) {
      stages {
        stage
        label
        value {
          value
          isApproximate
        }
        conversionFromPrevious
      }
    }
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

Render the funnel as a bar chart. `CRITICAL_VIOLATIONS` is the high + critical subset.
Mark approximate values. A big FINDINGS stage with a small VIOLATIONS stage means
findings exist that no posture policy promotes: a coverage question for the reader.
`controlBreakdown` gives compliance framework exposure (breadth of violated controls,
not volume); include it as a short `section` or `chart` only if it is non-empty.

### 4. Critical posture violations - deep dive - `section` per violation

```graphql
query ($after: DateTime, $before: DateTime, $cursor: String) {
  untriaged: violations(
    first: 1
    filter: {
      severity: { in: [CRITICAL] }
      policy: { triggerType: { in: [POSTURE] } }
      triageVerdict: { isNull: true }
      dateRange: { from: $after, to: $before }
    }
  ) {
    totalCount
  }
  violations(
    first: 5
    after: $cursor
    orderBy: { field: CREATED_AT, direction: DESC }
    filter: { severity: { in: [CRITICAL] }, policy: { triggerType: { in: [POSTURE] } }, dateRange: { from: $after, to: $before } }
  ) {
    totalCount
    pageInfo {
      hasNextPage
      endCursor
    }
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
      tool {
        name
      }
      skill {
        name
      }
      mcp {
        name
      }
      dataSource {
        name
      }
      accessChannel {
        name
      }
      model {
        name
      }
      device {
        name
      }
      flow {
        name
      }
      findings(first: 3) {
        nodes {
          type
          title
          evidence {
            ... on CitationEvidence {
              text
            }
            ... on LeakedValueEvidence {
              text
            }
            ... on VulnerabilityEvidence {
              description
              facts {
                packageName
                version
                cves {
                  id
                  severity
                  fixedIn
                }
              }
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

`untriaged.totalCount` is the untriaged critical count for the summary; never count
it from the returned page. If `pageInfo.hasNextPage` is true, run the query again with
`$cursor` set to `pageInfo.endCursor`; fetch nodes cut off by truncation with
`violation(id)`. If `totalCount` exceeds what the call budget allows, state how many
were left out. Each `section`, headed by the violation name:

- Policy, the affected resource (whichever anchor field is set: agent, tool, skill,
  MCP server, data source, access channel, model, device or flow), finding type(s),
  violation id prefix (first 8 characters of `id`).
- A masked "what was found", from the finding title and violation `reasoning`.
- Evidence excerpts: leaked-value text verbatim (already redacted by the backend);
  citation text masked before quoting; package, version, CVE ids, severity and
  `fixedIn` for a vulnerability.
- If `evidenceUnavailable` is set, say why instead of the excerpts.
- If the finding type has a pattern in the table above that the evidence matches
  (a placeholder-looking secret, a coding-agent tool, an installed version at
  `fixedIn`), note it as worth a human look.
- The human `triageVerdict` when set; otherwise "untriaged".

If there are no critical posture violations, say so in one line and skip the section.

To drill into one finding type, swap the `policy` filter for
`findingType: { in: [<TYPE>] }`.

### 5. High posture violations - `section`

Same query with `severity: { in: [HIGH] }`, `first: 10`, and only `id name
triageVerdict`, the anchor fields, and `findings(first: 3) { nodes { type } }`. One
line each.

### 6. Watch-list - `section`

What needs a human next, derived from the data above. Only items present; an empty
watch-list is fine. Candidates:

- Critical posture violations still untriaged.
- Findings whose evidence is unavailable, so they cannot be verified.
- A finding type with high volume but no posture violations (no policy covers it).
- A finding whose evidence matches a pattern from the finding-types table.
- A resource that dominates the posture violation count.

Each item: one line, the violation id prefix or type, and why it is on the list.
