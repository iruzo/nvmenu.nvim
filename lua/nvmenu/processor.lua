local M = {}

function M.create_lua_processor(lua_code)
  if not lua_code or lua_code == "" then
    vim.notify("NvmenuLua requires a Lua function", vim.log.levels.ERROR)
    return nil
  end

  return function(text)
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
end

function M.create_shell_processor(shell_cmd)
  if not shell_cmd or shell_cmd == "" then
    vim.notify("NvmenuShell requires a shell command", vim.log.levels.ERROR)
    return nil
  end

  return function(text)
    local temp_file = vim.fn.tempname()

    local file = io.open(temp_file, 'w')
    if not file then
      vim.notify("Failed to create temp file", vim.log.levels.ERROR)
      return text
    end
    file:write(text)
    file:close()

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

    if result:sub(-1) == '\n' then
      result = result:sub(1, -2)
    end

    return result
  end
end

return M