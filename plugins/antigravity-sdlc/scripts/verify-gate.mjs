#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";

const IGNORED_DIRS = new Set([
  ".git",
  "node_modules",
  "bin",
  "obj",
  ".svelte-kit",
  "dist",
  "build",
  "packages",
  ".vs",
  ".idea",
  "TestResults",
]);

/**
 * Recursively finds files under `rootDir` up to `maxDepth` (0 = direct children of rootDir)
 * matching `predicate(filePath, entryName)`, skipping ignored directories.
 */
function findFilesByPredicate(rootDir, predicate, maxDepth = 3, ignoredDirs = IGNORED_DIRS) {
  const results = [];
  const ignoredLower = new Set(Array.from(ignoredDirs, (d) => d.toLowerCase()));

  function walk(currentDir, depth) {
    let entries;
    try {
      entries = fs.readdirSync(currentDir, { withFileTypes: true });
    } catch {
      return;
    }

    entries.sort((a, b) => a.name.localeCompare(b.name));

    for (const entry of entries) {
      const fullPath = path.join(currentDir, entry.name);
      if (entry.isDirectory()) {
        if (ignoredLower.has(entry.name.toLowerCase())) {
          continue;
        }
        if (depth < maxDepth) {
          walk(fullPath, depth + 1);
        }
      } else if (entry.isFile()) {
        if (predicate(fullPath, entry.name)) {
          results.push(fullPath);
        }
      }
    }
  }

  walk(path.resolve(rootDir), 0);
  return results;
}

/**
 * Detects .NET projects (.csproj depth <= 3, .sln depth <= 2) and classifies them
 * into legacy (.NET Framework v4.x), maui (.NET MAUI with Windows TFM), modern, or none.
 */
function detectDotnetProjects(targetDir) {
  const resolvedDir = path.resolve(targetDir);
  const csprojFiles = findFilesByPredicate(
    resolvedDir,
    (_fullPath, name) => name.toLowerCase().endsWith(".csproj"),
    3
  );
  const slnFiles = findFilesByPredicate(
    resolvedDir,
    (_fullPath, name) => name.toLowerCase().endsWith(".sln"),
    2
  );

  let isLegacyFramework = false;
  const mauiProjects = [];
  const mauiPathSet = new Set();

  for (const projPath of csprojFiles) {
    let raw = "";
    try {
      raw = fs.readFileSync(projPath, "utf8");
    } catch {
      continue;
    }

    if (/<TargetFrameworkVersion>v4\./i.test(raw)) {
      isLegacyFramework = true;
    }

    if (/<UseMaui>\s*true\s*<\/UseMaui>/i.test(raw)) {
      const tfmMatch = raw.match(/(net\d+\.\d+-windows[\d.]+)/i);
      const windowsTfm = tfmMatch ? tfmMatch[1] : null;
      mauiProjects.push({
        path: projPath,
        name: path.basename(projPath),
        windowsTfm,
      });
      mauiPathSet.add(projPath.toLowerCase());
    }
  }

  const testProjects = csprojFiles.filter((p) => /test/i.test(path.basename(p)));
  const nonMauiTestProjects = testProjects.filter((p) => !mauiPathSet.has(p.toLowerCase()));

  let mode = "none";
  if (csprojFiles.length > 0 || slnFiles.length > 0) {
    if (isLegacyFramework) {
      mode = "legacy";
    } else if (mauiProjects.some((p) => Boolean(p.windowsTfm))) {
      mode = "maui";
    } else {
      mode = "modern";
    }
  }

  return {
    mode,
    csprojFiles,
    slnFiles,
    isLegacyFramework,
    mauiProjects,
    testProjects,
    nonMauiTestProjects,
  };
}

/**
 * Monorepo-aware Node / SvelteKit detector: scans `package.json` up to depth <= 2
 * (excluding ignored directories) and returns only projects defining at least one
 * of `scripts.check`, `scripts.build`, or `scripts.test`.
 */
