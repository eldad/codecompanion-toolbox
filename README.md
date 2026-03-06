# codecompanion-toolbox

Custom tools for [codecompanion.nvim](https://github.com/olimorris/codecompanion.nvim) v19+.

## Groups

Three groups are provided out of the box. Type the handle in chat to load all
tools in that group at once:

| Handle | Tools loaded |
|--------|--------------------------------------------------------------|
| `@git` | `git_inspect`, `git_commit`, `git_branch`, `git_checkout`, `git_pull`, `git_push` |
| `@rust` | `cargo_check`, `cargo_clippy`, `cargo_clippy_fix`, `cargo_fmt`, `cargo_build`, `cargo_build_release`, `cargo_test`, `cargo_run`, `cargo_doc`, `cargo_update`, `cargo_add` |
| `@java` | `gradle_build`, `gradle_build_no_check`, `gradle_test`, `gradle_spotless_apply`, `gradle_spotless_check`, `gradle_dependencies`, `gradle_clean`, `gradle_run_task` |

You can also load individual tools with their own `@tool_name` handle.

## Tools

### Git

| Tool | Description | Auto-approve |
|------|-------------|:------------:|
| `git_inspect` | Read-only: status, diff, log, show, blame, … | ✓ |
| `git_commit` | Create a commit with a message | ✓ |
| `git_branch` | Create / delete / rename branches | ✓ |
| `git_checkout` | Switch branches or restore files | ✓ |
| `git_pull` | Pull from remote | ✓ |
| `git_push` | Push to remote | ✗ (always asks) |

### Rust

| Tool | Description | Auto-approve |
|------|-------------|:------------:|
| `cargo_check` | `cargo check` (fastest type-check) | ✓ |
| `cargo_clippy` | `cargo clippy` | ✓ |
| `cargo_clippy_fix` | `cargo clippy --fix` | ✓ |
| `cargo_fmt` | `cargo fmt` | ✓ |
| `cargo_build` | `cargo build` | ✓ |
| `cargo_build_release` | `cargo build --release` | ✓ |
| `cargo_test` | `cargo test` (optional filter) | ✓ |
| `cargo_run` | `cargo run` | ✗ (always asks) |
| `cargo_doc` | `cargo doc` | ✓ |
| `cargo_update` | `cargo update` | ✓ |
| `cargo_add` | `cargo add <crate>` | ✗ (always asks) |

### Java / Gradle

| Tool | Description | Auto-approve |
|------|-------------|:------------:|
| `gradle_build` | `./gradlew build` | ✓ |
| `gradle_build_no_check` | `./gradlew build -x check` | ✓ |
| `gradle_test` | `./gradlew test` (optional `--tests` filter) | ✓ |
| `gradle_spotless_apply` | `./gradlew spotlessApply` | ✓ |
| `gradle_spotless_check` | `./gradlew spotlessCheck` (dry-run) | ✓ |
| `gradle_dependencies` | `./gradlew dependencies` | ✓ |
| `gradle_clean` | `./gradlew clean` | ✓ |
| `gradle_run_task` | `./gradlew <task>` (generic) | ✗ (always asks) |

> **Auto-approve = ✗** means `allowed_in_yolo_mode = false` — even in YOLO mode,
> the tool will prompt for confirmation every single invocation.

## Installation

### lazy.nvim (recommended)

```lua
{
  "eldad/codecompanion-toolbox",
  dependencies = { "olimorris/codecompanion.nvim" },
  config = function()
    -- Simplest: just merge the tools into codecompanion's existing config.
    require("codecompanion-toolbox").setup()
  end,
}
```

If you manage your full `codecompanion` config yourself, pass it through here
so everything is set up in one call:

```lua
{
  "eldad/codecompanion-toolbox",
  dependencies = { "olimorris/codecompanion.nvim" },
  config = function()
    require("codecompanion-toolbox").setup({
      codecompanion_config = {
        -- your normal codecompanion.setup() options
        adapters = { ... },
        strategies = { ... },
      },
    })
  end,
}
```

### Manual merge

If you prefer to keep full control, access the raw tools table directly:

```lua
require("codecompanion").setup({
  interactions = {
    chat = {
      tools = vim.tbl_deep_extend(
        "force",
        require("codecompanion.config").interactions.chat.tools,
        require("codecompanion-toolbox").tools
      ),
    },
  },
})
```

### Adding tools to the built-in `@agent` group

```lua
-- inside your codecompanion setup
groups = {
  ["agent"] = {
    tools = {
      -- built-in tools …
      "ask_questions", "create_file", "delete_file", "file_search",
      "get_changed_files", "get_diagnostics", "grep_search",
      "insert_edit_into_file", "read_file", "run_command",
      -- custom tools from this plugin
      "git_inspect", "git_commit", "git_branch", "git_checkout",
      "git_pull", "git_push",
      "cargo_check", "cargo_clippy", "cargo_clippy_fix", "cargo_fmt",
      "cargo_build", "cargo_build_release", "cargo_test", "cargo_run",
      "cargo_doc", "cargo_update", "cargo_add",
      "gradle_build", "gradle_build_no_check", "gradle_test",
      "gradle_spotless_apply", "gradle_spotless_check",
      "gradle_dependencies", "gradle_clean", "gradle_run_task",
    },
  },
},
```
