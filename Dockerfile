# Example: Node.js application
# Replace with your own Dockerfile for other languages
# See docs/DOCKERFILE_EXAMPLES.md for Python, Go, and more

FROM node:25-alpine

WORKDIR /app
COPY --chown=node:node app/ .

USER node

EXPOSE 3000
HEALTHCHECK --interval=10s --timeout=5s --retries=3 --start-period=10s \
  CMD wget -qO /dev/null http://localhost:3000/health || exit 1
CMD ["node", "server.js"]