function detectNodeProjects(targetDir) {
  const resolvedDir = path.resolve(targetDir);
  const pkgFiles = findFilesByPredicate(
    resolvedDir,
    (_fullPath, name) => name === "package.json",
    2
  );

  const projects = [];
  for (const pkgPath of pkgFiles) {
    let pkg;
    try {
      pkg = JSON.parse(fs.readFileSync(pkgPath, "utf8"));
    } catch {
      continue;
    }

    const scripts = pkg && typeof pkg.scripts === "object" && pkg.scripts !== null ? pkg.scripts : {};
    const checkScript = typeof scripts.check === "string" && scripts.check.trim() ? scripts.check : null;
    const buildScript = typeof scripts.build === "string" && scripts.build.trim() ? scripts.build : null;
    const testScript = typeof scripts.test === "string" && scripts.test.trim() ? scripts.test : null;

    if (!checkScript && !buildScript && !testScript) {
      continue;
    }

    const dir = path.dirname(pkgPath);
    const relRaw = path.relative(resolvedDir, dir);
    const relDir = relRaw ? relRaw.split(path.sep).join("/") : ".";

    projects.push({
      packageJsonPath: pkgPath,
      dir,
      relDir,
      name: typeof pkg.name === "string" && pkg.name.trim() ? pkg.name.trim() : relDir,
      scripts: {
        check: checkScript,
        build: buildScript,
        test: testScript,
      },
      isVitest: Boolean(testScript && /\bvitest\b/.test(testScript)),
    });
  }

  return projects;
}

function isCommandAvailable(cmd) {
  const locator = process.platform === "win32" ? "where" : "which";
  const result = spawnSync(locator, [cmd], {
    stdio: "ignore",
    shell: false,
  });
  return result.status === 0;
}

function findMsBuild() {
  if (isCommandAvailable("msbuild")) {
    return "msbuild";
  }

  if (process.platform === "win32") {
    const programFilesX86 = process.env["ProgramFiles(x86)"] || "C:\\Program Files (x86)";
    const vswhere = path.join(
      programFilesX86,
      "Microsoft Visual Studio",
      "Installer",
      "vswhere.exe"
    );
    if (fs.existsSync(vswhere)) {
      const res = spawnSync(
        vswhere,
        [
          "-latest",
          "-requires",
          "Microsoft.Component.MSBuild",
          "-find",
          "MSBuild\\**\\Bin\\MSBuild.exe",
        ],
        { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"], shell: false }
      );
      if (res.status === 0 && res.stdout) {
        const first = res.stdout
          .split(/\r?\n/)
          .map((line) => line.trim())
          .find((line) => line.length > 0 && fs.existsSync(line));
        if (first) {
          return first;
        }
      }
    }
  }

  return null;
}

function parseArgs(argv) {
  let targetDir = ".";
  let skipSecurity = false;
  let positionalUsed = false;

  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--skip-security") {
      skipSecurity = true;
      continue;
    }
    if (arg === "--target-dir") {
      if (i + 1 < argv.length) {
        targetDir = argv[++i];
      }
      continue;
    }
    if (arg.startsWith("--target-dir=")) {
      targetDir = arg.slice("--target-dir=".length);
      continue;
    }
    if (!arg.startsWith("-") && !positionalUsed) {
      targetDir = arg;
      positionalUsed = true;
    }
  }

  return { targetDir, skipSecurity };
}

