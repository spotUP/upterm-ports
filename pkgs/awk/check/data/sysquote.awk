BEGIN { system("echo \"q\" a*b 'it is'"); c = "awk '{ print \"got:\" $0 }'"; print "x" | c; close(c) }
