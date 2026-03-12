<div align="center">

# Docker Deploy Starter

**Docker + GitHub Actions CI/CD + one-click deploy to any VPS.**

Build your app. Push to deploy.

[![CI](https://github.com/heznpc/docker-deploy-starter/actions/workflows/ci.yml/badge.svg)](https://github.com/heznpc/docker-deploy-starter/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Docker](https://img.shields.io/badge/Docker-ready-2496ED.svg)](https://www.docker.com/)
[![GHCR](https://img.shields.io/badge/GHCR-ready-181717.svg)](https://ghcr.io)

**English** | [한국어](README.ko.md)

</div>

---

> **Part of [Starter Series](https://github.com/heznpc/starter-series)** — Stop explaining CI/CD to your AI every time. Clone and start.
>
> [Docker Deploy](https://github.com/heznpc/docker-deploy-starter) · [Discord Bot](https://github.com/heznpc/discord-bot-starter) · [Telegram Bot](https://github.com/heznpc/telegram-bot-starter) · [Browser Extension](https://github.com/heznpc/browser-extension-starter) · [Electron App](https://github.com/heznpc/electron-app-starter) · [npm Package](https://github.com/heznpc/npm-package-starter) · [React Native](https://github.com/heznpc/react-native-starter) · [VS Code Extension](https://github.com/heznpc/vscode-extension-starter) · [MCP Server](https://github.com/heznpc/mcp-server-starter)

---

## Quick Start

```bash
# 1. Click "Use this template" on GitHub (or clone)
git clone https://github.com/heznpc/docker-deploy-starter.git my-app
cd my-app

# 2. Replace app/ with your application
rm -rf app/
# Copy your app files here

# 3. Update Dockerfile for your language
# See docs/DOCKERFILE_EXAMPLES.md for Python, Go, Rust, Java, etc.

# 4. Test locally
cp .env.example .env
docker compose up
```

## What's Included

```
├── app/                        # Example app (replace with yours)
│   ├── server.js               # Minimal Node.js HTTP server
│   └── package.json
├── Dockerfile                  # Example build (swap for your language)
├── docker-compose.yml          # Local development
├── .github/
│   ├── workflows/
│   │   ├── ci.yml              # Dockerfile lint, compose validate, build test
│   │   ├── cd.yml              # Build → GHCR push → VPS deploy via SSH
│   │   └── setup.yml           # Auto setup checklist on first use
│   └── PULL_REQUEST_TEMPLATE.md
├── docs/
│   ├── DOCKERFILE_EXAMPLES.md  # Dockerfiles for Node, Python, Go, Rust, Java
│   ├── GHCR_SETUP.md           # GitHub Container Registry setup
│   ├── HTTPS_SETUP.md          # HTTPS with Caddy reverse proxy
│   └── VPS_DEPLOY.md           # VPS SSH deployment guide
├── scripts/
│   └── bump-version.js         # Version bump utility
└── VERSION                     # Current version
```

## Features

- **Language agnostic** — Swap the Dockerfile for any language (Node, Python, Go, Rust, Java, static)
- **CI Pipeline** — Dockerfile lint (hadolint), docker-compose validation, build verification, Trivy CVE scan on every push
- **CD Pipeline** — Build → push to GHCR → health-checked deploy to VPS via docker compose + auto GitHub Release
- **Dockerfile examples** — Multi-stage builds for Node, Python, Go, Rust, Java in docs
- **Version management** — `node scripts/bump-version.js patch/minor/major`
- **Local dev** — `docker compose up` with volume mounts for live reload
- **HTTPS guide** — Caddy reverse proxy with automatic TLS
- **Deploy guides** — Step-by-step docs for GHCR and VPS setup
- **Template setup** — Auto-creates setup checklist issue on first use

## CI/CD

### CI (every PR + push to main)

| Step | What it does |
|------|-------------|
| Lint Dockerfile | [Hadolint](https://github.com/hadolint/hadolint) checks for best practices |
| Validate compose | Verifies `docker-compose.yml` syntax |
| Build test | Builds the Docker image to catch build errors |
| Scan image | [Trivy](https://github.com/aquasecurity/trivy) scans for CRITICAL/HIGH CVEs |

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

# Rebuild after Dockerfile changes
docker compose up --build

# Bump version
node scripts/bump-version.js patch   # 1.0.0 → 1.0.1
node scripts/bump-version.js minor   # 1.0.0 → 1.1.0
node scripts/bump-version.js major   # 1.0.0 → 2.0.0
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