function runVerifyGate(options = {}) {
  const targetDir = options.targetDir || ".";
  const skipSecurity = Boolean(options.skipSecurity);
  const resolvedDir = path.resolve(targetDir);

  if (!fs.existsSync(resolvedDir) || !fs.statSync(resolvedDir).isDirectory()) {
    console.error(`[FAIL] Target directory does not exist or is not a directory: ${resolvedDir}`);
    return { failed: true, exitCode: 1, summary: [`[FAIL] Invalid target directory: ${resolvedDir}`] };
  }

  let failed = false;
  const summary = [];

  function runStep(name, command, args, cwd, extraOpts = {}) {
    console.log(`\n[GATE] Running: ${name} ...`);
    const result = spawnSync(command, args, {
      cwd,
      stdio: "inherit",
      shell: false,
      ...extraOpts,
    });

    if (result.error) {
      console.error(`[FAIL] ${name} : ${result.error.message}`);
      failed = true;
      summary.push(`[FAIL] ${name}`);
      return false;
    }

    if (result.status !== 0) {
      console.error(`[FAIL] ${name} (exit code ${result.status ?? "unknown"})`);
      failed = true;
      summary.push(`[FAIL] ${name}`);
      return false;
    }

    console.log(`[PASS] ${name}`);
    summary.push(`[PASS] ${name}`);
    return true;
  }

  // 1. .NET Detection (Legacy .NET Framework, .NET MAUI, Modern .NET)
  const dotnetInfo = detectDotnetProjects(resolvedDir);
  if (dotnetInfo.mode === "legacy") {
    const msbuildPath = findMsBuild();
    if (msbuildPath) {
      const target = dotnetInfo.slnFiles[0] || dotnetInfo.csprojFiles[0];
      runStep("MSBuild (.NET Framework)", msbuildPath, [target, "/nologo", "/v:minimal"], resolvedDir);
    } else {
      summary.push(
        "[SKIP] MSBuild (.NET Framework detected, MSBuild unavailable in environment - rely on static verification)"
      );
    }
  } else if (dotnetInfo.mode === "maui") {
    if (isCommandAvailable("dotnet")) {
      for (const mp of dotnetInfo.mauiProjects) {
        if (!mp.windowsTfm) continue;
        runStep(
          `.NET MAUI Build (${mp.name} / ${mp.windowsTfm})`,
          "dotnet",
          ["build", mp.path, "-f", mp.windowsTfm, "--nologo", "--verbosity", "minimal"],
          resolvedDir
        );
      }
      for (const tp of dotnetInfo.nonMauiTestProjects) {
        runStep(
          `.NET Test (${path.basename(tp)})`,
          "dotnet",
          ["test", tp, "--nologo", "--verbosity", "minimal"],
          resolvedDir
        );
      }
    } else {
      summary.push("[SKIP] .NET MAUI (dotnet SDK not installed)");
    }
  } else if (dotnetInfo.mode === "modern") {
    if (isCommandAvailable("dotnet")) {
      if (dotnetInfo.slnFiles.length === 1) {
        const sln = dotnetInfo.slnFiles[0];
        const built = runStep(
          `.NET Build (${path.basename(sln)})`,
          "dotnet",
          ["build", sln, "--nologo", "--verbosity", "minimal"],
          resolvedDir
        );
        if (built && dotnetInfo.testProjects.length > 0) {
          runStep(
            `.NET Test (${path.basename(sln)})`,
            "dotnet",
            ["test", sln, "--no-build", "--nologo", "--verbosity", "minimal"],
            resolvedDir
          );
        }
      } else if (dotnetInfo.slnFiles.length > 1) {
        for (const sln of dotnetInfo.slnFiles) {
          const slnName = path.basename(sln);
          const built = runStep(
            `.NET Build (${slnName})`,
            "dotnet",
            ["build", sln, "--nologo", "--verbosity", "minimal"],
            resolvedDir
          );
          if (built && dotnetInfo.testProjects.length > 0) {
            runStep(
              `.NET Test (${slnName})`,
              "dotnet",
              ["test", sln, "--no-build", "--nologo", "--verbosity", "minimal"],
              resolvedDir
            );
          }
        }
      } else {
        let allBuilt = true;
        for (const proj of dotnetInfo.csprojFiles) {
          const ok = runStep(
            `.NET Build (${path.basename(proj)})`,
            "dotnet",
            ["build", proj, "--nologo", "--verbosity", "minimal"],
            resolvedDir
          );
          if (!ok) allBuilt = false;
        }
        if (allBuilt) {
          for (const tp of dotnetInfo.testProjects) {
            runStep(
              `.NET Test (${path.basename(tp)})`,
              "dotnet",
              ["test", tp, "--no-build", "--nologo", "--verbosity", "minimal"],
              resolvedDir
            );
          }
        }
      }
    } else {
      summary.push("[SKIP] .NET (dotnet SDK not installed)");
    }
  }

  // 2. Node / SvelteKit Detection (Monorepo-aware)
  const nodeProjects = detectNodeProjects(resolvedDir);
  if (nodeProjects.length > 0) {
    const isWin = process.platform === "win32";
    const npmCmd = isWin ? "npm.cmd" : "npm";
    if (isCommandAvailable("npm")) {
      const npmOpts = { shell: isWin };
      for (const proj of nodeProjects) {
        const suffix = proj.relDir === "." ? "" : ` (${proj.relDir})`;
        if (proj.scripts.check) {
          runStep(`npm run check${suffix}`, npmCmd, ["run", "check"], proj.dir, npmOpts);
        }
        if (proj.scripts.build) {
          runStep(`npm run build${suffix}`, npmCmd, ["run", "build"], proj.dir, npmOpts);
        }
        if (proj.scripts.test) {
          if (proj.isVitest) {
            runStep(`npm test (vitest)${suffix}`, npmCmd, ["test", "--", "--run"], proj.dir, npmOpts);
          } else {
            runStep(`npm test${suffix}`, npmCmd, ["test"], proj.dir, npmOpts);
          }
        }
      }
    } else {
      summary.push("[SKIP] Node/npm (npm not installed)");
    }
  }

  // 3. Python Detection
  const hasPythonProject =
    fs.existsSync(path.join(resolvedDir, "pyproject.toml")) ||
    fs.existsSync(path.join(resolvedDir, "requirements.txt"));
  if (hasPythonProject) {
    if (isCommandAvailable("pytest")) {
      runStep("pytest", "pytest", ["-q"], resolvedDir);
    } else {
      summary.push("[SKIP] pytest (not installed)");
    }
  }

  // 4. Static Security Scanners (unless --skip-security)
  if (!skipSecurity) {
    if (isCommandAvailable("gitleaks")) {
      runStep("Gitleaks (Secrets Scan)", "gitleaks", ["detect", "--source", ".", "--no-git", "--redact"], resolvedDir);
    } else {
      summary.push("[SKIP] Gitleaks (not installed)");
    }

    if (isCommandAvailable("semgrep")) {
      runStep("Semgrep (SAST Scan)", "semgrep", ["scan", "--config", "auto", "--error", "--quiet"], resolvedDir);
    } else {
      summary.push("[SKIP] Semgrep (not installed)");
    }

    if (isCommandAvailable("trivy")) {
      runStep(
        "Trivy (Dependency Scan)",
        "trivy",
        ["fs", "--severity", "HIGH,CRITICAL", "--exit-code", "1", "--quiet", "."],
        resolvedDir
      );
    } else {
      summary.push("[SKIP] Trivy (not installed)");
    }
  }

  console.log("\n========== VERIFY GATE SUMMARY ==========");
  for (const line of summary) {
    console.log(line);
  }
  console.log("=========================================");

  return { failed, exitCode: failed ? 1 : 0, summary };
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  const result = runVerifyGate(args);
  process.exit(result.exitCode);
}

export {
  IGNORED_DIRS,
  findFilesByPredicate,
  detectDotnetProjects,
  detectNodeProjects,
  parseArgs,
  runVerifyGate,
};

const isDirectRun =
  typeof process.argv[1] === "string" &&
  import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href;

if (isDirectRun) {
  main();
}
