local M = {}

local fuzzy = require('nvmenu.fuzzy')
local ui = require('nvmenu.ui')
local keymaps = require('nvmenu.keymaps')
local state_module = require('nvmenu.state')
local processor = require('nvmenu.processor')

M.config = {
  transparent_background = false,
  load_default_theme = false
}

local function create_fuzzy_finder(process_fn)
  if M.config.load_default_theme then
    vim.cmd('colorscheme default')
  end
  if M.config.transparent_background then
    vim.cmd('highlight Normal guibg=NONE ctermbg=NONE')
    vim.cmd('highlight NonText guibg=NONE ctermbg=NONE')
    vim.cmd('highlight SignColumn guibg=NONE ctermbg=NONE')
    vim.cmd('highlight EndOfBuffer guibg=NONE ctermbg=NONE')
    vim.cmd('highlight Visual guibg=NONE ctermbg=NONE gui=reverse cterm=reverse')
  end

  -- Create custom highlight for matched characters using theme colors
  vim.cmd('highlight default link NvmenuMatch Function')

  -- Disable all events to prevent plugin interference
  vim.o.eventignore = 'all'

  local source_buf = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(source_buf, 0, -1, false)

  local win = vim.api.nvim_get_current_win()
  local buf = source_buf

  local original_ui_opts = ui.setup_window_options(win)
  local original_buf_state = state_module.setup_buffer_state(buf)

  local state = state_module.create_state(lines)

  local function update_display()
    ui.update_display(win, buf, state)
  end

  local function filter_results()
    state.filtered_lines = fuzzy.filter_and_sort(state.original_lines, state.query)
    state.selected = 1
    update_display()
  end

  local function select_current()
    if #state.filtered_lines > 0 and state.selected > 0 and state.selected <= #state.filtered_lines then
      local text = state.filtered_lines[state.selected].line

      if process_fn then
        text = process_fn(text)
      end

      vim.fn.setreg('+', text)
    end

    ui.restore_window_options(original_ui_opts)
    vim.cmd('quit!')
  end

  local function close_finder()
    ui.restore_window_options(original_ui_opts)
    vim.cmd('quit!')
  end

  local callbacks = {
    update_display = update_display,
    filter_results = filter_results,
    select_current = select_current,
    close_finder = close_finder
  }

  keymaps.setup_keymaps(win, buf, state, callbacks)
  filter_results()
end

function M.nvmenu()
  create_fuzzy_finder()
end

function M.nvmenu_lua(lua_code)
  local process_fn = processor.create_lua_processor(lua_code)
  if process_fn then
    create_fuzzy_finder(process_fn)
  end
end

function M.nvmenu_shell(shell_cmd)
  local process_fn = processor.create_shell_processor(shell_cmd)
  if process_fn then
    create_fuzzy_finder(process_fn)
  end
end

function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', M.config, opts or {})
end

return M
