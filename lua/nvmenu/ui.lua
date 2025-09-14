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

  -- Calculate scrolling window
  local total_results = #state.filtered_lines
  local start_idx = 1
  local end_idx = math.min(total_results, max_results)

  -- Implement scrolling based on selection
  if state.selected > max_results then
    start_idx = state.selected - max_results + 1
    end_idx = state.selected
  elseif state.selected > end_idx then
    local offset = state.selected - end_idx
    start_idx = start_idx + offset
    end_idx = end_idx + offset
  end

  -- Extract visible window of results
  local visible_results = {}
  for i = start_idx, end_idx do
    if state.filtered_lines[i] then
      table.insert(visible_results, {
        text = state.filtered_lines[i].line,
        positions = state.filtered_lines[i].positions,
        original_idx = i
      })
    end
  end

  -- Fill empty space at top
  local num_empty_lines = max_results - #visible_results
  for i = 1, num_empty_lines do
    table.insert(display_lines, "")
  end

  -- Add results (best matches at bottom - reverse the visible window)
  for i = #visible_results, 1, -1 do
    local item = visible_results[i]
    local is_selected = (item.original_idx == state.selected)
    local prefix = is_selected and "● " or "  "
    table.insert(display_lines, prefix .. item.text)
  end

  -- Add search bar
  table.insert(display_lines, "")
  local mode_indicator = state.mode == "normal" and "[N]" or ""
  local scroll_indicator = total_results > max_results and
    string.format(" (%d/%d)", state.selected, total_results) or ""
  table.insert(display_lines, mode_indicator .. "> " .. state.query .. scroll_indicator)

  -- Ensure exact window height
  local current_height = #display_lines
  if current_height < window_height then
    for i = 1, window_height - current_height do
      table.insert(display_lines, 1, "")
    end
  end

  vim.api.nvim_buf_set_option(buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, display_lines)
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)

  -- Highlight selected item and matched characters
  vim.api.nvim_buf_clear_namespace(buf, -1, 0, -1)
  for i, item in ipairs(visible_results) do
    local line_nr = num_empty_lines + (#visible_results - i)
    local prefix_offset = 2 -- Account for "● " or "  " prefix
    
    -- Highlight matched characters
    if item.positions and #item.positions > 0 then
      for _, pos in ipairs(item.positions) do
        vim.api.nvim_buf_add_highlight(buf, -1, 'NvmenuMatch', line_nr, prefix_offset + pos - 1, prefix_offset + pos)
      end
    end
    
    -- Highlight selected item
    if item.original_idx == state.selected then
      vim.api.nvim_buf_add_highlight(buf, -1, 'Visual', line_nr, 0, -1)
      vim.api.nvim_win_set_cursor(win, {line_nr + 1, 0})
    end
  end
end

return M
