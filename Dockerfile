# Example: Node.js application
# Replace with your own Dockerfile for other languages
# See docs/DOCKERFILE_EXAMPLES.md for Python, Go, and more
#
# Pinned to a digest for reproducibility. Dependabot's docker ecosystem
# refreshes this on a schedule. Node 20 reached EOL on 2026-04-30, so
# this targets Node 22 (active LTS through 2027-04).

FROM node:22-alpine@sha256:968df39aedcea65eeb078fb336ed7191baf48f972b4479711397108be0966920

WORKDIR /app
COPY --chown=node:node app/ .

# Run as the non-root `node` user that ships with the official image.
USER node

EXPOSE 3000
HEALTHCHECK --interval=10s --timeout=5s --retries=3 --start-period=10s \
  CMD wget -qO /dev/null http://localhost:${PORT:-3000}/health || exit 1
CMD ["node", "server.js"]
