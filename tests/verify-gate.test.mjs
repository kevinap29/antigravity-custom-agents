import test from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import {
  detectDotnetProjects,
  detectNodeProjects,
  parseArgs,
} from "../plugins/antigravity-sdlc/scripts/verify-gate.mjs";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const VERIFY_GATE_SCRIPT = path.resolve(
  __dirname,
  "../plugins/antigravity-sdlc/scripts/verify-gate.mjs"
);

function withTempDir(fn) {
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "verify-gate-test-"));
  try {
    return fn(tmpDir);
  } finally {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  }
}

function writeFile(baseDir, relPath, content) {
  const fullPath = path.join(baseDir, relPath);
  fs.mkdirSync(path.dirname(fullPath), { recursive: true });
  fs.writeFileSync(fullPath, content, "utf8");
  return fullPath;
}

test("detectNodeProjects discovers monorepo package.json files and ignores excluded dirs", () => {
  withTempDir((tmpDir) => {
    writeFile(
      tmpDir,
      "package.json",
      JSON.stringify({ name: "root-app", scripts: { build: "echo build" } })
    );
    writeFile(
      tmpDir,
      "frontend/package.json",
      JSON.stringify({ name: "frontend-app", scripts: { check: "echo ok", test: "vitest" } })
    );
    writeFile(
      tmpDir,
      "apps/web/package.json",
      JSON.stringify({ name: "web-app", scripts: { test: "node --test" } })
    );
    // Should be skipped: no check/build/test scripts
    writeFile(
      tmpDir,
      "tools/package.json",
      JSON.stringify({ name: "tools-only", scripts: { lint: "echo lint" } })
    );
    // Should be skipped: ignored directories
    writeFile(
      tmpDir,
      "node_modules/pkg/package.json",
      JSON.stringify({ name: "dep-pkg", scripts: { test: "exit 1" } })
    );
    writeFile(
      tmpDir,
      "dist/package.json",
      JSON.stringify({ name: "dist-pkg", scripts: { test: "exit 1" } })
    );

    const projects = detectNodeProjects(tmpDir);
    const relDirs = projects.map((p) => p.relDir).sort();

    assert.deepEqual(relDirs, [".", "apps/web", "frontend"]);

    const frontend = projects.find((p) => p.relDir === "frontend");
    assert.ok(frontend);
    assert.equal(frontend.isVitest, true);
    assert.equal(frontend.scripts.check, "echo ok");

    const web = projects.find((p) => p.relDir === "apps/web");
    assert.ok(web);
    assert.equal(web.isVitest, false);
  });
});

test("CLI runs passing nested monorepo check script and exits 0 with [PASS] summary", () => {
  withTempDir((tmpDir) => {
    writeFile(
      tmpDir,
      "frontend/package.json",
      JSON.stringify({
        name: "nested-frontend",
        scripts: {
          check: "node -e \"console.log('check-ok')\"",
        },
      })
    );
    // Ignored dir should never execute
    writeFile(
      tmpDir,
      "node_modules/bad-pkg/package.json",
      JSON.stringify({
        name: "bad-pkg",
        scripts: {
          test: "node -e \"process.exit(1)\"",
        },
      })
    );

    const res = spawnSync(
      process.execPath,
      [VERIFY_GATE_SCRIPT, "--target-dir", tmpDir, "--skip-security"],
      { encoding: "utf8" }
    );

    assert.equal(res.status, 0, `Expected exit 0, got ${res.status}\nSTDOUT:\n${res.stdout}\nSTDERR:\n${res.stderr}`);
    assert.match(res.stdout, /========== VERIFY GATE SUMMARY ==========/);
    assert.match(res.stdout, /\[PASS\] npm run check \(frontend\)/);
  });
});

test("CLI exits 1 and reports [FAIL] when nested monorepo test script fails", () => {
  withTempDir((tmpDir) => {
    writeFile(
      tmpDir,
      "frontend/package.json",
      JSON.stringify({
        name: "failing-frontend",
        scripts: {
          test: "node -e \"process.exit(1)\"",
        },
      })
    );

    const res = spawnSync(
      process.execPath,
      [VERIFY_GATE_SCRIPT, "--target-dir", tmpDir, "--skip-security"],
      { encoding: "utf8" }
    );

    assert.equal(res.status, 1, `Expected exit 1, got ${res.status}\nSTDOUT:\n${res.stdout}\nSTDERR:\n${res.stderr}`);
    assert.match(res.stdout, /========== VERIFY GATE SUMMARY ==========/);
    assert.match(res.stdout, /\[FAIL\] npm test \(frontend\)/);
  });
});

