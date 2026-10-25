# Machine: stage-vps

Ubuntu 24.04 VPS (4 vCPU, 16GB) used for staging and remote dev. Notes that apply only to this machine go here.

## What this box is

- Staging only, not the live server. Nothing here is production.
- Agents run as `majd`, which has passwordless sudo and Docker access. Repos live in `~/projects`.
- The staging sites (coach-me-docs, coachme-feed) run as Docker Compose projects behind Traefik (`/docker/traefik`) and deploy from `/root/projects/active`. Don't stop or rebuild them, and don't touch Traefik, unless asked.
- coachak's self-hosted GitHub Actions runner lives here (user `gh-runner`, service `actions.runner.issamajd-coachak.stage-vps`). Its job hooks (`/home/gh-runner/job-cleanup.sh`) run `docker compose down --volumes` in the checkout before and after each job.
- CI jobs and a local `docker compose up` in `~/projects/coachak` bind the same host ports (3000, 3001, 5432, 6379, 8080, 9000, 9001, 3310). Stop the local stack (`docker compose down`) before pushing, or the job fails to bind; a running job does the same to a local stack.

## Tools

- Node 24 and pnpm (Corepack), Docker, gh, uv, ffmpeg, poppler-utils, qpdf (11.10+ in `/usr/local/bin`), and Playwright's Chromium dependencies are installed system-wide.
- No desktop or GUI. Computer use, the Chrome extension and screen recording of native windows don't work here; headless Playwright does.
