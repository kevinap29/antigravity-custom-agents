#!/usr/bin/env bash
set -euo pipefail

# Verifikasi kesehatan instalasi Antigravity Custom Agents, Skills, RTK Plugin, dan GEMINI.md.

GEMINI_DIR="${HOME}/.gemini"
CONFIG_AGENTS_DIR="${GEMINI_DIR}/config/agents"
ANTIGRAVITY_AGENTS_DIR="${GEMINI_DIR}/antigravity/agents"
CONFIG_SKILLS_DIR="${GEMINI_DIR}/config/skills"
CONFIG_RTK_DIR="${GEMINI_DIR}/config/plugins/rtk"
GEMINI_MD_PATH="${GEMINI_DIR}/GEMINI.md"

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

EXPECTED_SKILLS=(
  "dotnet-webforms-patterns"
  "frontend-mobile-patterns"
  "portainer-harbor-deploy"
)

EXPECTED_RTK_FILES=(
  "plugin.json"
  "hooks.json"
  "rules/AGENTS.md"
)

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

ok_count=0
warn_count=0
fail_count=0
total_required=$(( (${#EXPECTED_AGENTS[@]} * 2) + ${#EXPECTED_SKILLS[@]} + ${#EXPECTED_RTK_FILES[@]} + 1 ))

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

echo -e "${CYAN}[1/5] Memeriksa Agents di config/agents (${#EXPECTED_AGENTS[@]} file)...${NC}"
for agent in "${EXPECTED_AGENTS[@]}"; do
  check_file "${CONFIG_AGENTS_DIR}/${agent}" "config/agents/${agent}" || true
done

echo ""
echo -e "${CYAN}[2/5] Memeriksa Agents di antigravity/agents (${#EXPECTED_AGENTS[@]} file)...${NC}"
for agent in "${EXPECTED_AGENTS[@]}"; do
  check_file "${ANTIGRAVITY_AGENTS_DIR}/${agent}" "antigravity/agents/${agent}" || true
done

echo ""
echo -e "${CYAN}[3/5] Memeriksa Custom Skills (${#EXPECTED_SKILLS[@]} skill)...${NC}"
for skill in "${EXPECTED_SKILLS[@]}"; do
  check_file "${CONFIG_SKILLS_DIR}/${skill}/SKILL.md" "config/skills/${skill}/SKILL.md" || true
done

echo ""
echo -e "${CYAN}[4/5] Memeriksa Plugin RTK & Binary CLI...${NC}"
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
echo -e "${CYAN}[5/5] Memeriksa Global Rules (GEMINI.md)...${NC}"
check_file "${GEMINI_MD_PATH}" "GEMINI.md" || true

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
