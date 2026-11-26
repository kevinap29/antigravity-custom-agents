#!/usr/bin/env node

import { execFileSync } from "node:child_process";
import path from "node:path";
import { pathToFileURL } from "node:url";

const PROTECTED_BRANCHES = new Set(["main", "master", "develop"]);
const DIRECT_DB_CLIS = new Set([
  "sqlcmd",
  "invoke-sqlcmd",
  "sqlite3",
  "psql",
  "mysql",
  "sqlpackage",
]);
const COMMAND_WRAPPERS = new Set(["sudo", "env", "command", "nohup", "time", "rtk"]);
const SHELL_EXECUTABLES = new Set(["sh", "bash", "zsh", "dash", "pwsh", "powershell", "cmd"]);

const GIT_GLOBAL_VALUE_FLAGS = new Set([
  "-C",
  "-c",
  "--git-dir",
  "--work-tree",
  "--namespace",
  "--exec-path",
  "--super-prefix",
  "--config-env",
]);

const GIT_PUSH_VALUE_FLAGS = new Set([
  "--repo",
  "--receive-pack",
  "--exec",
  "-o",
  "--push-option",
]);

const DOTNET_EF_VALUE_FLAGS = new Set([
  "-p",
  "--project",
  "-s",
  "--startup-project",
  "-c",
  "--context",
  "--configuration",
  "-f",
  "--framework",
  "-r",
  "--runtime",
  "--msbuildprojectextensionspath",
]);

function allow() {
  process.stdout.write(JSON.stringify({ decision: "allow" }) + "\n");
}

function deny(reason) {
  process.stdout.write(JSON.stringify({ decision: "deny", reason }) + "\n");
}

function extractCommand(payload) {
  if (!payload || typeof payload !== "object") return null;
  const candidates = [
    payload.tool_input?.CommandLine,
    payload.tool_input?.commandLine,
    payload.tool_input?.command,
    payload.tool_info?.command_line,
    payload.tool_info?.CommandLine,
    payload.input?.CommandLine,
    payload.arguments?.CommandLine,
  ];
  for (const value of candidates) {
    if (typeof value === "string" && value.trim().length > 0) {
      return value;
    }
  }
  return null;
}

function extractCwd(payload) {
  if (!payload || typeof payload !== "object") return undefined;
  const candidates = [
    payload.cwd,
    payload.working_directory,
    payload.tool_input?.cwd,
    payload.tool_info?.cwd,
  ];
  for (const value of candidates) {
    if (typeof value === "string" && value.trim().length > 0) {
      return value.trim();
    }
  }
  return undefined;
}

function splitSegments(commandLine) {
  const segments = [];
  let current = "";
  let quote = null;

  for (let i = 0; i < commandLine.length; i++) {
    const ch = commandLine[i];
    const next = commandLine[i + 1];

    if (quote === "'") {
      if (ch === "'") {
        quote = null;
      }
      current += ch;
      continue;
    }

    if (quote === '"') {
      if (ch === "\\" && (next === '"' || next === "\\")) {
        current += ch + next;
        i++;
        continue;
      }
      if (ch === '"') {
        quote = null;
      }
      current += ch;
      continue;
    }

    if (ch === "'" || ch === '"') {
      quote = ch;
      current += ch;
      continue;
    }

    if (ch === ";" || ch === "\n" || ch === "\r") {
      if (current.trim().length > 0) segments.push(current.trim());
      current = "";
      continue;
    }

    if ((ch === "&" && next === "&") || (ch === "|" && next === "|")) {
      if (current.trim().length > 0) segments.push(current.trim());
      current = "";
      i++;
      continue;
    }

    if (ch === "|") {
      if (current.trim().length > 0) segments.push(current.trim());
      current = "";
      continue;
    }

    current += ch;
  }

  if (current.trim().length > 0) {
    segments.push(current.trim());
  }

  return segments;
}

