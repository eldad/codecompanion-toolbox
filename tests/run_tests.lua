-- tests/run_tests.lua
-- Plain nvim --headless test runner — no external dependencies.
-- Run with:  nvim --headless --noplugin -l tests/run_tests.lua
--
-- Exit codes: 0 = all passed, 1 = one or more failures.

package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

-- ---------------------------------------------------------------------------
-- Stub: codecompanion cmd_tool
-- The tool files only need cmd_tool to wrap a spec table; return the spec
-- as-is so build_cmd closures are directly accessible.
-- ---------------------------------------------------------------------------
package.preload["codecompanion.interactions.chat.tools.builtin.cmd_tool"] = function()
  return function(spec) return spec end
end

-- ---------------------------------------------------------------------------
-- Load modules under test
-- ---------------------------------------------------------------------------
local utils = require("codecompanion-toolbox.utils")
local build_cmd = utils.build_cmd
local git  = require("codecompanion-toolbox.git")
local java = require("codecompanion-toolbox.java")
local rust = require("codecompanion-toolbox.rust")

-- ---------------------------------------------------------------------------
-- Minimal test harness
-- ---------------------------------------------------------------------------
local passed = 0
local failed = 0

local function eq(got, expected, label)
  if got == expected then
    passed = passed + 1
    io.write(("  PASS  %s\n"):format(label))
  else
    failed = failed + 1
    io.write(("  FAIL  %s\n    expected: %s\n    got:      %s\n"):format(
      label, tostring(expected), tostring(got)))
  end
end

local function describe(name, fn)
  io.write(("\n%s\n"):format(name))
  fn()
end

-- ---------------------------------------------------------------------------
-- build_cmd (core helper)
-- ---------------------------------------------------------------------------
describe("build_cmd – core helper", function()
  local bc = build_cmd

  eq(bc("git status", {}),
     "git status",
     "no parts → base only")

  eq(bc("git log", { "--oneline" }),
     "git log --oneline",
     "one non-empty part")

  eq(bc("git log", { "--oneline", "-n 5" }),
     "git log --oneline -n 5",
     "two non-empty parts")

  eq(bc("git commit", { "", "-m 'fix'" }),
     "git commit -m 'fix'",
     "empty string part is skipped")

  eq(bc("git commit", { "  ", "\t", "-m 'fix'" }),
     "git commit -m 'fix'",
     "whitespace-only parts are skipped")

  eq(bc("git commit", { nil, "-m 'fix'" }),
     "git commit -m 'fix'",
     "nil part is skipped")

  eq(bc("cargo test", { "", "", "2>&1" }),
     "cargo test 2>&1",
     "multiple empty parts before a real suffix")

  eq(bc("base", { "a", "b", "c" }),
     "base a b c",
     "three parts joined with single spaces")
end)

-- ---------------------------------------------------------------------------
-- git tools
-- ---------------------------------------------------------------------------
describe("git_inspect", function()
  local bc = git.git_inspect.build_cmd

  eq(bc({ subcommand = "status", args = "" }),
     "git status",
     "status, no extra args")

  eq(bc({ subcommand = "log", args = "--oneline -n 10" }),
     "git log --oneline -n 10",
     "log with extra args")

  eq(bc({ subcommand = "INVALID", args = "" }),
     "git status",
     "unknown subcommand falls back to 'git status'")

  eq(bc({ subcommand = "branch --list", args = "" }),
     "git branch --list",
     "compound subcommand with no args")

  eq(bc({ subcommand = "diff", args = "HEAD~1" }),
     "git diff HEAD~1",
     "diff with a revision argument")
end)

describe("git_commit", function()
  local bc = git.git_commit.build_cmd

  -- shellescape wraps the message in single quotes on Linux
  eq(bc({ message = "init", files = "src/foo.lua", flags = "" }),
     "git commit src/foo.lua -m 'init'",
     "files, no flags")

  eq(bc({ message = "fix", files = "", flags = "--amend" }),
     "git commit --amend -m 'fix'",
     "flags, no files")

  eq(bc({ message = "wip", files = "a.lua b.lua", flags = "--no-verify" }),
     "git commit a.lua b.lua --no-verify -m 'wip'",
     "files and flags")

  eq(bc({ message = "bare", files = "", flags = "" }),
     "git commit -m 'bare'",
     "no files, no flags")
end)

