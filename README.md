<div align="center">

# Docker Deploy Starter

**Docker + GitHub Actions CI/CD + one-click deploy to any VPS.**

Build your app. Push to deploy.

[![CI](https://github.com/starter-series/docker-deploy-starter/actions/workflows/ci.yml/badge.svg)](https://github.com/starter-series/docker-deploy-starter/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Docker](https://img.shields.io/badge/Docker-ready-2496ED.svg)](https://www.docker.com/)
[![GHCR](https://img.shields.io/badge/GHCR-ready-181717.svg)](https://ghcr.io)

**English** | [한국어](README.ko.md)

</div>

---

> **Part of [Starter Series](https://github.com/starter-series/starter-series)** — Stop explaining CI/CD to your AI every time. Clone and start.
>
> **Docker Deploy** · [Discord Bot](https://github.com/starter-series/discord-bot-starter) · [Telegram Bot](https://github.com/starter-series/telegram-bot-starter) · [Browser Extension](https://github.com/starter-series/browser-extension-starter) · [Electron App](https://github.com/starter-series/electron-app-starter) · [npm Package](https://github.com/starter-series/npm-package-starter) · [React Native](https://github.com/starter-series/react-native-starter) · [VS Code Extension](https://github.com/starter-series/vscode-extension-starter) · [MCP Server](https://github.com/starter-series/mcp-server-starter) · [Python MCP Server](https://github.com/starter-series/python-mcp-server-starter) · [Cloudflare Pages](https://github.com/starter-series/cloudflare-pages-starter)

---

## Quick Start

**Via [create-starter](https://github.com/starter-series/create-starter)** (recommended):

```bash
npx @starter-series/create my-service --template docker-deploy
cd my-service
# Add your app's Dockerfile + code, then:
npm run compose:check
npm run build
docker compose up
```

**Or clone directly:**

```bash
git clone https://github.com/starter-series/docker-deploy-starter my-service
cd my-service
npm run compose:check
npm run build
docker compose up
```

**Full setup (bring your own app):**

```bash
# 1. Click "Use this template" on GitHub (or clone)
git clone https://github.com/starter-series/docker-deploy-starter.git my-app
cd my-app

# 2. Replace app/ with your application
rm -rf app/
# Copy your app files here

# 3. Update Dockerfile for your language
# See docs/DOCKERFILE_EXAMPLES.md for Python, Go, Rust, Java, etc.

# 4. Test locally
cp .env.example .env
npm run smoke
docker compose up
```

## What's Included

```
├── app/                        # Example app (replace with yours)
│   ├── server.js               # Minimal Node.js HTTP server
│   └── package.json
├── Dockerfile                  # Example build (swap for your language)
├── docker-compose.yml          # Local development
├── .env.example                # Local/prod env template
├── .github/
│   ├── workflows/
│   │   ├── ci.yml              # Lint, compose validate, build test, JS tests
│   │   ├── cd.yml              # Build → GHCR push → VPS deploy via SSH
│   │   └── setup.yml           # Auto setup checklist on first use
│   └── PULL_REQUEST_TEMPLATE.md
├── docs/
│   ├── DOCKERFILE_EXAMPLES.md  # Dockerfiles for Node, Python, Go, Rust, Java
│   ├── GHCR_SETUP.md           # GitHub Container Registry setup
│   ├── HTTPS_SETUP.md          # HTTPS with Caddy reverse proxy
│   └── VPS_DEPLOY.md           # VPS SSH deployment guide
├── scripts/
│   ├── bump-version.js         # Version bump utility (validates VERSION)
│   └── deploy-with-rollback.sh # Health-checked deploy + auto rollback
├── tests/                      # node:test suites + rollback integration test
├── package.json                # `npm test` runner
├── package-lock.json           # npm audit/reproducibility lockfile
└── VERSION                     # Current version
```

## Features

- **Language agnostic** — Swap the Dockerfile for any language (Node, Python, Go, Rust, Java, static)
- **CI Pipeline** — Dockerfile lint (hadolint), docker-compose validation, build verification, Trivy CVE scan, plus `node:test` suites (version-bump + `/health`) on every push
- **CD Pipeline** — Build → push to GHCR → health-checked deploy to VPS via docker compose + auto GitHub Release
- **Real health checks** — `/health` reflects a readiness signal and can return `503`; wire your own dependency probes (DB, cache, …) so failed deploys actually roll back
- **Dockerfile examples** — Multi-stage builds for Node, Python, Go, Rust, Java in docs
- **Version management** — `node scripts/bump-version.js patch/minor/major` (validates `VERSION`, fails loudly on a malformed file instead of writing garbage)
- **Local dev** — `docker compose up` with volume mounts for live reload
- **HTTPS guide** — Caddy reverse proxy with automatic TLS
- **Deploy guides** — Step-by-step docs for GHCR and VPS setup
- **Template setup** — Auto-creates setup checklist issue on first use

## Health checks (`/health`)

The deploy pipeline rolls back when the new container fails its health check
(`docker compose up -d --wait`). That safety net only works if `/health` can
actually report failure — a `/health` that always returns `200` makes every
deploy look healthy and silently disables rollback.

- **Currently implemented** — `app/server.js` exposes `/health` backed by a
  list of async readiness checks. All checks passing → `200 {"status":"ok"}`.
  Any check returning falsy or throwing → `503 {"status":"unavailable"}`.
  Unknown paths return `404` (the example server is not a catch-all). The
  default check only confirms the HTTP listener is bound.
- **Design intent** — fail-closed: a dependency outage should surface as an
  unhealthy container so the orchestrator stops routing traffic and the CD
  rollback triggers, rather than serving a broken app behind a green check.
- **You must wire real checks.** Replace the example app and register probes
  for the dependencies your app actually needs:

  ```js
  const { createApp } = require('./server.js');
  const { server } = createApp({
    readinessChecks: [
      async () => { await db.query('SELECT 1'); return true; },
      async () => (await redis.ping()) === 'PONG',
    ],
  });
  server.listen(process.env.PORT || 3000);
  ```

- **Non-goals** — this is not a metrics/liveness framework. It is the minimal
  readiness contract the rollback logic depends on; swap in your stack's
  health library if you need more.

## CI/CD

### CI (every PR + push to main)

| Step | What it does |
|------|-------------|
| Lint Dockerfile | [Hadolint](https://github.com/hadolint/hadolint) checks for best practices |
| Validate compose | Verifies `docker-compose.yml` syntax |
| Build test | Builds the Docker image to catch build errors |
| Scan image | [Trivy](https://github.com/aquasecurity/trivy) scans for CRITICAL CVEs |

### Security & Maintenance

| Workflow | What it does |
|----------|-------------|
| CodeQL (`codeql.yml`) | Static analysis for security vulnerabilities (push/PR + weekly) |
| Maintenance (`maintenance.yml`) | Weekly CI health check — auto-creates issue on failure |
| Stale (`stale.yml`) | Labels inactive issues/PRs after 30 days, auto-closes after 7 more |

### CD (manual trigger or tag push)

| Step | What it does |
|------|-------------|
| Version guard | Fails if git tag already exists for this version |
| Build & push | Builds image and pushes to GitHub Container Registry |
| Deploy | SSHs into your VPS, pulls new image, health-checked restart via docker compose |
| Image cleanup | Prunes old images on VPS + keeps last 10 versions on GHCR |
| GitHub Release | Creates a tagged release with auto-generated notes |

**How to deploy:**

1. Set up GitHub Secrets (see below)
2. Bump version: `node scripts/bump-version.js patch`
3. **Manual:** Go to **Actions** tab → **Deploy** → **Run workflow**
4. **Auto:** Push a version tag — `git tag v$(cat VERSION) && git push --tags`

### GitHub Secrets

| Secret | Description |
|--------|-------------|
| `VPS_HOST` | Your server IP or domain |
| `VPS_USER` | SSH username |
| `VPS_SSH_KEY` | SSH private key |

See **[docs/VPS_DEPLOY.md](docs/VPS_DEPLOY.md)** for a detailed setup guide.

> **Note:** GHCR authentication uses `GITHUB_TOKEN` automatically — no extra secrets needed.

## Development

```bash
# Start locally with Docker
docker compose up

# Credential-free smoke before first run
npm run compose:check
npm run build

# Rebuild after Dockerfile changes
docker compose up --build

# Bump version (fails loudly if VERSION is malformed — never writes 1.2.NaN)
node scripts/bump-version.js patch   # 1.0.0 → 1.0.1
node scripts/bump-version.js minor   # 1.0.0 → 1.1.0
node scripts/bump-version.js major   # 1.0.0 → 2.0.0
```

### Tests

```bash
# Node tests: version-bump validation + /health (200) and unknown path (404)
npm test

# Compose config + Docker image smoke
npm run smoke

# Rollback integration test (needs Docker; also run in CI)
bash tests/rollback-integration.sh
```

## Switching Languages

1. Replace `app/` with your application code
2. Pick a Dockerfile from **[docs/DOCKERFILE_EXAMPLES.md](docs/DOCKERFILE_EXAMPLES.md)** (Python, Go, Rust, Java, static)
3. Update `docker-compose.yml` ports if needed
4. Update `.env.example` with your app's environment variables
5. Test: `docker compose up --build`

## Why VPS?

Platforms like Railway/Render/Vercel are great for single apps. But when you need more, VPS wins:

- **One server, everything** — Run app + DB + cache on one machine instead of paying per service
- **No vendor lock-in** — Standard Docker + SSH. Move between any VPS provider
- **Full system access** — GPU, custom packages, compliance, any OS-level config
- **Always on** — No cold starts, no spin-down, no sleep timers
- **Predictable cost** — Flat monthly price, no usage-based surprises

**Use Railway/Render/Vercel instead if:**
- You're deploying a single web app and want zero infrastructure management
- You need managed databases with automatic backups

## Why This Over Blog Tutorials?

Every "Docker + GitHub Actions" tutorial teaches the same steps. You end up copy-pasting YAML, debugging GHCR auth, wiring SSH keys, and setting up health checks — every single time.

This template gives you the entire pipeline, tested and ready. `git clone` → replace `app/` → push → deployed.

## Contributing

PRs welcome. Please use the [PR template](.github/PULL_REQUEST_TEMPLATE.md).

## License

[MIT](LICENSE)