function tokenizeSegment(segment) {
  const tokens = [];
  let current = "";
  let inToken = false;
  let wasQuoted = false;
  let quote = null;

  for (let i = 0; i < segment.length; i++) {
    const ch = segment[i];
    const next = segment[i + 1];

    if (quote === "'") {
      if (ch === "'") {
        quote = null;
      } else {
        current += ch;
      }
      inToken = true;
      continue;
    }

    if (quote === '"') {
      if (ch === "\\" && (next === '"' || next === "\\")) {
        current += next;
        i++;
      } else if (ch === '"') {
        quote = null;
      } else {
        current += ch;
      }
      inToken = true;
      continue;
    }

    if (ch === "'" || ch === '"') {
      quote = ch;
      wasQuoted = true;
      inToken = true;
      continue;
    }

    if (ch === " " || ch === "\t") {
      if (inToken) {
        tokens.push({ text: current, quoted: wasQuoted });
        current = "";
        inToken = false;
        wasQuoted = false;
      }
      continue;
    }

    current += ch;
    inToken = true;
  }

  if (inToken) {
    tokens.push({ text: current, quoted: wasQuoted });
  }

  return tokens;
}

function normalizeExeName(raw) {
  const parts = raw.split(/[/\\]/);
  const base = parts[parts.length - 1] || "";
  return base.toLowerCase().replace(/\.(exe|cmd|bat|ps1)$/i, "");
}

function stripLeadingPrefixes(tokens) {
  let idx = 0;
  const envOverrides = {};
  const recordEnvAssignment = (text) => {
    const eqIdx = text.indexOf("=");
    if (eqIdx > 0) {
      const key = text.slice(0, eqIdx);
      const val = text.slice(eqIdx + 1);
      if (key === "GIT_DIR" || key === "GIT_WORK_TREE") {
        envOverrides[key] = val;
      }
    }
  };

  while (idx < tokens.length) {
    const tok = tokens[idx];
    if (!tok.quoted && tok.text === "&") {
      idx++;
      continue;
    }
    if (!tok.quoted && /^[A-Za-z_][A-Za-z0-9_]*=/.test(tok.text)) {
      recordEnvAssignment(tok.text);
      idx++;
      continue;
    }
    const exe = normalizeExeName(tok.text);
    if (COMMAND_WRAPPERS.has(exe) && idx + 1 < tokens.length) {
      idx++;
      while (
        idx < tokens.length &&
        !tokens[idx].quoted &&
        (tokens[idx].text.startsWith("-") || /^[A-Za-z_][A-Za-z0-9_]*=/.test(tokens[idx].text))
      ) {
        if (/^[A-Za-z_][A-Za-z0-9_]*=/.test(tokens[idx].text)) {
          recordEnvAssignment(tokens[idx].text);
        }
        idx++;
      }
      continue;
    }
    break;
  }
  return { tokens: tokens.slice(idx), envOverrides };
}

