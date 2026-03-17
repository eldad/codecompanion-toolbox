-- codecompanion-toolbox: custom tools for codecompanion.nvim
--
-- Exposes a setup(opts) function for use with lazy.nvim, and also returns
-- the raw tools table so it can be merged manually if preferred.

local M = {}

--- Build a shell command from a base string and a list of optional parts.
--- Only non-empty parts are included; parts are joined with a single space.
---
---@param base string The fixed beginning of the command (e.g. "git commit").
---@param parts string[] Optional extra tokens to append (empty strings are skipped).
---@return string
function M.build_cmd(base, parts)
  local tokens = { base }
  for _, part in ipairs(parts) do
    local p = vim.trim(part or "")
    if p ~= "" then
      table.insert(tokens, p)
    end
  end
  return table.concat(tokens, " ")
end

local git = require("codecompanion-toolbox.git")
local rust = require("codecompanion-toolbox.rust")
local java = require("codecompanion-toolbox.java")

M.tools = {
  groups = {
    ["git"] = {
      description = "Git tools — inspect, commit, branch, checkout, pull, push",
      system_prompt = "You have access to git tools for repository inspection and management. Use git_inspect for read-only operations (status, diff, log, show, blame). Use the other git tools for mutations (commit, branch, checkout, pull, push). Always inspect before mutating.",
      tools = {
        "git_inspect",
        "git_commit",
        "git_branch",
        "git_checkout",
        "git_pull",
        "git_push",
      },
      opts = {
        collapse_tools = true,
      },
    },
    ["rust"] = {
      description = "Rust / Cargo tools — check, clippy, fmt, build, test, run, doc, update, add",
      system_prompt = "You have access to Rust development tools via Cargo. Use cargo_check for the fastest type-checking feedback. Use cargo_clippy to lint, cargo_clippy_fix to auto-fix lints, cargo_fmt to format. Use cargo_build / cargo_build_release to compile, cargo_test to run tests (with optional filter), cargo_run to execute the binary. Use cargo_doc to generate documentation, cargo_update to refresh dependencies, and cargo_add to add new crates.",
      tools = {
        "cargo_check",
        "cargo_clippy",
        "cargo_clippy_fix",
        "cargo_fmt",
        "cargo_build",
        "cargo_build_release",
        "cargo_test",
        "cargo_run",
        "cargo_doc",
        "cargo_update",
        "cargo_add",
      },
      opts = {
        collapse_tools = true,
      },
    },
    ["java"] = {
      description = "Java / Gradle tools — build, test, format, dependencies, clean, custom tasks",
      system_prompt = "You have access to Java/Kotlin project tools via Gradle. Use gradle_build for a full build, gradle_build_no_check for compilation without tests, gradle_test to run tests (optionally filtered), gradle_spotless_apply to auto-format sources, gradle_spotless_check for a formatting dry-run, gradle_dependencies to inspect the dependency tree, gradle_clean to wipe build outputs, and gradle_run_task for any other Gradle task.",
      tools = {
        "gradle_build",
        "gradle_build_no_check",
        "gradle_test",
        "gradle_spotless_apply",
        "gradle_spotless_check",
        "gradle_dependencies",
        "gradle_clean",
        "gradle_run_task",
      },
      opts = {
        collapse_tools = true,
      },
    },
  },

  -- Git

  ["git_inspect"] = {
    callback = function()
      return git.git_inspect
    end,
    description = "Run read-only git inspection commands (status, diff, log, show, blame, …)",
    opts = {
      require_approval_before = true,
    },
  },
  ["git_commit"] = {
    callback = function()
      return git.git_commit
    end,
    description = "Create a git commit with a message",
    opts = {
      require_approval_before = true,
    },
  },
  ["git_branch"] = {
    callback = function()
      return git.git_branch
    end,
    description = "Create, delete, or rename git branches",
    opts = {
      require_approval_before = true,
    },
  },
  ["git_checkout"] = {
    callback = function()
      return git.git_checkout
    end,
    description = "Switch branches or restore working tree files",
    opts = {
      require_approval_before = true,
    },
  },
  ["git_pull"] = {
    callback = function()
      return git.git_pull
    end,
    description = "Pull changes from a remote repository",
    opts = {
      require_approval_before = true,
    },
  },
  ["git_push"] = {
    callback = function()
      return git.git_push
    end,
    description = "Push commits to a remote repository",
    opts = {
      allowed_in_yolo_mode = false,
      require_approval_before = true,
    },
  },

  -- Rust

  ["cargo_clippy"] = {
    callback = function()
      return rust.cargo_clippy
    end,
    description = "Run cargo clippy to lint the Rust project",
    opts = {
      require_approval_before = true,
    },
  },
  ["cargo_clippy_fix"] = {
    callback = function()
      return rust.cargo_clippy_fix
    end,
    description = "Run cargo clippy --fix to auto-apply lint fixes",
    opts = {
      require_approval_before = true,
    },
  },
  ["cargo_fmt"] = {
    callback = function()
      return rust.cargo_fmt
    end,
    description = "Run cargo fmt to format Rust source files",
    opts = {
      require_approval_before = true,
    },
  },
  ["cargo_build"] = {
    callback = function()
      return rust.cargo_build
    end,
    description = "Run cargo build (debug mode)",
    opts = {
      require_approval_before = true,
    },
  },
  ["cargo_build_release"] = {
    callback = function()
      return rust.cargo_build_release
    end,
    description = "Run cargo build --release (optimized)",
    opts = {
      require_approval_before = true,
    },
  },
  ["cargo_update"] = {
    callback = function()
      return rust.cargo_update
    end,
    description = "Run cargo update to update Cargo.lock dependencies",
    opts = {
      require_approval_before = true,
    },
  },
  ["cargo_add"] = {
    callback = function()
      return rust.cargo_add
    end,
    description = "Run cargo add to add a dependency to Cargo.toml",
    opts = {
      allowed_in_yolo_mode = false,
      require_approval_before = true,
    },
  },
  ["cargo_test"] = {
    callback = function()
      return rust.cargo_test
    end,
    description = "Run cargo test to build and execute tests, with optional filter",
    opts = {
      require_approval_before = true,
    },
  },
  ["cargo_run"] = {
    callback = function()
      return rust.cargo_run
    end,
    description = "Run cargo run to compile and execute the project binary",
    opts = {
      allowed_in_yolo_mode = false,
      require_approval_before = true,
    },
  },
  ["cargo_check"] = {
    callback = function()
      return rust.cargo_check
    end,
    description = "Run cargo check to type-check without producing a binary (fastest feedback)",
    opts = {
      require_approval_before = true,
    },
  },
  ["cargo_doc"] = {
    callback = function()
      return rust.cargo_doc
    end,
    description = "Run cargo doc to generate API documentation",
    opts = {
      require_approval_before = true,
    },
  },

  -- Java (Gradle)

  ["gradle_build"] = {
    callback = function()
      return java.gradle_build
    end,
    description = "Run ./gradlew build (full build with checks)",
    opts = {
      require_approval_before = true,
    },
  },
  ["gradle_build_no_check"] = {
    callback = function()
      return java.gradle_build_no_check
    end,
    description = "Run ./gradlew build -x check (compile only, skip tests)",
    opts = {
      require_approval_before = true,
    },
  },
  ["gradle_test"] = {
    callback = function()
      return java.gradle_test
    end,
    description = "Run ./gradlew test, optionally for a specific test class or method",
    opts = {
      require_approval_before = true,
    },
  },
  ["gradle_spotless_apply"] = {
    callback = function()
      return java.gradle_spotless_apply
    end,
    description = "Run ./gradlew spotlessApply to auto-format sources",
    opts = {
      require_approval_before = true,
    },
  },
  ["gradle_spotless_check"] = {
    callback = function()
      return java.gradle_spotless_check
    end,
    description = "Run ./gradlew spotlessCheck to verify formatting without modifying files",
    opts = {
      require_approval_before = true,
    },
  },
  ["gradle_dependencies"] = {
    callback = function()
      return java.gradle_dependencies
    end,
    description = "Run ./gradlew dependencies to print the dependency tree",
    opts = {
      require_approval_before = true,
    },
  },
  ["gradle_clean"] = {
    callback = function()
      return java.gradle_clean
    end,
    description = "Run ./gradlew clean to delete all build outputs",
    opts = {
      require_approval_before = true,
    },
  },
  ["gradle_run_task"] = {
    callback = function()
      return java.gradle_run_task
    end,
    description = "Run an arbitrary ./gradlew <task> command",
    opts = {
      allowed_in_yolo_mode = false,
      require_approval_before = true,
    },
  },
}

--- Merge the toolbox tools into an existing codecompanion setup.
---
---@param opts? { codecompanion_config?: table } Extra options:
---   - codecompanion_config: a full codecompanion config table to merge into.
---     When provided, the tools are deep-merged and passed to codecompanion.setup().
---     When omitted, only the tools table is merged into codecompanion's current config.
function M.setup(opts)
  opts = opts or {}

  local cc_config = require("codecompanion.config")
  local existing_tools = (cc_config.interactions and cc_config.interactions.chat and cc_config.interactions.chat.tools)
    or {}

  local merged_tools = vim.tbl_deep_extend("force", existing_tools, M.tools)

  local base = opts.codecompanion_config or {}
  base.interactions = base.interactions or {}
  base.interactions.chat = base.interactions.chat or {}
  base.interactions.chat.tools = merged_tools

  require("codecompanion").setup(base)
end

return M
