# Detection tables & alternatives

Load this file only when the repository does not fit the defaults of `SKILL.md`
or when the user asks for an alternative. The bundled runner natively supports
Docker Compose, Podman Compose and bare host processes; everything else below
is realised by wrapping `WT_APP_CMD` / `WT_COMPOSE_FILE` or by adapting the runner.

## 1. Detecting the project

### Task runner
| File | Propose |
|---|---|
| `Makefile` | Make (default) |
| `Justfile` / `justfile` | Just |
| `Taskfile.yml` / `Taskfile.yaml` | Task (go-task) |
| `Earthfile` | Earthly |
| `mise.toml` / `.tool-versions` | Mise tasks |
| `package.json` | npm / pnpm / yarn / bun scripts |
| `Cargo.toml` (`Makefile.toml`) | cargo-make |
| `pyproject.toml` | Poetry / PDM / Hatch / `uv run` |
| `build.gradle` / `pom.xml` | Gradle / Maven |

Only Make, Just and Task have a ready-made include in this skill. For any other
runner, write thin targets that call `scripts/worktree-dev.sh <subcommand>`.

### Container / process runtime
| Signal | Propose |
|---|---|
| `compose.y(a)ml`, `docker-compose.y(a)ml` | Docker Compose (default) |
| `podman` / `podman-compose` on the machine | Podman Compose |
| `nerdctl` on the machine | nerdctl compose (set `WT_CONTAINER_ENGINE=docker` with a `docker` shim, or adapt `compose()`) |
| `Procfile` / `process-compose.yaml` | process-compose / Overmind / Foreman (run it as `WT_APP_CMD`) |
| `devenv.nix` / `flake.nix` | devenv / Nix (run it as `WT_APP_CMD`) |
| nothing | Bare host processes (`WT_CONTAINER_ENGINE=none`) |

### Default ports of the main checkout (slot 0)
- **Frontend**: Vite 5173, React/Next 3000, Angular 4200, Nuxt 3000, SvelteKit 5173.
- **Backend**: Spring Boot / Go / NestJS 8080, FastAPI / Django 8000, Node/Express 3000 or 4000, .NET 5000, Rails 3000.
- **Services**: PostgreSQL 5432, MySQL/MariaDB 3306, Redis 6379, MongoDB 27017, RabbitMQ 5672/15672.

## 2. Alternatives by dimension

### Container & process runtime
- **Podman Compose**: rootless, daemonless; good isolation on shared machines.
- **nerdctl compose**: Docker-compatible CLI for containerd.
- **Dev Containers (`devcontainer` CLI)**: one isolated devcontainer per worktree.
- **Procfile / `process-compose` / `overmind` / `foreman`**: multi-service on the host without virtualisation overhead.
- **Nix / devenv**: hermetic environment per directory.
- **Bare host processes**: `setsid` + PID file (what the runner does), or systemd user services.

### Database isolation
- **Dedicated container per worktree** *(default)*: own volume and host port; total data/migration isolation.
- **Shared instance, one database per worktree** (`<db>_<slot>`): lighter; the app or a hook must create the DB.
- **Shared instance, one schema per worktree** (`search_path = wt_<slot>, public`).
- **File-based** (SQLite / DuckDB / LibSQL in `.worktree-dev/app.db`): zero RAM when idle.
- **Branching / copy-on-write**: Neon, PlanetScale, Supabase branches, ZFS/Btrfs snapshots.
- **Cache & queue isolation**: Redis DB index (`SELECT <slot>`) or key prefix (`wt:<slot>:*`), RabbitMQ vhost (`/wt_<slot>`).

### Port allocation & routing
- **`BASE + slot`** *(default, implemented)*.
- **Segmented ranges per service** (apps `8100-8199`, DBs `15500-15599`, metrics `19000-19099`): same arithmetic with more base ports.
- **Local reverse proxy** (Traefik, Caddy, nginx-proxy) on `<branch-slug>.<project>.localhost`: browsers resolve `*.localhost` to 127.0.0.1 (RFC 6761); Caddy also gives local HTTPS.
- **Ephemeral port (port 0)**: the app binds port 0 and the chosen port is written back to `.worktree-dev/slot.env`. Needs app cooperation; not implemented by the runner.

### Environment variables & secrets
- **Canonical names** *(default)*: `PORT`, `DATABASE_URL`, `REDIS_URL`; rename through `WT_ENV_*_NAME`.
- **Framework prefixes**: `VITE_API_URL`, `NEXT_PUBLIC_APP_PORT`, `SPRING_APPLICATION_JSON`, `ASPNETCORE_URLS`: export them from `WT_APP_CMD` or the conf file.
- **Shell loaders**: `direnv` (`.envrc` sourcing `.worktree-dev/slot.env`), `mise` (`.mise.local.toml`).
- **Secret managers**: `op run --env-file=.env --`, `infisical run --`, `doppler run --`, Vault / AWS Secrets Manager: prefix `WT_APP_CMD` with the wrapper instead of copying secrets between worktrees.

### Untracked files worth inheriting
- Local env: `.env`, `.env.local`, `.env.development.local`.
- Registry credentials: `.npmrc`, `.pypirc`, `pip.conf`, `nuget.config`, `~/.m2`-style `settings.xml`, `.cargo/config.toml`.
- SDK versions: `.tool-versions`, `.mise.toml`, `.nvmrc`, `.node-version`, `.python-version`, `.ruby-version`, `.sdkmanrc`.
- IDE: `.vscode/settings.json`, `.idea/runConfigurations/`.
- Large read-only data (models, datasets, caches): use `link:` entries, not copies.
- Per-worktree-only ignores: `.git/info/exclude` rather than the shared `.gitignore`.
