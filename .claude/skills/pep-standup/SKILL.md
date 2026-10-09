---
name: pep-standup
description: Use this skill when the user wants a status update, standup summary, or meeting-prep recap of PEPs — e.g. "give me a standup update", "what's the PEP status", "summarize progress since last week", "what's next". Turns the CLI's raw status/next output into a short narrative summary instead of a listing the user has to read and synthesize themselves.
---

# PEP Standup Summary

`./tools/pep-tools.sh status --since <date>` and `./tools/pep-tools.sh next` already produce
copy/paste-ready grouped output — this skill's job is to turn that into something someone would
actually say out loud in a standup, not just relay the raw listing.

## Steps

1. **Determine the time window.** Ask "since when?" if not specified. Default to 7 days ago if
   the user doesn't care, or infer a date from an earlier mention of the last standup/check-in.

2. **Run both commands:**
   ```bash
   ./tools/pep-tools.sh status --since <date>
   ./tools/pep-tools.sh next
   ```

3. **Synthesize — don't just relay the output.** Organize by what someone needs to hear, not by
   the tool's section order:
   - **Shipped / completed this period** — one line each, from the "Completed" section
   - **In progress** — what changed (from "Other updates"), and flag anything that looks stuck
     (Draft/Active status with an Updated date well before the window — i.e. nothing's moved)
   - **Newly raised** — brief, from "New PEPs raised"
   - **Up next** — the top 1-2 High priority items from `next`; mention Medium/Low only if
     nothing High is queued
   - **Needs attention** — anything `status` flagged with an unexpected or missing status field

4. **Keep it short.** This is for reading aloud or pasting into a chat message, not a report.
   Prefer prose bullets over restating raw command output.

5. **If nothing changed in the window, say so plainly** rather than padding the summary to look
   substantial.
