---
name: portainer-harbor-deploy
description: Standard SOP and templates for RAM-efficient Docker/Portainer Stack deployment on Ubuntu Linux VPS and GitHub Actions CI/CD image pushes to Harbor private container registry. Use when creating or updating Dockerfiles, Portainer docker-compose.yml, or Harbor CI/CD workflows.
---

# Portainer & Harbor Deployment Guide

Use this guide to maintain consistent Portainer Docker stacks and Harbor CI/CD pipelines.

## 1. RAM-Efficient, Portainer-Friendly `docker-compose.yml`
- Avoid fragile relative bind mounts in Portainer GitOps/Web Editor; use **named volumes** or documented absolute paths.
- Use `${VAR}` placeholders for all environment configs and secrets (populated via Portainer Stack Env).
- Always include `restart: unless-stopped`, `healthcheck`, `mem_limit`, and `json-file` log rotation.

```yaml
services:
  app:
    image: ${HARBOR_REGISTRY}/${HARBOR_PROJECT}/${IMAGE_NAME}:${IMAGE_TAG}
    container_name: ${APP_NAME:-app}
    restart: unless-stopped
    mem_limit: 512m
    environment:
      ASPNETCORE_ENVIRONMENT: ${ASPNETCORE_ENVIRONMENT:-Production}
      ConnectionStrings__Default: ${DB_CONNECTION_STRING}
    ports:
      - "${APP_PORT:-8080}:8080"
    volumes:
      - app_data:/app/data
    healthcheck:
      test: ["CMD-SHELL", "curl -fsS http://localhost:8080/health || exit 1"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 20s
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"

volumes:
  app_data:
```

## 2. RAM-Efficient Dockerfile Checklist (Multi-Stage & Non-Root)
1. Use multi-stage builds (`sdk` for restore/publish; `aspnet` / `node:alpine` / `distroless` for runtime).
2. Create and run the container under a non-root user.
3. Exclude `.git`, `node_modules`, `bin`, `obj`, and `.env`/secret files via `.dockerignore`.

## 3. GitHub Actions CI/CD to Harbor Registry
- Store credentials in GitHub Secrets (`HARBOR_REGISTRY`, `HARBOR_USERNAME`, `HARBOR_PASSWORD`, optional `PORTAINER_WEBHOOK_URL`).
- Use immutable tags (`sha-<short>` and semver on release tags), not `:latest`-only.

```yaml
name: Build and Push to Harbor

on:
  push:
    branches: ["main"]
    tags: ["v*.*.*"]

jobs:
  docker:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Docker meta
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ secrets.HARBOR_REGISTRY }}/${{ vars.HARBOR_PROJECT }}/${{ vars.IMAGE_NAME }}
          tags: |
            type=sha,prefix=sha-
            type=semver,pattern={{version}}

      - name: Login to Harbor
        uses: docker/login-action@v3
        with:
          registry: ${{ secrets.HARBOR_REGISTRY }}
          username: ${{ secrets.HARBOR_USERNAME }}
          password: ${{ secrets.HARBOR_PASSWORD }}

      - name: Build and push
        uses: docker/build-push-action@v6
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
```

## 4. Pre-Finish Verification
1. Validate YAML syntax (`python -c "import yaml; yaml.safe_load(open('...'))"` if `pyyaml` exists, or `docker compose config --no-interpolate` if Docker CLI exists).
2. Confirm zero hardcoded passwords, tokens, or connection strings in YAML or Dockerfiles.
3. Update `README.md`/`AGENTS.md` if new env vars or ports must be configured in Portainer.
