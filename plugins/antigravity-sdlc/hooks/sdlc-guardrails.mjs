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

const GIT_CHECKOUT_VALUE_FLAGS = new Set([
  "-b",
  "-B",
  "--orphan",
  "--conflict",
  "-U",
  "--unified",
  "--pathspec-from-file",
]);

const GIT_RESTORE_VALUE_FLAGS = new Set([
  "-s",
  "--source",
  "--conflict",
  "--pathspec-from-file",
]);

const GIT_BRANCH_VALUE_FLAGS = new Set([
  "--contains",
  "--no-contains",
  "--merged",
  "--no-merged",
  "--points-at",
  "--sort",
  "--format",
  "-u",
  "--set-upstream-to",
]);

const PS_DELETE_COMMANDS = new Set([
  "remove-item",
  "ri",
  "del",
  "erase",
  "rd",
  "rmdir",
]);

const PS_DELETE_IGNORED_VALUE_FLAGS = new Set([
  "-exclude",
  "-include",
  "-filter",
  "-stream",
  "-credential",
  "-erroraction",
  "-ea",
  "-warningaction",
  "-wa",
  "-informationaction",
  "-infa",
  "-outvariable",
  "-ov",
  "-errorvariable",
  "-ev",
]);

const DANGEROUS_WIPE_EXACT_PATHS = new Set([
  ".",
  "..",
  "./",
  ".\\",
  "../",
  "..\\",
  "/",
  "\\",
  "~",
  "~/",
  "~\\",
  "*",
  "/*",
  "\\*",
  "./*",
  ".\\*",
  "../*",
  "..\\*",
  "~/*",
  "~\\*",
  "$home",
  "${home}",
  "$env:userprofile",
]);

function isDotWorktreeTarget(raw) {
  if (typeof raw !== "string") return false;
  const trimmed = raw.trim();
  return trimmed === "." || trimmed === "./" || trimmed === ".\\" || trimmed === ":/";
}

function isDangerousWipePath(raw) {
  if (typeof raw !== "string") return false;
  const trimmed = raw.trim();
  if (!trimmed) return false;
  const lower = trimmed.toLowerCase();
  if (DANGEROUS_WIPE_EXACT_PATHS.has(lower)) {
    return true;
  }
  // Multiple slashes only (e.g. "//", "\\\")
  if (/^[/\\]+$/.test(trimmed)) {
    return true;
  }
  // Windows drive root (e.g. "C:", "C:\", "C:/", "D:\", "C:\*")
  if (/^[a-zA-Z]:[/\\]*\*?$/.test(trimmed)) {
    return true;
  }
  return false;
}

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

function hasClosingBacktick(str, startIdx) {
  for (let i = startIdx; i < str.length; i++) {
    if (str[i] === "\\" && i + 1 < str.length) {
      i++;
      continue;
    }
    if (str[i] === "`") {
      return true;
    }
  }
  return false;
}

