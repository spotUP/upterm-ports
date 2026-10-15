BEGIN { system("echo \"q\" a*b 'it is'"); c = "gawk '{ print \"got:\" $0 }'"; print "x" | c; close(c) }
