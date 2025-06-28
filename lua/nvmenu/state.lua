local M = {}

function M.create_state(lines)
  return {
    query = "",
    selected = 1,
    filtered_lines = lines,
    original_lines = lines,
    mode = "input"
  }
end

function M.setup_buffer_state(buf)
  local original_modifiable = vim.api.nvim_buf_get_option(buf, 'modifiable')
  local original_readonly = vim.api.nvim_buf_get_option(buf, 'readonly')
  
  vim.api.nvim_buf_set_option(buf, 'modifiable', true)
  vim.api.nvim_buf_set_option(buf, 'readonly', false)
  
  return {
    modifiable = original_modifiable,
    readonly = original_readonly
  }
end

function M.restore_buffer_state(buf, original_state)
  vim.api.nvim_buf_set_option(buf, 'modifiable', original_state.modifiable)
  vim.api.nvim_buf_set_option(buf, 'readonly', original_state.readonly)
end

return M