#!/usr/bin/env bash
set -euo pipefail

# Rollback / uninstall komponen bundle Antigravity Custom Agents secara aman dan idempoten.
# Hanya menghapus 9 agent bundle, plugin antigravity-sdlc (termasuk 3 legacy skill bundle),
# dan plugin RTK tanpa menyentuh file lain di ~/.gemini.

GEMINI_DIR="${HOME}/.gemini"
CONFIG_AGENTS_DIR="${GEMINI_DIR}/config/agents"
ANTIGRAVITY_AGENTS_DIR="${GEMINI_DIR}/antigravity/agents"
CONFIG_SKILLS_DIR="${GEMINI_DIR}/config/skills"
CONFIG_SDLC_DIR="${GEMINI_DIR}/config/plugins/antigravity-sdlc"
CONFIG_RTK_DIR="${GEMINI_DIR}/config/plugins/rtk"

BUNDLE_AGENTS=(
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

BUNDLE_SKILLS=(
  "dotnet-webforms-patterns"
  "frontend-mobile-patterns"
  "portainer-harbor-deploy"
)

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

removed_count=0

echo -e "${CYAN}============================================================${NC}"
echo -e "${CYAN}  Antigravity Bundle Uninstaller (Unix/macOS)               ${NC}"
echo -e "${CYAN}============================================================${NC}"
echo "Target direktori: ${GEMINI_DIR}"
echo ""

echo -e "${YELLOW}[1/3] Menghapus 9 Custom Agents bundle...${NC}"
for agent in "${BUNDLE_AGENTS[@]}"; do
  for dir in "${CONFIG_AGENTS_DIR}" "${ANTIGRAVITY_AGENTS_DIR}"; do
    target_path="${dir}/${agent}"
    if [[ -e "${target_path}" || -L "${target_path}" ]]; then
      rm -f "${target_path}"
      echo "  [-] Dihapus: ${target_path}"
      removed_count=$((removed_count + 1))
    fi
  done
done

echo ""
echo -e "${YELLOW}[2/3] Menghapus Plugin antigravity-sdlc & legacy skills bundle...${NC}"
if [[ -e "${CONFIG_SDLC_DIR}" || -L "${CONFIG_SDLC_DIR}" ]]; then
  rm -rf "${CONFIG_SDLC_DIR}"
  echo "  [-] Dihapus: ${CONFIG_SDLC_DIR}"
  removed_count=$((removed_count + 1))
fi
for skill in "${BUNDLE_SKILLS[@]}"; do
  skill_path="${CONFIG_SKILLS_DIR}/${skill}"
  if [[ -e "${skill_path}" || -L "${skill_path}" ]]; then
    rm -rf "${skill_path}"
    echo "  [-] Dihapus (legacy): ${skill_path}"
    removed_count=$((removed_count + 1))
  fi
done

echo ""
echo -e "${YELLOW}[3/3] Menghapus Plugin RTK bundle...${NC}"
if [[ -e "${CONFIG_RTK_DIR}" || -L "${CONFIG_RTK_DIR}" ]]; then
  rm -rf "${CONFIG_RTK_DIR}"
  echo "  [-] Dihapus: ${CONFIG_RTK_DIR}"
  removed_count=$((removed_count + 1))
fi

echo ""
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}  UNINSTALL SELESAI (${removed_count} item dihapus)${NC}"
echo -e "${GREEN}============================================================${NC}"
echo -e "${CYAN}Catatan: File ${GEMINI_DIR}/GEMINI.md serta agent/skill pribadi Anda tetap dipertahankan.${NC}"