function splitSegments(commandLine) {
  const segments = [];
  let current = "";
  let quote = null;
  let cmdSubDepth = 0;
  let subQuote = null;
  let inBacktick = false;

  for (let i = 0; i < commandLine.length; i++) {
    const ch = commandLine[i];
    const next = commandLine[i + 1];

    if (cmdSubDepth > 0) {
      if (subQuote === "'") {
        if (ch === "'") {
          subQuote = null;
        }
        current += ch;
        continue;
      }

      if (subQuote === '"') {
        if (ch === "\\" && (next === '"' || next === "\\")) {
          current += ch + next;
          i++;
          continue;
        }
        if (ch === '"') {
          subQuote = null;
        }
        current += ch;
        continue;
      }

      if (ch === "'" || ch === '"') {
        subQuote = ch;
        current += ch;
        continue;
      }

      if (ch === "(") {
        cmdSubDepth++;
        current += ch;
        continue;
      }

      if (ch === ")") {
        cmdSubDepth--;
        current += ch;
        continue;
      }

      current += ch;
      continue;
    }

    if (inBacktick) {
      if (ch === "\\" && i + 1 < commandLine.length) {
        current += ch + next;
        i++;
        continue;
      }
      if (ch === "`") {
        inBacktick = false;
      }
      current += ch;
      continue;
    }

    if (quote === "'") {
      if (ch === "'") {
        quote = null;
      }
      current += ch;
      continue;
    }

    if (quote === '"') {
      if (ch === "\\" && (next === '"' || next === "\\" || next === "$" || next === "`")) {
        current += ch + next;
        i++;
        continue;
      }
      if (ch === "$" && next === "(") {
        cmdSubDepth = 1;
        subQuote = null;
        current += ch + next;
        i++;
        continue;
      }
      if (ch === "`" && hasClosingBacktick(commandLine, i + 1)) {
        inBacktick = true;
        current += ch;
        continue;
      }
      if (ch === '"') {
        quote = null;
      }
      current += ch;
      continue;
    }

    if (ch === "\\" && (next === "$" || next === "`" || next === "'" || next === '"' || next === "\\")) {
      current += ch + next;
      i++;
      continue;
    }

    if (ch === "$" && next === "(") {
      cmdSubDepth = 1;
      subQuote = null;
      current += ch + next;
      i++;
      continue;
    }

    if (ch === "`" && hasClosingBacktick(commandLine, i + 1)) {
      inBacktick = true;
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

function checkGitCommand(tokens, cwd, branchResolver, envOverrides = {}, allowGitCommit = false) {
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

  if (subcmd === "commit") {
    const commitAllowed =
      allowGitCommit === true || process.env.SDLC_ALLOW_GIT_COMMIT === "1";
    if (!commitAllowed) {
      return "[SDLC Guardrail] Autonomous 'git commit' is blocked. Require explicit user confirmation (or set SDLC_ALLOW_GIT_COMMIT=1 for intentional manual override).";
    }
    return null;
  }

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

  if (subcmd === "checkout") {
    let afterDoubleDash = false;
    for (let j = i + 1; j < tokens.length; j++) {
      const arg = tokens[j].text;
      if (!afterDoubleDash && arg === "--") {
        afterDoubleDash = true;
        continue;
      }
      if (!afterDoubleDash && GIT_CHECKOUT_VALUE_FLAGS.has(arg)) {
        j++;
        continue;
      }
      if (!afterDoubleDash && arg.startsWith("-")) {
        continue;
      }
      if (isDotWorktreeTarget(arg)) {
        return "[SDLC Guardrail] Destructive 'git checkout .' / 'git checkout -- .' discards all unstaged worktree changes and is blocked. Require explicit user confirmation.";
      }
    }
    return null;
  }

  if (subcmd === "restore") {
    let hasStaged = false;
    let hasWorktree = false;
    let afterDoubleDash = false;
    const targets = [];

    for (let j = i + 1; j < tokens.length; j++) {
      const arg = tokens[j].text;
      if (!afterDoubleDash && arg === "--") {
        afterDoubleDash = true;
        continue;
      }
      if (!afterDoubleDash && GIT_RESTORE_VALUE_FLAGS.has(arg)) {
        j++;
        continue;
      }
      if (!afterDoubleDash && arg.startsWith("-")) {
        if (arg === "--staged" || arg === "-S") {
          hasStaged = true;
        } else if (arg === "--worktree" || arg === "-W") {
          hasWorktree = true;
        } else if (/^-[a-zA-Z]+$/.test(arg)) {
          if (arg.includes("S")) hasStaged = true;
          if (arg.includes("W")) hasWorktree = true;
        }
        continue;
      }
      targets.push(arg);
    }

    const modifiesWorktree = hasWorktree || !hasStaged;
    if (modifiesWorktree && targets.some((t) => isDotWorktreeTarget(t))) {
      return "[SDLC Guardrail] Destructive 'git restore .' discards all unstaged worktree changes and is blocked. Use targeted file paths or require explicit user confirmation.";
    }
    return null;
  }

  if (subcmd === "branch") {
    let hasDelete = false;
    let hasForce = false;
    let hasForceDelete = false;
    let afterDoubleDash = false;
    const branches = [];

    for (let j = i + 1; j < tokens.length; j++) {
      const arg = tokens[j].text;
      if (!afterDoubleDash && arg === "--") {
        afterDoubleDash = true;
        continue;
      }
      if (!afterDoubleDash && GIT_BRANCH_VALUE_FLAGS.has(arg)) {
        j++;
        continue;
      }
      if (!afterDoubleDash && arg.startsWith("-")) {
        if (arg === "-D") {
          hasForceDelete = true;
        } else if (arg === "-d" || arg === "--delete") {
          hasDelete = true;
        } else if (arg === "-f" || arg === "--force") {
          hasForce = true;
        } else if (/^-[a-zA-Z]+$/.test(arg)) {
          if (arg.includes("D")) hasForceDelete = true;
          if (arg.includes("d")) hasDelete = true;
          if (arg.includes("f")) hasForce = true;
        }
        continue;
      }
      branches.push(arg);
    }

    if (hasForceDelete || (hasDelete && hasForce)) {
      for (const branch of branches) {
        const normalized = branch.replace(/^refs\/heads\//i, "").trim().toLowerCase();
        if (PROTECTED_BRANCHES.has(normalized)) {
          return `[SDLC Guardrail] Force-deleting protected branch '${branch}' is blocked.`;
        }
      }
    }
    return null;
  }

  if (subcmd === "stash") {
    for (let j = i + 1; j < tokens.length; j++) {
      const arg = tokens[j].text;
      if (arg === "--") break;
      if (arg.startsWith("-")) continue;
      if (arg.toLowerCase() === "clear") {
        return "[SDLC Guardrail] Destructive 'git stash clear' wipes all stashed work and is blocked. Require explicit user confirmation.";
      }
      break;
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

function checkRmCommand(tokens) {
  let hasRecursive = false;
  let hasForce = false;
  let afterDoubleDash = false;
  const targets = [];

  for (let i = 1; i < tokens.length; i++) {
    const arg = tokens[i].text;
    if (!afterDoubleDash && arg === "--") {
      afterDoubleDash = true;
      continue;
    }
    if (!afterDoubleDash && arg.startsWith("-") && arg !== "-") {
      if (arg === "--recursive") {
        hasRecursive = true;
      } else if (arg === "--force") {
        hasForce = true;
      } else if (/^-[a-zA-Z]+$/.test(arg)) {
        if (arg.includes("r") || arg.includes("R")) hasRecursive = true;
        if (arg.includes("f")) hasForce = true;
      }
      continue;
    }
    targets.push(arg);
  }

  if (hasRecursive && hasForce) {
    for (const target of targets) {
      if (isDangerousWipePath(target)) {
        return `[SDLC Guardrail] Destructive recursive force delete ('rm -rf ${target}') is blocked to prevent catastrophic workspace/filesystem loss.`;
      }
    }
  }

  return null;
}

function checkPowerShellDeleteCommand(tokens) {
  let hasRecursive = false;
  let hasForce = false;
  const rawTargets = [];

  for (let i = 1; i < tokens.length; i++) {
    const arg = tokens[i].text;
    const lower = arg.toLowerCase();

    if (lower === "-path" || lower === "-literalpath") {
      if (i + 1 < tokens.length) {
        rawTargets.push(tokens[++i].text);
      }
      continue;
    }

    if (lower.startsWith("-path:") || lower.startsWith("-literalpath:")) {
      const colonIdx = arg.indexOf(":");
      const boundTarget = arg.slice(colonIdx + 1);
      if (boundTarget.length > 0) {
        rawTargets.push(boundTarget);
      }
      continue;
    }

    if (PS_DELETE_IGNORED_VALUE_FLAGS.has(lower)) {
      i++;
      continue;
    }

    if (arg.startsWith("-") && arg !== "-") {
      const [flagName, flagVal] = lower.split(":");
      const isDisabled = flagVal === "false" || flagVal === "$false";
      if (!isDisabled && flagName.length >= 2) {
        if ("-recurse".startsWith(flagName)) {
          hasRecursive = true;
        } else if ("-force".startsWith(flagName)) {
          hasForce = true;
        }
      }
      continue;
    }

    rawTargets.push(arg);
  }

  if (hasRecursive && hasForce) {
    for (const rawTarget of rawTargets) {
      const parts = rawTarget.split(",");
      for (const part of parts) {
        const candidate = part.trim();
        if (isDangerousWipePath(candidate)) {
          return `[SDLC Guardrail] Destructive recursive force delete ('${tokens[0].text} -Recurse -Force ${candidate}') is blocked to prevent catastrophic workspace/filesystem loss.`;
        }
      }
    }
  }

  return null;
}

const DIR_CHANGE_COMMANDS = new Set(["cd", "set-location", "sl", "pushd"]);

function isPowerShellEncodedFlag(flag) {
  return flag === "-ec" || (flag.startsWith("-e") && "-encodedcommand".startsWith(flag));
}

function decodePowerShellEncodedCommand(rawPayload) {
  if (typeof rawPayload !== "string") {
    return null;
  }
  const trimmed = rawPayload.trim();
  if (!trimmed || trimmed.length % 4 !== 0 || !/^[A-Za-z0-9+/]+={0,2}$/.test(trimmed)) {
    return null;
  }
  try {
    const buf = Buffer.from(trimmed, "base64");
    if (buf.length === 0 || buf.length % 2 !== 0) {
      return null;
    }
    const decoded = buf.toString("utf16le").replace(/\0/g, "").trim();
    return decoded.length > 0 ? decoded : null;
  } catch {
    return null;
  }
}

function extractCommandSubstitutions(segment) {
  const results = [];
  let quote = null;

  for (let i = 0; i < segment.length; i++) {
    const ch = segment[i];
    const next = segment[i + 1];

    if (quote === "'") {
      if (ch === "'") {
        quote = null;
      }
      continue;
    }

    if (quote === '"') {
      if (ch === "\\" && (next === '"' || next === "\\" || next === "$" || next === "`")) {
        i++;
        continue;
      }
      if (ch === '"') {
        quote = null;
        continue;
      }
    } else {
      if (ch === "\\" && (next === "$" || next === "`" || next === "'" || next === '"' || next === "\\")) {
        i++;
        continue;
      }
      if (ch === "'" || ch === '"') {
        quote = ch;
        continue;
      }
    }

    if (ch === "$" && next === "(") {
      let j = i + 2;
      let parenDepth = 1;
      let innerQuote = null;

      while (j < segment.length && parenDepth > 0) {
        const c = segment[j];
        const cn = segment[j + 1];

        if (innerQuote === "'") {
          if (c === "'") {
            innerQuote = null;
          }
          j++;
          continue;
        }

        if (innerQuote === '"') {
          if (c === "\\" && (cn === '"' || cn === "\\")) {
            j += 2;
            continue;
          }
          if (c === '"') {
            innerQuote = null;
          }
          j++;
          continue;
        }

        if (c === "'" || c === '"') {
          innerQuote = c;
        } else if (c === "(") {
          parenDepth++;
        } else if (c === ")") {
          parenDepth--;
        }
        j++;
      }

      if (parenDepth === 0) {
        const inner = segment.slice(i + 2, j - 1).trim();
        if (inner.length > 0) {
          results.push(inner);
        }
        i = j - 1;
      }
      continue;
    }

    if (ch === "`") {
      let j = i + 1;
      while (j < segment.length) {
        if (segment[j] === "\\" && j + 1 < segment.length) {
          j += 2;
          continue;
        }
        if (segment[j] === "`") {
          break;
        }
        j++;
      }

      if (j < segment.length && segment[j] === "`") {
        const inner = segment.slice(i + 1, j).trim();
        if (inner.length > 0) {
          results.push(inner);
        }
        i = j;
      }
    }
  }

  return results;
}

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

  if (depth > 3) {
    return "[SDLC Guardrail] Command nesting depth exceeded (> 3); blocked to prevent guardrail bypass.";
  }
  let currentCwd = options.cwd || process.cwd();
  const branchResolver =
    typeof options.branchResolver === "function" ? options.branchResolver : resolveCurrentGitBranch;
  const allowGitCommit = options.allowGitCommit === true;

  const segments = splitSegments(commandLine);

  for (const segment of segments) {
    const rawTokens = tokenizeSegment(segment);
    const { tokens, envOverrides: segEnv } = stripLeadingPrefixes(rawTokens);
    const envOverrides = options.envOverrides ? { ...options.envOverrides, ...segEnv } : segEnv;

    const substitutions = extractCommandSubstitutions(segment);
    for (const subCmd of substitutions) {
      const subReason = evaluateCommandLine(
        subCmd,
        { cwd: currentCwd, branchResolver, envOverrides, allowGitCommit },
        depth + 1
      );
      if (subReason) return subReason;
    }

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
      const reason = checkGitCommand(tokens, currentCwd, branchResolver, envOverrides, allowGitCommit);
      if (reason) return reason;
    }

    if (exe === "dotnet") {
      const reason = checkDotnetEf(tokens);
      if (reason) return reason;
    }

    if (exe === "rm") {
      const reason = checkRmCommand(tokens) || checkPowerShellDeleteCommand(tokens);
      if (reason) return reason;
    }

    if (PS_DELETE_COMMANDS.has(exe)) {
      const reason = checkPowerShellDeleteCommand(tokens);
      if (reason) return reason;
    }

    if (SHELL_EXECUTABLES.has(exe)) {
      const isPowerShell = exe === "pwsh" || exe === "powershell";
      for (let i = 1; i < tokens.length; i++) {
        const flag = tokens[i].text.toLowerCase();
        if (isPowerShell && isPowerShellEncodedFlag(flag)) {
          if (i + 1 >= tokens.length) {
            return "[SDLC Guardrail] Unreadable PowerShell -EncodedCommand payload is blocked.";
          }
          const decoded = decodePowerShellEncodedCommand(tokens[i + 1].text);
          if (!decoded) {
            return "[SDLC Guardrail] Unreadable PowerShell -EncodedCommand payload is blocked.";
          }
          const nestedReason = evaluateCommandLine(
            decoded,
            { cwd: currentCwd, branchResolver, envOverrides, allowGitCommit },
            depth + 1
          );
          if (nestedReason) return nestedReason;
          i++;
          continue;
        }
        if ((flag === "-c" || flag === "-command" || flag === "/c") && i + 1 < tokens.length) {
          const nestedReason = evaluateCommandLine(
            tokens[i + 1].text,
            { cwd: currentCwd, branchResolver, envOverrides, allowGitCommit },
            depth + 1
          );
          if (nestedReason) return nestedReason;
          i++;
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
