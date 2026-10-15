local f = assert(io.open("/tmp/lua-io-test.txt", "w"))
f:write("line one\n", 42, "\nlast\n")
f:close()
for l in io.lines("/tmp/lua-io-test.txt") do print("[" .. l .. "]") end
local r = assert(io.open("/tmp/lua-io-test.txt", "r"))
print(r:read("l"), r:read("n"), r:read("a"))
r:close()
print((io.open("/tmp/no-such-file-here", "r")))
os.remove("/tmp/lua-io-test.txt")
