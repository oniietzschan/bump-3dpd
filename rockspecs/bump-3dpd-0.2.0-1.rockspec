package = "bump-3dpd"
version = "0.2.0-1"
source = {
   url = "git://github.com/oniietzschan/bump-3dpd",
   tag = "0.2.0",
}
description = {
   summary = "A 3D collision detection library for Lua",
   detailed = [[
   bump-3dpd is a library for for resolving collisions between three-dimensional
   axis-aligned bounding boxes (AABBs). It is ideal for simple games that require
   non-realistic physics.
   ]],
   homepage = "http://github.com/oniietzschan/bump-3dpd",
   license = "MIT",
}
dependencies = {
   "lua >= 5.1",
}
build = {
   type = "builtin",
   modules = {
      ["bump-3dpd"] = "bump-3dpd.lua",
   },
}
