---
name: draft-pep
description: Use this skill when the user wants to create, draft, or write a new PEP (Project Enhancement Package) in this repo's PEP framework — e.g. "create a PEP for X", "draft a PEP", "write up Y as a PEP", "let's plan this as a PEP", "new-pep". Produces fully-drafted section content (Motivation, Specification, Risks, etc.) instead of leaving template placeholders in place, then uses tools/pep-tools.sh to handle numbering, filename, and ID formatting so the result stays consistent with the CLI's own conventions.
---

# Drafting a PEP

The project's `tools/pep-tools.sh new-pep` command only captures a title, type, priority, and
one-line abstract — everything else in the generated file is template boilerplate
(`- Functional requirements`, `[Phase Name]`, an empty Risks table). The project's own `stubs`
command exists specifically to catch PEPs left in that state. Your job is to make sure the PEP
this skill produces never shows up in that list.

## Steps

1. **Confirm you're in a PEP-framework project.** Look for `docs/peps/` and `tools/pep-tools.sh`
   at the project root. If missing, ask the user for the right directory instead of guessing.

2. **Gather the idea.** Use whatever the user already described in this conversation. Only ask
   clarifying questions for things you genuinely can't infer — the problem being solved, scope
   boundaries, hard constraints. Don't interrogate the user through the whole template field by
   field; draft first and let them correct you.

3. **Check for related PEPs.** Run `./tools/pep-tools.sh list` and skim `docs/peps/` for anything
   this new PEP relates to, supersedes, or should reference — both to avoid restating context
   that already lives elsewhere and to populate References accurately.

4. **Pick Type and Priority.** Choose from the 10 types (Project, Feature, Process,
   Infrastructure, Documentation, Bug, Enhancement, Research, Security, Performance) and a
   priority (High/Medium/Low) based on the content. State your choice and a one-line reason —
   don't pick silently.

5. **Create the file non-interactively.** `new-pep` is an interactive prompt loop (`read -r` for
   title, type, priority, abstract), so drive it with piped stdin rather than trying to answer
   prompts turn by turn:

   ```bash
   printf '<type-number>\n<priority-letter>\n<one-line abstract>\n' | ./tools/pep-tools.sh new-pep "<Title>"
   ```

   - `<type-number>` is the 1–10 index printed by the type menu (Project=1 … Performance=10).
   - `<priority-letter>` is `H`, `M`, or `L`.
   - The abstract must be a single line — no embedded newlines, or the pipe breaks early.

   This produces `docs/peps/<prefix>-NNN-<type-slug>-<title-slug>.md` with the header fields
   filled in and the Abstract set. Everything else in the body is still placeholder text.

6. **Fill in every remaining section with real content, in place, using Edit:**
   - **Motivation** — the actual problem/context, in prose, not "Why is this change needed?"
   - **Specification → Requirements** — concrete functional/non-functional requirements and
     constraints, not the literal bullets "Functional requirements" / "Non-functional
     requirements" / "Constraints"
   - **Implementation Approach** — the real design/tech choices, not "High-level design"
   - **Success Criteria** — measurable, checkable outcomes, not "Measurable outcomes"
   - **Implementation Plan** — name the actual phases, not `[Phase Name]`
   - **Testing Strategy** and **Documentation Requirements** — specific to this PEP, not generic
     bullets
   - **Risks and Mitigation** — real rows in the table; don't leave it as an empty header
   - **References** — link related PEPs found in step 3 if relevant

7. **If the AI block is enabled** (the file has a `## Claude Prompt Context` heading), fill that
   section in with real context too — not the bracketed placeholders from the template.

8. **Leave Status as Draft.** Don't flip it to Active yourself.

9. **Report the result**: the PEP ID and filename, and mention `./tools/pep-tools.sh new-branch
   <num>` as the next step when they're ready to start work — don't run it unless asked.

If the user already wrote out the PEP's content nearly verbatim earlier in the conversation, use
that content directly rather than re-drafting it from scratch.
