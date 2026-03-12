# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability, please report it responsibly:

1. **Do NOT open a public issue.**
2. Email **security@heznpc.dev** or use [GitHub Security Advisories](../../security/advisories/new).
3. Include steps to reproduce, impact assessment, and suggested fix if possible.

We will respond within 48 hours and work with you to resolve the issue.

## Security Features

This template includes automated security checks in CI:

- **Dependency audit** — `npm audit` on every push (HIGH/CRITICAL threshold)
- **Secret leak detection** — [gitleaks](https://github.com/gitleaks/gitleaks) scans every commit
- **Dependency updates** — [Dependabot](https://docs.github.com/en/code-security/dependabot) monitors for vulnerable dependencies
- **Dockerfile lint** — [Hadolint](https://github.com/hadolint/hadolint) enforces best practices
- **Container scan** — [Trivy](https://github.com/aquasecurity/trivy) detects CRITICAL/HIGH CVEs in built images

## Best Practices

- Never commit `.env` files or secrets — they are gitignored by default
- Use GitHub Secrets for deployment credentials
- Keep dependencies up to date by merging Dependabot PRs
