#!/usr/bin/env bash
set -euo pipefail

# Installer otomatis Antigravity Custom Agents, Skills, dan Global Rules (GEMINI.md)
# Mendukung Linux dan macOS secara idempoten.

GEMINI_MD_MODE="prompt"

for arg in "$@"; do
  case "$arg" in
    --gemini-mode=*)
      GEMINI_MD_MODE="${arg#*=}"
      ;;
    -h|--help)
      echo "Penggunaan: bash install.sh [--gemini-mode=prompt|overwrite|merge|skip]"
      exit 0
      ;;
    *)
      echo "Argumen tidak dikenal: $arg" >&2
      exit 1
      ;;
  esac
done

case "${GEMINI_MD_MODE}" in
  prompt|overwrite|merge|skip)
    ;;
  *)
    echo "[ERROR] Nilai --gemini-mode tidak valid: '${GEMINI_MD_MODE}'. Pilihan yang valid: prompt, overwrite, merge, skip." >&2
    exit 1
    ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_AGENTS="${SCRIPT_DIR}/agents"
SOURCE_SKILLS="${SCRIPT_DIR}/skills"
SOURCE_PLUGINS_RTK="${SCRIPT_DIR}/plugins/rtk"
SOURCE_GEMINI_MD="${SCRIPT_DIR}/GEMINI.md"

if [[ ! -d "${SOURCE_AGENTS}" || ! -d "${SOURCE_SKILLS}" || ! -d "${SOURCE_PLUGINS_RTK}" || ! -f "${SOURCE_GEMINI_MD}" ]]; then
  echo "[ERROR] Struktur folder bundle tidak lengkap di ${SCRIPT_DIR}." >&2
  exit 1
fi

GEMINI_DIR="${HOME}/.gemini"
TARGET_CONFIG_AGENTS="${GEMINI_DIR}/config/agents"
TARGET_ANTIGRAVITY_AGENTS="${GEMINI_DIR}/antigravity/agents"
TARGET_CONFIG_SKILLS="${GEMINI_DIR}/config/skills"
TARGET_CONFIG_PLUGINS_RTK="${GEMINI_DIR}/config/plugins/rtk"
TARGET_GEMINI_MD="${GEMINI_DIR}/GEMINI.md"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}============================================================${NC}"
echo -e "${CYAN}  Antigravity Custom Agents & Skills Installer (Unix/macOS) ${NC}"
echo -e "${CYAN}============================================================${NC}"
echo "Target direktori: ${GEMINI_DIR}"
echo ""

# 1. Menyiapkan direktori target
mkdir -p "${TARGET_CONFIG_AGENTS}" "${TARGET_ANTIGRAVITY_AGENTS}" "${TARGET_CONFIG_SKILLS}" "${TARGET_CONFIG_PLUGINS_RTK}"

# 2. Menyalin agents dan menautkan ke ~/.gemini/antigravity/agents
agent_count=0
echo -e "${YELLOW}[1/4] Menginstal Custom Agents...${NC}"
shopt -s nullglob
for agent_file in "${SOURCE_AGENTS}"/*.md; do
  filename="$(basename "${agent_file}")"
  cp -f "${agent_file}" "${TARGET_CONFIG_AGENTS}/${filename}"
  ln -sfn "${TARGET_CONFIG_AGENTS}/${filename}" "${TARGET_ANTIGRAVITY_AGENTS}/${filename}" || \
    cp -f "${TARGET_CONFIG_AGENTS}/${filename}" "${TARGET_ANTIGRAVITY_AGENTS}/${filename}"
  echo "  - ${filename}"
  agent_count=$((agent_count + 1))
done
shopt -u nullglob
echo -e "  ${GREEN}[OK] ${agent_count} agent terpasang ke ${TARGET_CONFIG_AGENTS} & ${TARGET_ANTIGRAVITY_AGENTS}.${NC}"

# 3. Menyalin skills
skill_count=0
echo ""
echo -e "${YELLOW}[2/4] Menginstal Custom Skills...${NC}"
shopt -s nullglob
for skill_dir in "${SOURCE_SKILLS}"/*/; do
  skill_name="$(basename "${skill_dir}")"
  rm -rf "${TARGET_CONFIG_SKILLS}/${skill_name}"
  cp -R "${skill_dir%/}" "${TARGET_CONFIG_SKILLS}/${skill_name}"
  echo "  - ${skill_name}"
  skill_count=$((skill_count + 1))
done
shopt -u nullglob
echo -e "  ${GREEN}[OK] ${skill_count} skill terpasang ke ${TARGET_CONFIG_SKILLS}.${NC}"

