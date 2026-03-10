---@module "codecompanion.interactions.chat.tools.builtin.cmd_tool"
local cmd_tool = require("codecompanion.interactions.chat.tools.builtin.cmd_tool")

local M = {}

M.cargo_clippy = cmd_tool({
  name = "cargo_clippy",
  description = table.concat({
    "Run `cargo clippy` to lint the current Rust project.",
    "Returns warnings and errors from the Rust linter.",
  }, " "),
  schema = {
    properties = {
      args = {
        type = "string",
        description = "Optional extra arguments (e.g. '-- -W clippy::pedantic', '-p <package>'). Empty string for default clippy run.",
      },
    },
    required = { "args" },
  },
  build_cmd = function(args)
    local extra = vim.trim(args.args or "")
    if extra ~= "" then
      return "cargo clippy " .. extra .. " 2>&1"
    end
    return "cargo clippy 2>&1"
  end,
})

M.cargo_clippy_fix = cmd_tool({
  name = "cargo_clippy_fix",
  description = table.concat({
    "Run `cargo clippy --fix` to automatically apply lint fixes to the Rust project.",
    "This modifies source files in place. Pass '--allow-dirty' or '--allow-staged' if the working tree is not clean.",
  }, " "),
  schema = {
    properties = {
      args = {
        type = "string",
        description = "Optional extra arguments (e.g. '--allow-dirty', '--allow-staged', '-p <package>'). Empty string for defaults.",
      },
    },
    required = { "args" },
  },
  build_cmd = function(args)
    local extra = vim.trim(args.args or "")
    if extra ~= "" then
      return "cargo clippy --fix " .. extra .. " 2>&1"
    end
    return "cargo clippy --fix 2>&1"
  end,
})

M.cargo_fmt = cmd_tool({
  name = "cargo_fmt",
  description = "Run `cargo fmt` to format all Rust source files in the project according to rustfmt rules.",
  schema = {
    properties = {
      args = {
        type = "string",
        description = "Optional extra arguments (e.g. '--check' for dry-run, '-p <package>'). Empty string for default formatting.",
      },
    },
    required = { "args" },
  },
  build_cmd = function(args)
    local extra = vim.trim(args.args or "")
    if extra ~= "" then
      return "cargo fmt " .. extra .. " 2>&1"
    end
    return "cargo fmt 2>&1"
  end,
})

M.cargo_build = cmd_tool({
  name = "cargo_build",
  description = table.concat({
    "Run `cargo build` to compile the Rust project in debug mode.",
    "Optionally pass extra arguments such as '-p <package>' or '--features <feature>'.",
  }, " "),
  schema = {
    properties = {
      args = {
        type = "string",
        description = "Optional extra arguments (e.g. '-p <package>', '--features <feat>'). Empty string for default build.",
      },
    },
    required = { "args" },
  },
  build_cmd = function(args)
    local extra = vim.trim(args.args or "")
    if extra ~= "" then
      return "cargo build " .. extra .. " 2>&1"
    end
    return "cargo build 2>&1"
  end,
})

M.cargo_build_release = cmd_tool({
  name = "cargo_build_release",
  description = table.concat({
    "Run `cargo build --release` to compile the Rust project with optimizations.",
    "Optionally pass extra arguments such as '-p <package>' or '--features <feature>'.",
  }, " "),
  schema = {
    properties = {
      args = {
        type = "string",
        description = "Optional extra arguments (e.g. '-p <package>', '--features <feat>'). Empty string for default release build.",
      },
    },
    required = { "args" },
  },
  build_cmd = function(args)
    local extra = vim.trim(args.args or "")
    if extra ~= "" then
      return "cargo build --release " .. extra .. " 2>&1"
    end
    return "cargo build --release 2>&1"
  end,
})

M.cargo_update = cmd_tool({
  name = "cargo_update",
  description = table.concat({
    "Run `cargo update` to update dependencies in Cargo.lock to their latest compatible versions.",
    "Optionally target a specific package with '-p <package>'.",
  }, " "),
  schema = {
    properties = {
      args = {
        type = "string",
        description = "Optional extra arguments (e.g. '-p <package>' to update a specific dependency). Empty string for full update.",
      },
    },
    required = { "args" },
  },
  build_cmd = function(args)
    local extra = vim.trim(args.args or "")
    if extra ~= "" then
      return "cargo update " .. extra .. " 2>&1"
    end
    return "cargo update 2>&1"
  end,
})

