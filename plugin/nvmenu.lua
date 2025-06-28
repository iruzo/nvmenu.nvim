vim.api.nvim_create_user_command('Nvmenu', function()
  require('nvmenu').nvmenu()
end, {})

vim.api.nvim_create_user_command('NvmenuLua', function(opts)
  require('nvmenu').nvmenu_lua(opts.args)
end, {
  nargs = 1,
  desc = 'Process selected text with Lua function before copying'
})

vim.api.nvim_create_user_command('NvmenuShell', function(opts)
  require('nvmenu').nvmenu_shell(opts.args)
end, {
  nargs = 1,
  desc = 'Process selected text with shell command before copying'
})
