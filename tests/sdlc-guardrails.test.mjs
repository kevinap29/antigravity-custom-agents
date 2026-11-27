import test from "node:test";
import assert from "node:assert/strict";
import path from "node:path";
import {
  evaluateCommandLine,
  extractCommand,
  extractCwd,
} from "../plugins/antigravity-sdlc/hooks/sdlc-guardrails.mjs";

const featureBranchResolver = () => "feature/login";
const mainBranchResolver = () => "main";

test("allows safe commands and dry-runs", () => {
  const safeCommands = [
    "git push origin feature/login",
    "git status",
    "git clean -n -fd",
    "git clean --dry-run -fdx",
    "git clean -nfd",
    "git clean -ndf",
    'rg "git push --force"',
    'echo "sqlcmd"',
  ];

  for (const cmd of safeCommands) {
    assert.equal(
      evaluateCommandLine(cmd, { branchResolver: featureBranchResolver }),
      null,
      `Expected safe command to be allowed: ${cmd}`
    );
  }
});

test("blocks all git push force-push variants", () => {
  const forcePushCommands = [
    "git push -f",
    "git push --force",
    "git push --force-with-lease",
    "git push --force-with-lease=main",
    "git push --force-if-includes",
    "git push -uf origin feature/x",
    "git push -fu origin feature/x",
    "git push -fv origin feature/x",
    "git push origin +feature/x",
    "git push origin +HEAD:feature/x",
    "git push +main",
    "git push --signed --force origin feat/x",
  ];

  for (const cmd of forcePushCommands) {
    const reason = evaluateCommandLine(cmd, { branchResolver: featureBranchResolver });
    assert.ok(reason, `Expected force-push command to be blocked: ${cmd}`);
    assert.match(reason, /\[SDLC Guardrail\]/);
  }
});

test("blocks direct pushes to protected branches", () => {
  const protectedCommands = [
    "git push origin main",
    "git push origin master",
    "git push origin HEAD:refs/heads/develop",
  ];

  for (const cmd of protectedCommands) {
    const reason = evaluateCommandLine(cmd, { branchResolver: featureBranchResolver });
    assert.ok(reason, `Expected protected branch push to be blocked: ${cmd}`);
    assert.match(reason, /protected branch/i);
  }
});

test("blocks implicit git push when on protected branch and allows on feature branch", () => {
  for (const cmd of ["git push", "git push origin"]) {
    const blocked = evaluateCommandLine(cmd, { branchResolver: mainBranchResolver });
    assert.ok(blocked, `Expected implicit push on main to be blocked: ${cmd}`);
    assert.match(blocked, /Implicit git push while on protected branch 'main'/);

    const allowed = evaluateCommandLine(cmd, { branchResolver: featureBranchResolver });
    assert.equal(allowed, null, `Expected implicit push on feature branch to be allowed: ${cmd}`);
  }
});

test("tracks directory changes and global git flags for implicit git push", () => {
  const baseCwd = path.resolve("workspace-root");
  const subrepoCwd = path.resolve(baseCwd, "subrepo");

  const calls = [];
  const spyResolver = (globalGitArgs, cwd) => {
    calls.push({ globalGitArgs, cwd });
    return "main";
  };

  const cdReason = evaluateCommandLine("cd subrepo && git push", {
    cwd: baseCwd,
    branchResolver: spyResolver,
  });
  assert.ok(cdReason);
  assert.deepEqual(calls[0], { globalGitArgs: [], cwd: subrepoCwd });

  const slReason = evaluateCommandLine("Set-Location subrepo; git push", {
    cwd: baseCwd,
    branchResolver: spyResolver,
  });
  assert.ok(slReason);
  assert.deepEqual(calls[1], { globalGitArgs: [], cwd: subrepoCwd });

  const gitDirReason = evaluateCommandLine("git --git-dir=/custom/.git push", {
    cwd: baseCwd,
    branchResolver: spyResolver,
  });
  assert.ok(gitDirReason);
  assert.deepEqual(calls[2], { globalGitArgs: ["--git-dir=/custom/.git"], cwd: baseCwd });

  const gitCReason = evaluateCommandLine("git -C ../other push", {
    cwd: baseCwd,
    branchResolver: spyResolver,
  });
  assert.ok(gitCReason);
  assert.deepEqual(calls[3], { globalGitArgs: ["-C", "../other"], cwd: baseCwd });
});

