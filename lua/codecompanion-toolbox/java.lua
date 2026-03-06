---@module "codecompanion.interactions.chat.tools.builtin.cmd_tool"
local cmd_tool = require("codecompanion.interactions.chat.tools.builtin.cmd_tool")

local M = {}

M.gradle_build = cmd_tool({
  name = "gradle_build",
  description = table.concat({
    "Run `./gradlew build` to compile, test, and assemble the Java/Kotlin project.",
    "This executes the full build lifecycle including all checks.",
  }, " "),
  schema = {
    properties = {
      args = {
        type = "string",
        description = "Optional extra arguments (e.g. '--info', '--stacktrace', '-p <subproject>'). Empty string for default build.",
      },
    },
    required = { "args" },
  },
  build_cmd = function(args)
    local extra = vim.trim(args.args or "")
    if extra ~= "" then
      return "./gradlew build " .. extra
    end
    return "./gradlew build"
  end,
})

M.gradle_build_no_check = cmd_tool({
  name = "gradle_build_no_check",
  description = table.concat({
    "Run `./gradlew build -x check` to compile and assemble the project while skipping all verification tasks.",
    "Use this for a faster build when you only need compilation without running tests or other checks.",
  }, " "),
  schema = {
    properties = {
      args = {
        type = "string",
        description = "Optional extra arguments (e.g. '--info', '-p <subproject>'). Empty string for defaults.",
      },
    },
    required = { "args" },
  },
  build_cmd = function(args)
    local extra = vim.trim(args.args or "")
    if extra ~= "" then
      return "./gradlew build -x check " .. extra
    end
    return "./gradlew build -x check"
  end,
})

M.gradle_test = cmd_tool({
  name = "gradle_test",
  description = table.concat({
    "Run `./gradlew test` to execute tests in the Java/Kotlin project.",
    "Optionally target a specific test class or method using the '--tests' filter.",
    "Examples: '--tests com.example.MyTest' or '--tests com.example.MyTest.myMethod'.",
  }, " "),
  schema = {
    properties = {
      test_filter = {
        type = "string",
        description = "Optional test filter (e.g. 'com.example.MyTest', 'com.example.MyTest.myMethod'). Empty string to run all tests.",
      },
      args = {
        type = "string",
        description = "Optional extra arguments (e.g. '--info', '--stacktrace', '-p <subproject>'). Empty string for defaults.",
      },
    },
    required = { "test_filter", "args" },
  },
  build_cmd = function(args)
    local filter = vim.trim(args.test_filter or "")
    local extra = vim.trim(args.args or "")
    local cmd = "./gradlew test"
    if filter ~= "" then
      cmd = cmd .. " --tests " .. vim.fn.shellescape(filter)
    end
    if extra ~= "" then
      cmd = cmd .. " " .. extra
    end
    return cmd
  end,
})

M.gradle_spotless_apply = cmd_tool({
  name = "gradle_spotless_apply",
  description = table.concat({
    "Run `./gradlew spotlessApply` to auto-format all source files according to the project's Spotless configuration.",
    "This modifies files in place.",
  }, " "),
  schema = {
    properties = {
      args = {
        type = "string",
        description = "Optional extra arguments (e.g. '-p <subproject>'). Empty string for defaults.",
      },
    },
    required = { "args" },
  },
  build_cmd = function(args)
    local extra = vim.trim(args.args or "")
    if extra ~= "" then
      return "./gradlew spotlessApply " .. extra
    end
    return "./gradlew spotlessApply"
  end,
})

M.gradle_dependencies = cmd_tool({
  name = "gradle_dependencies",
  description = table.concat({
    "Run `./gradlew dependencies` to print the full dependency tree of the project.",
    "Useful for diagnosing version conflicts or understanding transitive dependencies.",
    "Optionally scope to a specific configuration (e.g. '--configuration runtimeClasspath').",
  }, " "),
  schema = {
    properties = {
      args = {
        type = "string",
        description = "Optional extra arguments (e.g. '--configuration runtimeClasspath', '-p <subproject>'). Empty string for full tree.",
      },
    },
    required = { "args" },
  },
  build_cmd = function(args)
    local extra = vim.trim(args.args or "")
    if extra ~= "" then
      return "./gradlew dependencies " .. extra
    end
    return "./gradlew dependencies"
  end,
})

M.gradle_clean = cmd_tool({
  name = "gradle_clean",
  description = table.concat({
    "Run `./gradlew clean` to delete all build outputs.",
    "Use before a full rebuild to ensure a clean state.",
  }, " "),
  schema = {
    properties = {
      args = {
        type = "string",
        description = "Optional extra arguments (e.g. '-p <subproject>'). Empty string for defaults.",
      },
    },
    required = { "args" },
  },
  build_cmd = function(args)
    local extra = vim.trim(args.args or "")
    if extra ~= "" then
      return "./gradlew clean " .. extra
    end
    return "./gradlew clean"
  end,
})

M.gradle_spotless_check = cmd_tool({
  name = "gradle_spotless_check",
  description = table.concat({
    "Run `./gradlew spotlessCheck` to verify source formatting without modifying files.",
    "This is the dry-run counterpart to spotlessApply.",
    "Returns a non-zero exit code if any file is not formatted correctly.",
  }, " "),
  schema = {
    properties = {
      args = {
        type = "string",
        description = "Optional extra arguments (e.g. '-p <subproject>'). Empty string for defaults.",
      },
    },
    required = { "args" },
  },
  build_cmd = function(args)
    local extra = vim.trim(args.args or "")
    if extra ~= "" then
      return "./gradlew spotlessCheck " .. extra
    end
    return "./gradlew spotlessCheck"
  end,
})

M.gradle_run_task = cmd_tool({
  name = "gradle_run_task",
  description = table.concat({
    "Run an arbitrary `./gradlew <task>` command.",
    "Use this for any Gradle task not covered by the dedicated tools.",
    "You must specify the task name. Optionally pass extra arguments.",
  }, " "),
  schema = {
    properties = {
      task = {
        type = "string",
        description = "The Gradle task to run (e.g. 'assemble', 'publish', 'bootRun', 'flywayMigrate').",
      },
      args = {
        type = "string",
        description = "Optional extra arguments (e.g. '--info', '--stacktrace', '-p <subproject>'). Empty string for defaults.",
      },
    },
    required = { "task", "args" },
  },
  build_cmd = function(args)
    local task = vim.trim(args.task or "")
    local extra = vim.trim(args.args or "")
    local cmd = "./gradlew " .. task
    if extra ~= "" then
      cmd = cmd .. " " .. extra
    end
    return cmd
  end,
})

return M
