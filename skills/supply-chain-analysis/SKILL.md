---
name: supply-chain-analysis
description: Assess the supply-chain risk of an MCP server, skill, connector, or plugin. Use whenever the user asks whether an artifact is safe, trusted, malicious, reputable, signed, who publishes it, which agents depend on it, or whether the organization should allow it.
---

# Supply Chain Analysis

Answer supply-chain questions from the reputation service's stored assessments. Never compute, guess, or
"vibe-check" a rating yourself: the rating and its justification come from the data, and you report them.

## Hard rules

- `reputation` is `null` until an artifact has been assessed. Say "not assessed yet", never "safe".
- Quote the assessment's `summary` as the justification. Do not rewrite the verdict.
- Keep `query_graphql` selections flat and small (~16 KB cap, truncated lists carry a `__truncated` marker). Skip `behaviors.evidence`
  unless the user asks for proof.
- Call `graphql_introspection` `describe` on `ReputationAssessment` and the filter you use before the first query.

## Route the question

| User asks                                                               | Path                        | Reference to read                 |
| ----------------------------------------------------------------------- | --------------------------- | --------------------------------- |
| "Is _our_ X safe?", "which of my MCP servers are risky?", "who uses X?" | Tenant inventory first      | `references/queries/inventory.md` |
| "Is X trustworthy?" for something not necessarily installed             | Global catalog              | `references/queries/catalog.md`   |
| "What does BEHAVIOR mean?", "why is it suspicious?"                     | Explain findings            | `references/behaviors.md`         |
| "Should we block / allow it?", "what do we do now?"                     | Decide and word the verdict | `references/verdict-playbook.md`  |

If the artifact could be either, try the inventory first and fall back to the catalog.

Open references from the `references/` directory next to this skill. Read
`references/examples.md` when you are unsure how a full answer should look.

## Present the answer

1. **Rating** - `riskLevel`, publisher (verified or not), signature, in one line.
2. **Why** - the assessment `summary`.
3. **Notable behaviors** - the `behavior` values that explain the rating, in plain English
   (see `references/behaviors.md`).
4. **Next step** - block / review / allow per `references/verdict-playbook.md`, plus dependent agents
   when the user asked about impact.
5. **Freshness** - cite `assessedAt`; point to the Supply Chain page when unassessed.