test("preserves GIT_DIR and GIT_WORK_TREE env overrides for implicit git push", () => {
  const baseCwd = path.resolve("workspace-root");
  const calls = [];
  const envSpyResolver = (globalGitArgs, cwd, envOverrides) => {
    calls.push({ globalGitArgs, cwd, envOverrides });
    return "main";
  };

  const bareEnvReason = evaluateCommandLine("GIT_DIR=/other/.git git push", {
    cwd: baseCwd,
    branchResolver: envSpyResolver,
  });
  assert.ok(bareEnvReason);
  assert.match(bareEnvReason, /Implicit git push while on protected branch 'main'/);
  assert.deepEqual(calls[0], {
    globalGitArgs: [],
    cwd: baseCwd,
    envOverrides: { GIT_DIR: "/other/.git" },
  });

  const wrapperEnvReason = evaluateCommandLine(
    "env GIT_DIR=/other/.git GIT_WORK_TREE=/other git push",
    {
      cwd: baseCwd,
      branchResolver: envSpyResolver,
    }
  );
  assert.ok(wrapperEnvReason);
  assert.match(wrapperEnvReason, /Implicit git push while on protected branch 'main'/);
  assert.deepEqual(calls[1], {
    globalGitArgs: [],
    cwd: baseCwd,
    envOverrides: { GIT_DIR: "/other/.git", GIT_WORK_TREE: "/other" },
  });
});

test("blocks destructive git reset and git clean variants", () => {
  const destructiveCommands = [
    "git reset --hard",
    "git clean -fd",
    "git clean -fdx",
    "git clean -fx",
    "git clean -fX",
    "git clean --force -d",
    "git clean -enode -fd",
  ];

  for (const cmd of destructiveCommands) {
    const reason = evaluateCommandLine(cmd);
    assert.ok(reason, `Expected destructive git command to be blocked: ${cmd}`);
    assert.match(reason, /\[SDLC Guardrail\]/);
  }
});

test("blocks direct database CLIs including nested shell invocations", () => {
  const dbCommands = [
    "sqlcmd -S localhost -Q 'SELECT 1'",
    "Invoke-Sqlcmd -Query 'SELECT 1'",
    "sqlcmd.exe -S localhost",
    "sqlite3 app.db 'SELECT 1;'",
    "psql -U postgres -d app",
    "mysql -u root -p",
    "sqlpackage /Action:Publish",
    'pwsh -Command "Invoke-Sqlcmd -Query \'SELECT 1\'"',
  ];

  for (const cmd of dbCommands) {
    const reason = evaluateCommandLine(cmd);
    assert.ok(reason, `Expected DB CLI command to be blocked: ${cmd}`);
    assert.match(reason, /DB-first policy/i);
  }
});

test("blocks EF Core Code-First commands", () => {
  const efCommands = [
    "dotnet ef migrations add Init",
    "dotnet ef database update",
    "dotnet ef migrations add Init --project src/App.csproj",
  ];

  for (const cmd of efCommands) {
    const reason = evaluateCommandLine(cmd);
    assert.ok(reason, `Expected EF Core Code-First command to be blocked: ${cmd}`);
    assert.match(reason, /DB-first policy/i);
  }
});

