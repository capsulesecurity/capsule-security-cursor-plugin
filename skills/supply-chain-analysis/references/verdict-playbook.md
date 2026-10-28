# Verdict Playbook

How to turn an assessment into a recommendation. The rating comes from the service; the recommendation
is how the organization should act on it. Say which is which.

## By risk level

| `riskLevel`         | Meaning                                                                                                 | Default recommendation                                                                                                                                                      |
| ------------------- | ------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `MALICIOUS`         | Confirmed harmful behavior in the artifact's own content.                                               | **Block.** Remove from agents that use it, revoke credentials it could have read, review activity since install.                                                            |
| `SUSPICIOUS`        | Risky capabilities, unverifiable code, or a mismatch between purpose and behavior. Not proof of intent. | **Review.** Name the behaviors that drove it; ask whether the capability is needed for the use case; prefer a signed alternative from a verified publisher when one exists. |
| `UNKNOWN`           | The analyzer ran but found nothing it could assess (no source code or tool surface).                    | **Do not infer safety.** Treat like unassessed: say it could not be assessed and fall back to publisher and signature facts.                                                |
| `BENIGN`            | No risk signals found.                                                                                  | **Allow**, with the usual caveats about publisher and signature below.                                                                                                      |
| `TRUSTED`           | Positively identified as known-good software.                                                           | **Allow.**                                                                                                                                                                  |
| `null` (unassessed) | The reputation service has not covered it.                                                              | **Do not infer safety.** Say it is unassessed, point to the Supply Chain page, and fall back to publisher and signature facts from the inventory.                           |

## Modifiers

Apply after the base recommendation; they can move "allow" to "review", never "block" to "allow".

- `signature: UNSIGNED` or `UNKNOWN` - distribution cannot be verified as untampered. Call it out on
  every verdict; for SUSPICIOUS it is an extra reason to review.
- `publisher.verified: false` - identity unconfirmed. A well-known name with `verified: false` is still
  unverified; say "claims to be published by X".
- `publisher.verified: true` - lowers the odds of impersonation, not of risky behavior. Official
  vendor servers are often SUSPICIOUS for legitimate reasons (broad cloud permissions, arbitrary code
  execution as the product).
- Stale `assessedAt` (older than the installed `version`) - the assessment may not describe what is
  running. Say so.

## Word it for the reader

The portal serves several personas; match the framing to who is asking, without changing the facts.

- **Security analyst** - lead with behaviors and evidence, then impact (which agents, which
  environments). They want the quote and the location.
- **AI engineer** - lead with what the artifact does and which capability is the problem; offer the
  concrete alternative (pin a version, use the signed fork, gate the risky tool).
- **CISO / executive** - lead with the rating and the count: how many installed artifacts are
  SUSPICIOUS or MALICIOUS, how many agents touch them. One sentence of why.
- **Non-expert** - consequence first ("this can run any command on the machine that hosts the agent"),
  then the plain recommendation. No enum names.

## Template

> **Rating:** SUSPICIOUS - published by `alpacahq` (unverified), signed, assessed 2026-08-18.
> **Why:** <assessment summary, verbatim or lightly trimmed>.
> **Behaviors:** places real trades (`HANDLES_PAYMENTS`), reads portfolio data (`ACCESSES_PRIVATE_DATA`).
> **Recommendation:** review - the trading capability is the product, so allow only for agents that
> are meant to trade; 2 agents in `production` use it today.

Always end with what the user can do next: block, review with the owner, or allow and monitor.
