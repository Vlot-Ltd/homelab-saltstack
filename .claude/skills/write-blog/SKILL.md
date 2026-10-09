---
name: write-blog
description: Use this skill when the user wants to write, generate, or fill in a Build Log (BLOG) documenting what was actually implemented for a PEP — e.g. "write a blog for PEP 5", "document what I built", "create a build log", "new-blog". Drafts the log from the PEP's plan plus real git history on the feature branch, instead of leaving template placeholders in place.
---

# Writing a BLOG (Build Log)

A BLOG exists to record what was *actually* built against what the PEP *planned* — the value is
entirely in that comparison being accurate. Never invent commits, test results, or deviations
that didn't happen; where you're not sure, ask instead of guessing.

## Steps

1. **Confirm blogs are enabled.** Check `ENABLE_BLOGS` in `.peprc`, or that `docs/blogs/` exists.
   If disabled, tell the user and stop — don't silently flip the config on.

2. **Identify the PEP.** If not given a number, try to infer it from the current branch name
   (`feature/<prefix>-NNN-...`) via `git branch --show-current`; otherwise ask.

3. **Read the PEP file in full** — this is the "planned" side. Pay particular attention to the
   Implementation Plan phases and Success Criteria; that's what you'll be comparing against.

4. **Gather the "actual" side from git:**
   ```bash
   git log --oneline <base>..HEAD          # commit history on the feature branch
   git diff <base>...HEAD --stat            # file-level scope of the change
   ```
   `<base>` is wherever the branch diverged from (usually `main` or `master`). Read individual
   commits if a subject line alone doesn't give you enough to describe what happened.

5. **Create the file:**
   ```bash
   ./tools/pep-tools.sh new-blog [blog-num] <pep-num>
   ```
   `blog-num` can be omitted to auto-assign. This command is not interactive — no stdin piping
   needed, unlike `new-pep`.

6. **Fill in the placeholder sections using Edit, grounded in what you found in steps 3–4:**
   - **Implementation Summary** — what actually got built, in prose
   - **Deviations from PEP → Changed Approaches** — only fill this in where something genuinely
     differed from the plan; leave it out (or say "none") if implementation matched the PEP
   - **Technical Implementation → Code Changes** — the real branch name and actual key commits
     from `git log`, not the placeholder `abc1234` hashes
   - **Testing Results** — only state what you can verify was actually run; ask the user rather
     than fabricate pass/fail results
   - **Monitoring and Validation → Validation Checklist** — check an item off only if you have
     evidence it's true, not by default

7. **Leave anything you're not confident about as an explicit question** to the user — metrics,
   monitoring setup, and rollback specifics especially. A BLOG is a factual record, not a plan;
   getting it wrong is worse than leaving it blank.
