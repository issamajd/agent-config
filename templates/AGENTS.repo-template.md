# <repo> (<Span.PACKAGEID>)

<!--
AGENTS.md for a gitprojects repo. Two shapes:
  framework (rndfwcore): the full file. Owns build, runtime, release flow,
    conventions and the glossary. Keep it to what rarely changes.
  child (product core or customer): under 25 lines. One paragraph on what
    the repo is and where the code is, a pointer to ../rndfwcore/AGENTS.md,
    place in the tree, then ONLY what differs from the framework repo.
Never repeat framework content in a child, never describe folder contents
agents can read themselves, never copy what BUILD/pipeline.config.yml,
modulesSolutions.config.yml or baseruntime.lock.json already say. No
machine paths, no secrets. Add a CLAUDE.md beside it containing "@AGENTS.md".
-->

One or two sentences: what this repo is, package ID, applicationNamespace, and the two or three folders where its own code lives.

Framework, build, runtime, glossary and conventions: `../rndfwcore/AGENTS.md`. Read that first. This file lists only what is different here.

## Place in the tree

- Chain or parent(s), pinned in `BUILD/baseruntime.lock.json`. Siblings if useful. Children or "none".
- Which layer a change belongs to, and the rule: if it belongs in a parent, name the parent repo and file and stop.

## Differences from the framework repo

- Base runtime: gitignored and replayed, or still tracked; which script moves it.
- Tests: the command, or "none" and what done means instead.
- Anything that only this repo does (mobile build, patching parent screens, env presets).
- DB deliverables: the RNDSCRIPTS path for this product or customer.
- Commit and branch conventions if they differ from the framework.
