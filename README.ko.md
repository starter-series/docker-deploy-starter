<div align="center">

# Docker Deploy Starter

**Docker + GitHub Actions CI/CD + 원클릭 VPS 배포.**

앱을 만들고, 푸시하면 배포됩니다.

[![CI](https://github.com/starter-series/docker-deploy-starter/actions/workflows/ci.yml/badge.svg)](https://github.com/starter-series/docker-deploy-starter/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Docker](https://img.shields.io/badge/Docker-ready-2496ED.svg)](https://www.docker.com/)
[![GHCR](https://img.shields.io/badge/GHCR-ready-181717.svg)](https://ghcr.io)

[English](README.md) | **한국어**

</div>

---

> **[Starter Series](https://github.com/starter-series/starter-series)** — 매번 AI한테 CI/CD 설명하지 마세요. clone하고 바로 시작하세요.
>
> [Docker Deploy](https://github.com/starter-series/docker-deploy-starter) · [Discord Bot](https://github.com/starter-series/discord-bot-starter) · [Telegram Bot](https://github.com/starter-series/telegram-bot-starter) · [Browser Extension](https://github.com/starter-series/browser-extension-starter) · [Electron App](https://github.com/starter-series/electron-app-starter) · [npm Package](https://github.com/starter-series/npm-package-starter) · [React Native](https://github.com/starter-series/react-native-starter) · [VS Code Extension](https://github.com/starter-series/vscode-extension-starter) · [MCP Server](https://github.com/starter-series/mcp-server-starter) · [Cloudflare Pages](https://github.com/starter-series/cloudflare-pages-starter)

---

## 빠른 시작

```bash
# 1. GitHub에서 "Use this template" 클릭 (또는 clone)
git clone https://github.com/starter-series/docker-deploy-starter.git my-app
cd my-app

# 2. app/ 폴더를 내 앱으로 교체
rm -rf app/
# 내 앱 파일 복사

# 3. Dockerfile을 내 언어에 맞게 수정
# Python, Go, Rust, Java 등은 docs/DOCKERFILE_EXAMPLES.md 참고

# 4. 로컬 테스트
cp .env.example .env
docker compose up
```

## 구성

```
├── app/                        # 예시 앱 (내 앱으로 교체)
│   ├── server.js               # 최소 Node.js HTTP 서버
│   └── package.json
├── Dockerfile                  # 예시 빌드 (언어별 교체)
├── docker-compose.yml          # 로컬 개발용
├── .github/
│   ├── workflows/
│   │   ├── ci.yml              # Dockerfile 린트, compose 검증, 빌드 테스트
│   │   ├── cd.yml              # 빌드 → GHCR 푸시 → VPS SSH 배포
│   │   └── setup.yml           # 첫 사용 시 셋업 체크리스트 자동 생성
│   └── PULL_REQUEST_TEMPLATE.md
├── docs/
│   ├── DOCKERFILE_EXAMPLES.md  # Node, Python, Go, Rust, Java용 Dockerfile
│   ├── GHCR_SETUP.md           # GitHub Container Registry 설정
│   ├── HTTPS_SETUP.md          # Caddy 리버스 프록시 + 자동 HTTPS
│   └── VPS_DEPLOY.md           # VPS SSH 배포 가이드
├── scripts/
│   └── bump-version.js         # 버전 범프
└── VERSION                     # 현재 버전
```

## 기능

- **언어 무관** — Dockerfile만 바꾸면 Node, Python, Go, Rust, Java, 정적 사이트 모두 가능
- **CI 파이프라인** — Dockerfile 린트 (hadolint), docker-compose 검증, 빌드 테스트
- **CD 파이프라인** — 빌드 → GHCR 푸시 → docker compose 헬스체크 기반 VPS 배포 + GitHub Release 자동 생성
- **Dockerfile 예시** — Node, Python, Go, Rust, Java용 멀티스테이지 빌드 docs 제공
- **버전 관리** — `node scripts/bump-version.js patch/minor/major`
- **로컬 개발** — `docker compose up`으로 볼륨 마운트 + 라이브 리로드
- **HTTPS 가이드** — Caddy 리버스 프록시 + 자동 TLS
- **배포 가이드** — GHCR, VPS 설정 단계별 문서
- **템플릿 셋업** — 첫 사용 시 체크리스트 이슈 자동 생성

## CI/CD

### CI (PR + main 푸시마다)

| 단계 | 설명 |
|------|------|
| Dockerfile 린트 | [Hadolint](https://github.com/hadolint/hadolint)로 베스트 프랙티스 검사 |
| Compose 검증 | `docker-compose.yml` 문법 확인 |
| 빌드 테스트 | Docker 이미지 빌드로 오류 사전 감지 |

### 보안 & 유지보수

| 워크플로우 | 역할 |
|-----------|------|
| CodeQL (`codeql.yml`) | 보안 취약점 정적 분석 (push/PR + 주간) |
| Maintenance (`maintenance.yml`) | 주간 CI 헬스 체크 — 실패 시 이슈 자동 생성 |
| Stale (`stale.yml`) | 비활성 이슈/PR 30일 후 라벨링, 7일 후 자동 종료 |

### CD (수동 실행 또는 태그 푸시)

| 단계 | 설명 |
|------|------|
| 버전 확인 | 이미 존재하는 태그면 실패 |
| 빌드 & 푸시 | 이미지 빌드 후 GitHub Container Registry에 푸시 |
| 배포 | VPS에 SSH 접속, 새 이미지 풀, docker compose로 헬스체크 기반 재시작 |
| 이미지 정리 | VPS 오래된 이미지 정리 + GHCR 최근 10개 버전 유지 |
| GitHub Release | 자동 릴리스 노트와 함께 태그 생성 |

**배포 방법:**

1. GitHub Secrets 설정 (아래 참고)
2. 버전 범프: `node scripts/bump-version.js patch`
3. **수동:** **Actions** 탭 → **Deploy** → **Run workflow**
4. **자동:** 버전 태그 푸시 — `git tag v$(cat VERSION) && git push --tags`

### GitHub Secrets

| Secret | 설명 |
|--------|------|
| `VPS_HOST` | 서버 IP 또는 도메인 |
| `VPS_USER` | SSH 사용자명 |
| `VPS_SSH_KEY` | SSH 개인키 |

자세한 설정은 **[docs/VPS_DEPLOY.md](docs/VPS_DEPLOY.md)** 참고.

> **참고:** GHCR 인증은 `GITHUB_TOKEN`을 자동으로 사용합니다 — 추가 시크릿 불필요.

## 개발

```bash
# Docker로 로컬 실행
docker compose up

# Dockerfile 변경 후 재빌드
docker compose up --build

# 버전 범프
node scripts/bump-version.js patch   # 1.0.0 → 1.0.1
node scripts/bump-version.js minor   # 1.0.0 → 1.1.0
node scripts/bump-version.js major   # 1.0.0 → 2.0.0
```

## 언어 변경

1. `app/`을 내 앱 코드로 교체
2. **[docs/DOCKERFILE_EXAMPLES.md](docs/DOCKERFILE_EXAMPLES.md)**에서 Dockerfile 선택 (Python, Go, Rust, Java, 정적)
3. 필요하면 `docker-compose.yml` 포트 수정
4. `.env.example`에 내 앱의 환경변수 추가
5. 테스트: `docker compose up --build`

## 왜 VPS?

Railway/Render/Vercel 같은 플랫폼은 단일 앱에는 좋습니다. 하지만 그 이상이 필요하면 VPS가 유리합니다:

- **서버 하나에 전부** — 앱 + DB + 캐시를 한 머신에서. 서비스당 과금 없음
- **벤더 종속 없음** — 표준 Docker + SSH. 어떤 VPS든 이동 가능
- **시스템 전체 접근** — GPU, 커스텀 패키지, 컴플라이언스, OS 레벨 설정
- **항상 켜져 있음** — 콜드 스타트 없음, 슬립 없음
- **예측 가능한 비용** — 월 정액, 사용량 기반 청구 없음

**Railway/Render/Vercel이 나은 경우:**
- 웹 앱 하나 배포하고 인프라 관리 제로를 원할 때
- 자동 백업이 포함된 매니지드 DB가 필요할 때

## 왜 블로그 튜토리얼 대신?

"Docker + GitHub Actions" 튜토리얼은 전부 같은 걸 가르칩니다. YAML 복붙하고, GHCR 인증 디버깅하고, SSH 키 연결하고, 헬스체크 설정하는 걸 매번 반복하게 됩니다.

이 템플릿은 전체 파이프라인을 테스트 완료 상태로 제공합니다. `git clone` → `app/` 교체 → push → 배포 끝.

## 기여

PR 환영합니다. [PR 템플릿](.github/PULL_REQUEST_TEMPLATE.md)을 사용해 주세요.

## 라이선스

[MIT](LICENSE)
