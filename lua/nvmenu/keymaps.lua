local M = {}

function M.setup_keymaps(win, buf, state, callbacks)
  local opts = { buffer = buf, silent = true, nowait = true }
  
  -- Navigation is reversed since best matches are at the bottom
  vim.keymap.set('n', '<Down>', function()
    if state.selected > 1 then
      state.selected = state.selected - 1
      callbacks.update_display()
    end
  end, opts)
  
  vim.keymap.set('n', '<Up>', function()
    local max_results = vim.api.nvim_win_get_height(win) - 2
    local visible_count = math.min(#state.filtered_lines, max_results)
    if state.selected < visible_count then
      state.selected = state.selected + 1
      callbacks.update_display()
    end
  end, opts)
  
  vim.keymap.set('n', 'j', function()
    if state.selected > 1 then
      state.selected = state.selected - 1
      callbacks.update_display()
    end
  end, opts)
  
  vim.keymap.set('n', 'k', function()
    local max_results = vim.api.nvim_win_get_height(win) - 2
    local visible_count = math.min(#state.filtered_lines, max_results)
    if state.selected < visible_count then
      state.selected = state.selected + 1
      callbacks.update_display()
    end
  end, opts)
  
  vim.keymap.set('n', '<CR>', callbacks.select_current, opts)
  vim.keymap.set('n', '<C-m>', callbacks.select_current, opts)
  
  vim.keymap.set('n', '<Esc>', callbacks.close_finder, opts)
  vim.keymap.set('n', 'q', callbacks.close_finder, opts)
  vim.keymap.set('n', '<C-c>', callbacks.close_finder, opts)
  
  for i = 32, 126 do
    local char = string.char(i)
    vim.keymap.set('n', char, function()
      state.query = state.query .. char
      callbacks.filter_results()
    end, opts)
  end
  
  vim.keymap.set('n', '<BS>', function()
    if #state.query > 0 then
      state.query = state.query:sub(1, -2)
      callbacks.filter_results()
    end
  end, opts)
  
  vim.keymap.set('n', '<C-u>', function()
    state.query = ""
    callbacks.filter_results()
  end, opts)
end

return M