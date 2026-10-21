---
name: apply-contract
description: Apply the Company working contract (architecture boundaries, conventions, source of truth, definition of done) to a new repository. Use when starting or onboarding a repository and writing its CLAUDE.md.
---

# Apply the contract to a new repository

The rules are in `${CLAUDE_PLUGIN_ROOT}/rules/`: `architecture.md`, `conventions.md`,
`source-of-truth.md`, `definition-of-done.md`. They describe the Company transfers service.
Treat them as a template: copy the structure, not the facts.

## Steps

1. **Check before you write.** Read the new repository. For every line you want in its
   CLAUDE.md, mark it CONFIRMED, WRONG or CANNOT TELL. Never copy a Company fact (a rule
   name, a limit, a path) without finding it in the new repository.
2. **Separate three things:** repository facts, assumptions, missing information.
3. **Commands.** List only the build, test, lint and format commands that exist and that
   you ran, copied exactly. Run the check form of format and lint, never one that rewrites
   files. Name the others as "exist, not run".
4. **Architecture boundaries.** Map the new layers and write the allowed direction of
   dependency, what each layer must not import, and where configuration and error mapping
   live (see `rules/architecture.md`).
5. **Conventions.** Adapt `rules/conventions.md` to the language: naming, types, money or
   other domain types, test naming and layout, and how tests avoid the network.
6. **Source of truth.** Name the document that wins when code, docs and tests disagree
   (`rules/source-of-truth.md`). List known conflicts as open, with their ticket, and do not
   fix them as a side effect.
7. **Definition of done and stop-and-ask list** from `rules/definition-of-done.md`, with the
   new repository's commands. Keep CLAUDE.md under 150 lines.
8. **Permissions.** Propose a `.claude/settings.json`: allow only the exact read-only
   commands of CLAUDE.md, deny reading `.env` and secrets, deny network commands, ask before
   changes to CI and `.env`.

## Do not

- Invent a rule the new repository does not support.
- Resolve an open conflict between sources yourself: ask a human.