test("detectDotnetProjects classifies Modern .NET, Multi-SLN, MAUI Windows TFM, Legacy v4.x, and empty dirs", () => {
  // 1. Empty directory
  withTempDir((tmpDir) => {
    const info = detectDotnetProjects(tmpDir);
    assert.equal(info.mode, "none");
    assert.equal(info.csprojFiles.length, 0);
    assert.equal(info.slnFiles.length, 0);
  });

  // 2. Modern .NET (single .sln + app + tests)
  withTempDir((tmpDir) => {
    writeFile(tmpDir, "App.sln", "");
    writeFile(
      tmpDir,
      "src/App/App.csproj",
      "<Project Sdk=\"Microsoft.NET.Sdk\"><PropertyGroup><TargetFramework>net9.0</TargetFramework></PropertyGroup></Project>"
    );
    writeFile(
      tmpDir,
      "tests/App.Tests/App.Tests.csproj",
      "<Project Sdk=\"Microsoft.NET.Sdk\"><PropertyGroup><TargetFramework>net9.0</TargetFramework></PropertyGroup></Project>"
    );

    const info = detectDotnetProjects(tmpDir);
    assert.equal(info.mode, "modern");
    assert.equal(info.slnFiles.length, 1);
    assert.equal(info.csprojFiles.length, 2);
    assert.equal(info.testProjects.length, 1);
  });

  // 3. Multi-SLN Modern .NET
  withTempDir((tmpDir) => {
    writeFile(tmpDir, "Api.sln", "");
    writeFile(tmpDir, "Worker.sln", "");
    writeFile(
      tmpDir,
      "src/Api/Api.csproj",
      "<Project Sdk=\"Microsoft.NET.Sdk.Web\"><PropertyGroup><TargetFramework>net9.0</TargetFramework></PropertyGroup></Project>"
    );

    const info = detectDotnetProjects(tmpDir);
    assert.equal(info.mode, "modern");
    assert.equal(info.slnFiles.length, 2);
  });

  // 4. .NET MAUI with Windows TFM + non-MAUI test project
  withTempDir((tmpDir) => {
    writeFile(
      tmpDir,
      "src/MobileApp/MobileApp.csproj",
      `<Project Sdk="Microsoft.NET.Sdk.Razor">
        <PropertyGroup>
          <TargetFrameworks>net9.0-android;net9.0-windows10.0.19041.0</TargetFrameworks>
          <UseMaui>true</UseMaui>
        </PropertyGroup>
      </Project>`
    );
    writeFile(
      tmpDir,
      "tests/MobileApp.Tests/MobileApp.Tests.csproj",
      "<Project Sdk=\"Microsoft.NET.Sdk\"><PropertyGroup><TargetFramework>net9.0</TargetFramework></PropertyGroup></Project>"
    );

    const info = detectDotnetProjects(tmpDir);
    assert.equal(info.mode, "maui");
    assert.equal(info.mauiProjects.length, 1);
    assert.equal(info.mauiProjects[0].windowsTfm, "net9.0-windows10.0.19041.0");
    assert.equal(info.nonMauiTestProjects.length, 1);
  });

  // 5. Legacy .NET Framework v4.x
  withTempDir((tmpDir) => {
    writeFile(tmpDir, "LegacyWeb.sln", "");
    writeFile(
      tmpDir,
      "LegacyWeb/LegacyWeb.csproj",
      `<Project ToolsVersion="15.0">
        <PropertyGroup>
          <TargetFrameworkVersion>v4.7.2</TargetFrameworkVersion>
        </PropertyGroup>
      </Project>`
    );

    const info = detectDotnetProjects(tmpDir);
    assert.equal(info.mode, "legacy");
    assert.equal(info.isLegacyFramework, true);
    assert.equal(info.slnFiles.length, 1);
  });
});

test("parseArgs parses --target-dir, positional dir, and --skip-security", () => {
  assert.deepEqual(parseArgs([]), { targetDir: ".", skipSecurity: false });
  assert.deepEqual(parseArgs(["--target-dir", "/repo", "--skip-security"]), {
    targetDir: "/repo",
    skipSecurity: true,
  });
  assert.deepEqual(parseArgs(["--target-dir=/repo2"]), {
    targetDir: "/repo2",
    skipSecurity: false,
  });
  assert.deepEqual(parseArgs(["./subdir", "--skip-security"]), {
    targetDir: "./subdir",
    skipSecurity: true,
  });
});