M.cargo_add = cmd_tool({
  name = "cargo_add",
  description = table.concat({
    "Run `cargo add` to add a new dependency to the Rust project's Cargo.toml.",
    "You must specify the crate name. Optionally include version, features, or flags.",
  }, " "),
  schema = {
    properties = {
      crate = {
        type = "string",
        description = "The crate name to add (e.g. 'serde', 'tokio').",
      },
      args = {
        type = "string",
        description = "Optional extra arguments (e.g. '--features derive', '--dev', '--optional'). Empty string if none.",
      },
    },
    required = { "crate", "args" },
  },
  build_cmd = function(args)
    local crate = vim.trim(args.crate or "")
    local extra = vim.trim(args.args or "")
    if extra ~= "" then
      return string.format("cargo add %s %s 2>&1", crate, extra)
    end
    return "cargo add " .. crate .. " 2>&1"
  end,
})

M.cargo_test = cmd_tool({
  name = "cargo_test",
  description = table.concat({
    "Run `cargo test` to build and execute tests in the Rust project.",
    "Accepts an optional filter to run a specific test, module, or integration test.",
    "Pass extra arguments after '--' to forward them to the test binary (e.g. '-- --nocapture').",
  }, " "),
  schema = {
    properties = {
      filter = {
        type = "string",
        description = "Optional test name or module filter (e.g. 'test_parse', 'parser::tests'). Empty string to run all tests.",
      },
      args = {
        type = "string",
        description = "Optional extra arguments (e.g. '-p <package>', '--lib', '-- --nocapture'). Empty string for defaults.",
      },
    },
    required = { "filter", "args" },
  },
  build_cmd = function(args)
    local filter = vim.trim(args.filter or "")
    local extra = vim.trim(args.args or "")
    local cmd = "cargo test"
    if filter ~= "" then
      cmd = cmd .. " " .. filter
    end
    if extra ~= "" then
      cmd = cmd .. " " .. extra
    end
    return cmd .. " 2>&1"
  end,
})

M.cargo_run = cmd_tool({
  name = "cargo_run",
  description = table.concat({
    "Run `cargo run` to compile and execute the project's binary target.",
    "Useful for smoke-testing after a build. Pass arguments after '--' to forward them to the binary.",
  }, " "),
  schema = {
    properties = {
      args = {
        type = "string",
        description = "Optional extra arguments (e.g. '--bin <name>', '-p <package>', '-- --help'). Empty string for defaults.",
      },
    },
    required = { "args" },
  },
  build_cmd = function(args)
    local extra = vim.trim(args.args or "")
    if extra ~= "" then
      return "cargo run " .. extra .. " 2>&1"
    end
    return "cargo run 2>&1"
  end,
})

M.cargo_check = cmd_tool({
  name = "cargo_check",
  description = table.concat({
    "Run `cargo check` to type-check the Rust project without producing a binary.",
    "This is the fastest feedback loop for catching compilation errors.",
    "Prefer this over `cargo build` when you only need to verify the code compiles.",
  }, " "),
  schema = {
    properties = {
      args = {
        type = "string",
        description = "Optional extra arguments (e.g. '-p <package>', '--all-targets', '--features <feat>'). Empty string for defaults.",
      },
    },
    required = { "args" },
  },
  build_cmd = function(args)
    local extra = vim.trim(args.args or "")
    if extra ~= "" then
      return "cargo check " .. extra .. " 2>&1"
    end
    return "cargo check 2>&1"
  end,
})

M.cargo_doc = cmd_tool({
  name = "cargo_doc",
  description = table.concat({
    "Run `cargo doc` to generate API documentation for the Rust project and its dependencies.",
    "Useful for understanding a crate's public API surface.",
    "Pass '--open' to open the docs in a browser, or '--no-deps' to skip dependency docs.",
  }, " "),
  schema = {
    properties = {
      args = {
        type = "string",
        description = "Optional extra arguments (e.g. '--open', '--no-deps', '-p <package>'). Empty string for defaults.",
      },
    },
    required = { "args" },
  },
  build_cmd = function(args)
    local extra = vim.trim(args.args or "")
    if extra ~= "" then
      return "cargo doc " .. extra .. " 2>&1"
    end
    return "cargo doc 2>&1"
  end,
})

return M
