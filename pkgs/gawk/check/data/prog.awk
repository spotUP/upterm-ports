{ n[$1] += $2 }
END { for (k in n) print k, n[k] | "gawk '{ print NR \": \" $0 }'"; close("gawk") }
