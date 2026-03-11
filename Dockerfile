# Example: Node.js application
# Replace with your own Dockerfile for other languages
# See docs/DOCKERFILE_EXAMPLES.md for Python, Go, and more

FROM node:20-alpine AS build

WORKDIR /app
COPY app/package*.json ./
RUN npm ci --omit=dev
COPY app/ .

FROM node:20-alpine

WORKDIR /app
COPY --from=build /app .

EXPOSE 3000
CMD ["node", "server.js"]