describe("git_branch", function()
  local bc = git.git_branch.build_cmd

  eq(bc({ action = "create", name = "feature", flags = "" }),
     "git branch feature",
     "create, no flags")

  eq(bc({ action = "create", name = "feature", flags = "-t origin/main" }),
     "git branch -t origin/main feature",
     "create with tracking flag")

  eq(bc({ action = "delete", name = "old-branch", flags = "" }),
     "git branch -d old-branch",
     "delete, defaults to -d")

  eq(bc({ action = "delete", name = "old-branch", flags = "-D" }),
     "git branch -D old-branch",
     "delete with -D (force)")

  eq(bc({ action = "rename", name = "new-name", flags = "old-name" }),
     "git branch -m old-name new-name",
     "rename: flags carries old name")

  eq(bc({ action = "rename", name = "new-name", flags = "" }),
     "git branch -m new-name",
     "rename: no old name (flags empty)")
end)

describe("git_checkout", function()
  local bc = git.git_checkout.build_cmd

  eq(bc({ target = "main", flags = "" }),
     "git checkout main",
     "simple branch checkout")

  eq(bc({ target = "feature", flags = "-b" }),
     "git checkout -b feature",
     "create and checkout new branch")

  eq(bc({ target = "src/foo.lua", flags = "--" }),
     "git checkout -- src/foo.lua",
     "restore file")
end)

describe("git_pull", function()
  local bc = git.git_pull.build_cmd

  eq(bc({ args = "" }),
     "git pull",
     "default pull")

  eq(bc({ args = "origin main" }),
     "git pull origin main",
     "explicit remote and branch")

  eq(bc({ args = "--rebase" }),
     "git pull --rebase",
     "rebase flag")
end)

describe("git_push", function()
  local bc = git.git_push.build_cmd

  eq(bc({ args = "" }),
     "git push",
     "default push")

  eq(bc({ args = "origin main" }),
     "git push origin main",
     "explicit remote and branch")

  eq(bc({ args = "--force" }),
     "git push --force",
     "force push")
end)

-- ---------------------------------------------------------------------------
-- java / gradle tools
-- ---------------------------------------------------------------------------
describe("gradle_build", function()
  local bc = java.gradle_build.build_cmd

  eq(bc({ args = "" }),
     "./gradlew build",
     "default build")

  eq(bc({ args = "--info" }),
     "./gradlew build --info",
     "with --info flag")
end)

describe("gradle_build_no_check", function()
  local bc = java.gradle_build_no_check.build_cmd

  eq(bc({ args = "" }),
     "./gradlew build -x check",
     "default no-check build")

  eq(bc({ args = "-p sub" }),
     "./gradlew build -x check -p sub",
     "with subproject")
end)

describe("gradle_test", function()
  local bc = java.gradle_test.build_cmd

  eq(bc({ test_filter = "", args = "" }),
     "./gradlew test",
     "run all tests")

  eq(bc({ test_filter = "com.example.FooTest", args = "" }),
     "./gradlew test --tests 'com.example.FooTest'",
     "filtered to a single class")

  eq(bc({ test_filter = "com.example.FooTest", args = "--info" }),
     "./gradlew test --tests 'com.example.FooTest' --info",
     "filtered with extra args")

  eq(bc({ test_filter = "", args = "--stacktrace" }),
     "./gradlew test --stacktrace",
     "no filter, extra args only")
end)

describe("gradle_spotless_apply", function()
  local bc = java.gradle_spotless_apply.build_cmd
  eq(bc({ args = "" }),      "./gradlew spotlessApply",         "default")
  eq(bc({ args = "-p sub" }),"./gradlew spotlessApply -p sub",  "with subproject")
end)

describe("gradle_spotless_check", function()
  local bc = java.gradle_spotless_check.build_cmd
  eq(bc({ args = "" }),      "./gradlew spotlessCheck",         "default")
  eq(bc({ args = "-p sub" }),"./gradlew spotlessCheck -p sub",  "with subproject")
end)

describe("gradle_dependencies", function()
  local bc = java.gradle_dependencies.build_cmd
  eq(bc({ args = "" }),
     "./gradlew dependencies",
     "default")
  eq(bc({ args = "--configuration runtimeClasspath" }),
     "./gradlew dependencies --configuration runtimeClasspath",
     "scoped to a configuration")
end)

describe("gradle_clean", function()
  local bc = java.gradle_clean.build_cmd
  eq(bc({ args = "" }),      "./gradlew clean",         "default")
  eq(bc({ args = "-p sub" }),"./gradlew clean -p sub",  "with subproject")
end)

