max_line_length = false
allow_defined = false -- Do NOT allow implicitly defined globals.
allow_defined_top = false -- Do NOT allow implicitly defined globals.

files = {
  ['main.lua'] = {
    std = 'luajit+love',
  },
  ['bump-3dpd.lua'] = {
    std = 'luajit',
  },
  ['spec/*'] = {
    std = 'luajit+busted',
  },
}

exclude_files = {
  'lua_install/*', -- CI: hererocks
  'demolibs/*',
  'bump-3dpd-original.lua',
}
