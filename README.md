# cmp-nvim-wikilinks

A source for [nvim-cmp][].

It completes files in wikilinks `` against your `&path`.

It is intended to be used when editing [Obsidian](https://obsidian.md/) vaults within neovim.

# Dependencies

* Neovim ≥ 0.5
* [nvim-cmp][]

# Installation & Setup

```lua

require('cmp_nvim_wikilinks').setup {}
-- see <https://github.com/hrsh7th/nvim-cmp#setup> for additional setup options
cmp.setup {
  -- ...
  sources = cmp.config.sources({
    -- ...
    { name = 'wikilinks' }, -- complete obsidian-style wikilinks against &path
  })
}
```


[nvim-cmp]: https://github.com/hrsh7th/nvim-cmp
