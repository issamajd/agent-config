# agent-config

One repo that configures Claude Code and Codex on every machine (Windows via Git Bash, macOS, Linux).

Three layers compose into each machine's `~/.claude` and `~/.codex`:

| Layer | Folder | Holds |
| --- | --- | --- |
| common | `common/` | rules and skills for every machine and both tools |
| profile | `profiles/<name>/` | a focus area: `dotnet`, `typescript`, ... |
| machine | `machines/<name>/` | which profile this machine uses, plus local-only notes |

Each layer has the same shape:

```
claude.md            Claude instructions for this layer (imported into ~/.claude/CLAUDE.md)
agents.md            Codex instructions for this layer (concatenated into ~/.codex/AGENTS.md)
skills/shared/       skills linked into both tools
skills/claude/       skills linked into Claude only
skills/codex/        skills linked into Codex only
agents/              Claude subagents (*.md), linked as a subfolder of ~/.claude/agents
```

## First install on a machine

```bash
git clone git@github.com:issamajd/agent-config.git ~/agent-config
cd ~/agent-config
./install.sh --machine <short-name> --profile <dotnet|typescript>
git add machines/<short-name> && git commit -m "Add machine <short-name>" && git push
```

On Windows run this from Git Bash. `<short-name>` is stored in the untracked `.machine` file, so
hostname changes do not matter. Claude asks once to approve imports from outside the working
directory; say yes.

## Day to day

- Edit anything under `common/`, `profiles/` or `machines/`, commit, push.
- On another machine: `./sync.sh` (pull, then install). Skills and Claude instructions are live
  links, so a plain `git pull` already updates them; `sync.sh` also picks up new skills and
  regenerates Codex's `AGENTS.md`.
- Optional: `./install.sh --autosync` registers a login job that runs `sync.sh`
  (scheduled task on Windows, launchd on macOS, systemd user timer or cron on Linux).
  `./install.sh --no-autosync` removes it.

## Adding things

- **Skill**: put a folder with a `SKILL.md` under the right layer and audience, e.g.
  `common/skills/shared/my-skill/`. Run `./install.sh`. A later layer wins if two layers define
  the same skill name.
- **Profile**: create `profiles/<name>/` with the shape above. Point a machine at it with
  `./install.sh --profile <name>`.
- **Machine**: see "First install".
- **Subagent**: drop a `.md` into a layer's `agents/`.
## What stays out of the repo

`~/.claude/settings.json` and `~/.codex/config.toml` hold secrets and machine paths and are never
committed. Sanitized starting points live in `common/templates/`. A pre-commit hook rejects those
filenames and anything that looks like a password or token.

## Files the installer writes

| Path | How |
| --- | --- |
| `~/.claude/CLAUDE.md` | generated: one `@import` line per layer |
| `~/.claude/skills/<name>` | link into the repo (junction on Windows) |
| `~/.claude/agents/<layer>/` | link into the repo |
| `~/.codex/AGENTS.md` | generated: layers concatenated |
| `~/.codex/skills/<name>` | link into the repo |

Anything the installer replaces is moved to `~/.claude/backups/agent-config-<timestamp>/`.
Tool-managed folders (`~/.claude/skills/synced`, `~/.codex/skills/.system`, ...) are left alone.
