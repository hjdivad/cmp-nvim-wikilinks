# cmp-nvim-wikilinks

A wikilinks-completion source for [nvim-cmp][].

## ✨ Features

It completes files in wikilinks (e.g. `[[foo/bar.md]]`) against your `&path`.

It is intended to be used when editing [Obsidian](https://obsidian.md/) vaults within neovim.

## 📦 Installation & Setup

### Requirements

* Neovim ≥ 0.5
* [nvim-cmp][]

### With [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
-- ~/.config/nvim/lua/plugins/completion.lua
return {
  {
    "hjdivad/cmp-nvim-wikilinks",
    opts = {
      -- log_level = 'trace',
      -- log_to_file = true,
      -- glob_suffixes = { "*" }
    }
  },
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "hjdivad/cmp-nvim-wikilinks",
    },
    opts = function()
      local cmp = require("cmp")
      return {
        sources = cmp.config.sources({
          { name = "wikilinks" }, -- complete [[foo]] &c.
        }),
      }
    end,
  },
}
```

### Configuration

```lua
require('cmp-nvim-wikilinks').setup({
  log_level = 'info', -- logging
  log_to_file = false,
  -- A table of suffixes to complete. See :help wildcards
  -- The default matches files and directories in `&path`.  To also match files in directories, use { "*", "*/*" }.  To match everything recursively in `&path` use { "*", "**/*" }.
  glob_suffixes = { "*" }
})
```

[nvim-cmp]: https://github.com/hrsh7th/nvim-cmp