# 4. Menyalin plugin RTK ke ~/.gemini/config/plugins/rtk
echo ""
echo -e "${YELLOW}[3/4] Menginstal Plugin RTK (Token Optimizer)...${NC}"
rm -rf "${TARGET_CONFIG_PLUGINS_RTK}"
mkdir -p "${TARGET_CONFIG_PLUGINS_RTK}"
cp -R "${SOURCE_PLUGINS_RTK}/." "${TARGET_CONFIG_PLUGINS_RTK}/"
echo -e "  ${GREEN}[OK] Konfigurasi plugin RTK disalin ke ${TARGET_CONFIG_PLUGINS_RTK}.${NC}"

if command -v rtk >/dev/null 2>&1; then
  echo -e "  ${GREEN}[OK] CLI 'rtk' terdeteksi ($(command -v rtk)).${NC}"
else
  echo -e "  ${YELLOW}[!] Binary CLI 'rtk' belum ditemukan di PATH.${NC}"
  echo "      Agar hook penghemat token RTK aktif maksimal, pasang binary 'rtk' via:"
  echo "      - Homebrew (macOS/Linux): brew install rtk"
  echo "      - Cargo (Rust)          : cargo install --git https://github.com/rtk-ai/rtk"
  echo "      - Release Binary        : https://github.com/rtk-ai/rtk/releases"
fi

# 5. Mengatur GEMINI.md
echo ""
echo -e "${YELLOW}[4/4] Mengatur Global Profile & Guardrails (GEMINI.md)...${NC}"
if [[ ! -f "${TARGET_GEMINI_MD}" ]]; then
  cp -f "${SOURCE_GEMINI_MD}" "${TARGET_GEMINI_MD}"
  echo -e "  ${GREEN}[OK] GEMINI.md baru dibuat di ${TARGET_GEMINI_MD}.${NC}"
else
  mode="${GEMINI_MD_MODE}"
  if [[ "${mode}" == "prompt" ]]; then
    if [[ -t 0 ]]; then
      echo "  [!] File ${TARGET_GEMINI_MD} sudah ada."
      echo "      [1] Backup & Timpa (overwrite)"
      echo "      [2] Backup & Gabungkan (merge/append)"
      echo "      [3] Lewati (skip)"
      read -r -p "      Pilih (1/2/3) [Default: 3]: " choice
      case "${choice}" in
        1) mode="overwrite" ;;
        2) mode="merge" ;;
        *) mode="skip" ;;
      esac
    else
      echo "  [!] Non-interactive mode & GEMINI.md sudah ada; mempertahankan file eksisting (skip)."
      mode="skip"
    fi
  fi

  timestamp="$(date +%Y%m%d-%H%M%S)"
  backup_file="${TARGET_GEMINI_MD}.bak.${timestamp}"

  case "${mode}" in
    overwrite)
      cp -f "${TARGET_GEMINI_MD}" "${backup_file}"
      cp -f "${SOURCE_GEMINI_MD}" "${TARGET_GEMINI_MD}"
      echo "  [OK] Backup disimpan ke: ${backup_file}"
      echo -e "  ${GREEN}[OK] GEMINI.md berhasil ditimpa.${NC}"
      ;;
    merge)
      if grep -q "Global Developer Profile & Rules" "${TARGET_GEMINI_MD}"; then
        echo -e "  ${YELLOW}[!] Bagian 'Global Developer Profile & Rules' sudah ada. Melewati duplikasi.${NC}"
      else
        cp -f "${TARGET_GEMINI_MD}" "${backup_file}"
        {
          echo ""
          echo "---"
          echo ""
          cat "${SOURCE_GEMINI_MD}"
        } >> "${TARGET_GEMINI_MD}"
        echo "  [OK] Backup disimpan ke: ${backup_file}"
        echo -e "  ${GREEN}[OK] Konten GEMINI.md berhasil digabungkan.${NC}"
      fi
      ;;
    *)
      echo -e "  ${YELLOW}[SKIP] GEMINI.md eksisting dipertahankan.${NC}"
      ;;
  esac
fi

echo ""
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}  INSTALASI SELESAI!                                        ${NC}"
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}Ringkasan lokasi terpasang:${NC}"
echo -e "${GREEN}  - Agents (Config)      : ${TARGET_CONFIG_AGENTS}${NC}"
echo -e "${GREEN}  - Agents (Antigravity) : ${TARGET_ANTIGRAVITY_AGENTS}${NC}"
echo -e "${GREEN}  - Skills               : ${TARGET_CONFIG_SKILLS}${NC}"
echo -e "${GREEN}  - Plugin (RTK)         : ${TARGET_CONFIG_PLUGINS_RTK}${NC}"
echo -e "${GREEN}  - Global Rules         : ${TARGET_GEMINI_MD}${NC}"
echo ""
echo -e "${CYAN}Langkah berikutnya:${NC}"
echo "  1. Restart / buka ulang Antigravity atau sesi Gemini CLI Anda."
echo "  2. Verifikasi agent tersedia dengan memanggil 'sdlc-team-lead' atau 'pr-review-fixer'."
