local M = {}

local function create_telescope_picker(process_fn)
  local actions = require('telescope.actions')
  local action_state = require('telescope.actions.state')

  require('telescope.builtin').current_buffer_fuzzy_find({
    previewer = false,
    layout_strategy = 'vertical',
    layout_config = {
      width = 0.92,
      height = 0.92,
    },
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)

        if selection then
          local text = selection.text

          -- Apply processing function if provided
          if process_fn then
            text = process_fn(text)
          end

          vim.fn.setreg('+', text)
        end

        vim.cmd('quit!')
      end)

      map('i', '<esc>', function()
        actions.close(prompt_bufnr)
        vim.cmd('quit!')
      end)

      map('n', '<esc>', function()
        actions.close(prompt_bufnr)
        vim.cmd('quit!')
      end)

      return true
    end,
  })
end

-- Simple copy (original behavior)
function M.signal()
  create_telescope_picker()
end

-- Process with Lua function
function M.signal_lua(lua_code)
  if not lua_code or lua_code == "" then
    vim.notify("SignalLua requires a Lua function", vim.log.levels.ERROR)
    return
  end

  local process_fn = function(text)
    local success, result = pcall(function()
      local func = load("return " .. lua_code)()
      return func(text)
    end)

    if success then
      return result
    else
      vim.notify("Error in Lua function: " .. result, vim.log.levels.ERROR)
      return text
    end
  end

  create_telescope_picker(process_fn)
end

-- Process with shell command
function M.signal_shell(shell_cmd)
  if not shell_cmd or shell_cmd == "" then
    vim.notify("SignalShell requires a shell command", vim.log.levels.ERROR)
    return
  end

  local process_fn = function(text)
    local temp_file = vim.fn.tempname()

    -- Write text to temp file
    local file = io.open(temp_file, 'w')
    if not file then
      vim.notify("Failed to create temp file", vim.log.levels.ERROR)
      return text
    end
    file:write(text)
    file:close()

    -- Execute shell command
    local cmd = string.format("cat %s | %s", vim.fn.shellescape(temp_file), shell_cmd)
    local handle = io.popen(cmd)
    if not handle then
      vim.notify("Failed to execute shell command", vim.log.levels.ERROR)
      os.remove(temp_file)
      return text
    end

    local result = handle:read("*a")
    handle:close()
    os.remove(temp_file)

    -- Remove trailing newline if present
    if result:sub(-1) == '\n' then
      result = result:sub(1, -2)
    end

    return result
  end

  create_telescope_picker(process_fn)
end

return M
