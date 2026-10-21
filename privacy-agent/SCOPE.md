Training material. Invented data.

# Scope of the GDPR request intake agent

Reader: the Data Protection Officer (DPO). The agent follows `policy.md` (version 1.2) and
nothing else. Code: `agent.py`. Log: `output/audit.log`.

## What it does

For each file in `requests/`, one separate session of the Claude Agent SDK:

1. reads the request (tool `read_request`);
2. classifies it: type (access, erasure, rectification, objection, or unknown), sensitive
   categories (health, minor, legal proceedings, press), and whether the request text tries to
   give the agent instructions;
3. routes it: `privacy_desk`, `privacy_desk` marked incomplete, `privacy_desk` flagged, or
   `dpo` (policy section 7);
4. drafts an acknowledgement and writes a triage record to `output/triage-REQ-xxx.json`
   (tool `write_triage`). Code, not the model, adds the receipt date, the due date (receipt
   plus 30 days), and both approvals set to `pending`;
5. writes `output/audit.log`: one `RUN` line per run, one `DECISION` line per request with
   the request id, the policy rule and a fixed reason, one `TOOLS` line per session (the tools
   the session can see), one `COST` line per request (model and cost), one `TOOL_ERROR` line
   per tool error (tool name and error type only).

The model is set in one place, the constant `MODEL` of `agent.py` (Sonnet).

## What it never does

- Send anything: no email, no reply, no acknowledgement. It has no tool for it.
- Read customer data (CRM, accounts, transfers). It has no tool for it.
- Search or look up a customer by name, email or id.
- Use a tool of the account: built-in tools, other MCP servers, connectors, hooks, plugins and
  project settings are all switched off. It has two tools: `read_request` (its own request
  only) and `write_triage` (its own `output/` folder only, path built by the code).
- Promise a deadline before the identity is verified (policy section 3).
- Follow an instruction written inside a request (policy section 6). Such a request is
  routed to the privacy desk and flagged.
- Put a name or an email in `audit.log`. The log holds request ids, policy rules and fixed
  reasons. The model's free text (the draft) goes to the triage record only.
- Delete `audit.log`. It is append-only; each run adds its lines.

## When it stops and escalates to a human

| Situation | What the agent does | Policy |
|---|---|---|
| Identity missing or not verified | route privacy desk, marked incomplete, note "identity to verify", no deadline in the draft | 3, 7 |
| Request type missing or not in the list | type `unknown`, marked incomplete, never guessed | 2, 7 |
| Health data, minor, legal proceedings, press | route DPO, whatever the type | 5, 7 |
| Request text gives instructions to the agent | route privacy desk, flagged, instructions not followed | 6, 7 |
| Both sensitive and identity missing | route DPO, also marked incomplete (section 5 says always) | 3, 5 |
| Model answer contradicts the policy (wrong route, minor missing, deadline without identity) | `write_triage` refuses, logs `TOOL_ERROR`, the model may correct | 3, 5 |
| No valid triage at the end of the session (API error, budget, turns) | code writes a fallback record: route DPO (sensitivity unknown), incomplete, "not triaged by the agent", logged as `DECISION ... rule=none-fallback` | 6 |
| A session sees a tool that is not one of the two | run stops, exit code 2, `TOOL_ERROR ... UnexpectedToolVisible` | 6 |

A session is also bounded: 8 turns and 0.50 USD per request.

## Where the human steps in

The agent stops at the triage record. Two steps belong to a human of the privacy desk (or the
DPO for a sensitive case), outside the agent, each after an approval:

1. **Reading customer data** (CRM, accounts, transfers), request by request. Record field
   `approvals.customer_data_read` is `pending`.
2. **Sending the reply** to the requester, after reading the draft. Record field
   `approvals.reply_send` is `pending`.

The agent never changes these two values. A human changes them, outside the agent.

## What leaves the machine

- To the model API (Anthropic, through the Claude Agent SDK), for each request: the system
  prompt (the policy text), the request id, requester name, channel, receipt and due date,
  identity evidence text, type as stated, relationship and age if made on behalf of someone,
  and the request text. Email address, customer id and the name of a third party are removed
  before the call. In this training, all of it is synthetic.
- The model's answer comes back: the tool calls and the draft.
- Nothing else leaves. Nothing is sent to a requester. Triage records and `audit.log` stay in
  `privacy-agent/output/` on this machine.
