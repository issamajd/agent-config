# Machine: my-mac

Majd's personal MacBook Air. Notes that apply only to this machine go here.

## Staging VPS

- `ssh stage-vps` reaches the staging VPS (187.127.97.161, Ubuntu 24.04) as root; `ssh stage-vps-dev` reaches it as `majd`, the dev user. Both use `~/.ssh/id_ed25519`, with no password.
- It is staging only, not the live server. Never treat it, or anything deployed on it, as production.
- Dev work happens as `majd` in `~/projects` (coachak, coach-me-docs). `/root/projects/active` holds the checkouts the staging sites deploy from; leave them to deploys.
- It also hosts coachak's self-hosted GitHub Actions runner (`stage-vps` label, user `gh-runner`). Jobs run one at a time on the same box as the staging sites.