test("extractCommand and extractCwd handle standard hook payload shapes", () => {
  assert.equal(extractCommand({ tool_input: { CommandLine: "git status" } }), "git status");
  assert.equal(extractCommand({ tool_info: { command_line: "git push" } }), "git push");
  assert.equal(extractCommand({}), null);

  assert.equal(extractCwd({ cwd: "/repo" }), "/repo");
  assert.equal(extractCwd({ working_directory: "/repo2" }), "/repo2");
  assert.equal(extractCwd({ tool_input: { cwd: "/repo3" } }), "/repo3");
  assert.equal(extractCwd({ tool_info: { cwd: "/repo4" } }), "/repo4");
  assert.equal(extractCwd({}), undefined);
});

test("blocks destructive git checkout and git restore worktree discards", () => {
  const blockedCommands = [
    "git checkout -- .",
    "git checkout .",
    "git checkout -- ./",
    "git checkout -- :/",
    "git checkout HEAD -- .",
    "git restore .",
    "git restore -- .",
    "git restore -- :/",
    "git restore --worktree .",
    "git restore -W .",
    "git restore --staged --worktree .",
    "git restore -SW .",
    'bash -c "git checkout -- ."',
    'pwsh -Command "git restore ."',
    "rtk git checkout -- .",
  ];

  for (const cmd of blockedCommands) {
    const reason = evaluateCommandLine(cmd, { branchResolver: featureBranchResolver });
    assert.ok(reason, `Expected destructive checkout/restore to be blocked: ${cmd}`);
    assert.match(reason, /\[SDLC Guardrail\]/);
  }
});

test("allows safe git checkout and git restore operations", () => {
  const allowedCommands = [
    "git checkout -b feat/x",
    "git checkout main",
    "git checkout -- path/to/file.cs",
    "git checkout HEAD -- src/App.svelte",
    "git restore --staged .",
    "git restore -S .",
    "git restore --staged file.txt",
    "git restore file.txt",
    "git restore --worktree src/index.ts",
    'echo "git checkout -- ."',
  ];

  for (const cmd of allowedCommands) {
    assert.equal(
      evaluateCommandLine(cmd, { branchResolver: featureBranchResolver }),
      null,
      `Expected safe checkout/restore to be allowed: ${cmd}`
    );
  }
});

test("blocks force-deleting protected branches and git stash clear, allows feature branch deletes", () => {
  const blockedCommands = [
    "git branch -D main",
    "git branch -D master",
    "git branch -D develop",
    "git branch -d -f main",
    "git branch -df master",
    "git branch --delete --force develop",
    "git branch -D feat/x main",
    "git stash clear",
    "rtk git stash clear",
    'sh -c "git branch -D main"',
    'pwsh -Command "git stash clear"',
  ];

  for (const cmd of blockedCommands) {
    const reason = evaluateCommandLine(cmd, { branchResolver: featureBranchResolver });
    assert.ok(reason, `Expected destructive branch/stash command to be blocked: ${cmd}`);
    assert.match(reason, /\[SDLC Guardrail\]/);
  }

  const allowedCommands = [
    "git branch -d feature/x",
    "git branch -D feature/x",
    "git branch -a",
    "git stash",
    "git stash push -m 'wip'",
    "git stash pop",
    "git stash list",
  ];

  for (const cmd of allowedCommands) {
    assert.equal(
      evaluateCommandLine(cmd, { branchResolver: featureBranchResolver }),
      null,
      `Expected safe branch/stash command to be allowed: ${cmd}`
    );
  }
});

