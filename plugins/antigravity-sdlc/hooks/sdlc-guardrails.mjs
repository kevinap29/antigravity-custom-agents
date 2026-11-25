#!/usr/bin/env node

const PROTECTED_BRANCHES = new Set(["main", "master", "develop"]);
const DIRECT_DB_CLIS = new Set(["sqlcmd", "sqlite3", "psql", "mysql"]);
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
  "--signed",
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
  return base.toLowerCase().replace(/\.exe$/i, "");
}

function stripLeadingPrefixes(tokens) {
  let idx = 0;
  while (idx < tokens.length) {
    const tok = tokens[idx];
    if (!tok.quoted && tok.text === "&") {
      idx++;
      continue;
    }
    if (!tok.quoted && /^[A-Za-z_][A-Za-z0-9_]*=/.test(tok.text)) {
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
        idx++;
      }
      continue;
    }
    break;
  }
  return tokens.slice(idx);
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

function checkGitPush(tokens) {
  let i = 1;
  while (i < tokens.length) {
    const t = tokens[i].text;
    if (t === "--") {
      i++;
      break;
    }
    if (GIT_GLOBAL_VALUE_FLAGS.has(t)) {
      i += 2;
      continue;
    }
    if (t.startsWith("-")) {
      i++;
      continue;
    }
    break;
  }

  if (i >= tokens.length || tokens[i].text.toLowerCase() !== "push") {
    return null;
  }

  i++;
  const positional = [];
  let endOfFlags = false;
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
    if (!endOfFlags && t.startsWith("-")) {
      i++;
      continue;
    }
    positional.push(t);
    i++;
  }

  if (positional.length === 0) {
    return null;
  }

  const refspecs = positional.length === 1 ? [positional[0]] : positional.slice(1);
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

function evaluateCommandLine(commandLine, depth = 0) {
  if (depth > 3) return null;
  const segments = splitSegments(commandLine);

  for (const segment of segments) {
    const rawTokens = tokenizeSegment(segment);
    const tokens = stripLeadingPrefixes(rawTokens);
    if (tokens.length === 0) continue;

    const exe = normalizeExeName(tokens[0].text);

    if (DIRECT_DB_CLIS.has(exe)) {
      return `[SDLC Guardrail] Direct database CLI execution ('${exe}') is blocked by DB-first policy.`;
    }

    if (exe === "git") {
      const reason = checkGitPush(tokens);
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
          const nestedReason = evaluateCommandLine(tokens[i + 1].text, depth + 1);
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

  const denyReason = evaluateCommandLine(commandLine);
  if (denyReason) {
    deny(denyReason);
    return;
  }

  allow();
}

main().catch(() => {
  allow();
});
