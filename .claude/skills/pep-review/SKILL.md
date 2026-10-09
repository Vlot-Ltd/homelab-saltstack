---
name: pep-review
description: Use this skill when the user wants a PEP reviewed for quality or completeness before moving it out of Draft — e.g. "review this PEP", "is PEP 5 ready for Active", "check this PEP", "review my PEP before I submit it". Checks for unfilled template boilerplate, vague or unmeasurable content, and broken cross-references — complementary to `pep-tools.sh stubs`, which only catches PEPs that are still verbatim template text.
---

# Reviewing a PEP

`pep-tools.sh stubs` catches PEPs nobody has touched yet. This skill catches the next failure
mode: PEPs that were edited, but not well enough to actually be useful — vague requirements,
unmeasurable success criteria, an empty risks table, or cross-references to PEPs that don't
exist.

## Steps

1. **Identify the PEP** — by number, path, or the currently open file.

2. **Run `./tools/pep-tools.sh stubs`.** If this PEP is flagged as still-mostly-boilerplate, lead
   with that finding — no need to check anything else in detail until it's actually been written.

3. **Read the full file** and check each section against `docs/templates/pep-template.md`,
   flagging anything that's still template language or otherwise weak:
   - **Abstract** — still generic/placeholder text, or vague enough to describe any PEP
   - **Motivation** — doesn't explain a real, specific problem
   - **Specification → Requirements** — bullets are still literally "Functional requirements" /
     "Non-functional requirements" / "Constraints" rather than actual content
   - **Success Criteria** — not measurable — no way to tell after the fact whether it succeeded
   - **Implementation Plan** — phase names still bracketed placeholders like `[Phase Name]`
   - **Risks and Mitigation** — table has only the header row, or rows with empty cells
   - **Supersedes / Superseded-By** — if set to anything other than the "(if applicable)"
     placeholder, verify that PEP ID actually exists under `docs/peps/`
   - **References → Related PEPs** — verify referenced IDs actually exist
   - **Status** — one of Draft / Active / Implemented / Rejected / Superseded / Informational

4. **Report as a short checklist** — ✅ for what's solid, ⚠️ for what needs work, one line of
   reasoning each. This is a review, not a rewrite: don't paste in replacement prose unprompted.

5. **Offer to fix specific issues via Edit**, but only after the user says which ones they want
   addressed.
