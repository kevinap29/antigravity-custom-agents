#!/usr/bin/env bash
set -euo pipefail

# Sinkronisasi & update Antigravity Custom Agents, Skills, dan RTK Plugin ke ~/.gemini.

GEMINI_MD_MODE="skip"

for arg in "$@"; do
  case "$arg" in
    --gemini-mode=*)
      GEMINI_MD_MODE="${arg#*=}"
      ;;
    -h|--help)
      echo "Penggunaan: bash update.sh [--gemini-mode=skip|prompt|overwrite|merge]"
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

echo ""
echo -e "${YELLOW}[*] Menjalankan installer sinkronisasi (--gemini-mode=${GEMINI_MD_MODE})...${NC}"
bash "${INSTALL_SCRIPT}" "--gemini-mode=${GEMINI_MD_MODE}"

echo ""
echo -e "${YELLOW}[*] Menjalankan verifikasi kesehatan instalasi...${NC}"
bash "${VERIFY_SCRIPT}"
