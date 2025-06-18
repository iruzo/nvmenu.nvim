-- Simple copy command
vim.api.nvim_create_user_command('Signal', function()
  require('signal').signal()
end, {})

-- Lua processing command
vim.api.nvim_create_user_command('SignalLua', function(opts)
  require('signal').signal_lua(opts.args)
end, {
  nargs = 1,
  desc = 'Process selected text with Lua function before copying'
})

-- Shell processing command
vim.api.nvim_create_user_command('SignalShell', function(opts)
  require('signal').signal_shell(opts.args)
end, {
  nargs = 1,
  desc = 'Process selected text with shell command before copying'
})
