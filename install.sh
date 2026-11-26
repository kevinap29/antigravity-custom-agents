#!/usr/bin/env bash
set -euo pipefail

# Modular Installer Antigravity Custom Agents, SDLC Plugin, Deterministic Gate, dan Add-ons (Unix/macOS).
# Mendukung Linux dan macOS secara idempoten.

GEMINI_MD_MODE="prompt"
WITH_SECURITY_TOOLS=false
WITH_MEMORY=false
QDRANT_MODE=""
RESPONSE_LANGUAGE=""
NON_INTERACTIVE=false

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
    --non-interactive)
      NON_INTERACTIVE=true
      ;;
    -h|--help)
      echo "Penggunaan: bash install.sh [--gemini-mode=prompt|overwrite|merge|skip] [--with-security-tools] [--with-memory] [--qdrant-mode=local|localhost|remote] [--response-language=<lang>] [--non-interactive]"
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

if [[ -n "${QDRANT_MODE}" ]]; then
  case "${QDRANT_MODE}" in
    local|localhost|remote)
      ;;
    *)
      echo "[ERROR] Nilai --qdrant-mode tidak valid: '${QDRANT_MODE}'. Pilihan yang valid: local, localhost, remote." >&2
      exit 1
      ;;
  esac
fi

IS_INTERACTIVE=false
if [[ -t 0 && "${NON_INTERACTIVE}" == "false" ]]; then
  IS_INTERACTIVE=true
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_AGENTS="${SCRIPT_DIR}/agents"
SOURCE_PLUGINS_SDLC="${SCRIPT_DIR}/plugins/antigravity-sdlc"
SOURCE_PLUGINS_RTK="${SCRIPT_DIR}/plugins/rtk"
SOURCE_VERIFY_GATE="${SOURCE_PLUGINS_SDLC}/scripts/verify-gate.ps1"
SOURCE_MCP="${SCRIPT_DIR}/mcp"
SOURCE_MEMORY="${SCRIPT_DIR}/memory"
SOURCE_GEMINI_MD="${SCRIPT_DIR}/GEMINI.md"

if [[ ! -d "${SOURCE_AGENTS}" || ! -d "${SOURCE_PLUGINS_SDLC}" || ! -d "${SOURCE_PLUGINS_RTK}" || ! -f "${SOURCE_VERIFY_GATE}" || ! -f "${SOURCE_GEMINI_MD}" ]]; then
  echo "[ERROR] Struktur folder Core bundle tidak lengkap di ${SCRIPT_DIR}." >&2
  exit 1
fi

GEMINI_DIR="${HOME}/.gemini"
TARGET_CONFIG_AGENTS="${GEMINI_DIR}/config/agents"
TARGET_ANTIGRAVITY_AGENTS="${GEMINI_DIR}/antigravity/agents"
TARGET_CONFIG_SKILLS="${GEMINI_DIR}/config/skills"
TARGET_CONFIG_PLUGINS_SDLC="${GEMINI_DIR}/config/plugins/antigravity-sdlc"
TARGET_CONFIG_PLUGINS_RTK="${GEMINI_DIR}/config/plugins/rtk"
TARGET_SCRIPTS="${GEMINI_DIR}/scripts"
TARGET_MCP="${GEMINI_DIR}/mcp"
TARGET_MEMORY="${GEMINI_DIR}/memory"
TARGET_BIN="${GEMINI_DIR}/bin"
TARGET_GEMINI_MD="${GEMINI_DIR}/GEMINI.md"
ADDONS_PROFILE="${GEMINI_DIR}/.addons.json"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}============================================================${NC}"
echo -e "${CYAN}  Antigravity Custom Agents & Skills Installer (Unix/macOS) ${NC}"
echo -e "${CYAN}============================================================${NC}"
echo "Target direktori: ${GEMINI_DIR}"
echo ""

# ------------------------------------------------------------
# 0. OS & Environment Preflight Check
# ------------------------------------------------------------
echo -e "${CYAN}[PREFLIGHT] Memeriksa OS & tool lingkungan...${NC}"
OS_NAME="$(uname -s)"
ARCH_NAME="$(uname -m)"
echo "  - OS/Arch  : ${OS_NAME} (${ARCH_NAME})"

