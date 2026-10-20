-- KoboldOS colorscheme — Crimson / Charcoal / Gold / Ivory, matching the sway,
-- foot, waybar and mako configs. Built on tokyonight (LazyVim's default) so
-- every plugin LazyVim ships is themed: we hand it our own palette as a style.

-- stylua: ignore
local palette = {
  bg             = "#1B1B1B", -- charcoal
  bg_dark        = "#151515",
  bg_dark1       = "#101010",
  bg_highlight   = "#2A2A2A",
  fg             = "#F5F0E6", -- ivory
  fg_dark        = "#D8D2C4",
  fg_gutter      = "#3A3A3A",
  comment        = "#857D6E",
  dark3          = "#4A4A4A",
  dark5          = "#A89F8C",
  terminal_black = "#3A3A3A",

  red            = "#D0505A", -- builtins, tags
  red1           = "#B0313A", -- errors
  purple         = "#CF4A52", -- keywords: crimson
  magenta        = "#B57A8A", -- rose
  magenta2       = "#E0BB63",
  blue           = "#E0BB63", -- functions: gold
  blue0          = "#8B1E24", -- selection / search: sway focused crimson
  blue1          = "#6BA39D", -- types
  blue2          = "#6BA39D", -- info
  blue5          = "#A89F8C", -- operators, punctuation
  blue6          = "#E0BB63",
  blue7          = "#5A4A26", -- diff change
  cyan           = "#7FB3AD",
  teal           = "#6BA39D", -- hints
  green          = "#A3B06A", -- strings: olive
  green1         = "#C9B98E", -- properties
  green2         = "#6E7B3E", -- diff add
  yellow         = "#D8C08A", -- parameters, warnings
  orange         = "#D98A4E", -- constants, numbers

  git = { add = "#8A9A50", change = "#C8A24A", delete = "#B0313A" },
}

-- tokyonight loads styles via its own module loader, which honours package.loaded.
package.loaded["tokyonight.colors.koboldos"] = palette

require("tokyonight").load({
  style = "koboldos",
  on_colors = function(c)
    c.bg_visual = "#4A1A1E" -- crimson, dimmed enough to keep text readable
    c.border = "#3A3A3A"
    c.border_highlight = "#C8A24A" -- gold, like the sway focus indicator
    c.warning = "#C8A24A"

    -- Same ANSI colours as foot, so :terminal matches the real terminal.
    -- stylua: ignore
    c.terminal = {
      black   = "#1B1B1B", black_bright   = "#3A3A3A",
      red     = "#8B1E24", red_bright     = "#B0313A",
      green   = "#6E7B3E", green_bright   = "#8A9A50",
      yellow  = "#C8A24A", yellow_bright  = "#E0BB63",
      blue    = "#4E6A85", blue_bright    = "#6A88A5",
      magenta = "#8B4A5A", magenta_bright = "#A96578",
      cyan    = "#4E807C", cyan_bright    = "#6BA39D",
      white   = "#D8D2C4", white_bright   = "#F5F0E6",
    }
  end,
  on_highlights = function(hl, c)
    hl.CursorLineNr = { fg = "#C8A24A", bold = true }
    hl.Search = { bg = "#8B1E24", fg = c.fg }
    hl.IncSearch = { bg = "#C8A24A", fg = c.bg }
    hl.CurSearch = hl.IncSearch
  end,
})

vim.g.colors_name = "koboldos"
