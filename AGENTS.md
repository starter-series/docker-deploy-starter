# Docker Deploy Starter

Language-agnostic Docker + GitHub Actions CI/CD + VPS SSH deployment starter.

## Project Structure

```
app/              → Example app (replace with your own)
Dockerfile        → Example Node.js (swap for your language, see docs/DOCKERFILE_EXAMPLES.md)
docker-compose.yml → Local dev + VPS deployment
.env.example      → Environment variables template
VERSION           → Single source of truth for version (1.0.0)
scripts/bump-version.js → Version bumping (patch/minor/major)
docs/             → Setup guides (VPS, GHCR, HTTPS, Dockerfile examples)
```

## CI/CD Pipeline

- **ci.yml**: Runs on push/PR to main. Hadolint lint + docker-compose validate + Docker build test + Trivy CVE scan (CRITICAL/HIGH). No secrets needed.
- **cd.yml**: Manual trigger OR tag push (v*). Builds image (Buildx + GHA cache) → pushes to GHCR → deploys to VPS via SSH → cleans old images → creates GitHub Release. Concurrency controlled (no parallel deploys).
- **setup.yml**: First push only. Auto-creates GitHub Issue with setup checklist.

## Secrets (for CD)

| Secret | Required | Purpose |
|--------|----------|---------|
| `VPS_HOST` | Yes | VPS IP or domain |
| `VPS_USER` | Yes | SSH username |
| `VPS_SSH_KEY` | Yes | SSH private key (full PEM content) |
| `APP_PORT` | No | Defaults to 3000 |
| `GITHUB_TOKEN` | Auto | Provided by GitHub Actions |

## What to Modify

- `app/` → Replace with your application code
- `Dockerfile` → Swap for your language (copy from docs/DOCKERFILE_EXAMPLES.md)
- `.env.example` → Add your app-specific environment variables
- `docker-compose.yml` → Update ports, volumes, service name if needed
- `VERSION` → Bump via `node scripts/bump-version.js patch|minor|major`

## Do NOT Modify

- `.github/workflows/ci.yml` → CI pipeline structure
  - **Why**: Hadolint → compose validate → build → Trivy scan 순서가 의도적. 빠른 검사부터 느린 검사 순서로 fail-fast.
- `.github/workflows/cd.yml` → Deployment pipeline
  - **Why**: GHCR push → SSH deploy → cleanup → release 순서에 의존성이 있음. 순서 변경 시 미배포 이미지가 릴리즈되거나, 배포 전 이미지가 정리될 수 있음.
- Version guard logic in cd.yml
  - **Why**: 같은 버전을 두 번 배포하면 GHCR 태그 충돌 + GitHub Release 중복 생성. 이 guard가 없으면 CI 통과해도 CD에서 조용히 깨짐.
- Health check pattern in Dockerfile and docker-compose.yml
  - **Why**: `docker compose up -d --wait`가 health check 통과를 기다림. health check 없으면 컨테이너 시작 = 배포 성공으로 판단해서 깨진 앱이 배포될 수 있음.
- Concurrency control in cd.yml
  - **Why**: 동시에 두 배포가 실행되면 SSH에서 race condition 발생. `cancel-in-progress: false`로 순서대로 실행.

## Customization Examples

- **Change port**: Set `APP_PORT` secret in GitHub + update `EXPOSE` in Dockerfile + update `.env`
- **Add database**: Add service to docker-compose.yml, add DB env vars to .env.example
- **Switch to Python/Go/Rust/Java**: Copy Dockerfile from docs/DOCKERFILE_EXAMPLES.md, replace app/
- **Add HTTPS**: Follow docs/HTTPS_SETUP.md (Caddy reverse proxy)
