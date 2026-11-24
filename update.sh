#!/usr/bin/env bash
set -euo pipefail

# Sinkronisasi & update Antigravity Custom Agents, Skills, RTK Plugin, Deterministic Gate,
# serta Add-ons aktif (~/.gemini/.addons.json) ke ~/.gemini.

GEMINI_MD_MODE="skip"
WITH_SECURITY_TOOLS=false
WITH_MEMORY=false
QDRANT_MODE=""
RESPONSE_LANGUAGE=""

for arg in "$@"; do
  case "$arg" in
    --gemini-mode=*)
      GEMINI_MD_MODE="${arg#*=}"
      ;;
    --with-security-tools)
      WITH_SECURITY_TOOLS=true
      ;;
    --with-memory)
      WITH_MEMORY=true
      ;;
    --qdrant-mode=*)
      QDRANT_MODE="$(printf '%s' "${arg#*=}" | tr '[:upper:]' '[:lower:]')"
      ;;
    --response-language=*)
      RESPONSE_LANGUAGE="${arg#*=}"
      ;;
    -h|--help)
      echo "Penggunaan: bash update.sh [--gemini-mode=skip|prompt|overwrite|merge] [--with-security-tools] [--with-memory] [--qdrant-mode=local|localhost|remote] [--response-language=<lang>]"
      exit 0
      ;;
    *)
      echo "Argumen tidak dikenal: $arg" >&2
      exit 1
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_SCRIPT="${SCRIPT_DIR}/install.sh"
VERIFY_SCRIPT="${SCRIPT_DIR}/verify.sh"

if [[ ! -f "${INSTALL_SCRIPT}" || ! -f "${VERIFY_SCRIPT}" ]]; then
  echo "[ERROR] Skrip install.sh atau verify.sh tidak ditemukan di ${SCRIPT_DIR}." >&2
  exit 1
fi

CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${CYAN}============================================================${NC}"
echo -e "${CYAN}  Antigravity Bundle Updater (Unix/macOS)                   ${NC}"
echo -e "${CYAN}============================================================${NC}"

if [[ -d "${SCRIPT_DIR}/.git" ]] && command -v git >/dev/null 2>&1; then
  if [[ -n "$(git -C "${SCRIPT_DIR}" remote 2>/dev/null || true)" ]]; then
    echo -e "${YELLOW}[*] Menarik pembaruan terbaru dari Git remote...${NC}"
    git -C "${SCRIPT_DIR}" pull --ff-only
  else
    echo "[i] Repositori Git belum memiliki remote; melewati git pull."
  fi
else
  echo "[i] Bukan repositori Git (mode arsip/ZIP); langsung menyinkronkan file lokal."
fi

ADDONS_PROFILE="${HOME}/.gemini/.addons.json"
if [[ -f "${ADDONS_PROFILE}" ]]; then
  if grep -Eq '"centralMemory"[[:space:]]*:[[:space:]]*true' "${ADDONS_PROFILE}"; then
    WITH_MEMORY=true
  fi
  if [[ -z "${QDRANT_MODE}" && "${WITH_MEMORY}" == "true" ]]; then
    if grep -Eq '"qdrantMode"[[:space:]]*:[[:space:]]*"localhost"' "${ADDONS_PROFILE}"; then
      QDRANT_MODE="localhost"
    elif grep -Eq '"qdrantMode"[[:space:]]*:[[:space:]]*"remote"' "${ADDONS_PROFILE}"; then
      QDRANT_MODE="remote"
    else
      QDRANT_MODE="local"
    fi
  fi
  if [[ -z "${RESPONSE_LANGUAGE}" ]]; then
    saved_lang="$(sed -n 's/.*"responseLanguage"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "${ADDONS_PROFILE}" | head -n 1 || true)"
    if [[ -n "${saved_lang}" ]]; then
      RESPONSE_LANGUAGE="${saved_lang}"
    fi
  fi
  echo "[i] Profil .addons.json ditemukan (responseLanguage=${RESPONSE_LANGUAGE:-English}, centralMemory=${WITH_MEMORY}, qdrantMode=${QDRANT_MODE:-null})."
fi

if [[ -z "${RESPONSE_LANGUAGE}" ]]; then
  RESPONSE_LANGUAGE="English"
fi

INSTALL_ARGS=("--gemini-mode=${GEMINI_MD_MODE}" "--response-language=${RESPONSE_LANGUAGE}" "--non-interactive")
if [[ "${WITH_SECURITY_TOOLS}" == "true" ]]; then
  INSTALL_ARGS+=("--with-security-tools")
fi
if [[ "${WITH_MEMORY}" == "true" ]]; then
  INSTALL_ARGS+=("--with-memory")
  if [[ -n "${QDRANT_MODE}" ]]; then
    INSTALL_ARGS+=("--qdrant-mode=${QDRANT_MODE}")
  fi
fi

echo ""
echo -e "${YELLOW}[*] Menjalankan installer sinkronisasi (--gemini-mode=${GEMINI_MD_MODE})...${NC}"
bash "${INSTALL_SCRIPT}" "${INSTALL_ARGS[@]}"

echo ""
echo -e "${YELLOW}[*] Menjalankan verifikasi kesehatan instalasi...${NC}"
bash "${VERIFY_SCRIPT}"
