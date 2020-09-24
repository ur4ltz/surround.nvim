# surround.nvim

> Warning this is a beta and my first plugin. I won't be responsible for broken codes because the parser failed or something. You are encouraged to test this and report bugs and
feature requests.

# Features
## Key mappings

1. Provides key mapping to add surrounding characters.( visually select then press `s<char>` )
2. Provides key mapping to replace surrounding characters.( `sr<from><to>` )
3. Provides key mapping to delete surrounding characters.( `sd<char>` )

## IDK I was bored

1. Cycle surrounding quotes type. (stq)
1. Cycle surrounding brackets type. (stb)
1. Use `<char> == f` for adding, replacing, deleting functions.

# Installation

1. vim-plug: `Plug 'blackcauldron7/surround.nvim'`
1. minPlug:  `MinPlug blackcauldron7/surround.nvim`

- Put this somewhere in your init.vim: `lua require"surround".setup{}`

# Configuration

## Format: for **vimscript** `let g:surround_<option>` and for **lua** `vim.g.surround_<option>`

- pairs: dictionary or lua table of form `{ nestable: {{},...}, linear: {{},....} }` where linear is an array of arrays which contain non nestable pairs of surrounding characters first opening and second closing like ", ' and nestable is an array of arrays which contain nestable pairs of surrounding characters like (, {, [. `(default: { nestable = { {"(", ")"}, {"[", "]"}, {"{", "}"} }, linear = { {"'", "'"}, {'"', '"'} } })`
- context\_offset: number of lines to look for above and below the current line while searching for nestable pairs. `(default: 50)`
- load_\_autogroups: whether to load inbuilt autogroups or not. `(default: false)`
- load_\_keymaps: whether to load inbuilt keymaps or not. `(default: true)`
- quotes: an array of items to be considered as quotes while cycling through them. `(default: ["'", '"']`
- brackets: an array of items to be considered as brackets while cycling through them. `(default: ["(", "{", "["]`

# Caveats

1. Only supports neovim and always will because it's written in lua which is neovim exclusive.
1. Doesn't support python docstrings and html tags yet.
1. No vim docs(idk how to make them. Need help)
2. Beta plugin not tested too much.(Help would be appreciated by testing and reporting bugs)
1. No . repeat support(idk how to achieve this help would be appreciated.) (although there is a mapping `ss` which repeats last surround command.)


# Contributing
You are more than welcome to submit PR for a feature you would like to see or bug fixes.

