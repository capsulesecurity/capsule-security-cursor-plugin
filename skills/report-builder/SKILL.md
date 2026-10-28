---
name: report-builder
description: Build a downloadable PDF risk digest from live Capsule data. Use whenever the user asks to export, download, or produce a PDF, report, or risk/posture digest of detections and findings.
---

# Report Builder

Produce an AI-risk report as a downloadable PDF. Always work from live data — never invent numbers.

## 0. Scope the report before building

If the user's intent is unclear — which report they want, or how comprehensive it should be —
**ask them first** rather than guessing. ask the user in conversation to confirm the depth: a quick
one-paragraph summary, or a full multi-section report with charts. Skip the question when the
intent is already clear (they named a report, a persona, or an obvious scope).

Pick the reference that matches the audience, open it from `references/reports/<file>` in this skill's directory, then follow its structure:

- **`risk-analysis.md`** — generic security-posture / detection digest, including a daily
  detection report with an evidence deep dive on critical violations (the default when no audience
  is named).
- **`findings-posture.md`** - posture findings report: findings by type, the posture funnel,
  and an evidence deep dive on critical posture violations.
- **`detections-runtime.md`** - runtime detections report: detections by type, the runtime
  funnel, and an evidence deep dive on critical runtime violations.
- **`analyst.md`** — SOC analyst: what was discovered, who owns it, who responded and how.
- **`ai-engineer.md`** — AI engineer: fleet wiring (agents ↔ models ↔ tools ↔ MCP ↔ data
  sources), posture risks, unused-Skill/MCP callouts.
- **`ciso-executive.md`** - CISO / board, or a customer security report: period-over-period
  KPIs, shadow-AI vs. governed delta, notable examples, compliance exposure.
- **`exec-briefing.md`** - executive weekly briefing laid out like a newspaper front page
  (lead, headline-style news items, threat sidebar, charts), with week-over-week comparison.

## 1. Gather the data with `query_graphql`

Start with the type breakdown. Detections are runtime events; findings are posture issues. Both are
aggregated by type:

```graphql
query {
  agents {
    aggregations {
      detections {
        byType {
          type
          count
        }
        total
      }
      findings {
        byType {
          type
          count
        }
        total
      }
    }
  }
}
```

The `type` values are detection/finding codes (e.g. `PII_LEAKAGE`, `PROMPT_INJECTION`,
`GOAL_MANIPULATION_RISK`). Pass them through verbatim — `generate_report` resolves each code to its
human title for you.

To break the digest down further, re-run the query with an `agents(filter: …)` argument (for example a
platform filter) for the few platforms or agents that matter. Stay within a handful of queries; if you
hit the data-fetch limit, summarize what you have.

## 2. Call `generate_report`

Assemble the digest from what you fetched as `{ title, blocks: [...] }`, an ordered list of content
blocks:

- `summary` — `{ type: 'summary', body }`, one short paragraph stating the current risk level in plain
  prose (total high-severity issues, runtime detections vs. posture findings).
- `threats` — `{ type: 'threats', items: [{ type, count }] }`, the combined `byType` aggregations,
  highest count first.
- `section` — `{ type: 'section', heading, body }`, optional prose sections, e.g. "By platform" or
  "Notable examples".
- `chart` — `{ type: 'chart', title, config }`, a Chart.js configuration.

The PDF is delivered to the user as a download — a short confirmation in the conversation is enough; you
do not need to repeat its contents. `generate_report` applies the Capsule brand styling (palette, header,
accent rules) automatically, so you only supply the content. For tone and wording, follow the
`capsule-brand` skill: calm, precise, confident.
