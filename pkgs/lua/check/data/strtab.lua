local s = "Amiga Term"
print(s:upper(), #s, s:sub(1, 5), s:find("Term"), s:rep(2, "-"))
print(string.format("%5.2f|%-4d|%s", 3.14159, 42, "x"), ("a,b,c"):gsub(",", ";"))
local t = {5, 3, 9, 1}
table.sort(t)
print(table.concat(t, " "), #t, select("#", table.unpack(t)))
table.insert(t, 7) table.remove(t, 1)
print(table.concat(t, ","))
