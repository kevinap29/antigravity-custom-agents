# Contributing to `antigravity-custom-agents`

Thank you for your interest in contributing! This repository is built as an open learning resource and production-ready starter kit for multi-agent SDLC workflows in Antigravity.

Whether you are fixing a typo, refining an agent prompt, adding a portable `SKILL.md` module, or improving cross-platform scripts, your contributions are welcome.

---

## Ways to Contribute

- **New or Improved Agents (`agents/`):** Add specialized roles or sharpen instructions, boundaries, and handoff rules in existing agent files.
- **Portable Skills (`plugins/antigravity-sdlc/skills/`):** Share battle-tested domain patterns packaged as `SKILL.md`.
- **Guardrails & Hooks (`plugins/`):** Improve enforcement logic in `sdlc-guardrails.mjs`, rules, or RTK plugin configurations.
- **Central Memory & MCP (`mcp/`, `memory/`):** Enhance `central_memory_mcp.py`, Qdrant integration, or shared architecture templates.
- **Cross-Platform Tooling (`*.sh`, `*.ps1`, `scripts/`):** Fix edge cases or improve installation, verification, and update scripts.
- **Documentation (`README*.md`, `CHEATSHEET*.md`):** Improve clarity, add examples, or keep English and Indonesian documentation in sync.

---

## Pull Request Workflow

1. **Fork** the repository and clone your fork locally.
2. **Create a feature branch** from `main`:
   ```bash
   git checkout -b feat/your-feature-name
   ```
   Use clear prefixes such as `feat/`, `fix/`, `docs/`, or `chore/`.
3. **Make your changes** following the guidelines below.
4. **Verify locally** before pushing:
   - **macOS / Linux:**
     ```bash
     ./verify.sh
     ```
   - **Windows (PowerShell):**
     ```powershell
     .\verify.ps1
     ```
5. **Commit cleanly** with descriptive messages and push your branch to your fork.
6. **Open a Pull Request** against `main` with:
   - A short summary of *what* changed and *why*.
   - Any manual test or verification output.
   - Notes if documentation or installer scripts were updated.

---

## Contribution Guidelines

### 1. Agents (`agents/*.md`)
- Keep each agent focused on a **single clear responsibility**—avoid turning one agent into a generic catch-all prompt.
- Explicitly define scope, expected inputs/outputs, and when to hand off to `sdlc-team-lead` or another specialist.

### 2. Skills (`plugins/.../skills/<skill-name>/SKILL.md`)
- Place each skill in its own kebab-case directory containing a `SKILL.md` file.
- Focus on concrete, actionable conventions, anti-patterns, and checklists rather than high-level theory.

### 3. Cross-Platform Parity
- If you modify installation, update, verification, or uninstall behavior