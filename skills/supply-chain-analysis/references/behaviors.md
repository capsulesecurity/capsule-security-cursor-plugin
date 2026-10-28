# Behaviors

`ReputationBehavior` values the analyzer can report. Only behaviors it actually found are listed on an
assessment, each with evidence from the artifact's own content. A behavior is a capability, not a
verdict: the same value can be the product's whole purpose (a shell MCP runs shell commands) or a red
flag (a weather skill runs shell commands). Read it against the `summary`.

Weight: **high** behaviors usually justify SUSPICIOUS on their own and MALICIOUS when combined with
concealment; **medium** need context; **low** are neutral capability inventory unless the summary says
otherwise.

| Behavior                     | Plain English                                                                                                                         | Weight | Typical false-positive                                                                         |
| ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- | ------ | ---------------------------------------------------------------------------------------------- |
| `MALICIOUS_CODE`             | Code whose purpose is harm: obfuscated payloads, backdoors, miners hidden in installers.                                              | high   | None. Treat as confirmed.                                                                      |
| `DATA_EXFILTRATION`          | Sends local data, secrets, or conversation content to a third party the user did not ask for.                                         | high   | Vendor telemetry mislabeled; check the destination in evidence.                                |
| `CREDENTIAL_EXPOSURE`        | Reads, stores, or ships API keys, tokens, private keys, or passwords.                                                                 | high   | Reading its own configured API key from env is normal; hardcoded or committed secrets are not. |
| `PROMPT_INJECTION`           | Instructions inside the artifact that try to steer the agent beyond its task.                                                         | high   | Ordinary frontmatter trigger text sometimes fires this; the summary usually says so.           |
| `SUSPICIOUS_DOWNLOAD`        | Fetches and runs remote code at install or runtime: `curl \| sh`, opaque tarballs, base64 blobs.                                      | high   | Official vendor installer from the vendor's own domain (still worth naming).                   |
| `MALICIOUS_DOWNLOAD`         | Fetches a known-malicious payload: miners, droppers, base64-piped installers from attacker hosts.                                     | high   | Security scanners that list malware signatures as detection rules.                             |
| `OBFUSCATED_CODE`            | Base64, packed, or otherwise concealed code or commands.                                                                              | high   | Minified vendor bundles; decode the evidence before concluding.                                |
| `OUTPUT_POISONING`           | Tool results carry instructions planted for the agent, not data for the user.                                                         | high   | Tools that relay third-party text verbatim (that is `UNTRUSTED_CONTENT_EXPOSURE`).             |
| `SAMPLING_EXPLOITATION`      | Abuses MCP sampling to steer the client model, e.g. asking it to fetch secrets.                                                       | high   | Sampling used only to summarize or classify the tool's own data.                               |
| `TYPOSQUAT`                  | Name imitates a well-known package or brand (`twittter-mcp`).                                                                         | high   | Forks and community ports with similar names; check the publisher.                             |
| `TOOL_SHADOWING`             | Registers a tool under a standard or host-native name (`read_file`, `exec`) to intercept calls meant for the real one.                | high   | None in a legitimate server; check the tool name against the host's built-ins.                 |
| `REGISTRY_SECURITY_HOLD`     | The registry removed the package for security reasons and only a placeholder remains.                                                 | high   | None. Treat as confirmed.                                                                      |
| `CAPABILITY_MISDECLARATION`  | Declared behavior contradicts the code, e.g. a tool marked read-only that writes or posts data.                                       | high   | Stale annotations after a refactor; still worth naming.                                        |
| `DEFERRED_REMOTE_EXECUTION`  | Tool surface or instructions are resolved from a remote source at runtime, so what runs can change after review.                      | medium | OpenAPI-driven or boto3-driven servers are legitimately dynamic; note the source.              |
| `RUNTIME_TOOL_RESOLUTION`    | Tool list is discovered or proxied at runtime (remote `listTools`, dynamic registration), so the reviewed tools may not be what runs. | medium | Gateways to the vendor's own hosted MCP.                                                       |
| `COMMAND_INJECTION`          | Caller-supplied input reaches a shell, `eval`, or query string without sanitizing.                                                    | medium | Database and REPL tools that execute user queries by design.                                   |
| `PATH_TRAVERSAL`             | File paths from tool arguments can escape the intended directory.                                                                     | medium | Evidence often quotes the guard itself (`resolve`, `isPathInside`); check it is enforced.      |
| `HARDCODED_CREDENTIAL`       | A password, key, or token is committed in code or config.                                                                             | medium | Development defaults and localhost-only keys.                                                  |
| `PERMISSION_OVERREACH`       | Asks for or documents broader permissions than the task needs; skips approval prompts; `--yolo`, permission-skip flags.               | medium | Delegation-to-coding-agent skills document these flags as options.                             |
| `OVERSIGHT_EVASION`          | Acts in a way that defeats the human-in-the-loop gate, e.g. marking destructive tools safe or auto-approving its own calls.           | medium | Trusted-automation setups the user opted into; check that the bypass is documented and opt-in. |
| `UNTRUSTED_CONTENT_EXPOSURE` | Pulls arbitrary open-web or third-party content into the agent context (search results, page text, DMs from strangers).               | medium | Every web-search MCP has this; it is a prompt-injection surface, not proof of intent.          |
| `RUNS_SHELL_COMMANDS`        | Executes shell commands, often with tool arguments interpolated into the command string.                                              | medium | Shell/automation MCPs by design; interpolation without sanitizing is the real concern.         |
| `DEPLOYS_CODE`               | Pushes, deploys, or publishes code or infrastructure.                                                                                 | medium | CI/CD and IaC integrations.                                                                    |
| `MODIFIES_SYSTEM_SERVICES`   | Installs daemons, cron jobs, launchd agents, or startup hooks.                                                                        | medium | Legitimate scheduler skills; persistence without consent is the concern.                       |
| `CONTROLS_BROWSER`           | Drives a browser or the user's logged-in Chrome profile, executes page JS, reads cookies.                                             | medium | Browser-automation MCPs by design; CSP stripping or debugger attach on all URLs raises it.     |
| `CAN_DELETE_RESOURCES`       | Can delete cloud resources, files, records, or accounts.                                                                              | medium | Cloud management servers gate this behind flags; check the summary for guards.                 |
| `HANDLES_PAYMENTS`           | Moves money: crypto transactions, payment APIs, trading.                                                                              | medium | Official payment-provider integrations.                                                        |
| `SENDS_MESSAGES_AS_USER`     | Posts, emails, or messages on the user's behalf.                                                                                      | medium | Communication integrations by design; autonomous posting without confirmation is the concern.  |
| `ACCESSES_PRIVATE_DATA`      | Reads mail, messages, health data, browsing history, private databases.                                                               | medium | The integration's stated purpose usually is that data.                                         |
| `QUERIES_DATABASES`          | Runs SQL or other database queries, sometimes with caller-supplied strings.                                                           | low    | Database MCPs by design; unparameterised SQL is the concern.                                   |
| `READS_WRITES_FILES`         | Reads or writes files on the host.                                                                                                    | low    | Almost every local MCP.                                                                        |
| `CALLS_EXTERNAL_APIS`        | Talks to third-party HTTP APIs.                                                                                                       | low    | Almost every integration.                                                                      |
| `TRACKS_TELEMETRY`           | Sends usage analytics to the vendor.                                                                                                  | low    | Standard for commercial tools; note the endpoint if hardcoded.                                 |
| `UNPINNED_DEPENDENCY`        | Dependencies use version ranges (`^1.2.0`, `>=`), so a reinstall can pull new code.                                                   | low    | Near-universal in npm and PyPI packages.                                                       |

## Reading a set of behaviors

- **Capability that matches the product** (`RUNS_SHELL_COMMANDS` on a shell MCP): report as "does what it
  says", still worth the user knowing.
- **Capability that does not match** (`SUSPICIOUS_DOWNLOAD` on a paper-summariser): lead with it.
- **Unsigned + unverified publisher + any high behavior**: recommend block until reviewed.
- **No behaviors listed**: say the analyzer found no risk-relevant behaviors; that is not the same as
  `TRUSTED`.
