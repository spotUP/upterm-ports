{ n[$1] += $2 }
END { for (k in n) print k, n[k] | "awk '{ print NR \": \" $0 }'"; close("awk") }
