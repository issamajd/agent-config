---
name: html-communication
description: >-
  Present something to the user as a readable HTML Artifact instead of a wall of
  markdown: a plan, an explanation, an architecture walkthrough, a comparison of
  options, a review summary. Use when the user says "HTML", "as a page", "make
  it readable", "explain this properly", "walk me through", or asks for a plan
  (plan mode, ExitPlanMode, "how would you tackle this"). Not for short answers.
---

# HTML Communication

Long explanations and plans presented as a wall of markdown are hard to scan and
easy to skim past. This skill turns what you were going to write into a polished,
theme-aware HTML **Artifact** the user can actually read: the point up top, the
detail in sections, files and risks where they belong. It does **not** change how
you *think* about the content or the approval flow; it changes only the surface
you present it on.

## When this applies

- The user asks for HTML, a page, or a more readable or thorough explanation.
- You are about to hand over a plan for sign-off: plan mode (`ExitPlanMode`) or
  an informal "here's how I'd approach it".
- You are about to write more than a screen of markdown explaining how something
  works, why it broke, or what the options are.

If the answer is genuinely short, a few lines of markdown in chat is faster and
respects the user's time. Use judgment.

## Workflow

Do your normal research and thinking first. This skill is about *presentation*;
good content still comes from understanding the code. Then:

1. **Load design guidance.** Invoke the `frontend-design` skill (the user wants
   its aesthetic sensibility applied here). The `Artifact` tool will separately
   pull in `artifact-design` for its own constraints; that is expected.

2. **Decide the sections.** For a plan, read `references/plan-anatomy.md` and
   pick the sections that plan actually needs. For an explanation, let the
   subject set the structure: what it is, how it works (a diagram or sequence
   if flow matters), why it is that way, where the traps are, what to do next.
   Don't fill sections with filler; three honest sections beat five padded ones.

3. **Build the HTML.** Start from `assets/plan-scaffold.html`. It is body-content
   only and already handles the parts that are easy to get wrong: light/dark
   theming that respects the viewer's toggle, responsiveness with no horizontal
   page scroll, and a fully self-contained page (the Artifact CSP blocks external
   fonts, scripts and images, so everything stays inline). Treat it as a
   **starting point to riff on**, not a template: rename and reorder the sections
   for the subject, retune palette, type and layout per `frontend-design`, and
   keep the theming and responsiveness mechanics intact. Replace every
   `{{ placeholder }}` with real content and delete sections you don't use.

4. **Render it.** Write the file to your scratchpad directory, then call the
   `Artifact` tool with that file path. Give it a stable `<title>` (two to four
   words naming the subject), a one-sentence `description`, and an `icon` such
   as `map` for a plan or `book` for an explanation. If you revise after
   feedback, edit the same file and call `Artifact` again with the same path so
   it redeploys to the same URL.

5. **Present it.** In chat, keep it to 2–3 lines: link the artifact and give the
   one-sentence gist. The artifact *is* the content; don't re-dump it as markdown
   alongside.
   - **In plan mode:** still call `ExitPlanMode` for approval, but its markdown
     can be a compact digest (title + step titles) that points to the artifact.
   - **Otherwise:** ask what to change, or stop if nothing is needed.

## What makes the page good

The design should serve the reading, not decorate it. Aim for:

- **Point first.** The title names the outcome or the subject, not the chore.
  The intro says in a sentence why the reader should care or why this approach.
- **Scannable.** Short sections with one idea each. Concrete names of files,
  functions and commands where they help, in code style.
- **Honest.** Decisions the user must weigh in on, assumptions, and unknowns go
  in a visible section, not buried in prose, so they can be vetoed cheaply.
- **Restraint.** No filler sections, no restating the page in chat, no design
  flourish that doesn't help someone read faster.

See `references/plan-anatomy.md` for the plan-specific section guide and effort
calibration.