function extractTargetBranch(refspec) {
  let spec = refspec.replace(/^\+/, "");
  const colonIdx = spec.indexOf(":");
  if (colonIdx !== -1) {
    spec = spec.slice(colonIdx + 1);
  }
  spec = spec.replace(/^refs\/heads\//i, "");
  return spec.trim();
}

function resolveCurrentGitBranch(globalGitArgs, cwd, envOverrides = {}) {
  try {
    const env =
      envOverrides && Object.keys(envOverrides).length > 0
        ? { ...process.env, ...envOverrides }
        : process.env;
    const out = execFileSync("git", [...globalGitArgs, "rev-parse", "--abbrev-ref", "HEAD"], {
      cwd: cwd || process.cwd(),
      env,
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
      timeout: 1500,
    });
    return out.trim();
  } catch {
    return null;
  }
}

function extractDirectoryChangeTarget(tokens) {
  let i = 1;
  while (i < tokens.length) {
    const t = tokens[i].text;
    const lower = t.toLowerCase();
    if (lower === "--") {
      return tokens[i + 1]?.text || null;
    }
    if (lower === "-path" || lower === "-literalpath") {
      return tokens[i + 1]?.text || null;
    }
    if (lower === "/d") {
      i++;
      continue;
    }
    if (t.startsWith("-") && t !== "-") {
      i++;
      continue;
    }
    return t;
  }
  return null;
}

function checkGitCommand(tokens, cwd, branchResolver, envOverrides = {}) {
  let i = 1;
  const globalGitArgs = [];
  while (i < tokens.length) {
    const t = tokens[i].text;
    if (t === "--") {
      i++;
      break;
    }
    if (GIT_GLOBAL_VALUE_FLAGS.has(t)) {
      if (i + 1 < tokens.length && (t === "-C" || t === "--git-dir" || t === "--work-tree")) {
        globalGitArgs.push(t, tokens[i + 1].text);
      }
      i += 2;
      continue;
    }
    if (
      t.startsWith("--git-dir=") ||
      t.startsWith("--work-tree=") ||
      (t.startsWith("-C") && t.length > 2)
    ) {
      globalGitArgs.push(t);
      i++;
      continue;
    }
    if (t.startsWith("-")) {
      i++;
      continue;
    }
    break;
  }

  if (i >= tokens.length) {
    return null;
  }

  const subcmd = tokens[i].text.toLowerCase();

  if (subcmd === "reset") {
    for (let j = i + 1; j < tokens.length; j++) {
      if (tokens[j].text === "--hard") {
        return "[SDLC Guardrail] Destructive 'git reset --hard' is blocked. Require explicit user confirmation outside automated agent runs.";
      }
    }
    return null;
  }

  if (subcmd === "clean") {
    let hasDryRun = false;
    let hasForce = false;
    let hasDir = false;
    let hasIgnored = false;
    for (let j = i + 1; j < tokens.length; j++) {
      const arg = tokens[j].text;
      if (arg === "--") break;
      if (arg === "-e" || arg === "--exclude") {
        j++;
        continue;
      }
      if (arg.startsWith("-e") && arg.length > 2) continue;
      if (arg === "--dry-run") hasDryRun = true;
      if (arg === "--force") hasForce = true;
      if (/^-[a-zA-Z]+$/.test(arg)) {
        if (arg.includes("n")) hasDryRun = true;
        if (arg.includes("f")) hasForce = true;
        if (arg.includes("d")) hasDir = true;
        if (arg.includes("x") || arg.includes("X")) hasIgnored = true;
      }
    }
    if (hasDryRun) {
      return null;
    }
    if (hasForce && (hasDir || hasIgnored)) {
      return "[SDLC Guardrail] Destructive 'git clean' (-fd/-fx/-fX/-fdx) is blocked. Require explicit user confirmation.";
    }
    return null;
  }

  if (subcmd !== "push") {
    return null;
  }

  i++;
  const positional = [];
  let endOfFlags = false;
  let isForcePush = false;
  while (i < tokens.length) {
    const t = tokens[i].text;
    if (!endOfFlags && t === "--") {
      endOfFlags = true;
      i++;
      continue;
    }
    if (!endOfFlags && GIT_PUSH_VALUE_FLAGS.has(t)) {
      i += 2;
      continue;
    }
    if (
      !endOfFlags &&
      (t === "-f" ||
        t === "--force" ||
        t === "--force-with-lease" ||
        t.startsWith("--force-with-lease=") ||
        t === "--force-if-includes" ||
        (/^-[a-zA-Z]+$/.test(t) && t.includes("f")))
    ) {
      isForcePush = true;
      i++;
      continue;
    }
    if (!endOfFlags && t.startsWith("-")) {
      i++;
      continue;
    }
    if (t.startsWith("+")) {
      isForcePush = true;
    }
    positional.push(t);
    i++;
  }

  if (isForcePush) {
    return "[SDLC Guardrail] Force push ('--force', '-f', '--force-with-lease', '--force-if-includes', or '+refspec') is blocked to prevent remote history loss.";
  }

  // Implicit push ('git push' or 'git push origin') -> resolve active branch
  if (positional.length <= 1) {
    const resolveBranch = typeof branchResolver === "function" ? branchResolver : resolveCurrentGitBranch;
    const currentBranch = resolveBranch(globalGitArgs, cwd, envOverrides);
    if (currentBranch && PROTECTED_BRANCHES.has(currentBranch.toLowerCase())) {
      return `[SDLC Guardrail] Implicit git push while on protected branch '${currentBranch}' is blocked. Switch to a feature branch and open a PR instead.`;
    }
    if (positional.length === 1) {
      const target = extractTargetBranch(positional[0]);
      if (PROTECTED_BRANCHES.has(target.toLowerCase())) {
        return `[SDLC Guardrail] Direct git push to protected branch '${target}' is blocked. Push to a feature branch and open a PR instead.`;
      }
    }
    return null;
  }

  const refspecs = positional.slice(1);
  for (const refspec of refspecs) {
    const target = extractTargetBranch(refspec);
    if (PROTECTED_BRANCHES.has(target.toLowerCase())) {
      return `[SDLC Guardrail] Direct git push to protected branch '${target}' is blocked. Push to a feature branch and open a PR instead.`;
    }
  }

  return null;
}

function checkDotnetEf(tokens) {
  if (tokens.length < 3 || tokens[1].text.toLowerCase() !== "ef") {
    return null;
  }

  const subcommands = [];
  for (let i = 2; i < tokens.length; i++) {
    const t = tokens[i].text;
    if (DOTNET_EF_VALUE_FLAGS.has(t.toLowerCase())) {
      i++;
      continue;
    }
    if (t.startsWith("-")) {
      continue;
    }
    subcommands.push(t.toLowerCase());
  }

  if (subcommands[0] === "migrations") {
    return "[SDLC Guardrail] EF Core Code-First command 'dotnet ef migrations' is blocked by DB-first policy.";
  }

  if (subcommands[0] === "database" && subcommands[1] === "update") {
    return "[SDLC Guardrail] EF Core Code-First command 'dotnet ef database update' is blocked by DB-first policy.";
  }

  return null;
}

const DIR_CHANGE_COMMANDS = new Set(["cd", "set-location", "sl", "pushd"]);

function evaluateCommandLine(commandLine, optionsOrDepth = {}, depthArg = 0) {
  let options = {};
  let depth = depthArg;
  if (typeof optionsOrDepth === "number") {
    depth = optionsOrDepth;
  } else if (optionsOrDepth && typeof optionsOrDepth === "object") {
    options = optionsOrDepth;
    if (typeof options.depth === "number") {
      depth = options.depth;
    }
  }

  if (depth > 3) return null;
  let currentCwd = options.cwd || process.cwd();
  const branchResolver =
    typeof options.branchResolver === "function" ? options.branchResolver : resolveCurrentGitBranch;

  const segments = splitSegments(commandLine);

  for (const segment of segments) {
    const rawTokens = tokenizeSegment(segment);
    const { tokens, envOverrides: segEnv } = stripLeadingPrefixes(rawTokens);
    const envOverrides = options.envOverrides ? { ...options.envOverrides, ...segEnv } : segEnv;
    if (tokens.length === 0) continue;

    const exe = normalizeExeName(tokens[0].text);

    if (DIR_CHANGE_COMMANDS.has(exe)) {
      const targetDir = extractDirectoryChangeTarget(tokens);
      if (targetDir && targetDir !== "-") {
        currentCwd = path.resolve(currentCwd, targetDir);
      }
      continue;
    }

    if (DIRECT_DB_CLIS.has(exe)) {
      return `[SDLC Guardrail] Direct database CLI execution ('${exe}') is blocked by DB-first policy.`;
    }

    if (exe === "git") {
      const reason = checkGitCommand(tokens, currentCwd, branchResolver, envOverrides);
      if (reason) return reason;
    }

    if (exe === "dotnet") {
      const reason = checkDotnetEf(tokens);
      if (reason) return reason;
    }

    if (SHELL_EXECUTABLES.has(exe)) {
      for (let i = 1; i < tokens.length - 1; i++) {
        const flag = tokens[i].text.toLowerCase();
        if (flag === "-c" || flag === "-command" || flag === "/c") {
          const nestedReason = evaluateCommandLine(
            tokens[i + 1].text,
            { cwd: currentCwd, branchResolver, envOverrides },
            depth + 1
          );
          if (nestedReason) return nestedReason;
        }
      }
    }
  }

  return null;
}

async function readStdin() {
  const chunks = [];
  for await (const chunk of process.stdin) {
    chunks.push(chunk);
  }
  return Buffer.concat(chunks).toString("utf8");
}

async function main() {
  let raw = "";
  try {
    raw = await readStdin();
  } catch {
    allow();
    return;
  }

  if (!raw || raw.trim().length === 0) {
    allow();
    return;
  }

  let payload;
  try {
    payload = JSON.parse(raw);
  } catch {
    allow();
    return;
  }

  const commandLine = extractCommand(payload);
  if (!commandLine) {
    allow();
    return;
  }

  const cwd = extractCwd(payload);
  const denyReason = evaluateCommandLine(commandLine, { cwd });
  if (denyReason) {
    deny(denyReason);
    return;
  }

  allow();
}

export { evaluateCommandLine, extractCommand, extractCwd };

const isDirectRun =
  typeof process.argv[1] === "string" &&
  import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href;

if (isDirectRun) {
  main().catch(() => {
    allow();
  });
}
