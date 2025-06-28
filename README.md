# signal.nvim

Use your Neovim as a fuzzy finder.

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  'iruzo/signal.nvim',
  cmd = {'Signal', 'SignalLua', 'SignalShell'},
  config = function()
    require'signal'
  end
},
```

## Usage

### Manual Commands

**Simple copy (default):**
```vim
:Signal
```

**Process with Lua function:**
```vim
:SignalLua function(text) local parts = vim.split(text, '|', {plain=true}); return parts[2] and parts[2]:gsub(' ', '\n') or text end
```

**Process with shell command:**
```vim
:SignalShell cut -d'|' -f2 | tr ' ' '\n'
```

### Direct Execution with Files

You can use signal.nvim directly when opening files:

**With piped content:**
```bash
cat your_file.txt | nvim -c "Signal"
```

**With direct file:**
```bash
nvim your_file.txt -c "Signal"
```

## How it works

1. Opens the fuzzy finder ui
2. Optionally processes the selected text with Lua function or shell command
3. Copies the result to your system clipboard (using the `+` register)
4. Closes Neovim immediately after selection

## Examples

**Extract content after delimiter (like `cut -d'|' -f2`):**
```vim
:SignalLua function(text) local parts = vim.split(text, '|', {plain=true}); return parts[2] or text end
```

**Replace spaces with newlines (like `tr ' ' '\n'`):**
```vim
:SignalLua function(text) return text:gsub(' ', '\n') end
```

**Combine operations (like `cut -d'|' -f2 | tr ' ' '\n'`):**
```vim
:SignalShell cut -d'|' -f2 | tr ' ' '\n'
```
