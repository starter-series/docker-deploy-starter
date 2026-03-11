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
│   └── VPS_DEPLOY.md           # VPS SSH deployment guide
├── scripts/
│   └── bump-version.sh         # Version bump utility
└── VERSION                     # Current version
```

## Features

- **Language agnostic** — Swap the Dockerfile for any language (Node, Python, Go, Rust, Java, static)
- **CI Pipeline** — Dockerfile lint (hadolint), docker-compose validation, build verification on every push
- **CD Pipeline** — One-click build → push to GHCR → deploy to VPS via SSH + auto GitHub Release
- **Dockerfile examples** — Multi-stage builds for Node, Python, Go, Rust, Java in docs
- **Version management** — `./scripts/bump-version.sh patch/minor/major`
- **Local dev** — `docker compose up` with volume mounts for live reload
- **Deploy guides** — Step-by-step docs for GHCR and VPS setup
- **Template setup** — Auto-creates setup checklist issue on first use

## CI/CD

### CI (every PR + push to main)

| Step | What it does |
|------|-------------|
| Lint Dockerfile | [Hadolint](https://github.com/hadolint/hadolint) checks for best practices |
| Validate compose | Verifies `docker-compose.yml` syntax |
| Build test | Builds the Docker image to catch build errors |

### CD (manual trigger via Actions tab)

| Step | What it does |
|------|-------------|
| Version guard | Fails if git tag already exists for this version |
| Build & push | Builds image and pushes to GitHub Container Registry |
| Deploy | SSHs into your VPS, pulls new image, restarts container |
| GitHub Release | Creates a tagged release with auto-generated notes |

**How to deploy:**

1. Set up GitHub Secrets (see below)
2. Bump version: `./scripts/bump-version.sh patch`
3. Go to **Actions** tab → **Deploy** → **Run workflow**

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
./scripts/bump-version.sh patch   # 1.0.0 → 1.0.1
./scripts/bump-version.sh minor   # 1.0.0 → 1.1.0
./scripts/bump-version.sh major   # 1.0.0 → 2.0.0
```

## Switching Languages

1. Replace `app/` with your application code
2. Pick a Dockerfile from **[docs/DOCKERFILE_EXAMPLES.md](docs/DOCKERFILE_EXAMPLES.md)** (Python, Go, Rust, Java, static)
3. Update `docker-compose.yml` ports if needed
4. Update `.env.example` with your app's environment variables
5. Test: `docker compose up --build`

## Why This Over Copy-Pasting Blog Tutorials?

Every Docker + GitHub Actions tutorial teaches the same steps. But you end up copy-pasting YAML, debugging auth issues, and wiring it all together yourself. This template gives you the whole pipeline, tested and ready.

|  | This template | Blog tutorials | ChristianLempa/boilerplates |
|---|---|---|---|
| Philosophy | Thin starter with CI/CD | Learn by building | Infrastructure toolkit |
| CI/CD | Full pipeline included | You assemble it | Not included |
| Deploy target | Any VPS via SSH | Varies | Not included |
| Container registry | GHCR (built-in) | Docker Hub (manual) | Not included |
| Language | Any (swap Dockerfile) | Usually one | Docker Compose configs |
| Maintenance | Template repo, updated | Blog post, static | CLI tool, DevOps focus |

**Choose this template if:**
- You have an app and want to deploy it with Docker — without figuring out CI/CD from scratch
- You want push-to-deploy on your own VPS (not locked into a platform)
- You're using AI tools to generate code and need production deployment out of the box

**Choose something else if:**
- You're deploying to Vercel/Railway/Render (they handle this automatically)
- You need Kubernetes orchestration (this is single-container, single-server)
- You want a full infrastructure-as-code toolkit (see ChristianLempa/boilerplates)

## Contributing

PRs welcome. Please use the [PR template](.github/PULL_REQUEST_TEMPLATE.md).

## License

[MIT](LICENSE)
