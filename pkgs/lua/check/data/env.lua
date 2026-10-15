print(os.getenv("LUA_TEST_VAR"), os.getenv("LUA_NO_SUCH_VAR"))
print(type(os.time()), os.date("%Y", 0) ~= nil)
