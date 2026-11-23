---
name: portainer-harbor-deploy
description: SOP dan template standar untuk deployment Docker/Portainer Stack di Ubuntu Linux VPS hemat RAM serta GitHub Actions CI/CD push image ke Harbor private container registry. Gunakan saat membuat atau memperbarui Dockerfile, docker-compose.yml Portainer, atau workflow Harbor CI/CD.
---

# Portainer & Harbor Deployment Guide

Gunakan panduan ini untuk menjaga konsistensi stack Docker di Portainer dan pipeline CI/CD ke Harbor.

## 1. Template `docker-compose.yml` Ramah Portainer Stack & Hemat RAM

- Hindari bind mount path relatif lokal yang rapuh pada Portainer GitOps/Web Editor; gunakan **named volume** atau path absolut yang terdokumentasi.
- Gunakan placeholder `${VAR}` untuk seluruh konfigurasi environment dan secret (diisi melalui Portainer Stack Env).
- Wajib sertakan `restart: unless-stopped`, `healthcheck`, `mem_limit`, dan rotasi log `json-file`.

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

## 2. Checklist Dockerfile Hemat RAM (Multi-Stage & Non-Root)

1. Gunakan multi-stage build (`sdk` untuk restore/publish, `aspnet` / `node:alpine` / `distroless` untuk runtime).
2. Buat dan jalankan container dengan user non-root.
3. Jangan salin `.git`, `node_modules`, `bin`, `obj`, atau file `.env`/secret ke image (gunakan `.dockerignore`).

## 3. GitHub Actions CI/CD ke Harbor Registry

- Simpan kredensial di GitHub Secrets (`HARBOR_REGISTRY`, `HARBOR_USERNAME`, `HARBOR_PASSWORD`, opsional `PORTAINER_WEBHOOK_URL`).
- Gunakan tag immutable (`sha-<short>` dan semver jika tag release), bukan hanya `:latest`.

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

## 4. Verifikasi Sebelum Selesai

1. Validasi sintaks YAML (`python -c "import yaml; yaml.safe_load(open('...'))"` jika `pyyaml` tersedia, atau `docker compose config --no-interpolate` jika Docker CLI ada).
2. Pastikan nol hardcoded password/token/connection string di YAML atau Dockerfile.
3. Perbarui `README.md`/`AGENTS.md` bila ada variabel env atau port baru yang wajib diset di Portainer.
