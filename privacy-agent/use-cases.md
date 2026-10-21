Training material. Invented data.

# Eight use cases at Company Bank (cycle 0 of M10)

Teams of Company Bank SA (invented) asked for AI help. For each case, choose the smallest
architecture that does the job: a single prompt, a deterministic chain, a router, an agent loop, or
a multi-agent system. A chain may have no model call at all.

## UC-1 · Customer notice in three languages
The communication team writes a notice about new fees in Romanian. It needs an English and a
Russian version, checked by a person before publication. About ten notices a month.

## UC-2 · Fee explanation for the mobile app
When a customer opens the fee screen, the app shows the fee of the transfer and one sentence that
explains it. The fee comes from `POST /fees` (the service of the repository). The sentence must
quote the rule of `docs/fee-rules.md` that applies. Up to 40,000 screens a day.

## UC-3 · Support mailbox
The support mailbox receives about 600 emails a day. Each one must go to one of five queues: cards,
loans, transfers, privacy, other. A queue team then answers by hand. A wrong queue costs a day.

## UC-4 · Incident investigation
An incident ticket, such as `incidents/INC-2026-0412.md`, describes a wrong fee seen by a customer.
Someone must read the ticket, search the code and the logs, form a hypothesis, write a failing test,
and try again until the cause is found. The number of steps is not known in advance.

## UC-5 · Monthly report to the regulator
Every month, the same six figures are taken from the same database views and put into the same
spreadsheet template. The regulator rejects any figure that cannot be traced to a query.

## UC-6 · Upgrade of 40 internal services
Forty Java services must move from Java 17 to Java 21. Each service is independent. Each change must
be reviewed by someone who did not write it before the merge.

## UC-7 · Payment beneficiary screening
Before an international payment, the name of the beneficiary is compared with a sanctions list. A
match blocks the payment until a compliance officer decides. The decision is regulated and must be
explained to an auditor.

## UC-8 · Meeting summary
After each weekly architecture meeting, the transcript must become a one-page summary with the
decisions and the owners. One summary a week.
