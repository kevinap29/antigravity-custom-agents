#!/usr/bin/env bash
set -euo pipefail

# Verifikasi kesehatan instalasi Antigravity Custom Agents, SDLC Plugin, RTK Plugin,
# Deterministic Gate, GEMINI.md, serta Add-ons aktif (~/.gemini/.addons.json).

GEMINI_DIR="${HOME}/.gemini"
CONFIG_AGENTS_DIR="${GEMINI_DIR}/config/agents"
ANTIGRAVITY_AGENTS_DIR="${GEMINI_DIR}/antigravity/agents"
CONFIG_SDLC_DIR="${GEMINI_DIR}/config/plugins/antigravity-sdlc"
CONFIG_RTK_DIR="${GEMINI_DIR}/config/plugins/rtk"
SCRIPTS_DIR="${GEMINI_DIR}/scripts"
MCP_DIR="${GEMINI_DIR}/mcp"
MEMORY_DIR="${GEMINI_DIR}/memory"
BIN_DIR="${GEMINI_DIR}/bin"
GEMINI_MD_PATH="${GEMINI_DIR}/GEMINI.md"
ADDONS_PROFILE="${GEMINI_DIR}/.addons.json"

EXPECTED_AGENTS=(
  "db-data-engineer.md"
  "devops-git-ops.md"
  "dotnet-cqrs-dev.md"
  "dotnet-webforms-dev.md"
  "frontend-mobile-dev.md"
  "pr-review-fixer.md"
  "qa-code-reviewer.md"
  "sdlc-team-lead.md"
  "ui-prototyper.md"
)

EXPECTED_SDLC_FILES=(
  "plugin.json"
  "hooks.json"
  "hooks/sdlc-guardrails.mjs"
  "rules/ENGINEERING_RULES.md"
  "scripts/verify-gate.ps1"
  "skills/dotnet-webforms-patterns/SKILL.md"
  "skills/frontend-mobile-patterns/SKILL.md"
  "skills/portainer-harbor-deploy/SKILL.md"
)

EXPECTED_RTK_FILES=(
  "plugin.json"
  "hooks.json"
  "rules/AGENTS.md"
)

CENTRAL_MEMORY_ENABLED=false
QDRANT_MODE=""
if [[ -f "${ADDONS_PROFILE}" ]]; then
  if grep -Eq '"centralMemory"[[:space:]]*:[[:space:]]*true' "${ADDONS_PROFILE}"; then
    CENTRAL_MEMORY_ENABLED=true
  fi
  if grep -Eq '"qdrantMode"[[:space:]]*:[[:space:]]*"local"' "${ADDONS_PROFILE}"; then
    QDRANT_MODE="local"
  elif grep -Eq '"qdrantMode"[[:space:]]*:[[:space:]]*"localhost"' "${ADDONS_PROFILE}"; then
    QDRANT_MODE="localhost"
  elif grep -Eq '"qdrantMode"[[:space:]]*:[[:space:]]*"remote"' "${ADDONS_PROFILE}"; then
    QDRANT_MODE="remote"
  fi
fi

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

