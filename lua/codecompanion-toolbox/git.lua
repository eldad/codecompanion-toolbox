---@module "codecompanion.interactions.chat.tools.builtin.cmd_tool"
local cmd_tool = require("codecompanion.interactions.chat.tools.builtin.cmd_tool")
local build_cmd = require("codecompanion-toolbox.utils").build_cmd

local M = {}

M.git_inspect = cmd_tool({
  name = "git_inspect",
  description = table.concat({
    "Run read-only git inspection commands in the current repository.",
    "Supported sub-commands: status, diff, log, show, blame, branch --list, stash list, remote -v, tag --list.",
    "Use this tool when you need to understand the state of the repository without making changes.",
  }, " "),
  schema = {
    properties = {
      subcommand = {
        type = "string",
        description = "The git sub-command to run (e.g. 'status', 'diff', 'log', 'show', 'blame').",
      },
      args = {
        type = "string",
        description = "Additional arguments to pass to the git sub-command (e.g. '--oneline -n 20' for log, a commit hash for show, a file path for blame). Empty string if none.",
      },
    },
    required = { "subcommand", "args" },
  },
  build_cmd = function(args)
    local allowed = {
      status = true,
      diff = true,
      log = true,
      show = true,
      blame = true,
      ["branch --list"] = true,
      ["stash list"] = true,
      ["remote -v"] = true,
      ["tag --list"] = true,
    }

    local sub = vim.trim(args.subcommand or "")
    if not allowed[sub] then
      return "git status"
    end

    return build_cmd("git " .. sub, { args.args })
  end,
})

M.git_commit = cmd_tool({
  name = "git_commit",
  description = table.concat({
    "Create a git commit.",
    "The LLM must supply a commit message and list of files to commit. Optionally pass extra flags such as '--amend'. flags should normally not be used.",
  }, " "),
  schema = {
    properties = {
      message = {
        type = "string",
        description = "The commit message.",
      },
      files = {
        type = "string",
        description = "list of files to commit.",
      },
      flags = {
        type = "string",
        description = "optional extra flags. empty string if none.",
      },
    },
    required = { "message", "flags" },
  },
  build_cmd = function(args)
    local msg = args.message or "auto-commit"
    local parts = { args.files, args.flags, "-m " .. vim.fn.shellescape(msg) }
    return build_cmd("git commit", parts)
  end,
})

M.git_branch = cmd_tool({
  name = "git_branch",
  description = table.concat({
    "Manage git branches: create, delete, or rename branches.",
    "Specify the action and target branch name. Optionally pass extra flags.",
  }, " "),
  schema = {
    properties = {
      action = {
        type = "string",
        enum = { "create", "delete", "rename" },
        description = "The branch action: 'create', 'delete', or 'rename'.",
      },
      name = {
        type = "string",
        description = "The branch name (for create/delete) or the new name (for rename).",
      },
      flags = {
        type = "string",
        description = "Optional extra flags (e.g. '-D' for force-delete, old branch name as first arg for rename). Empty string if none.",
      },
    },
    required = { "action", "name", "flags" },
  },
  build_cmd = function(args)
    local action = args.action or "create"
    local name = vim.trim(args.name or "")
    local flags = vim.trim(args.flags or "")

    if action == "create" then
      return build_cmd("git branch", { flags, name })
    elseif action == "delete" then
      local flag = (flags ~= "") and flags or "-d"
      return build_cmd("git branch", { flag, name })
    elseif action == "rename" then
      return build_cmd("git branch -m", { flags, name })
    end
    return "git branch"
  end,
})

M.git_checkout = cmd_tool({
  name = "git_checkout",
  description = table.concat({
    "Switch branches or restore working tree files using git checkout or git switch.",
    "Supply the target (branch name, commit, tag, or file path) and optional flags.",
  }, " "),
  schema = {
    properties = {
      target = {
        type = "string",
        description = "The branch, commit, tag, or file path to checkout.",
      },
      flags = {
        type = "string",
        description = "Optional extra flags (e.g. '-b' to create a new branch, '-- <path>' to restore a file). Empty string if none.",
      },
    },
    required = { "target", "flags" },
  },
  build_cmd = function(args)
    return build_cmd("git checkout", { args.flags, args.target })
  end,
})

M.git_pull = cmd_tool({
  name = "git_pull",
  description = "Pull changes from a remote repository. Optionally specify remote and branch.",
  schema = {
    properties = {
      args = {
        type = "string",
        description = "Optional arguments (e.g. 'origin main', '--rebase'). Empty string for default pull.",
      },
    },
    required = { "args" },
  },
  build_cmd = function(args)
    return build_cmd("git pull", { args.args })
  end,
})

M.git_push = cmd_tool({
  name = "git_push",
  description = table.concat({
    "Push commits to a remote repository.",
    "Optionally specify remote, branch, and flags such as '--force' or '--set-upstream'.",
  }, " "),
  schema = {
    properties = {
      args = {
        type = "string",
        description = "Optional arguments (e.g. 'origin main', '--force', '-u origin feature-branch'). Empty string for default push.",
      },
    },
    required = { "args" },
  },
  build_cmd = function(args)
    return build_cmd("git push", { args.args })
  end,
})

return M
