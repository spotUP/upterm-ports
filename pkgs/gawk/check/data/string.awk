BEGIN { s = "Hello, World"; print length(s), substr(s, 8), index(s, "W"), toupper(s)
  n = split("a:b:c", p, ":"); print n, p[3]; t = s; gsub(/o/, "0", t); print t }