test("blocks destructive rm -rf and PowerShell recursive force wipes on dangerous paths", () => {
  const blockedCommands = [
    "rm -rf .",
    "rm -fr ..",
    "rm -r -f ./",
    "rm --recursive --force /",
    "rm -rf ~",
    "rm -rf ~/",
    "rm -rf *",
    "rm -rf /*",
    "rm -rf ./*",
    "rm -rf C:\\",
    "rm -rf C:/",
    "rm -rf D:\\",
    "sudo rm -rf /",
    'bash -c "rm -rf ."',
    "Remove-Item -Recurse -Force .",
    "Remove-Item -r -f ..",
    "Remove-Item -rec -fo ./",
    "ri -Recurse -Force .\\",
    "del -Recurse -Force *",
    "erase -Recurse -Force /*",
    "rd -Recurse -Force C:\\",
    "rmdir -Recurse -Force ~",
    "Remove-Item -Path . -Recurse -Force",
    "Remove-Item -Path:. -Recurse -Force",
    "Remove-Item -LiteralPath C:/ -Recurse -Force",
    "Remove-Item -LiteralPath:C:/ -Recurse -Force",
    "rm -Recurse -Force .",
    "rm -Recurse -Force C:\\",
    "Remove-Item -Recurse -Force bin,.",
    'pwsh -Command "Remove-Item -Recurse -Force ."',
  ];

  for (const cmd of blockedCommands) {
    const reason = evaluateCommandLine(cmd, { branchResolver: featureBranchResolver });
    assert.ok(reason, `Expected destructive wipe to be blocked: ${cmd}`);
    assert.match(reason, /\[SDLC Guardrail\]/);
  }
});

test("allows targeted rm -rf and PowerShell Remove-Item build artifact cleanups", () => {
  const allowedCommands = [
    "rm -rf bin obj dist .svelte-kit node_modules",
    "rm -rf ./dist",
    "rm -rf build/output",
    "rm -Recurse -Force bin",
    "rm -r .", // not forced
    "Remove-Item -Recurse -Force bin,obj",
    "Remove-Item -Recurse -Force ./dist",
    "Remove-Item -Recurse -Force ./dist -Include *",
    "Remove-Item -Path .svelte-kit -Recurse -Force",
    "ri -Recurse -Force node_modules",
    "Remove-Item -Recurse .", // not forced
    'echo "rm -rf /"',
  ];

  for (const cmd of allowedCommands) {
    assert.equal(
      evaluateCommandLine(cmd, { branchResolver: featureBranchResolver }),
      null,
      `Expected safe targeted cleanup to be allowed: ${cmd}`
    );
  }
});

test("blocks autonomous git commit by default and allows with allowGitCommit option or SDLC_ALLOW_GIT_COMMIT=1", () => {
  const prevEnv = process.env.SDLC_ALLOW_GIT_COMMIT;
  delete process.env.SDLC_ALLOW_GIT_COMMIT;

  try {
    const blocked = evaluateCommandLine('git commit -m "test"');
    assert.ok(blocked, "Expected git commit to be blocked by default");
    assert.equal(
      blocked,
      "[SDLC Guardrail] Autonomous 'git commit' is blocked. Require explicit user confirmation (or set SDLC_ALLOW_GIT_COMMIT=1 for intentional manual override)."
    );

    const nestedBlocked = evaluateCommandLine('pwsh -Command "git commit -m test"');
    assert.ok(nestedBlocked, "Expected nested git commit to be blocked by default");

    assert.equal(
      evaluateCommandLine('git commit -m "test"', { allowGitCommit: true }),
      null,
      "Expected git commit to be allowed with options.allowGitCommit = true"
    );

    assert.equal(
      evaluateCommandLine('bash -c "git commit -m test"', { allowGitCommit: true }),
      null,
      "Expected nested git commit to be allowed when options.allowGitCommit = true"
    );

    process.env.SDLC_ALLOW_GIT_COMMIT = "1";
    assert.equal(
      evaluateCommandLine('git commit -m "test"'),
      null,
      "Expected git commit to be allowed when SDLC_ALLOW_GIT_COMMIT=1"
    );
  } finally {
    if (prevEnv === undefined) {
      delete process.env.SDLC_ALLOW_GIT_COMMIT;
    } else {
      process.env.SDLC_ALLOW_GIT_COMMIT = prevEnv;
    }
  }
});

test("fails closed when command nesting depth exceeds 3", () => {
  const directDepth4 = evaluateCommandLine("git status", {}, 4);
  assert.equal(
    directDepth4,
    "[SDLC Guardrail] Command nesting depth exceeded (> 3); blocked to prevent guardrail bypass."
  );

  const nestedSubDepth = evaluateCommandLine("echo $(echo $(echo $(echo $(git status))))");
  assert.equal(
    nestedSubDepth,
    "[SDLC Guardrail] Command nesting depth exceeded (> 3); blocked to prevent guardrail bypass."
  );

  // Depth 3 should still be evaluated normally and allowed if safe
  assert.equal(evaluateCommandLine("git status", {}, 3), null);
});

