---
name: component-docs
description: Document the components, endpoints and dependencies of a service from its repository only, with a file and line for every statement, an HTML page, an SVG architecture diagram, and lists of ASSUMPTION and MISSING. Use when a developer of another team must call or integrate a service, when documentation and code may disagree, or when asked for a component page or architecture diagram.
---

# Document the components of a service from the repository

The repository is the only source. A previous answer, a chat summary or an old README is not a
source. Every statement in the outputs cites a file and a line (or a commit).

## Outputs

| Output | Where | Content |
|---|---|---|
| Inventory and gap lists | the chat, before any file is written | components, endpoints, dependencies, each with its file |
| Page | `docs/<service>.html` | one self-contained HTML file: components, endpoints, rules, how to run and test, assumptions and gaps. Inline CSS, no external script, font or image |
| Diagram | `docs/<service>.svg` (also inlined in the page) | modules, calls and external systems the code shows, nothing else |
| Final lists | the chat, after the files | every ASSUMPTION and every MISSING, and what was run and what was not |

## Steps

1. **Inventory and gaps first (chat only, no file yet).**
   - Read the code, the tests and every existing document. Skip nothing the build reads: entry
     point, routes, schemas, domain, clients, configuration, dependency manifest.
   - List the components, the public endpoints and the dependencies (packages, environment
     variables, external services), each with its file and line.
   - List what the documentation says that the code does not do, and what the code does that no
     documentation says. Quote file and line for each point. A document that the repository itself
     calls stale is listed as a gap, never used as a source.
2. **Verify before you write.** Count line numbers in the file you cite; do not recall them.
   Check that a file you cite has not changed since the commit you cite (`git diff <commit> HEAD`).
   If a statement is about tests, search every test layer (unit tests and behave or other
   acceptance tests) before saying something is untested.
3. **The page.** Sections: components (table with file, role, dependencies), diagram, endpoints
   (request fields and rules, responses, error table with status, body, cause, source), the rules
   the code applies, dependencies and configuration, how to run, how to test, assumptions and
   gaps. Write for a developer of another team who must call the service. Plain words, no
   marketing words.
4. **The diagram.** Draw only what the code shows: modules, the direction of each call or import,
   what `main` wires, external systems. Mark as dashed what is outside the service or never called.
   Add a legend and the source folder. Write the SVG by hand, ASCII only, with `<title>` and `<desc>`.
   Build the page from a placeholder (`<!--DIAGRAM-->`) and inline the SVG with a script, so the two
   copies are identical. Check that the SVG is well-formed XML.
5. **Review as a second reader.** Re-read the output as someone who has not seen the work. List every
   claim that no file supports: negative claims ("no file records..."), reasons taken from a commit
   message, behaviour derived from reading code and never run, dates, and any figure without a
   source. Fix the claim or label it. Report the list in the chat.

## Rules on sources

- Order of trust when sources disagree: the document the repository names as source of truth, then
  the code, then tests, then other documents. If the repository names none, do not choose: report
  the conflict as MISSING and say which sources disagree.
- Do not settle a conflict between sources yourself, and do not change code to match a document.
- Quote a value (limit, rate, rule name) only after finding it in a file. Never copy a fact from
  another project or from memory.
- Output you did not observe is labelled: "from the tests", "from the feature file", "not run".

## ASSUMPTION and MISSING

- **ASSUMPTION**: a statement the repository does not let you verify (a framework default you did
  not run, a provider contract, a version that was not tested, a command you did not run). Write the
  word in capitals next to the statement, and say what would confirm it.
- **MISSING**: information the repository does not contain (a published tariff, a decision, an
  address, an authentication scheme, a test, a contract). Write the word in capitals. Do not fill
  it with a guess.
- Collect both in one section of the page and again in the chat, one line each.

## Commands

- Every command in the page works in Windows PowerShell and in macOS Terminal. Give both forms when
  they differ (path of the virtual environment, `curl` against `Invoke-WebRequest`, how to set an
  environment variable).
- Copy commands from the repository's README, Makefile or scripts. Run only the commands the
  project allows to run alone (tests, lint check). Do not start the service, call the network,
  install anything or rewrite files unless the project's rules and the user allow it. Say which
  commands were run, with their result, and which were not.

## Do not

- Cite a line you did not read, or a document the repository marks as out of date.
- Add to the diagram a component, arrow or label that the code does not show.
- Use marketing words, or soften a gap into a statement.
- Edit protected files (CI, secrets) or any source file: this skill writes documentation only.
