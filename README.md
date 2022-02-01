## surround.nvim

## Features

### Key mappings

### There are two keymap modes for normal mode mappings.

- sandwich and surround and they can be set using the options mentioned below.

#### Normal Mode - Sandwich Mode

1. Provides key mapping to add surrounding characters.( visually select then press `s<char>` or press `sa{motion}{char}`)
2. Provides key mapping to replace surrounding characters.( `sr<from><to>` )
3. Provides key mapping to delete surrounding characters.( `sd<char>` )
4. `ss` repeats last surround command.

#### Normal Mode - Surround Mode

1. Provides key mapping to add surrounding characters.( visually select then press `s<char>` or press `ys{motion}{char}`)
2. Provides key mapping to replace surrounding characters.( `cs<from><to>` )
3. Provides key mapping to delete surrounding characters.( `ds<char>` )

#### Insert Mode

- `<c-s><char>` will insert both pairs in insert mode.
- `<c-s><char><space>` will insert both pairs in insert mode with surrounding whitespace.
- `<c-s><char><c-s>` will insert both pairs on newlines insert mode.

### IDK I was bored

1. Cycle surrounding quotes type. (`stq`)
1. Cycle surrounding brackets type. (`stb`)
1. Use `<char> == f` for adding, replacing, deleting functions.

## Installation

1. vim-plug: `Plug 'blackcauldron7/surround.nvim'` and Put this somewhere in your init.vim: `lua require"surround".setup{}`
1. minPlug: `MinPlug blackcauldron7/surround.nvim` and Put this somewhere in your init.vim: `lua require"surround".setup{}`
1. Packer.nvim

```lua
use {
  "blackCauldron7/surround.nvim",
  config = function()
    require"surround".setup {mappings_style = "sandwich"}
  end
}
```

OR

```lua
use {
  "blackCauldron7/surround.nvim",
  config = function()
    require"surround".setup {mappings_style = "surround"}
  end
}
```



## Configuration

### Format: for **vimscript** `let g:surround_<option>` and for **lua** `vim.g.surround_<option>`

- `prefix`: prefix for sandwich mode. `(default: s)`
- `pairs`: dictionary or lua table of form `{ nestable: {{},...}, linear: {{},....} }` where linear is an array of arrays which contain non-nestable pairs of surrounding characters first opening and second closing like ", ' and nestable is an array of arrays which contain nestable pairs of surrounding characters like (, {, [. The key to each pair can be used as an alias instead of either value. For single-character pairs, this alias is optional and you can just use either value. For pairs that use multiple characters per bracket, an alias is required. You can for example set ```pairs = { linear = { Q = {'"""','"""'} } }``` to use Q to add triple double quotes around selected text. The key "f" is used to add/replace functions, configuring it for a pair will override that functionality.
  + Aliases must be a single letter.
  + Aliases are case-sensitive.
  + Aliases must be unique across the entire `pairs` table.
  + When adding your own pairs, you do not need to specify the defaults. Your own values will be added to the default table and overwrite aliases when necessary.
  + Defaults:
```lua
{
  nestable = {
    b = { "(", ")" },
    s = { "[", "]" },
    B = { "{", "}" },
    a = { "<", ">" }
    },
  linear = {
    q = { "'", "'" },
    t = { "`", "`" },
    d = { '"', '"' }
  },
}
```
- `context_offset`: number of lines to look for above and below the current line while searching for nestable pairs. `(default: 100)`
- `prompt`: whether to print a prompt in the command window asking for input. `(default: true)`
- `load_autogroups`: whether to load inbuilt autogroups or not. `(default: false)`
- `mappings_style`: "surround" or "sandwich" `(default: sandwich)`
- `load_keymaps`: whether to load inbuilt keymaps or not. `(default: true)`
- `quotes`: an array of items to be considered as quotes while cycling through them. `(default: ["'", '"'])`
- `brackets`: an array of items to be considered as brackets while cycling through them. `(default: ["(", "{", "["])`
- `map_insert_mode`: whether to load insert mode mappings or not. `(default: true)`
- `space_on_closing_char`: if the closing char should add surround space rather than the opening char. `(default: false)`
- `space_on_alias`: if the alias should add surround space. `(default: false)`

### or pass a lua table to the setup function

```lua
require"surround".setup {
  context_offset = 100,
  load_autogroups = false,
  mappings_style = "sandwich",
  map_insert_mode = true,
  quotes = {"'", '"'},
  brackets = {"(", '{', '['},
  space_on_closing_char = false,
  pairs = {
    nestable = { b = { "(", ")" }, s = { "[", "]" }, B = { "{", "}" }, a = { "<", ">" } },
    linear = { q = { "'", "'" }, t = { "`", "`" }, d = { '"', '"' }
  },
  prefix = "s"
}
```

## Caveats

1. Only supports neovim and always will because it's written in lua which is neovim exclusive.
1. ~~Doesn't support python docstrings and html tags yet.~~ Either can be added to the `pairs` table with an alias as shortcut. (No dynamic tags yet, though. You need to add the tags you want beforehand.)
1. No vim docs(idk how to make them. Need help)
1. Support for repeating actions with `.` requires [tpope's vim-repeat](https://github.com/tpope/vim-repeat).

## Contributing

You are more than welcome to submit PR for a feature you would like to see or bug fixes.
