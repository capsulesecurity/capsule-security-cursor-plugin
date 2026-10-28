# Detections Runtime Report

A runtime report over a time window: what the detection engine flagged in agent
sessions, which detections a runtime policy promoted to a violation, the evidence
behind every critical runtime violation, and a watch-list. This is the portal
equivalent of the detection analysis, sourced live through `query_graphql` instead of a
warehouse export. It is the runtime twin of `findings-posture.md`.

## When to use

The user asks for a "detections report", "runtime report", "what did the agents do",
"leakage report", "prompt injection report", or a per-detection-type review. Ask for
the time window if it isn't given; default to the last 7 days (runtime moves faster
than posture). For a posture report use `findings-posture.md`; for a mixed digest use
`risk-analysis.md`.

## Scope & constraints (read first - these shape what the report can say)

- **Single tenant, always.** `query_graphql` is scoped to the current tenant by the
  server; there is no tenant parameter and no cross-tenant query.
- **Detections vs. runtime violations.** A detection is a raw runtime signal on a
  session. It becomes a violation only when a RUNTIME policy matches it, and the policy
  sets the severity. One detection can match several policies, and one violation
  accumulates detections across sessions of the same agent. Report both counts and
  label them; never present one as the other, and do not reconcile them.
- **Aggregate-first.** `query_graphql` returns pre-computed aggregations on fixed
  dimensions only - there is no generic `GROUP BY`. Response is capped (~16 KB, truncated lists carry a __truncated marker). Build the report from counts and the top-N
  slices below; do not attempt an exhaustive per-detection table.
- **Severity lives on the violation.** Detections aggregate by _type_ only. Filter
  violations with `severity: { in: [HIGH, CRITICAL] }`.
- **Evidence is the triggering activities, not the transcript.** A detection carries
  the activities that triggered it and its cited evidence. The full session transcript
  is not exposed; do not describe what is not in the evidence.
- **Mask PII at assembly.** Only leaked-value evidence `text` is redacted by the
  backend. Citation text, detection descriptions, violation reasoning and activity
  messages are not: redact emails, tokens/secrets, card numbers, and long digit runs
  before putting them in a block. A `CREDENTIALS_LEAKAGE` or `PII_LEAKAGE` activity
  message can quote the value itself.
- **A failed query is a missing section, not zero.** If a query errors or hits the
  call budget, say which section is missing. Never fill it with 0 or "none found".
  Zero detections from a successful query is a valid result - say so plainly.
- **Report, don't re-judge.** Describe each detection from its own title, description
  and evidence. Do not rule on whether it is a true or false positive. Show the human
  `triageVerdict` when set, otherwise "untriaged". The patterns below are things to
  call out as worth a human look, never a verdict.

## Detection types

Pass type codes through verbatim; `generate_report` resolves each to its title. Use
the `DetectionType` enum as the source of truth. What each means, and what makes one
worth a human look:

| Type                              | Means                                                                                | Worth a human look when                                                                                        |
| --------------------------------- | ------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------- |
| `CREDENTIALS_LEAKAGE`             | A usable secret (key, token, password) appeared in the session                       | The value looks like a public client id, an OAuth `state`, a placeholder, or the session is endpoint telemetry |
| `PII_LEAKAGE`                     | Personal data tied to a real person appeared in the session                          | It is the account owner's own record from their own connector, or obviously synthetic data                     |
| `PHI_LEAKAGE`                     | A health fact tied to an identity appeared                                           | The identifier is a de-identified trial or subject id                                                          |
| `PCI_LEAKAGE`                     | An unmasked card number appeared                                                     | The digits are a long database record id or a known provider test number                                       |
| `BUSINESS_INTELLIGENCE_LEAKAGE`   | Confidential business data was exposed outside its audience                          | It fires alone with no external destination in the evidence                                                    |
| `EXTERNAL_DATA_EXPOSURE`          | Data moved to a sharing or exfiltration channel (webhook, paste site, public share)  | The destination is an internal proxy, a local pipe, or a repository the organization plausibly owns            |
| `PROMPT_INJECTION`                | Content tried to steer the agent away from its principal's intent                    | The text is platform scaffolding, the agent's own output, the user directing their own agent, or a document    |
| `INSTRUCTION_VIOLATION`           | The agent acted against established user or system instructions with security impact | The triggering activities do not include the user turn that set the intent                                     |
| `DANGEROUS_ACTIONS`               | The agent executed a destructive or irreversible operation, or bypassed a control    | The operation was read-only, or a user-initiated cleanup on a non-production system                            |
| `RECONNAISSANCE`                  | Broad discovery beyond the task's scope                                              | There is no user message in the evidence to define the task's scope                                            |
| `VULNERABLE_PACKAGE_INSTALLATION` | A package with a published advisory was installed (static analyzer, not the model)   | Rarely an FP; check the version against the advisory                                                           |
| `SYSTEM_CONFIGURATION_DISCLOSURE` | The agent disclosed its own system configuration                                     | Legacy type, not covered by the detection analysis; report from its own evidence                               |
| `DATA_MANIPULATION`               | The agent altered data it should not have                                            | Legacy type, not covered by the detection analysis; report from its own evidence                               |

