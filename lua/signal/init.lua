local M = {}

-- Bemenu-style fuzzy scoring algorithm
local function fuzzy_score(text, query)
  if query == "" then return { score = 1000, positions = {} } end
  
  local original_text = text
  text = text:lower()
  query = query:lower()
  
  local score = 0
  local positions = {}
  local text_idx = 1
  local query_idx = 1
  
  -- Find all query characters in order
  while query_idx <= #query and text_idx <= #text do
    if text:sub(text_idx, text_idx) == query:sub(query_idx, query_idx) then
      table.insert(positions, text_idx)
      query_idx = query_idx + 1
    end
    text_idx = text_idx + 1
  end
  
  -- Return nil if not all query characters found
  if query_idx <= #query then
    return nil
  end
  
  -- Bemenu scoring: exact prefix > early matches > word boundaries
  if original_text:lower():sub(1, #query) == query then
    score = 10000 + (1000 - #query) -- Exact prefix gets highest score
  else
    -- Score based on position of first match
    local first_pos = positions[1] or #text
    score = 1000 - first_pos
    
    -- Bonus for consecutive character matches
    local consecutive_bonus = 0
    for i = 2, #positions do
      if positions[i] == positions[i-1] + 1 then
        consecutive_bonus = consecutive_bonus + 10
      end
    end
    score = score + consecutive_bonus
    
    -- Bonus for word boundary matches
    for _, pos in ipairs(positions) do
      local char_before = pos > 1 and original_text:sub(pos-1, pos-1) or " "
      if char_before:match("[%s%p]") then
        score = score + 20
      end
    end
  end
  
  return { score = score, positions = positions }
end

local function filter_and_sort(lines, query)
  if query == "" then
    return lines
  end
  
  local scored_lines = {}
  for i, line in ipairs(lines) do
    local result = fuzzy_score(line, query)
    if result then
      table.insert(scored_lines, {
        line = line,
        original_index = i,
        score = result.score,
        positions = result.positions
      })
    end
  end
  
  -- Sort by score (higher is better)
  table.sort(scored_lines, function(a, b) return a.score > b.score end)
  
  local filtered = {}
  for _, item in ipairs(scored_lines) do
    table.insert(filtered, item.line)
  end
  
  return filtered
end

local function create_fuzzy_finder(process_fn)
  -- Get source lines from current buffer (only read once)
  local source_buf = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(source_buf, 0, -1, false)
  
  -- Use current window for fullscreen interface
  local win = vim.api.nvim_get_current_win()
  local buf = source_buf
  
  -- Store original buffer state to restore if needed
  local original_lines = vim.deepcopy(lines)
  local original_modifiable = vim.api.nvim_buf_get_option(buf, 'modifiable')
  local original_readonly = vim.api.nvim_buf_get_option(buf, 'readonly')
  
  -- Configure buffer for fuzzy finder
  vim.api.nvim_buf_set_option(buf, 'modifiable', true)
  vim.api.nvim_buf_set_option(buf, 'readonly', false)
  
  -- Isolate from other plugins and UI elements
  vim.cmd('only') -- Close all other windows
  
  -- Store original options
  local original_number = vim.api.nvim_win_get_option(win, 'number')
  local original_relativenumber = vim.api.nvim_win_get_option(win, 'relativenumber')
  local original_signcolumn = vim.api.nvim_win_get_option(win, 'signcolumn')
  local original_foldcolumn = vim.api.nvim_win_get_option(win, 'foldcolumn')
  local original_colorcolumn = vim.api.nvim_win_get_option(win, 'colorcolumn')
  local original_laststatus = vim.o.laststatus
  local original_cmdheight = vim.o.cmdheight
  local original_showtabline = vim.o.showtabline
  
  -- Disable UI elements that might interfere
  vim.api.nvim_win_set_option(win, 'number', false)
  vim.api.nvim_win_set_option(win, 'relativenumber', false)
  vim.api.nvim_win_set_option(win, 'signcolumn', 'no')
  vim.api.nvim_win_set_option(win, 'foldcolumn', '0')
  vim.api.nvim_win_set_option(win, 'colorcolumn', '')
  vim.o.laststatus = 0  -- Hide statusline
  vim.o.cmdheight = 0   -- Hide command line
  vim.o.showtabline = 0 -- Hide tabline
  
  -- Disable events that might interfere
  local original_eventignore = vim.o.eventignore
  vim.o.eventignore = 'all'
  
  -- State
  local state = {
    query = "",
    selected = 1,
    filtered_lines = lines,
    original_lines = lines
  }
  
  local function update_display()
    local display_lines = {}
    local window_height = vim.api.nvim_win_get_height(win)
    
    -- Calculate space for results (leave 2 lines for search at bottom)
    local max_results = window_height - 2
    local visible_results = {}
    
    -- Take first max_results items (best matches)
    for i = 1, math.min(#state.filtered_lines, max_results) do
      table.insert(visible_results, state.filtered_lines[i])
    end
    
    -- Fill with empty lines at the top
    local num_empty_lines = max_results - #visible_results
    for i = 1, num_empty_lines do
      table.insert(display_lines, "")
    end
    
    -- Add filtered results in reverse order (best matches at bottom)
    for i = #visible_results, 1, -1 do
      local line = visible_results[i]
      -- i is the original index (1 to #visible_results)
      -- We want to check if this original index matches our selection
      local prefix = (i == state.selected) and "● " or "  "
      table.insert(display_lines, prefix .. line)
    end
    
    -- Add search bar at bottom (ensure it's truly at the bottom)
    table.insert(display_lines, "")
    table.insert(display_lines, "> " .. state.query)
    
    -- Ensure we fill exactly the window height
    local current_height = #display_lines
    if current_height < window_height then
      -- Insert empty lines at the beginning to push search to bottom
      for i = 1, window_height - current_height do
        table.insert(display_lines, 1, "")
      end
    end
    
    -- Update buffer
    vim.api.nvim_buf_set_option(buf, 'modifiable', true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, display_lines)
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)
    
    -- Highlight current selection and position cursor
    vim.api.nvim_buf_clear_namespace(buf, -1, 0, -1)
    if state.selected > 0 and state.selected <= #visible_results then
      -- Calculate line position: empty lines + reverse position
      local line_nr = num_empty_lines + (#visible_results - state.selected) -- 0-indexed
      vim.api.nvim_buf_add_highlight(buf, -1, 'Visual', line_nr, 0, -1)
      
      -- Position cursor on the highlighted line (1-indexed for cursor)
      vim.api.nvim_win_set_cursor(win, {line_nr + 1, 0})
    end
  end
  
  local function filter_results()
    state.filtered_lines = filter_and_sort(state.original_lines, state.query)
    state.selected = 1
    update_display()
  end
  
  local function select_current()
    if #state.filtered_lines > 0 and state.selected > 0 and state.selected <= #state.filtered_lines then
      local text = state.filtered_lines[state.selected]
      
      -- Apply processing function if provided
      if process_fn then
        text = process_fn(text)
      end
      
      vim.fn.setreg('+', text)
    end
    
    -- Restore original settings before quitting
    vim.o.eventignore = original_eventignore
    vim.o.laststatus = original_laststatus
    vim.o.cmdheight = original_cmdheight
    vim.o.showtabline = original_showtabline
    vim.cmd('quit!')
  end
  
  local function close_finder()
    -- Restore original settings before quitting
    vim.o.eventignore = original_eventignore
    vim.o.laststatus = original_laststatus
    vim.o.cmdheight = original_cmdheight
    vim.o.showtabline = original_showtabline
    vim.cmd('quit!')
  end
  
  -- Set up key mappings
  local function setup_keymaps()
    local opts = { buffer = buf, silent = true, nowait = true }
    
    -- Navigation (reversed: Down/j moves up in list, Up/k moves down)
    vim.keymap.set('n', '<Down>', function()
      if state.selected > 1 then
        state.selected = state.selected - 1
        update_display()
      end
    end, opts)
    
    vim.keymap.set('n', '<Up>', function()
      local max_results = vim.api.nvim_win_get_height(win) - 2
      local visible_count = math.min(#state.filtered_lines, max_results)
      if state.selected < visible_count then
        state.selected = state.selected + 1
        update_display()
      end
    end, opts)
    
    vim.keymap.set('n', 'j', function()
      if state.selected > 1 then
        state.selected = state.selected - 1
        update_display()
      end
    end, opts)
    
    vim.keymap.set('n', 'k', function()
      local max_results = vim.api.nvim_win_get_height(win) - 2
      local visible_count = math.min(#state.filtered_lines, max_results)
      if state.selected < visible_count then
        state.selected = state.selected + 1
        update_display()
      end
    end, opts)
    
    -- Selection
    vim.keymap.set('n', '<CR>', select_current, opts)
    vim.keymap.set('n', '<C-m>', select_current, opts)
    
    -- Exit
    vim.keymap.set('n', '<Esc>', close_finder, opts)
    vim.keymap.set('n', 'q', close_finder, opts)
    vim.keymap.set('n', '<C-c>', close_finder, opts)
    
    -- Character input for search
    for i = 32, 126 do -- Printable ASCII characters
      local char = string.char(i)
      vim.keymap.set('n', char, function()
        state.query = state.query .. char
        filter_results()
      end, opts)
    end
    
    -- Backspace
    vim.keymap.set('n', '<BS>', function()
      if #state.query > 0 then
        state.query = state.query:sub(1, -2)
        filter_results()
      end
    end, opts)
    
    -- Clear query
    vim.keymap.set('n', '<C-u>', function()
      state.query = ""
      filter_results()
    end, opts)
  end
  
  -- Initialize with proper reversed display
  setup_keymaps()
  -- Trigger initial filter to ensure proper display order
  filter_results()
end

-- Simple copy (original behavior)
function M.signal()
  create_fuzzy_finder()
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

  create_fuzzy_finder(process_fn)
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

  create_fuzzy_finder(process_fn)
end

return M
