# SKILL: Writing Custom Tools for codecompanion.nvim v19+

## Overview

This document captures everything needed to create custom tools for
[codecompanion.nvim](https://github.com/olimorris/codecompanion.nvim) **v19+**
(verified against v19.2.0). It covers the full tool API, both authoring
patterns (the `cmd_tool` factory and raw function-based tools), the approval /
permission system, registration into config, and group membership.

---

## Architecture at a Glance

```
User config (setup)
  └─ interactions.chat.tools          ← flat table of tool entries + `opts` + `groups`
       ├─ opts                        ← global tool options
       ├─ groups                      ← named groups referencing tool keys
       ├─ ["my_tool"] = { … }        ← individual tool entries
       └─ …

Tool entry (in config)
  ├─ path       : string              → require() path resolved by Tools.resolve()
  ├─ callback   : fun(): tool_table   → factory function returning a tool table
  ├─ extends    : string              → name of a factory ("cmd_tool")
  ├─ description: string              → shown in the action palette
  ├─ enabled    : bool | fun(): bool  → conditional availability
  └─ opts       : table               → per-tool options (approval, yolo, etc.)

Resolved tool table (CodeCompanion.Tools.Tool)
  ├─ name           : string
  ├─ cmds           : table            → list of commands (functions or {cmd=…} tables)
  ├─ schema         : table            → OpenAI-style function-calling JSON schema
  ├─ args           : table            → parsed arguments from LLM (set at runtime)
  ├─ opts           : table            → merged options
  ├─ system_prompt  : string | fun()   → optional per-tool system prompt
  ├─ env            : table | fun()    → optional environment variable map
  ├─ handlers       : table            → lifecycle callbacks
  │    ├─ setup(self, meta)
  │    ├─ prompt_condition(self, meta)
  │    └─ on_exit(self, meta)
  └─ output         : table            → output formatting callbacks
       ├─ cmd_string(self, meta)       → string shown in approval prompt
       ├─ prompt(self, meta)           → approval dialog text
       ├─ success(self, stdout, meta)
       ├─ error(self, stderr, meta)
       ├─ rejected(self, meta)
       └─ cancelled(self, meta)
```

---

## The Two Authoring Patterns

### Pattern 1: `cmd_tool` Factory (for shell commands)

The preferred pattern for tools that run shell commands. The factory lives at:
```
codecompanion.interactions.chat.tools.builtin.cmd_tool
```

It accepts a **spec table** and returns a fully wired `CodeCompanion.Tools.Tool`
with default handlers for setup, approval prompts, success/error/rejection output.

#### Spec shape

```lua
---@param spec {
---  name:          string,
---  description:   string,
---  schema:        { properties: table, required: table, additionalProperties?: boolean },
---  build_cmd:     fun(args: table): string,
---  system_prompt?: string | fun(schema: table): string,
---  handlers?:     table,   -- override default handlers
---  output?:       table,   -- override default output handlers
---}
```

#### Minimal example

```lua
local cmd_tool = require("codecompanion.interactions.chat.tools.builtin.cmd_tool")

return cmd_tool({
  name = "cargo_fmt",
  description = "Run cargo fmt to format Rust source files.",
  schema = {
    properties = {
      args = {
        type = "string",
        description = "Extra arguments. Empty string for defaults.",
      },
    },
    required = { "args" },
  },
  build_cmd = function(args)
    local extra = vim.trim(args.args or "")
    if extra ~= "" then
      return "cargo fmt " .. extra
    end
    return "cargo fmt"
  end,
})
```

#### What the factory provides automatically

| Callback | Default behaviour |
|---|---|
| `handlers.setup` | Calls `build_cmd(self.args)`, splits result on spaces, inserts into `self.cmds` |
| `output.cmd_string` | Returns `build_cmd(self.args)` |
| `output.prompt` | `"Run the command \`<cmd>\`?"` |
| `output.success` | Joins stdout lines, wraps in markdown code block, sends to chat |
| `output.error` | Joins stderr lines, wraps in markdown, sends to chat |
| `output.rejected` | Sends rejection message (with optional reason) via `helpers.rejected` |

You can override any of these by passing `handlers = { … }` or `output = { … }`
in the spec — they are merged with `vim.tbl_extend("force", defaults, yours)`.

#### How cmd-based tools are executed

The orchestrator calls `cmd_to_func_tool()` which converts each `{ cmd = { … } }`
entry into a function that calls `vim.system()` with platform-aware shell wrapping.
The callback receives stdout/stderr split by newline with ANSI codes stripped.

If the cmd entry has a `.flag` key, the orchestrator stores the result
(`true` on exit code 0) in `chat.tool_registry.flags[flag]` — useful for
test-result tools.

---

### Pattern 2: Function-Based Tools (for Lua logic)

For tools that don't simply shell out — e.g. reading LSP diagnostics, searching
files with `vim.fs.find`, or anything using Neovim APIs directly.

#### Shape

```lua
---@class CodeCompanion.Tools.Tool
return {
  name = "my_tool",

  cmds = {
    -- Each entry is a function. They run sequentially; the output of one
    -- is passed as `input` to the next.
    ---@param self   CodeCompanion.Tools   (the Tools coordinator, NOT the tool itself)
    ---@param args   table                 (parsed JSON args from the LLM)
    ---@param input? { input?: any, output_cb: fun(msg) }
    ---@return { status: "success"|"error", data: any }?
    function(self, args, input)
      -- Synchronous: return { status = …, data = … }
      -- Async: call input.output_cb({ status = …, data = … }) and return nil
      return { status = "success", data = "hello" }
    end,
  },

  schema = {
    type = "function",
    ["function"] = {
      name = "my_tool",
      description = "…",
      parameters = {
        type = "object",
        properties = { … },
        required = { … },
      },
    },
  },

  handlers = {
    setup     = function(self, meta) end,           -- optional
    on_exit   = function(self, meta) end,           -- optional cleanup
    prompt_condition = function(self, meta)          -- optional
      return true  -- return false to skip approval even when configured
    end,
  },

  output = {
    cmd_string = function(self, meta) return "…" end,
    prompt     = function(self, meta) return "Run my_tool?" end,
    success    = function(self, stdout, meta)
      -- stdout is a list; each entry is what a cmd function returned in `data`
      local chat = meta.tools.chat
      local text = vim.iter(stdout):flatten():join("\n")
      chat:add_tool_output(self, text, "Short user-visible summary")
    end,
    error      = function(self, stderr, meta)
      local chat = meta.tools.chat
      local text = vim.iter(stderr):flatten():join("\n")
      chat:add_tool_output(self, text)
    end,
    rejected   = function(self, meta)
      local helpers = require("codecompanion.interactions.chat.tools.builtin.helpers")
      meta = vim.tbl_extend("force", { message = "User rejected my_tool" }, meta or {})
      helpers.rejected(self, meta)
    end,
  },
}
```

#### Key differences from cmd_tool

| Aspect | `cmd_tool` | Function-based |
|---|---|---|
| `cmds` entries | `{ cmd = {"git", "status"} }` tables (converted to functions internally) | Lua functions directly |
| `build_cmd` | Required — produces the command string | N/A |
| `self` in cmds | N/A (handled by factory) | Receives `CodeCompanion.Tools` (the coordinator), NOT the tool table. Access tool opts via `self.tool.opts` |
| Async support | Built-in via `vim.system` | Call `input.output_cb(msg)` and return `nil` |
| Default output handlers | Provided by factory | Must be written manually |

#### Accessing tool opts from within a function cmd

```lua
function(self, args, input)
  local max = self.tool.opts.max_results or 100
  -- self       = CodeCompanion.Tools (coordinator)
  -- self.tool  = the current CodeCompanion.Tools.Tool being executed
  -- self.tool.opts = merged opts from config + tool definition
end
```

---

## The Schema (OpenAI Function-Calling Format)

Every tool must declare a `schema` table that the adapter sends to the LLM.
It follows the OpenAI function-calling JSON schema:

```lua
schema = {
  type = "function",
  ["function"] = {
    name = "tool_name",           -- must match the tool's registration key
    description = "What the tool does — be detailed, this is the LLM's guide",
    parameters = {
      type = "object",
      properties = {
        my_param = {
          type = "string",        -- "string" | "number" | "boolean" | "array" | "object"
          description = "…",
          enum = { "a", "b" },    -- optional: constrain values
        },
        optional_param = {
          anyOf = {
            { type = "string" },
            { type = "null" },
          },
          description = "…",
        },
      },
      required = { "my_param" },
      additionalProperties = false,  -- default in cmd_tool factory
    },
    strict = true,                   -- set by cmd_tool factory; optional otherwise
  },
}
```

The `cmd_tool` factory wraps your `schema.properties` and `schema.required`
into this envelope automatically — you only provide the inner properties table.

For function-based tools, you write the full schema yourself.

---

## The `output` Callbacks in Detail

### `output.cmd_string(self, meta) → string`

Returns the string representation of the command being executed.
Used by the approval system for `require_cmd_approval` — each unique
`cmd_string` gets its own approval entry.

### `output.prompt(self, meta) → string`

The text shown in the confirmation dialog. If it returns `nil` or `""`,
a generic `Run the "tool_name" tool?` prompt is used.

### `output.success(self, stdout, meta)`

Called when a command exits successfully (status = "success").
- `stdout`: a list of output data (one entry per cmd function that ran).
  For shell commands, each entry is a list of lines.
  For function commands, each entry is whatever `data` was returned.
- `meta.tools.chat`: the chat buffer object.
- Call `chat:add_tool_output(self, llm_message, user_message?)` to send
  the result. If `user_message` is omitted, `llm_message` is used for both.

### `output.error(self, stderr, meta)`

Called when a command fails. `stderr` may be `nil` if empty.
Same pattern — call `chat:add_tool_output(self, message)`.

### `output.rejected(self, meta)`

Called when the user rejects execution. `meta.opts.reason` may contain
the user's typed reason. Use `helpers.rejected(self, meta)` for the
standard format.

### `output.cancelled(self, meta)`

Called when the user cancels (choice 4 in the approval dialog).
If not provided, a default message is used.

---

## The Approval & Permission System

### Config-level opts (per-tool)

```lua
opts = {
  require_approval_before = true,     -- show 4-choice dialog before running
  allowed_in_yolo_mode    = false,    -- if false, ALWAYS prompt (even in yolo mode)
  require_cmd_approval    = true,     -- approval is per unique cmd_string, not per tool
}
```

### Approval flow

1. Orchestrator checks `Approvals:is_approved(bufnr, { cmd = cmd_string, tool_name = name })`.
2. If not approved AND `require_approval_before` is truthy → show dialog.
3. Dialog choices:
   - **Allow always** → `Approvals:always(bufnr, { cmd, tool_name })` — cached for session.
   - **Allow once** → executes without caching.
   - **Reject** → prompts for a reason, sends rejection message to LLM, moves to next tool.
   - **Cancel** → cancels current + all queued tools, finalizes.

### `require_approval_before` variants

| Value | Behaviour |
|---|---|
| `true` | Always prompt (unless already approved or yolo mode) |
| `false` | Never prompt |
| `function(tool, tools) → bool` | Dynamic — called each time |
| `table` (e.g. `{ buffer = false, file = true }`) | Passed through `prompt_condition` handler for sub-cases |

### `allowed_in_yolo_mode = false`

This is the **strongest permission lock**. When set, the tool will ALWAYS
show the approval dialog regardless of yolo mode or prior approvals.
Use this for destructive or irreversible operations like `git push` or
`cargo add`.

### `require_cmd_approval = true`

Each distinct `cmd_string` is tracked separately. So if the LLM runs
`git push origin main` once and the user approves it always, a later
`git push --force` would still prompt. This is the built-in `run_command`
tool's default behaviour.

### Yolo mode

Users toggle yolo mode via `Approvals:toggle_yolo_mode(bufnr)`. When active,
all tools with `allowed_in_yolo_mode ~= false` auto-approve without prompting.

---

## Registering Tools in Config

### The config entry

Each tool is a key in `interactions.chat.tools`:

```lua
["my_tool"] = {
  -- Resolution: exactly ONE of these three:
  path     = "my.module.path",              -- require("codecompanion." .. path) then require(path)
  callback = function() return tool_table end,  -- factory function
  extends  = "cmd_tool",                    -- use a registered factory

  -- Metadata:
  description = "Human-readable description",
  enabled     = true,                        -- or function()

  -- Options:
  opts = {
    require_approval_before = true,
    allowed_in_yolo_mode    = true,          -- default
    require_cmd_approval    = false,         -- default
    -- any custom keys are merged into tool.opts at runtime
  },
},
```

### Resolution order (in `Tools.resolve()`)

1. `extends` → loads factory from `FACTORIES` registry, passes the entry through it.
2. `path` → `require("codecompanion." .. path)`, else `require(path)`, else `loadfile(path)`.
   If the loaded module itself has `.extends`, it's passed through that factory.
3. `callback` → calls the function; if result has `.extends`, factory-resolved.
4. Otherwise the entry itself is used as the tool table.

### The `callback` pattern (used in this project)

```lua
["cargo_fmt"] = {
  callback = function() return rust.cargo_fmt end,
  description = "Run cargo fmt",
  opts = { require_approval_before = true },
},
```

The callback returns the already-constructed `cmd_tool()` result. The `opts`
from the config entry are merged into `tool.opts` at resolve time by the
orchestrator.

### The `extends` pattern (inline, no separate file)

```lua
["cargo_fmt"] = {
  extends = "cmd_tool",
  name = "cargo_fmt",
  description = "Run cargo fmt",
  schema = { properties = { … }, required = { … } },
  build_cmd = function(args) return "cargo fmt" end,
  opts = { require_approval_before = true },
},
```

### The `path` pattern

```lua
["cargo_fmt"] = {
  path = "tools.rust",  -- require("tools.rust") must return a tool table
  description = "Run cargo fmt",
  opts = { … },
},
```

---

## Groups

Groups bundle tools under a single `@group_name` trigger in chat.

### Groups defined in this project

| Handle | Description | Tools |
|--------|-------------|-------|
| `@git` | Git inspection & management | `git_inspect`, `git_commit`, `git_branch`, `git_checkout`, `git_pull`, `git_push` |
| `@rust` | Rust / Cargo dev tools | `cargo_check`, `cargo_clippy`, `cargo_clippy_fix`, `cargo_fmt`, `cargo_build`, `cargo_build_release`, `cargo_test`, `cargo_run`, `cargo_doc`, `cargo_update`, `cargo_add` |
| `@java` | Java / Gradle dev tools | `gradle_build`, `gradle_build_no_check`, `gradle_test`, `gradle_spotless_apply`, `gradle_spotless_check`, `gradle_dependencies`, `gradle_clean`, `gradle_run_task` |

These are defined in `init.lua` inside the `groups` key of the returned config
table and are merged into codecompanion's group registry automatically.

### Group definition anatomy

```lua
groups = {
  ["rust"] = {
    description = "Rust / Cargo tools",
    system_prompt = "You have access to Rust development tools via Cargo. …",
    -- Or: system_prompt = function(group_config, ctx) return "…" end,
    -- Or: prompt = "I'm giving you access to ${tools}",  -- alternative to system_prompt
    tools = {
      "cargo_clippy",
      "cargo_fmt",
      "cargo_build",
    },
    opts = {
      collapse_tools = true,           -- show as single context item (default: true)
      ignore_system_prompt = false,    -- remove the main system prompt
      ignore_tool_system_prompt = false, -- remove the tools system prompt
    },
  },
},
```

When a user types `@rust` in chat, all listed tools are registered. The
tools must exist as keys in the same `interactions.chat.tools` table.

Each group can provide a `system_prompt` (string or function) that is injected
into the conversation when the group is activated. This is the right place for
domain-specific guidance (e.g. "always run clippy before committing").

### Adding custom tools to the built-in `@agent` group

Extend the tools list in your setup:

```lua
groups = {
  ["agent"] = {
    tools = {
      -- built-ins
      "ask_questions", "create_file", "delete_file", "file_search",
      "get_changed_files", "get_diagnostics", "grep_search",
      "insert_edit_into_file", "read_file", "run_command",
      -- custom
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

### Default tools (always loaded)

```lua
opts = {
  default_tools = { "read_file", "git_inspect" },
},
```

---

## The `chat:add_tool_output()` API

```lua
chat:add_tool_output(
  self,           -- the tool table (must have .function_call set by orchestrator)
  llm_message,    -- string: full output sent to the LLM in the next turn
  user_message?   -- string: optional shorter message shown in the chat buffer UI
)
```

If `user_message` is omitted, `llm_message` is displayed to both. Use this
to keep the UI clean while still giving the LLM full context.

---

## Lifecycle & Execution Flow

```
1. LLM response parsed → tool calls extracted
2. Tools:execute(chat, tool_calls)
3.   For each tool call:
4.     Tools:_resolve_and_prepare_tool()
5.       → Tools.resolve(config_entry)          -- resolve path/callback/extends/inline
6.       → deepcopy, parse JSON args, merge opts
7.     Push to Orchestrator queue
8.   Fire "ToolsStarted"
9.   Orchestrator:setup_next_tool()
10.    Pop tool from queue
11.    _setup_handlers() → handlers.setup()     -- build cmds dynamically
12.    cmd_to_func_tool()                        -- convert {cmd=…} to functions
13.    Check approval:
14.      If not approved → show dialog
15.      If approved or allowed → execute_tool()
16.    Runner.new():setup()
17.      run_tool(cmd_fn, args, { output_cb })
18.        cmd_fn returns { status, data } or calls output_cb async
19.      output_handler dispatches to orchestrator.success/error
20.    success/error → output.success/error callback → chat:add_tool_output()
21.    finalize_tool() → handlers.on_exit()
22.    setup_next_tool() (loop back to 10)
23.  All done → Fire "ToolsFinished"
24.  Auto-submit if configured
```

---

## Practical Patterns & Tips

### 1. Use `build_cmd` for safety

Validate/whitelist inputs in `build_cmd` to prevent the LLM from running
arbitrary commands:

```lua
build_cmd = function(args)
  local allowed = { status = true, diff = true, log = true }
  local sub = vim.trim(args.subcommand or "")
  if not allowed[sub] then
    return "git status"  -- safe fallback
  end
  return "git " .. sub
end
```

### 2. Use `vim.fn.shellescape()` for user-controlled strings

Always escape strings that end up in shell commands:

```lua
build_cmd = function(args)
  return string.format("git commit -m %s", vim.fn.shellescape(args.message))
end
```

### 3. All schema `required` fields must use string type (or anyOf with null)

The LLM must always send these fields. For optional-feeling parameters,
make them required but tell the LLM to pass an empty string:

```lua
properties = {
  args = {
    type = "string",
    description = "Extra arguments. Empty string if none.",
  },
},
required = { "args" },
```

This avoids schema validation failures while keeping the interface predictable.

### 4. Separate definition files from config registration

Keep tool definitions (the `cmd_tool()` calls) in dedicated files
(`git.lua`, `rust.lua`, etc.) and wire them into config via `callback`
in a single `init.lua`. This keeps tools testable and reusable.

### 5. Loading sibling files without requiring them to be on `package.path`

```lua
local this_dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h")
local function load_sibling(name)
  return dofile(this_dir .. "/" .. name .. ".lua")
end
```

### 6. The `flag` field for test-result tracking

```lua
-- In a cmd entry:
{ cmd = vim.split("cargo test", " "), flag = "testing" }
-- After execution, chat.tool_registry.flags["testing"] = true/false
```

### 7. Multi-step command chains

A tool can have multiple `cmds` entries. They execute sequentially:

```lua
cmds = {
  function(self, args, input) return { status = "success", data = "step1" } end,
  function(self, args, input)
    -- input.input contains "step1"
    return { status = "success", data = "step2" }
  end,
},
```

### 8. Async function tools

Return `nil` and use the callback:

```lua
function(self, args, input)
  vim.system({ "long", "command" }, {}, vim.schedule_wrap(function(out)
    input.output_cb({
      status = out.code == 0 and "success" or "error",
      data = vim.split(out.stdout, "\n"),
    })
  end))
  -- return nil → tells runner this is async
end
```

---

## Global Tool Options

Set at `interactions.chat.tools.opts`:

```lua
opts = {
  auto_submit_errors  = true,   -- auto-send error output back to LLM
  auto_submit_success = true,   -- auto-send success output back to LLM
  folds = {
    enabled = true,
    failure_words = { "cancelled", "error", "failed", "incorrect", "invalid", "rejected" },
  },
  default_tools = {},            -- tools always loaded in every chat
  system_prompt = {
    enabled = true,
    replace_main_system_prompt = false,
    prompt = function(args) return "…" end,  -- or string
  },
  tool_replacement_message = "the ${tool} tool",
},
```

---

## File Organisation (This Project)

```
tools/
├── init.lua       ← config table (tools + groups) to merge into codecompanion setup
│                    defines @git, @rust, @java groups
│                    uses `callback` pattern, sets per-tool opts
├── git.lua        ← cmd_tool() definitions for git operations
├── rust.lua       ← cmd_tool() definitions for cargo operations
├── java.lua       ← cmd_tool() definitions for gradle operations
├── README.md      ← user-facing setup instructions
├── IDEAS.md       ← original requirements
└── SKILL.md       ← this file
```

### Integration snippet

```lua
local custom_tools = dofile(vim.fn.expand("~/tools/init.lua"))

require("codecompanion").setup({
  interactions = {
    chat = {
      tools = vim.tbl_deep_extend("force",
        require("codecompanion.config").interactions.chat.tools,
        custom_tools
      ),
    },
  },
})
```

---

## Source Reference (codecompanion.nvim v19.2.0)

| File | Purpose |
|---|---|
| `interactions/chat/tools/init.lua` | `Tools` class — resolution, parsing, execution entry point |
| `interactions/chat/tools/orchestrator.lua` | Queue management, approval flow, cmd→func conversion, success/error dispatch |
| `interactions/chat/tools/runtime/runner.lua` | Sequential command execution, async support |
| `interactions/chat/tools/runtime/queue.lua` | Simple FIFO queue |
| `interactions/chat/tools/approvals.lua` | Per-buffer approval cache, yolo mode toggle |
| `interactions/chat/tools/filter.lua` | Filters tools by `enabled`, adapter, MCP status |
| `interactions/chat/tools/builtin/cmd_tool.lua` | Factory for shell-command tools |
| `interactions/chat/tools/builtin/helpers/init.lua` | `rejected()` helper for standard rejection messages |
| `interactions/chat/tool_registry.lua` | Schema registration, group management, system prompt injection |
| `config.lua` | Default tool/group/opts configuration |
