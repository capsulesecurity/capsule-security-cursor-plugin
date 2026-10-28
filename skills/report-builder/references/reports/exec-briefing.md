# Executive Weekly Briefing

An executive briefing laid out like a newspaper front page: a headline, a lead
story, five to seven short news items, a threat sidebar and one or two charts. Written for a reader
who has two minutes. Sourced live through `query_graphql`.

## When to use

The caller supplies a headline and a window (the last 7 days by default) and asks for the
weekly briefing. Do not ask scoping questions; build it.

## Rules (read first)

- **Single tenant.** `query_graphql` is scoped server-side. No by-tenant breakdown.
- **Never invent numbers.** Every figure comes from a query result. Plain numbers, no adjectives
  standing in for data.
- **A failed query is a missing story, not zero.** Say which item could not be produced. Zero from a
  successful query is a valid result; say so plainly.
- **Mask at assembly.** Redact emails, secrets/tokens and long digit runs in any quoted reasoning.
- **Raw vs violations.** Detections and findings are raw signals; violations are what a policy
  promoted. Label which one a number is.
- **Cite blocks by copying.** Use the exact GraphQL from `risk-analysis.md` and do not invent
  fields. `graphql_introspection` `describe` before changing any query.

## Queries

Run each for the current window and for the previous window of the same length (so you can state
what changed). Variables are `$after` / `$before`; the previous window ends where the current one starts.

Use these exact queries from `risk-analysis.md`:

- Section 3, threat landscape (`agents.aggregations` `byType`, with `activityWindow`).
- Section 4, highest-risk violations (`groups` severity split plus the top violations).
- Section 5, real-time blocks (PREVENTION policy ids, then blocked violations; `policyCountsByMode`).
- Section 7, top exposed owners (`topAgentCountByOwner`, `topAgentCountByFindingType`).
- From `findings-posture.md` section 2: open findings by type across every resource type
  (`discover { aggregations { byFindings } }`) for the posture item below. It is a current
  snapshot, not a weekly count.

Stay inside the data-fetch budget: fetch the previous window only for the totals you compare
(detections total, violation total, blocked count). If the budget runs out, report what you have.

## Block layout for `generate_report`

`title` is the supplied headline, verbatim. Emit blocks in this order:

1. `summary` - the lead. 2-3 sentences, plain numbers: raw detections and high/critical violations
   this week, and what changed vs the previous week (up, down or flat, with both numbers).
2. 5-7 `section` blocks, the news items, most important first. `heading` is a short headline-style
   sentence that states the news, e.g. "Detections up 18% as PII leakage doubles". `kicker` is one of
   `Policies`, `Detections`, `Findings`, `Owners`, `Enforcement`, or another one-word topic. Body is
   1-2 short paragraphs. The first three sections are also the dashboard highlights, so they must
   stand on their heading alone. Candidates, in order of importance:
   - The biggest week-over-week change.
   - The top risk type and its volume.
   - Enforcement coverage: blocked vs total violations, and whether any policy is in PREVENTION mode.
   - The top exposed owner or department.
   - Anything blocked in real time worth naming.
   - One posture item: the top open finding type and its count across all resources. Its
     `action` is `href` to the posture route from the
     Available Routes list, or a `prompt` such as "Which agents carry the most open findings?".
3. One `threats` block - combined `byType` aggregations for the current window, highest count first.
4. One or two `chart` blocks:
   - bar: detections by type (current window).
   - doughnut: policy count by mode (`policyCountsByMode`).

Skip a block whose data is missing instead of filling it. Never emit more than 7 sections.

## Call to action

Give every `section` one `action`, a quiet link under the story.

- Prefer `{ label, href }` to the page where the reader acts: policies, the violations list (filtered
  only if the route supports it), inventory, integrations. `href` must be one of the Available Routes
  listed in the system prompt, without route params. Never an external URL.
- Use `{ label, prompt }` when the next step is a question, e.g. "Why did PII leakage rise this week?".
- `label` is 2-4 words, imperative, no trailing punctuation: "Go to policies", "Ask why".

## Tone

Calm, precise, confident, like a wire report. No hype, no emoji, no em dashes. Follow the
`capsule-brand` skill. Do not repeat the report in chat; call `generate_report` exactly once.