Detections without a conversation (endpoint/EDR telemetry) cannot establish user
intent, so `INSTRUCTION_VIOLATION`, `RECONNAISSANCE` and `PROMPT_INJECTION` on them are
worth a human look. Tool invocations from some platforms arrive without content; say
so when the evidence is a bare tool name.

## Report structure

Emit `{ title, blocks: [...] }`. Recommended block order:

### 1. Executive summary - `summary` block

Prose headline: total detections in the window, the top detection type, runtime
violations (high/critical), how many critical ones are untriaged, and the single most
notable signal. Derive from the queries below; do not invent numbers.

### 2. Detections by type - `threats` block + a `chart`

Raw volume, whether or not a policy promoted it. Scope with `filter.activityWindow`;
omit it and the counts are tenant-wide, which you should say.

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
    }
  }
}
```

Render `byType` as a bar chart, highest first. Group the types the way the reader
thinks about them when it helps: data exposure (CREDENTIALS, PII, PHI, PCI, BUSINESS
INTELLIGENCE), channel (EXTERNAL_DATA_EXPOSURE), action (DANGEROUS_ACTIONS,
RECONNAISSANCE), and intent (PROMPT_INJECTION, INSTRUCTION_VIOLATION).

### 3. Runtime violations - `section` + `chart`

Which detections a runtime policy turned into a violation, and at what severity.

```graphql
query ($after: DateTime, $before: DateTime) {
  violations(
    first: 10
    orderBy: { field: SEVERITY, direction: DESC }
    filter: { policy: { triggerType: { in: [RUNTIME] } }, dateRange: { from: $after, to: $before } }
  ) {
    totalCount
    groups(grouping: { key: SEVERITY }, filter: { policy: { triggerType: { in: [RUNTIME] } }, dateRange: { from: $after, to: $before } }) {
      nodes {
        groupValue
        totalCount
      }
    }
    nodes {
      id
      name
      severity
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
    }
  }
}
```

Render the severity groups as a chart. One line per violation: severity, name, agent,
detection types, violation id prefix (first 8 characters of `id`) and session id.
Policy mode is read as it is today; a PREVENTION policy blocks, MONITORING and WARNING
record only.

### 4. Runtime funnel - `chart`

How much of the inventory produced detections, and how much of that a runtime policy
turned into a violation.

```graphql
query ($after: DateTime, $before: DateTime) {
  violations(first: 1, filter: { policy: { triggerType: { in: [RUNTIME] } }, dateRange: { from: $after, to: $before } }) {
    totalCount
    funnel(
      stages: [RESOURCES, DETECTIONS, VIOLATIONS, CRITICAL_VIOLATIONS]
      filter: { policy: { triggerType: { in: [RUNTIME] } }, dateRange: { from: $after, to: $before } }
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
  }
}
```

Render the funnel as a bar chart. `CRITICAL_VIOLATIONS` is the high + critical subset.
Mark approximate values. A big DETECTIONS stage with a small VIOLATIONS stage means
detections exist that no runtime policy promotes: a coverage question for the reader.

### 5. Critical runtime violations - deep dive - `section` per violation

```graphql
query ($after: DateTime, $before: DateTime, $cursor: String) {
  violations(
    first: 5
    after: $cursor
    orderBy: { field: CREATED_AT, direction: DESC }
    filter: { severity: { in: [CRITICAL] }, policy: { triggerType: { in: [RUNTIME] } }, dateRange: { from: $after, to: $before } }
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
      detections {
        type
        title
        description
        session {
          id
        }
        activities {
          message
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
      }
    }
  }
}
```

If `pageInfo.hasNextPage` is true, run the query again with `$cursor` set to
`pageInfo.endCursor`; if a response is truncated, fetch the cut-off nodes by `violation(id)`.
If `totalCount` exceeds what the call budget allows, state how many were left out. Each `section`, headed by the
violation name:

- Policy and mode, agent, detection type(s), violation id prefix and session id.
- A masked "what happened", from the detection title and description, the violation
  `reasoning`, and the triggering activity messages.
- Evidence excerpts: leaked-value text verbatim (already redacted); citation text and
  activity messages masked before quoting.
- If `evidenceUnavailable` is set, say why (retention expired vs. never captured)
  instead of the excerpts.
- If the detection type has a pattern in the table above that the evidence matches,
  note it as worth a human look.
- The human `triageVerdict` when set; otherwise "untriaged".

If there are no critical runtime violations, say so in one line and skip the section.

To drill into one detection type, swap the `policy` filter for
`detectionType: { in: [<TYPE>] }`.

### 6. Watch-list - `section`

What needs a human next, derived from the data above. Only items present; an empty
watch-list is fine. Candidates:

- Critical runtime violations still untriaged.
- Detections whose evidence is unavailable, so they cannot be verified.
- A detection type with high volume but no runtime violations (no policy covers it).
- A detection whose evidence matches a pattern from the detection-types table.
- An agent that dominates the runtime violation count.
- No runtime policy in PREVENTION mode, so nothing is blocked in real time.

Each item: one line, the violation id prefix or type, and why it is on the list.