PKG_MGR="none"
if command -v brew >/dev/null 2>&1; then
  PKG_MGR="brew"
elif command -v apt-get >/dev/null 2>&1; then
  PKG_MGR="apt"
fi
echo "  - Pkg Mgr  : ${PKG_MGR}"

PYTHON_BIN=""
if command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN="$(command -v python3)"
elif command -v python >/dev/null 2>&1 && python --version 2>&1 | grep -qE 'Python 3\.'; then
  PYTHON_BIN="$(command -v python)"
fi

if [[ -n "${PYTHON_BIN}" ]]; then
  echo -e "  ${GREEN}[OK]   python   : $(${PYTHON_BIN} --version 2>&1) (${PYTHON_BIN})${NC}"
else
  echo -e "  ${YELLOW}[MISS] python   : Python 3 tidak ditemukan (opsional untuk Add-on Central Memory)${NC}"
fi

NODE_BIN=""
if command -v node >/dev/null 2>&1; then
  NODE_BIN="$(command -v node)"
  echo -e "  ${GREEN}[OK]   node     : ${NODE_BIN}${NC}"
else
  echo -e "  ${YELLOW}[MISS] node     : Node.js tidak ditemukan (hook antigravity-sdlc-guardrails akan dinonaktifkan)${NC}"
fi

if command -v ssh >/dev/null 2>&1; then
  echo -e "  ${GREEN}[OK]   ssh      : $(command -v ssh)${NC}"
else
  echo -e "  ${YELLOW}[MISS] ssh      : ssh client belum ditemukan${NC}"
fi

for tool in gitleaks trivy semgrep; do
  if command -v "${tool}" >/dev/null 2>&1; then
    echo -e "  ${GREEN}[OK]   ${tool} : $(command -v "${tool}")${NC}"
  else
    echo -e "  ${YELLOW}[MISS] ${tool} : belum terpasang${NC}"
  fi
done

echo ""

# ------------------------------------------------------------
# CORE INSTALLATION (Selalu Terpasang)
# ------------------------------------------------------------
mkdir -p "${TARGET_CONFIG_AGENTS}" "${TARGET_ANTIGRAVITY_AGENTS}" "${TARGET_CONFIG_PLUGINS_SDLC}" "${TARGET_CONFIG_PLUGINS_RTK}" "${TARGET_SCRIPTS}"

SAME_AGENTS_DIR=false
if [ "${TARGET_CONFIG_AGENTS}" -ef "${TARGET_ANTIGRAVITY_AGENTS}" ]; then
  SAME_AGENTS_DIR=true
fi

