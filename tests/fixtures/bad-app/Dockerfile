FROM node:20-alpine
WORKDIR /app
COPY server.js .
EXPOSE 3000
HEALTHCHECK --interval=5s --timeout=3s --retries=3 --start-period=5s \
  CMD wget -qO /dev/null http://localhost:${PORT:-3000}/health || exit 1
CMD ["node", "server.js"]
