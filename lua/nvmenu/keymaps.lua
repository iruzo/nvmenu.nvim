local M = {}

local function move_selection(state, win, direction, amount, callbacks)
  local total_count = #state.filtered_lines
  
  if direction == "down" then
    state.selected = math.max(1, state.selected - amount)
  elseif direction == "up" then
    state.selected = math.min(total_count, state.selected + amount)
  elseif direction == "first" then
    state.selected = 1
  elseif direction == "last" then
    state.selected = total_count
  end
  
  callbacks.update_display()
end

function M.setup_keymaps(win, buf, state, callbacks)
  local opts = { buffer = buf, silent = true, nowait = true }
  
  -- Mode switching
  vim.keymap.set('n', '<Esc>', function()
    if state.mode == "input" then
      state.mode = "normal"
      callbacks.update_display()
    else
      callbacks.close_finder()
    end
  end, opts)
  
  vim.keymap.set('n', 'i', function()
    if state.mode == "normal" then
      state.mode = "input"
      callbacks.update_display()
    else
      state.query = state.query .. "i"
      callbacks.filter_results()
    end
  end, opts)
  
  vim.keymap.set('n', 'a', function()
    if state.mode == "normal" then
      state.mode = "input"
      callbacks.update_display()
    else
      state.query = state.query .. "a"
      callbacks.filter_results()
    end
  end, opts)
  
  -- Selection (works in both modes)
  vim.keymap.set('n', '<CR>', callbacks.select_current, opts)
  vim.keymap.set('n', '<C-m>', callbacks.select_current, opts)
  
  -- Exit (only in normal mode, input mode uses Esc for mode switch)
  vim.keymap.set('n', 'q', function()
    if state.mode == "normal" then
      callbacks.close_finder()
    else
      state.query = state.query .. "q"
      callbacks.filter_results()
    end
  end, opts)
  
  vim.keymap.set('n', '<C-c>', callbacks.close_finder, opts)
  
  -- Navigation (works in both modes but different behavior)
  vim.keymap.set('n', 'j', function()
    if state.mode == "normal" then
      move_selection(state, win, "down", 1, callbacks)
    else
      state.query = state.query .. "j"
      callbacks.filter_results()
    end
  end, opts)
  
  vim.keymap.set('n', 'k', function()
    if state.mode == "normal" then
      move_selection(state, win, "up", 1, callbacks)
    else
      state.query = state.query .. "k"
      callbacks.filter_results()
    end
  end, opts)
  
  -- Advanced navigation (normal mode only)
  vim.keymap.set('n', '<C-d>', function()
    if state.mode == "normal" then
      local half_screen = math.floor((vim.api.nvim_win_get_height(win) - 2) / 2)
      move_selection(state, win, "up", half_screen, callbacks)
    end
  end, opts)
  
  vim.keymap.set('n', '<C-u>', function()
    if state.mode == "normal" then
      local half_screen = math.floor((vim.api.nvim_win_get_height(win) - 2) / 2)
      move_selection(state, win, "down", half_screen, callbacks)
    else
      state.query = ""
      callbacks.filter_results()
    end
  end, opts)
  
  vim.keymap.set('n', 'g', function()
    if state.mode == "normal" then
      -- Wait for second 'g'
      local char = vim.fn.getchar()
      if char == string.byte('g') then
        move_selection(state, win, "last", 0, callbacks)
      end
    else
      state.query = state.query .. "g"
      callbacks.filter_results()
    end
  end, opts)
  
  vim.keymap.set('n', 'G', function()
    if state.mode == "normal" then
      move_selection(state, win, "first", 0, callbacks)
    else
      state.query = state.query .. "G"
      callbacks.filter_results()
    end
  end, opts)
  
  -- Arrow keys (work in both modes)
  vim.keymap.set('n', '<Down>', function()
    move_selection(state, win, "down", 1, callbacks)
  end, opts)
  
  vim.keymap.set('n', '<Up>', function()
    move_selection(state, win, "up", 1, callbacks)
  end, opts)
  
  -- Backspace (works in both modes, but only modifies query in input mode)
  vim.keymap.set('n', '<BS>', function()
    if state.mode == "input" and #state.query > 0 then
      state.query = state.query:sub(1, -2)
      callbacks.filter_results()
    end
  end, opts)
  
  -- Search mode
  vim.keymap.set('n', '/', function()
    if state.mode == "normal" then
      state.query = ""
      state.mode = "input"
      callbacks.filter_results()
    else
      state.query = state.query .. "/"
      callbacks.filter_results()
    end
  end, opts)
  
  -- Character input (only in input mode)
  for i = 32, 126 do
    local char = string.char(i)
    -- Skip characters that already have specific handlers
    if not vim.tbl_contains({'j', 'k', 'i', 'a', 'q', 'g', 'G', '/'}, char) then
      vim.keymap.set('n', char, function()
        if state.mode == "input" then
          state.query = state.query .. char
          callbacks.filter_results()
        end
      end, opts)
    end
  end
end

return M