ok_count=0
warn_count=0
fail_count=0
total_required=$(( (${#EXPECTED_AGENTS[@]} * 2) + ${#EXPECTED_SDLC_FILES[@]} + ${#EXPECTED_RTK_FILES[@]} + 2 ))
if [[ "${CENTRAL_MEMORY_ENABLED}" == "true" ]]; then
  total_required=$((total_required + 4))
  if [[ "${QDRANT_MODE}" == "local" || "${QDRANT_MODE}" == "localhost" ]]; then
    total_required=$((total_required + 1))
  fi
fi

echo -e "${CYAN}============================================================${NC}"
echo -e "${CYAN}  Antigravity Bundle Health-Check (Unix/macOS)              ${NC}"
echo -e "${CYAN}============================================================${NC}"
echo "Direktori target: ${GEMINI_DIR}"
echo ""

check_file() {
  local path="$1"
  local label="$2"
  if [[ -L "${path}" && ! -e "${path}" ]]; then
    echo -e "  ${RED}[FAIL] ${label} -> Symlink rusak/dangling (${path})${NC}"
    fail_count=$((fail_count + 1))
    return 1
  elif [[ ! -f "${path}" ]]; then
    echo -e "  ${RED}[FAIL] ${label} -> Tidak ditemukan (${path})${NC}"
    fail_count=$((fail_count + 1))
    return 1
  else
    echo -e "  ${GREEN}[OK]   ${label}${NC}"
    ok_count=$((ok_count + 1))
    return 0
  fi
}

check_dir() {
  local path="$1"
  local label="$2"
  if [[ ! -d "${path}" ]]; then
    echo -e "  ${RED}[FAIL] ${label} -> Direktori tidak ditemukan (${path})${NC}"
    fail_count=$((fail_count + 1))
    return 1
  else
    echo -e "  ${GREEN}[OK]   ${label}${NC}"
    ok_count=$((ok_count + 1))
    return 0
  fi
}

echo -e "${CYAN}[1/6] Memeriksa Agents di config/agents (${#EXPECTED_AGENTS[@]} file)...${NC}"
for agent in "${EXPECTED_AGENTS[@]}"; do
  check_file "${CONFIG_AGENTS_DIR}/${agent}" "config/agents/${agent}" || true
done

echo ""
echo -e "${CYAN}[2/6] Memeriksa Agents di antigravity/agents (${#EXPECTED_AGENTS[@]} file)...${NC}"
for agent in "${EXPECTED_AGENTS[@]}"; do
  check_file "${ANTIGRAVITY_AGENTS_DIR}/${agent}" "antigravity/agents/${agent}" || true
done

echo ""
echo -e "${CYAN}[3/6] Memeriksa Plugin antigravity-sdlc (${#EXPECTED_SDLC_FILES[@]} file)...${NC}"
for sdlc_file in "${EXPECTED_SDLC_FILES[@]}"; do
  check_file "${CONFIG_SDLC_DIR}/${sdlc_file}" "config/plugins/antigravity-sdlc/${sdlc_file}" || true
done

if [[ -f "${CONFIG_SDLC_DIR}/hooks.json" ]] && grep -q '__HOOK_SCRIPT_PATH__' "${CONFIG_SDLC_DIR}/hooks.json"; then
  echo -e "  ${YELLOW}[WARN] hooks.json masih berisi placeholder __HOOK_SCRIPT_PATH__ (jalankan install.sh / update.sh)${NC}"
  warn_count=$((warn_count + 1))
fi

if command -v node >/dev/null 2>&1; then
  echo -e "  ${GREEN}[OK]   Binary CLI 'node' tersedia di PATH ($(command -v node))${NC}"
else
  echo -e "  ${YELLOW}[WARN] Binary CLI 'node' belum ada di PATH (hook antigravity-sdlc-guardrails dinonaktifkan)${NC}"
  warn_count=$((warn_count + 1))
fi

echo ""
echo -e "${CYAN}[4/6] Memeriksa Plugin RTK & Binary CLI...${NC}"
for rtk_file in "${EXPECTED_RTK_FILES[@]}"; do
  check_file "${CONFIG_RTK_DIR}/${rtk_file}" "config/plugins/rtk/${rtk_file}" || true
done

if command -v rtk >/dev/null 2>&1; then
  echo -e "  ${GREEN}[OK]   Binary CLI 'rtk' tersedia di PATH ($(command -v rtk))${NC}"
else
  echo -e "  ${YELLOW}[WARN] Binary CLI 'rtk' belum ada di PATH (opsional; pasang via Homebrew/Cargo/release)${NC}"
  warn_count=$((warn_count + 1))
fi

echo ""
echo -e "${CYAN}[5/6] Memeriksa Core Deterministic Gate & Global Rules...${NC}"
check_file "${SCRIPTS_DIR}/verify-gate.ps1" "scripts/verify-gate.ps1" || true
check_file "${GEMINI_MD_PATH}" "GEMINI.md" || true

echo ""
echo -e "${CYAN}[6/6] Memeriksa Add-on Central Memory MCP & Security Scanners...${NC}"
if [[ "${CENTRAL_MEMORY_ENABLED}" == "true" ]]; then
  check_file "${MCP_DIR}/central_memory_mcp.py" "mcp/central_memory_mcp.py" || true
  check_file "${MCP_DIR}/requirements.txt" "mcp/requirements.txt" || true
  check_file "${MEMORY_DIR}/GLOBAL_RULES.md" "memory/GLOBAL_RULES.md" || true
  check_file "${MEMORY_DIR}/ARCHITECTURE_NOTES.md" "memory/ARCHITECTURE_NOTES.md" || true

  case "${QDRANT_MODE}" in
    local)
      check_dir "${MEMORY_DIR}/qdrant_local" "memory/qdrant_local (mode=local)" || true
      ;;
    localhost)
      check_file "${BIN_DIR}/qdrant-config.yaml" "bin/qdrant-config.yaml (mode=localhost)" || true
      if [[ -x "${BIN_DIR}/qdrant" ]]; then
        echo -e "  ${GREEN}[OK]   bin/qdrant tersedia (${BIN_DIR}/qdrant)${NC}"
      else
        echo -e "  ${YELLOW}[WARN] bin/qdrant belum tersedia di ${BIN_DIR} (unduh manual jika mode=localhost)${NC}"
        warn_count=$((warn_count + 1))
      fi
      ;;
    remote)
      echo -e "  ${GREEN}[OK]   Mode Qdrant: remote (gunakan QDRANT_URL / QDRANT_API_KEY)${NC}"
      ;;
    *)
      echo "  [INFO] qdrantMode belum diset di .addons.json (profil lama)"
      ;;
  esac

  if [[ -x "${MCP_DIR}/.venv/bin/python" ]]; then
    echo -e "  ${GREEN}[OK]   Python .venv tersedia (${MCP_DIR}/.venv/bin/python)${NC}"
  else
    echo -e "  ${YELLOW}[WARN] Python .venv belum dibuat di ${MCP_DIR}/.venv (opsional)${NC}"
    warn_count=$((warn_count + 1))
  fi
else
  echo -e "  ${YELLOW}[SKIP] Add-on Central Memory MCP tidak aktif di .addons.json${NC}"
fi

for tool in gitleaks trivy semgrep; do
  if command -v "${tool}" >/dev/null 2>&1; then
    echo -e "  ${GREEN}[OK]   Scanner '${tool}' tersedia ($(command -v "${tool}"))${NC}"
  else
    echo "  [INFO] Scanner '${tool}' belum terpasang (opsional)"
  fi
done

echo ""
echo -e "${CYAN}============================================================${NC}"
if [[ ${fail_count} -eq 0 && ${warn_count} -eq 0 ]]; then
  echo -e "${GREEN}  HASIL: ${ok_count} / ${total_required} komponen wajib OK (Semua sehat!)${NC}"
elif [[ ${fail_count} -eq 0 ]]; then
  echo -e "${YELLOW}  HASIL: ${ok_count} / ${total_required} komponen wajib OK (${warn_count} peringatan)${NC}"
else
  echo -e "${RED}  HASIL: ${ok_count} / ${total_required} komponen wajib OK (${fail_count} gagal, ${warn_count} peringatan)${NC}"
fi
echo -e "${CYAN}============================================================${NC}"

if [[ ${fail_count} -gt 0 ]]; then
  exit 1
fi
exit 0