# 1. Custom Agents
agent_count=0
echo -e "${YELLOW}[CORE 1/5] Menginstal Custom Agents...${NC}"
shopt -s nullglob
for agent_file in "${SOURCE_AGENTS}"/*.md; do
  filename="$(basename "${agent_file}")"
  cp -f "${agent_file}" "${TARGET_CONFIG_AGENTS}/${filename}"
  if [ "${SAME_AGENTS_DIR}" = false ]; then
    ln -sfn "${TARGET_CONFIG_AGENTS}/${filename}" "${TARGET_ANTIGRAVITY_AGENTS}/${filename}" || \
      cp -f "${TARGET_CONFIG_AGENTS}/${filename}" "${TARGET_ANTIGRAVITY_AGENTS}/${filename}"
  fi
  echo "  - ${filename}"
  agent_count=$((agent_count + 1))
done
shopt -u nullglob
if [ "${SAME_AGENTS_DIR}" = true ]; then
  echo -e "  ${GREEN}[OK] ${agent_count} agent terpasang ke ${TARGET_CONFIG_AGENTS} (antigravity/agents sudah terhubung via directory link).${NC}"
else
  echo -e "  ${GREEN}[OK] ${agent_count} agent terpasang ke ${TARGET_CONFIG_AGENTS} & ${TARGET_ANTIGRAVITY_AGENTS}.${NC}"
fi

# 2. Plugin antigravity-sdlc (Skills, Engineering Rules & Command Guardrails)
echo ""
echo -e "${YELLOW}[CORE 2/5] Menginstal Plugin antigravity-sdlc (Skills, Rules, Guardrails)...${NC}"
rm -rf "${TARGET_CONFIG_PLUGINS_SDLC}"
mkdir -p "${TARGET_CONFIG_PLUGINS_SDLC}"
cp -R "${SOURCE_PLUGINS_SDLC}/." "${TARGET_CONFIG_PLUGINS_SDLC}/"

installed_hook_script="${TARGET_CONFIG_PLUGINS_SDLC}/hooks/sdlc-guardrails.mjs"
installed_hooks_json="${TARGET_CONFIG_PLUGINS_SDLC}/hooks.json"
escaped_hook_script="${installed_hook_script//\\/\\\\}"
escaped_hook_script="${escaped_hook_script//\"/\\\"}"

if [[ -n "${NODE_BIN}" ]]; then
  hook_enabled="true"
  echo -e "  ${GREEN}[OK] Hook guardrail aktif (node: ${NODE_BIN}).${NC}"
else
  hook_enabled="false"
  echo -e "  ${YELLOW}[WARN] CLI 'node' tidak ditemukan di PATH; hook 'antigravity-sdlc-guardrails' dinonaktifkan (enabled: false) agar run_command tetap aman.${NC}"
fi

hooks_tmp="$(mktemp)"
while IFS= read -r line || [[ -n "${line}" ]]; do
  if [[ "${line}" == *"__HOOK_SCRIPT_PATH__"* ]]; then
    line="${line%%__HOOK_SCRIPT_PATH__*}${escaped_hook_script}${line#*__HOOK_SCRIPT_PATH__}"
  fi
  if [[ "${hook_enabled}" == "false" ]]; then
    line="$(printf '%s' "${line}" | sed -E 's/"enabled"[[:space:]]*:[[:space:]]*true/"enabled": false/')"
  fi
  printf '%s\n' "${line}"
done < "${installed_hooks_json}" > "${hooks_tmp}"
mv "${hooks_tmp}" "${installed_hooks_json}"

for legacy_skill in "dotnet-webforms-patterns" "frontend-mobile-patterns" "portainer-harbor-deploy"; do
  legacy_skill_path="${TARGET_CONFIG_SKILLS}/${legacy_skill}"
  if [[ -e "${legacy_skill_path}" || -L "${legacy_skill_path}" ]]; then
    rm -rf "${legacy_skill_path}"
    echo "  [~] Migrasi legacy skill dihapus: ${legacy_skill_path}"
  fi
done
echo -e "  ${GREEN}[OK] Plugin antigravity-sdlc terpasang ke ${TARGET_CONFIG_PLUGINS_SDLC}.${NC}"

# 3. Plugin RTK
echo ""
echo -e "${YELLOW}[CORE 3/5] Menginstal Plugin RTK (Token Optimizer)...${NC}"
rm -rf "${TARGET_CONFIG_PLUGINS_RTK}"
mkdir -p "${TARGET_CONFIG_PLUGINS_RTK}"
cp -R "${SOURCE_PLUGINS_RTK}/." "${TARGET_CONFIG_PLUGINS_RTK}/"
echo -e "  ${GREEN}[OK] Konfigurasi plugin RTK disalin ke ${TARGET_CONFIG_PLUGINS_RTK}.${NC}"

if command -v rtk >/dev/null 2>&1; then
  echo -e "  ${GREEN}[OK] CLI 'rtk' terdeteksi ($(command -v rtk)).${NC}"
else
  echo -e "  ${YELLOW}[!] Binary CLI 'rtk' belum ditemukan di PATH.${NC}"
  echo "      Pasang binary 'rtk' via: brew install rtk / cargo install --git https://github.com/rtk-ai/rtk"
fi

# 4. Core Script: verify-gate.ps1
echo ""
echo -e "${YELLOW}[CORE 4/5] Menginstal Deterministic Gate Script (verify-gate.ps1)...${NC}"
cp -f "${SOURCE_VERIFY_GATE}" "${TARGET_SCRIPTS}/verify-gate.ps1"
echo -e "  ${GREEN}[OK] verify-gate.ps1 disalin ke ${TARGET_SCRIPTS}/verify-gate.ps1.${NC}"

# 5. GEMINI.md
echo ""
echo -e "${YELLOW}[CORE 5/5] Mengatur Global Profile & Guardrails (GEMINI.md)...${NC}"

resolved_response_language="English"
if [[ -n "${RESPONSE_LANGUAGE}" ]]; then
  resolved_response_language="${RESPONSE_LANGUAGE}"
elif [[ "${IS_INTERACTIVE}" == "true" ]]; then
  echo "  Pilih bahasa respons AI di GEMINI.md:"
  echo "    [1] English (Default) | [2] Bahasa Indonesia | [3] Custom"
  read -r -p "  Masukkan pilihan (1/2/3) [Default: 1]: " lang_choice
  case "${lang_choice}" in
    2) resolved_response_language="Bahasa Indonesia" ;;
    3)
      read -r -p "  Masukkan bahasa respons (contoh: Japanese): " custom_lang
      if [[ -n "${custom_lang}" ]]; then
        resolved_response_language="${custom_lang}"
      fi
      ;;
    *) resolved_response_language="English" ;;
  esac
fi

incoming_gemini_content="$(cat "${SOURCE_GEMINI_MD}")"
incoming_gemini_content="${incoming_gemini_content//Always respond to the user in English./Always respond to the user in ${resolved_response_language}.}"

if [[ ! -f "${TARGET_GEMINI_MD}" ]]; then
  printf '%s\n' "${incoming_gemini_content}" > "${TARGET_GEMINI_MD}"
  echo -e "  ${GREEN}[OK] GEMINI.md baru dibuat di ${TARGET_GEMINI_MD} (ResponseLanguage=${resolved_response_language}).${NC}"
else
  mode="${GEMINI_MD_MODE}"
  if [[ "${mode}" == "prompt" ]]; then
    if [[ "${IS_INTERACTIVE}" == "true" ]]; then
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
      printf '%s\n' "${incoming_gemini_content}" > "${TARGET_GEMINI_MD}"
      echo "  [OK] Backup disimpan ke: ${backup_file}"
      echo -e "  ${GREEN}[OK] GEMINI.md berhasil ditimpa (ResponseLanguage=${resolved_response_language}).${NC}"
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
          printf '%s\n' "${incoming_gemini_content}"
        } >> "${TARGET_GEMINI_MD}"
        echo "  [OK] Backup disimpan ke: ${backup_file}"
        echo -e "  ${GREEN}[OK] Konten GEMINI.md berhasil digabungkan (ResponseLanguage=${resolved_response_language}).${NC}"
      fi
      ;;
    *)
      echo -e "  ${YELLOW}[SKIP] GEMINI.md eksisting dipertahankan.${NC}"
      ;;
  esac
fi

# ------------------------------------------------------------
# ADD-ON A: Security Scanners (gitleaks, trivy, opsional semgrep)
# ------------------------------------------------------------
echo ""
echo -e "${YELLOW}[ADD-ON A] Security Scanners (gitleaks, trivy, opsional semgrep)...${NC}"
missing_tools=()
for tool in gitleaks trivy semgrep; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    missing_tools+=("${tool}")
  fi
done

if [[ ${#missing_tools[@]} -eq 0 ]]; then
  echo -e "  ${GREEN}[OK] gitleaks, trivy, dan semgrep sudah terpasang.${NC}"
else
  want_sec="${WITH_SECURITY_TOOLS}"
  if [[ "${want_sec}" == "false" && "${IS_INTERACTIVE}" == "true" ]]; then
    read -r -p "  Install security scanners yang belum ada (${missing_tools[*]})? (y/N): " sec_ans
    if [[ "${sec_ans}" =~ ^([yY]|[yY][eE][sS])$ ]]; then
      want_sec=true
    fi
  fi

  if [[ "${want_sec}" == "true" ]]; then
    if [[ "${PKG_MGR}" == "brew" ]]; then
      for tool in "${missing_tools[@]}"; do
        echo -e "  ${CYAN}[*] Menjalankan: brew install ${tool}${NC}"
        brew install "${tool}" || echo -e "  ${YELLOW}[WARN] Gagal memasang ${tool} via brew.${NC}"
      done
    else
      echo -e "  ${YELLOW}[INFO] Package manager '${PKG_MGR}': pasang manual sesuai OS Anda:${NC}"
      echo "         - gitleaks : https://github.com/gitleaks/gitleaks/releases"
      echo "         - trivy    : https://aquasecurity.github.io/trivy/latest/getting-started/installation/"
      echo "         - semgrep  : pipx install semgrep (opsional)"
    fi
  else
    echo -e "  ${YELLOW}[SKIP] Instalasi security scanners dilewati.${NC}"
  fi
fi

# ------------------------------------------------------------
# ADD-ON B: Central Memory MCP (Qdrant: Local / Localhost / Remote)
# ------------------------------------------------------------
echo ""
echo -e "${YELLOW}[ADD-ON B] Central Memory MCP (Qdrant)...${NC}"
enable_memory="${WITH_MEMORY}"
if [[ "${enable_memory}" == "false" && "${IS_INTERACTIVE}" == "true" ]]; then
  read -r -p "  Pasang Add-on Central Memory MCP (Qdrant + memory rules)? (y/N): " mem_ans
  if [[ "${mem_ans}" =~ ^([yY]|[yY][eE][sS])$ ]]; then
    enable_memory=true
  fi
fi

resolved_qdrant_mode=""

if [[ "${enable_memory}" == "true" ]]; then
  if [[ -z "${PYTHON_BIN}" ]]; then
    echo -e "  ${YELLOW}[WARN] Python 3 tidak ditemukan. Add-on Central Memory MCP dilewati dengan aman.${NC}"
    enable_memory=false
  elif [[ ! -f "${SOURCE_MCP}/central_memory_mcp.py" || ! -d "${SOURCE_MEMORY}" ]]; then
    echo -e "  ${YELLOW}[WARN] Folder sumber mcp/ atau memory/ tidak lengkap. Add-on Central Memory MCP dilewati.${NC}"
    enable_memory=false
  else
    if [[ -n "${QDRANT_MODE}" ]]; then
      resolved_qdrant_mode="${QDRANT_MODE}"
    elif [[ "${IS_INTERACTIVE}" == "true" ]]; then
      echo "  Pilih mode Qdrant untuk Central Memory MCP:"
      echo "    [1] Local Embedded (tanpa server eksternal, simpan di ~/.gemini/memory/qdrant_local) [Default]"
      echo "    [2] Localhost Server (download binary resmi Qdrant ke ~/.gemini/bin/, port 6333)"
      echo "    [3] Remote VPS (QDRANT_URL eksternal / HTTPS)"
      read -r -p "  Masukkan pilihan (1/2/3) [Default: 1]: " q_choice
      case "${q_choice}" in
        2) resolved_qdrant_mode="localhost" ;;
        3) resolved_qdrant_mode="remote" ;;
        *) resolved_qdrant_mode="local" ;;
      esac
    else
      resolved_qdrant_mode="local"
    fi

    echo -e "  ${CYAN}[i] Mode Qdrant terpilih: ${resolved_qdrant_mode}${NC}"

    mkdir -p "${TARGET_MCP}" "${TARGET_MEMORY}"
    cp -f "${SOURCE_MCP}/central_memory_mcp.py" "${TARGET_MCP}/central_memory_mcp.py"
    cp -f "${SOURCE_MCP}/requirements.txt" "${TARGET_MCP}/requirements.txt"
    cp -f "${SOURCE_MEMORY}"/*.md "${TARGET_MEMORY}/"
    echo -e "  ${GREEN}[OK] File MCP & memory rules disalin ke ${TARGET_MCP} & ${TARGET_MEMORY}.${NC}"

    case "${resolved_qdrant_mode}" in
      local)
        qdrant_local_dir="${TARGET_MEMORY}/qdrant_local"
        mkdir -p "${qdrant_local_dir}"
        echo -e "  ${GREEN}[OK] Direktori Qdrant Local Embedded siap di ${qdrant_local_dir}.${NC}"
        echo -e "  ${CYAN}[INFO] Contoh env di mcp_config.json: \"QDRANT_LOCAL_PATH\": \"${qdrant_local_dir}\"${NC}"
        ;;
      localhost)
        qdrant_storage_dir="${TARGET_MEMORY}/qdrant_storage"
        mkdir -p "${TARGET_BIN}" "${qdrant_storage_dir}"
        qdrant_config_path="${TARGET_BIN}/qdrant-config.yaml"
        cat > "${qdrant_config_path}" <<YAML
service:
  host: 127.0.0.1
  http_port: 6333
storage:
  storage_path: ${qdrant_storage_dir}
YAML
        echo -e "  ${GREEN}[OK] Konfigurasi Qdrant lokal dibuat di ${qdrant_config_path}.${NC}"

        qdrant_bin_path="${TARGET_BIN}/qdrant"
        if [[ -x "${qdrant_bin_path}" ]]; then
          echo -e "  ${GREEN}[OK] Binary Qdrant sudah tersedia di ${qdrant_bin_path}.${NC}"
        else
          asset_name=""
          case "${OS_NAME}:${ARCH_NAME}" in
            Linux:x86_64|Linux:amd64)
              asset_name="qdrant-x86_64-unknown-linux-musl.tar.gz"
              ;;
            Linux:aarch64|Linux:arm64)
              asset_name="qdrant-aarch64-unknown-linux-musl.tar.gz"
              ;;
            Darwin:arm64|Darwin:aarch64)
              asset_name="qdrant-aarch64-apple-darwin.tar.gz"
              ;;
            Darwin:x86_64)
              asset_name="qdrant-x86_64-apple-darwin.tar.gz"
              ;;
          esac

          if [[ -z "${asset_name}" ]]; then
            echo -e "  ${YELLOW}[WARN] Kombinasi OS/Arch (${OS_NAME}/${ARCH_NAME}) tidak memiliki binary Qdrant prebuilt otomatis.${NC}"
          else
            download_url="https://github.com/qdrant/qdrant/releases/latest/download/${asset_name}"
            tmp_archive="$(mktemp "/tmp/qdrant-XXXXXX.tar.gz")"
            echo -e "  ${CYAN}[*] Mengunduh ${asset_name} ke ${TARGET_BIN}...${NC}"
            download_ok=false
            if command -v curl >/dev/null 2>&1; then
              if curl -fsSL "${download_url}" -o "${tmp_archive}"; then
                download_ok=true
              fi
            elif command -v wget >/dev/null 2>&1; then
              if wget -qO "${tmp_archive}" "${download_url}"; then
                download_ok=true
              fi
            else
              echo -e "  ${YELLOW}[WARN] curl/wget tidak ditemukan untuk mengunduh Qdrant.${NC}"
            fi

            if [[ "${download_ok}" == "true" ]] && tar -xzf "${tmp_archive}" -C "${TARGET_BIN}"; then
              chmod +x "${qdrant_bin_path}" 2>/dev/null || true
              echo -e "  ${GREEN}[OK] Binary Qdrant berhasil diunduh ke ${qdrant_bin_path}.${NC}"
            else
              echo -e "  ${YELLOW}[WARN] Gagal mengunduh/mengekstrak binary Qdrant (offline/diblokir).${NC}"
              echo "         Unduh manual dari https://github.com/qdrant/qdrant/releases (${asset_name}) dan ekstrak ke ${TARGET_BIN}."
            fi
            rm -f "${tmp_archive}"
          fi
        fi
        echo -e "  ${CYAN}[INFO] Jalankan Qdrant lokal: ${qdrant_bin_path} --config-path ${qdrant_config_path}${NC}"
        echo "         Lalu set QDRANT_URL=http://127.0.0.1:6333 di mcp_config.json."
        ;;
      remote)
        echo -e "  ${CYAN}[INFO] Mode Remote VPS dipilih. Set QDRANT_URL & QDRANT_API_KEY di mcp_config.json.${NC}"
        ;;
    esac

    VENV_DIR="${TARGET_MCP}/.venv"
    VENV_PYTHON="${VENV_DIR}/bin/python"
    if [[ ! -x "${VENV_PYTHON}" ]]; then
      want_venv=false
      if [[ "${IS_INTERACTIVE}" == "true" ]]; then
        read -r -p "  Buat Python .venv & install dependencies (requirements.txt) di ${VENV_DIR}? (y/N): " venv_ans
        if [[ "${venv_ans}" =~ ^([yY]|[yY][eE][sS])$ ]]; then
          want_venv=true
        fi
      fi
      if [[ "${want_venv}" == "true" ]]; then
        echo -e "  ${CYAN}[*] Membuat virtual environment di ${VENV_DIR}...${NC}"
        "${PYTHON_BIN}" -m venv "${VENV_DIR}"
        "${VENV_PYTHON}" -m pip install --upgrade pip || echo -e "  ${YELLOW}[WARN] Upgrade pip gagal.${NC}"
        "${VENV_PYTHON}" -m pip install -r "${TARGET_MCP}/requirements.txt" || echo -e "  ${YELLOW}[WARN] Instalasi requirements.txt gagal.${NC}"
      else
        echo -e "  ${CYAN}[INFO] Untuk setup venv manual nanti, jalankan:${NC}"
        echo "         ${PYTHON_BIN} -m venv \"${VENV_DIR}\" && \"${VENV_PYTHON}\" -m pip install -r \"${TARGET_MCP}/requirements.txt\""
      fi
    else
      echo -e "  ${GREEN}[OK] Virtual environment .venv sudah ada di ${VENV_DIR}.${NC}"
    fi
  fi
else
  echo -e "  ${YELLOW}[SKIP] Add-on Central Memory MCP tidak dipilih.${NC}"
fi

# ------------------------------------------------------------
# ADD-ON C: Qdrant SSH Tunnel (Khusus Windows — Skip di Unix/macOS)
# ------------------------------------------------------------
echo ""
echo -e "${YELLOW}[ADD-ON C] Qdrant SSH Tunnel (Windows-only)...${NC}"
if [[ "${enable_memory}" == "true" && "${resolved_qdrant_mode}" == "remote" ]]; then
  echo "  [INFO] Di Unix/macOS, gunakan: 'ssh -N -L 127.0.0.1:6333:127.0.0.1:6333 <SSH_USER>@<VPS_IP>' bila perlu tunnel."
else
  echo "  [SKIP] Add-on tunnel .vbs khusus Windows (dan tidak diperlukan pada mode ${resolved_qdrant_mode:-non-remote})."
fi

# ------------------------------------------------------------
# Simpan Profil Add-on ke ~/.gemini/.addons.json
# ------------------------------------------------------------
if [[ "${enable_memory}" == "true" ]]; then
  qdrant_mode_json="\"${resolved_qdrant_mode}\""
else
  qdrant_mode_json="null"
fi

escaped_lang="${resolved_response_language//\"/\\\"}"

cat > "${ADDONS_PROFILE}" <<EOF
{
  "responseLanguage": "${escaped_lang}",
  "centralMemory": ${enable_memory},
  "qdrantMode": ${qdrant_mode_json},
  "sshTunnel": false
}
EOF

echo ""
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}  INSTALASI SELESAI!                                        ${NC}"
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}Ringkasan lokasi terpasang:${NC}"
echo -e "${GREEN}  - Agents (Config)      : ${TARGET_CONFIG_AGENTS}${NC}"
echo -e "${GREEN}  - Agents (Antigravity) : ${TARGET_ANTIGRAVITY_AGENTS}${NC}"
echo -e "${GREEN}  - Plugin (SDLC)        : ${TARGET_CONFIG_PLUGINS_SDLC}${NC}"
echo -e "${GREEN}  - Plugin (RTK)         : ${TARGET_CONFIG_PLUGINS_RTK}${NC}"
echo -e "${GREEN}  - Deterministic Gate   : ${TARGET_SCRIPTS}/verify-gate.ps1${NC}"
echo -e "${GREEN}  - Global Rules         : ${TARGET_GEMINI_MD}${NC}"
echo -e "${GREEN}  - Add-ons Profile      : ${ADDONS_PROFILE} (responseLanguage=${resolved_response_language}, centralMemory=${enable_memory}, qdrantMode=${resolved_qdrant_mode:-null}, sshTunnel=false)${NC}"
echo ""
echo -e "${CYAN}Langkah berikutnya:${NC}"
echo "  1. Restart / buka ulang Antigravity atau sesi Gemini CLI Anda."
echo "  2. Verifikasi kesehatan instalasi dengan: bash verify.sh"