test("inspects PowerShell -EncodedCommand / -enc / -ec / -e payloads and fails closed on invalid base64", () => {
  const encodePs = (cmd) => Buffer.from(cmd, "utf16le").toString("base64");

  const resetPayload = encodePs("git reset --hard");
  const statusPayload = encodePs("git status");

  const blockedFull = evaluateCommandLine(`pwsh -EncodedCommand ${resetPayload}`);
  assert.ok(blockedFull, "Expected encoded git reset --hard to be blocked");
  assert.match(blockedFull, /git reset --hard/);

  const blockedShort = evaluateCommandLine(`powershell -ec ${resetPayload}`);
  assert.ok(blockedShort, "Expected powershell -ec git reset --hard to be blocked");
  assert.match(blockedShort, /git reset --hard/);

  for (const prefixFlag of ["-en", "-enco", "-encod", "-encode", "-encoded"]) {
    const blockedPrefix = evaluateCommandLine(`pwsh ${prefixFlag} ${resetPayload}`);
    assert.ok(blockedPrefix, `Expected pwsh ${prefixFlag} git reset --hard to be blocked`);
    assert.match(blockedPrefix, /git reset --hard/);
  }

  // bash -e (errexit) must not be treated as PowerShell -EncodedCommand
  assert.equal(evaluateCommandLine('bash -e -c "git status"'), null);

  const blockedE = evaluateCommandLine(`pwsh -e ${encodePs("sqlite3 app.db")}`);
  assert.ok(blockedE, "Expected pwsh -e sqlite3 to be blocked");
  assert.match(blockedE, /DB-first policy/i);

  assert.equal(
    evaluateCommandLine(`pwsh -enc ${statusPayload}`),
    null,
    "Expected pwsh -enc 'git status' to be allowed"
  );

  const malformedCases = [
    "pwsh -EncodedCommand not-valid-base64!!!",
    "pwsh -enc abc",
    "pwsh -ec ====",
    "pwsh -e YQ==",
    "pwsh -EncodedCommand",
  ];

  for (const cmd of malformedCases) {
    const reason = evaluateCommandLine(cmd);
    assert.equal(
      reason,
      "[SDLC Guardrail] Unreadable PowerShell -EncodedCommand payload is blocked.",
      `Expected malformed encoded command to fail closed: ${cmd}`
    );
  }
});

test("inspects command substitutions $() and backticks while respecting single quotes and normal variables", () => {
  const blockedCommands = [
    "echo $(sqlite3 app.db)",
    'echo "$(git reset --hard)"',
    "echo `git commit -m x`",
    'echo "`sqlite3 app.db`"',
    "echo $(echo $(git reset --hard))",
    "X=$(sqlite3)",
    "X=`psql`",
    "echo $(git status; git reset --hard)",
    "echo `git status && git commit -m x`",
    'echo "$(git status || sqlite3 app.db)"',
  ];

  for (const cmd of blockedCommands) {
    const reason = evaluateCommandLine(cmd, { branchResolver: featureBranchResolver });
    assert.ok(reason, `Expected command substitution to be blocked: ${cmd}`);
    assert.match(reason, /\[SDLC Guardrail\]/);
  }

  const allowedCommands = [
    "echo '$(sqlite3 app.db)'",
    "echo '`git reset --hard`'",
    'echo "hello"',
    "echo $env:PATH",
    "echo $foo",
    "echo $(git status)",
  ];

  for (const cmd of allowedCommands) {
    assert.equal(
      evaluateCommandLine(cmd, { branchResolver: featureBranchResolver }),
      null,
      `Expected safe command to be allowed: ${cmd}`
    );
  }
});
