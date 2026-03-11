# Dockerfile Examples

Replace the default `Dockerfile` with one of these examples for your language.

## Node.js (included by default)

```dockerfile
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
```

## Python (Flask / FastAPI)

```dockerfile
FROM python:3.12-slim AS build

WORKDIR /app
COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app/ .

FROM python:3.12-slim

WORKDIR /app
COPY --from=build /usr/local/lib/python3.12/site-packages /usr/local/lib/python3.12/site-packages
COPY --from=build /app .

EXPOSE 8000
CMD ["python", "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

## Go

```dockerfile
FROM golang:1.22-alpine AS build

WORKDIR /app
COPY app/go.mod app/go.sum ./
RUN go mod download
COPY app/ .
RUN CGO_ENABLED=0 go build -o server .

FROM alpine:3.20

WORKDIR /app
COPY --from=build /app/server .

EXPOSE 8080
CMD ["./server"]
```

## Rust

```dockerfile
FROM rust:1.78-alpine AS build

WORKDIR /app
RUN apk add --no-cache musl-dev
COPY app/Cargo.toml app/Cargo.lock ./
COPY app/src ./src
RUN cargo build --release

FROM alpine:3.20

WORKDIR /app
COPY --from=build /app/target/release/server .

EXPOSE 8080
CMD ["./server"]
```

## Java (Spring Boot)

```dockerfile
FROM eclipse-temurin:21-jdk-alpine AS build

WORKDIR /app
COPY app/ .
RUN ./gradlew bootJar --no-daemon

FROM eclipse-temurin:21-jre-alpine

WORKDIR /app
COPY --from=build /app/build/libs/*.jar app.jar

EXPOSE 8080
CMD ["java", "-jar", "app.jar"]
```

## Static Site (Nginx)

```dockerfile
FROM nginx:alpine

COPY app/ /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

## Tips

- **Multi-stage builds** reduce image size by separating build dependencies from runtime
- **Alpine base images** are smaller (~5 MB vs ~100 MB for Debian)
- **`COPY --from=build`** only copies what's needed into the final image
- Update `.dockerignore` when changing your app structure
- Update the `EXPOSE` port and `docker-compose.yml` to match your app
