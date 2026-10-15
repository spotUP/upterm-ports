package.path = "./mods/?.lua;" .. package.path
local m = require("mymod")
print(m.greet("lua"), package.loaded.mymod == m)
print(pcall(require, "nosuchmod") == false)
print((package.path:find("/UP-Term/share/lua/5.4/?.lua", 1, true)) ~= nil)
