---
name: git-worktree-management
description: >-
  Set up and operate parallel Git worktrees on any project: collision-free ports per worktree,
  isolated containers and databases, inheritance of untracked files (.env, .npmrc...), and a
  uniform wt-* command set (wt-up, wt-start, wt-stop, wt-down, wt-clean, wt-sync, wt-info,
  wt-env, wt-test) on top of make, just or task. Use when the user wants to run several
  branches side by side, hits port/DB/container collisions between worktrees, or asks to
  bootstrap or fix worktree isolation in a repo. The runtime is a plain bash script; no LLM is
  needed once it is installed.
---

# Git worktree isolation

Installs, in a target repository, a deterministic bash runner plus thin task-runner targets so that
each Git worktree gets its own slot: its own ports, compose project, DB and environment, with the
untracked local files it needs copied from the main checkout.

**You (the agent) do the setup once. After that the repo works without you.**

## Bundled files (`references/`)

| File | Role |
|---|---|
| `worktree-runner-template.sh` | The runner. Install as `scripts/worktree-dev.sh`. Run `scripts/worktree-dev.sh help` for its full variable reference. |
| `Makefile.include.mk` | `wt-*` targets for Make (install as `Makefile.wt.mk`) |
| `Justfile.include.just` | `wt-*` recipes for Just (install as `Justfile.wt.just`) |
| `Taskfile.include.yml` | `wt:*` tasks for go-task (install as `Taskfile.wt.yml`) |
| `alternatives.md` | Detection tables and alternatives (other runners, DB strategies, proxies, secret managers). Read it only when the defaults do not fit. |

## Setup procedure

### 1. Discover (read-only, no questions yet)
Inspect the repo: task runner file (`Makefile`, `Justfile`, `Taskfile.yml`...), compose file, how the app is
started (scripts, `package.json`, `Procfile`...), the ports it listens on, what DB it uses, which untracked
local files it needs (`.env*`, `.npmrc`, `.tool-versions`...; compare `.gitignore` with what exists on disk),
and whether `.gitignore` already covers `.worktree-dev/`. Check that the repo is a Git repo with a main checkout.

### 2. Propose, then confirm
Present **one** proposal built from the defaults below, filled with what you found, and ask only about what
you could not infer (typically: the app start command, the canonical ports, the DB strategy). Never impose.

| Dimension | Default | Runner support |
|---|---|---|
| Command runner | The one already in the repo, else Make | Make / Just / Task includes; anything else: thin wrappers |
| Containers | Docker Compose if a compose file exists, else none | `docker`, `podman`, `none` |
| Database | Dedicated container per worktree (`WT_DB_SERVICE`) | other strategies: see `alternatives.md` |
| Ports | Main checkout keeps canonical ports (slot 0); linked worktrees use `BASE + slot`, slot 1..99 | built in |
| Env vars | `PORT`, `DATABASE_URL`, `DB_PORT` | renameable via `WT_ENV_*_NAME` |
| Untracked files | `.env`, `.env.local`, `.npmrc`, `.tool-versions`, `.mise.toml` copied if missing | `.worktreeinclude` |

Base ports must not overlap the canonical ports or each other's ranges (`BASE + 1..99`); pick values that are free
on the machine (e.g. app `8100`, DB `15500`). If the repo has several services needing a port, extend the runner
(it handles one app port and one DB port out of the box) rather than hacking around it.

### 3. Generate
Put these in the repo, adapting the runner only through config:
1. `scripts/worktree-dev.sh`: copy of the runner, `chmod +x`.
2. `scripts/worktree-dev.conf`: project settings (sourced by the runner), e.g.
   ```bash
   WT_PROJECT_NAME=myapp
   WT_CONTAINER_ENGINE=docker
   WT_DB_SERVICE=db
   WT_APP_CMD='exec npm run dev -- --port "$PORT"'   # must listen on $PORT
   WT_HEALTH_URL='http://127.0.0.1:{port}/health'    # optional
   WT_TEST_CMD='npm run test:smoke'                  # optional
   WT_CANONICAL_APP_PORT=3000  WT_CANONICAL_DB_PORT=5432
   WT_APP_BASE_PORT=3100       WT_DB_BASE_PORT=15500
   ```
