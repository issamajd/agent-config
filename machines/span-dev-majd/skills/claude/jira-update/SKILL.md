---
name: jira-update
description: Update a SPAN Jira work item (span-group.atlassian.net) after working on it - reply to the tester's findings with a short comment, fill the Technical Comments field, and set Start date, End date and Progress %. Use when the user says "update the jira", "reply on jira", "comment on the ticket", "set progress/dates on <KEY>", or asks to report a fix back to Jira. Does not change status unless asked.
---

# Jira update (SPAN)

Reports work back on a Jira item the way the SPAN testers read it: what was wrong, what changed,
how it was tested, what to retest. Uses the Atlassian MCP tools (`getJiraIssue`, `editJiraIssue`,
`addCommentToJiraIssue`). Site: `span-group.atlassian.net` (pass it as `cloudId`).

## Fields

| Field | Id | Type | Value |
| --- | --- | --- | --- |
| Start date | `customfield_10015` | date `YYYY-MM-DD` | Day work started. Keep an existing earlier value. |
| End date | `customfield_10037` | date `YYYY-MM-DD` | Set when Progress is `1` (normally today); otherwise leave it empty. |
| Progress % | `customfield_10391` | **fraction 0-1** | Jira shows it multiplied by 100: send `1` for 100 %, `0.5` for 50 %. Sending `100` shows 10000 %. Never lower an existing value without saying why. |
| Technical Comments | `customfield_10106` | text (markdown) | Short technical note, replaced on each update. |
| Tester Comments | `customfield_10591` | text | Written by the tester. Read it, never edit it. |

Progress scale (value to send): `1` = work done and tested (by Majd, the tester, or our own harness/UAT
run; a pending customer-side retest or customer-supplied values does not hold it back). `0.7` = fixed,
not tested yet. `0.5` = root cause found, fix in progress. `0.2` = investigating.

If a field id stops working (Jira admin change), re-read them with
`getJiraIssue(fields=["*all"], expand="names")` and match by name.

## Procedure

1. **Read the item.** `getJiraIssue` with `fields: ["summary","description","status","comment","customfield_10015","customfield_10037","customfield_10391","customfield_10106","customfield_10591","timetracking"]`
   and `responseContentFormat: "markdown"`. Note every point the tester raised: the description's
   "Tester Comments" section on rework items, the Tester Comments field, and the latest comments.
2. **Collect the facts from this session.** Root cause, the change (repo + file, or DB script),
   how it was tested and by whom, what is still open. Do not claim a test that did not happen; a test
   by Majd on the desktop counts as "verified", a harness or mock counts as "verified by us".
3. **Write the Technical Comments field** (replace, 4-8 lines, markdown):
   ```
   **Cause:** <one or two sentences>
   **Fix:** <repo> - <file(s)>: <what changed, in plain words>
   **DB / config:** <script or XML, or "none">
   **Deploy:** <what must be released or run: DLLs, scripts, InitializeXal, restart>
   ```
4. **Write the comment** (new comment, markdown, 5-12 lines). Address the tester's points in order:
   ```
   Fixed. <one-line summary>
   - <tester point 1>: <answer>
   - <tester point 2>: <answer>
   **Tested:** <who/how, result>
   **Please retest:** <numbered steps, what the expected result is>
   **Open:** <only if something is left, e.g. waiting for OAuth values>
   ```
   Plain English, no blame, no stack traces. File names are fine; no passwords, tokens, secrets,
   client ids or internal server addresses.
5. **Show the draft first** (fields + comment) unless Majd said to post directly ("update the tasks",
   "update the jira" count as posting directly). Jira is shared with the customer's testers, so posting
   is outward-facing.
6. **Post.** `editJiraIssue` with `contentFormat: "markdown"` and
   `fields: { customfield_10015, customfield_10037 (or omit), customfield_10391, customfield_10106 }`, then
   `addCommentToJiraIssue` with `contentFormat: "markdown"`.
7. **Verify.** Re-read the four fields and the last comment; report what was set per item. For several
   items, one `searchJiraIssuesUsingJql` with `key in (...)` and the four field ids is enough.
8. **Fix a posted comment in place** with `addCommentToJiraIssue` + `commentId` (same body format)
   rather than adding a correction comment.

## Time tracking (only when asked)

- "Set the time tracking to 30 mins" means log work: `addWorklogToJiraIssue` with `timeSpent: "30m"`
  (also `2h`, `1d`). Omit `started` to book it now, or pass an ISO date-time for an earlier day. Read
  `timetracking` and `worklog` first so an existing worklog is updated (`worklogId`), not duplicated.
- Items arrive with an Original Estimate (usually `1d`). A worklog auto-reduces Remaining by the logged
  time (1d becomes 7h 30m), and the tool has no option to change that. To close the estimate on
  finished work, `editJiraIssue` with `fields: { timetracking: { remainingEstimate: "0m" } }`, only if
  Majd asks. Never touch the Original Estimate.
- Verify with `timetracking` in the same read-back as the other fields.

## Notes

- Comments come back with `jsdPublic: true`: the customer's testers see them. Write for them.
- Several items: `editJiraIssue` and `addCommentToJiraIssue` for different items can run in parallel.
- Partial work (Progress < 100) still gets a comment; put what is missing under **Open** and say who
  has to provide it.

## Don'ts

- Do not transition the status, change the assignee, or log work unless asked.
- Do not edit the description or the Tester Comments field.
- Do not set an End date while Progress is below `1`, or a Start date later than an existing one.
- Do not paste whole diffs; one short snippet at most, only if it explains the fix better than words.
- PR numbers go in Technical Comments only; the tester-facing comment says what changed, not where.
  Do not mention recordings or attachments that are not on the item (Majd keeps recordings private).
- Never ask for credentials, client secrets or tokens to be posted in Jira; ask for them "through a
  secure channel (not in Jira)".
- Do not claim "verified by the tester": that is the tester's call after retest.