describe("gradle_run_task", function()
  local bc = java.gradle_run_task.build_cmd
  eq(bc({ task = "bootRun", args = "" }),
     "./gradlew bootRun",
     "custom task, no args")
  eq(bc({ task = "publish", args = "--info" }),
     "./gradlew publish --info",
     "custom task with args")
end)

-- ---------------------------------------------------------------------------
-- rust / cargo tools
-- ---------------------------------------------------------------------------
describe("cargo_clippy", function()
  local bc = rust.cargo_clippy.build_cmd
  eq(bc({ args = "" }),
     "cargo clippy 2>&1",
     "default clippy")
  eq(bc({ args = "-- -W clippy::pedantic" }),
     "cargo clippy -- -W clippy::pedantic 2>&1",
     "with lint flags")
end)

describe("cargo_clippy_fix", function()
  local bc = rust.cargo_clippy_fix.build_cmd
  eq(bc({ args = "" }),
     "cargo clippy --fix 2>&1",
     "default clippy fix")
  eq(bc({ args = "--allow-dirty" }),
     "cargo clippy --fix --allow-dirty 2>&1",
     "with --allow-dirty")
end)

describe("cargo_fmt", function()
  local bc = rust.cargo_fmt.build_cmd
  eq(bc({ args = "" }),       "cargo fmt 2>&1",         "default fmt")
  eq(bc({ args = "--check" }),"cargo fmt --check 2>&1", "dry-run check")
end)

describe("cargo_build", function()
  local bc = rust.cargo_build.build_cmd
  eq(bc({ args = "" }),             "cargo build 2>&1",                    "default build")
  eq(bc({ args = "-p my_crate" }),  "cargo build -p my_crate 2>&1",        "with package flag")
end)

describe("cargo_build_release", function()
  local bc = rust.cargo_build_release.build_cmd
  eq(bc({ args = "" }),
     "cargo build --release 2>&1",
     "default release build")
  eq(bc({ args = "--features async" }),
     "cargo build --release --features async 2>&1",
     "with feature flag")
end)

describe("cargo_update", function()
  local bc = rust.cargo_update.build_cmd
  eq(bc({ args = "" }),            "cargo update 2>&1",            "default update")
  eq(bc({ args = "-p serde" }),    "cargo update -p serde 2>&1",   "update single crate")
end)

describe("cargo_add", function()
  local bc = rust.cargo_add.build_cmd
  eq(bc({ crate = "serde", args = "" }),
     "cargo add serde 2>&1",
     "add crate, no extra args")
  eq(bc({ crate = "serde", args = "--features derive" }),
     "cargo add serde --features derive 2>&1",
     "add crate with features")
  eq(bc({ crate = "tokio", args = "--dev" }),
     "cargo add tokio --dev 2>&1",
     "add as dev dependency")
end)

describe("cargo_test", function()
  local bc = rust.cargo_test.build_cmd
  eq(bc({ filter = "", args = "" }),
     "cargo test 2>&1",
     "run all tests")
  eq(bc({ filter = "parser::tests", args = "" }),
     "cargo test parser::tests 2>&1",
     "filtered by module")
  eq(bc({ filter = "test_parse", args = "-- --nocapture" }),
     "cargo test test_parse -- --nocapture 2>&1",
     "filter with binary args")
  eq(bc({ filter = "", args = "-p my_crate" }),
     "cargo test -p my_crate 2>&1",
     "no filter, package flag only")
end)

describe("cargo_run", function()
  local bc = rust.cargo_run.build_cmd
  eq(bc({ args = "" }),            "cargo run 2>&1",               "default run")
  eq(bc({ args = "-- --help" }),   "cargo run -- --help 2>&1",     "forward args to binary")
end)

describe("cargo_check", function()
  local bc = rust.cargo_check.build_cmd
  eq(bc({ args = "" }),                    "cargo check 2>&1",                    "default check")
  eq(bc({ args = "--all-targets" }),        "cargo check --all-targets 2>&1",      "all targets")
end)

describe("cargo_doc", function()
  local bc = rust.cargo_doc.build_cmd
  eq(bc({ args = "" }),          "cargo doc 2>&1",           "default doc")
  eq(bc({ args = "--no-deps" }), "cargo doc --no-deps 2>&1", "skip dependency docs")
end)

-- ---------------------------------------------------------------------------
-- Summary
-- ---------------------------------------------------------------------------
local total = passed + failed
io.write(("\n%d/%d tests passed"):format(passed, total))
if failed > 0 then
  io.write(("  (%d FAILED)\n"):format(failed))
  os.exit(1)
else
  io.write(" – all green\n")
  os.exit(0)
end