3. The task-runner include, imported from the project's own runner file (see header comments of each include).
4. `.worktreeinclude`, listing the untracked files found in step 1 (format below).
5. `.gitignore`: add `.worktree-dev/`.
6. Compose parameterisation: published host ports must read `${APP_PORT}` / `${DB_PORT}` (the runner exports
   them) and nothing may hard-code `container_name:` or a fixed host port, otherwise worktrees collide.
7. A short "Parallel worktrees" section in the project README or CLAUDE.md listing the `wt-*` commands.

### 4. Validate (do not skip)
- `bash -n scripts/worktree-dev.sh`, and `shellcheck` if installed.
- `wt-info` in the main checkout: slot 0, canonical ports.
- Create a throwaway worktree (`git worktree add ../<repo>-wt-check -b wt-check`), then there: `wt-sync`
  (expected files appear), `wt-start` (healthy), `wt-test`, `wt-info` (same slot as before: slot is sticky),
  and confirm the main checkout can run simultaneously.
- Finish with `wt-clean`, then remove the throwaway worktree and branch **only with the user's consent**.
- Report what passed and what could not be tested (e.g. no Docker on this machine).

## The `wt-*` contract

Identical across Make (`make wt-up`), Just (`just wt-up`) and Task (`task wt:up`).

| Target | Runner call | Behaviour |
|---|---|---|
| `wt-up` | `up` | Sync untracked files, resolve slot, start dependencies, run the app **in the foreground** (needs `WT_APP_CMD`; without it only dependencies start) |
| `wt-start` | `up -d` | Same, app detached (`setsid` + PID file + log in `.worktree-dev/`), waits for health |
| `wt-stop` | `stop` | Stop the app (SIGTERM then SIGKILL) and stop containers. Data and slot kept |
| `wt-down` | `down [--purge]` | Stop the app, remove containers. `--purge` also deletes volumes and state |
| `wt-clean` | `clean` | `down --purge`. **Destructive: deletes the worktree's DB volumes. Confirm with the user first** |
| `wt-sync` | `sync` | Copy missing `.worktreeinclude` entries from the main checkout |
| `wt-info` | `info` | Slot, project name, URLs, app/DB status |
| `wt-env` | `env [--port N]` | `export` lines, for `eval "$(make -s wt-env)"` |
| `wt-test` | `test` | Run `WT_TEST_CMD`, or a health check on the app port |

## How the runner behaves (for debugging)

- **Slot** = `cksum(worktree path)` mapped into 1..99, then the first slot that is neither claimed by a peer
  worktree (`.worktree-dev/slot.env` of every `git worktree list` entry) nor has its app/DB port busy. The main
  checkout is slot 0 with canonical ports. No free slot is a hard error.
- **State is sticky**: `.worktree-dev/slot.env` is written on first use and reused by every later command,
  so `wt-info` after `wt-start` reports the real ports. It is released only by `wt-clean` / `down --purge`.
  `up --port N` overrides the app port and persists too.
- **Isolation**: compose project `<project>-wt-<dirname>-<hash>`; DB container, network and volumes follow it.
- **Config** is the environment or `scripts/worktree-dev.conf`. It is executed as shell: same trust level as
  the script itself.
- **Port conflicts** at `up` (port taken by a foreign process) fail fast with a clear message.

## `.worktreeinclude`

One path per line, relative to the repo root, `#` for comments. Looked up in the worktree first, then in the main
checkout; without any file the default list above is used.
```text
.env
.env.local
.npmrc
.vscode/settings.json
data/fixtures/            # directories are copied
link:models/              # link: = symlink to the main checkout instead of a copy
```
- Only copies when the file exists in main **and not yet** in the worktree; never overwrites local edits.
- Absolute paths and `..` are rejected.
- This copies **secrets** between directories of the same machine. List only what the build needs, and make
  sure each entry is git-ignored. Prefer a secret manager wrapper (`op run --`, `doppler run --`) when the
  project already uses one.

## Rules for the agent

- Never overwrite an existing `Makefile`, `Justfile`, compose file or `.gitignore`: edit surgically, show the diff.
- Never run `wt-clean` / `down --purge`, delete volumes, or remove worktrees without explicit user consent.
- Do not commit or print the contents of `.env*` or other copied secret files.
- If the project needs more than one app port, a non-Postgres `DATABASE_URL` shape, or a proxy, adapt through
  `WT_DB_URL_TEMPLATE`, `WT_APP_CMD` and `scripts/worktree-dev.conf` first; edit the runner only as a last resort and say so.
