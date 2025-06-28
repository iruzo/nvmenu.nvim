local M = {}

function M.setup_window_options(win)
  local original_opts = {
    number = vim.api.nvim_win_get_option(win, 'number'),
    relativenumber = vim.api.nvim_win_get_option(win, 'relativenumber'),
    signcolumn = vim.api.nvim_win_get_option(win, 'signcolumn'),
    foldcolumn = vim.api.nvim_win_get_option(win, 'foldcolumn'),
    colorcolumn = vim.api.nvim_win_get_option(win, 'colorcolumn'),
    laststatus = vim.o.laststatus,
    cmdheight = vim.o.cmdheight,
    showtabline = vim.o.showtabline,
    eventignore = vim.o.eventignore
  }
  
  vim.api.nvim_win_set_option(win, 'number', false)
  vim.api.nvim_win_set_option(win, 'relativenumber', false)
  vim.api.nvim_win_set_option(win, 'signcolumn', 'no')
  vim.api.nvim_win_set_option(win, 'foldcolumn', '0')
  vim.api.nvim_win_set_option(win, 'colorcolumn', '')
  vim.o.laststatus = 0
  vim.o.cmdheight = 0
  vim.o.showtabline = 0
  vim.o.eventignore = 'all'
  
  if #vim.api.nvim_tabpage_list_wins(0) > 1 then
    vim.cmd('only')
  end
  
  return original_opts
end

function M.restore_window_options(original_opts)
  vim.o.eventignore = original_opts.eventignore
  vim.o.laststatus = original_opts.laststatus
  vim.o.cmdheight = original_opts.cmdheight
  vim.o.showtabline = original_opts.showtabline
end

function M.update_display(win, buf, state)
  local display_lines = {}
  local window_height = vim.api.nvim_win_get_height(win)
  
  local max_results = window_height - 2
  local visible_results = {}
  
  for i = 1, math.min(#state.filtered_lines, max_results) do
    table.insert(visible_results, state.filtered_lines[i])
  end
  
  local num_empty_lines = max_results - #visible_results
  for i = 1, num_empty_lines do
    table.insert(display_lines, "")
  end
  
  -- Show best matches at the bottom, with selection indicator
  for i = #visible_results, 1, -1 do
    local line = visible_results[i]
    local prefix = (i == state.selected) and "● " or "  "
    table.insert(display_lines, prefix .. line)
  end
  
  table.insert(display_lines, "")
  table.insert(display_lines, "> " .. state.query)
  
  local current_height = #display_lines
  if current_height < window_height then
    for i = 1, window_height - current_height do
      table.insert(display_lines, 1, "")
    end
  end
  
  vim.api.nvim_buf_set_option(buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, display_lines)
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)
  
  vim.api.nvim_buf_clear_namespace(buf, -1, 0, -1)
  if state.selected > 0 and state.selected <= #visible_results then
    local line_nr = num_empty_lines + (#visible_results - state.selected)
    vim.api.nvim_buf_add_highlight(buf, -1, 'Visual', line_nr, 0, -1)
    vim.api.nvim_win_set_cursor(win, {line_nr + 1, 0})
  end
end

return M