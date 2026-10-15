{ v[NR] = $1 }
END { n = asort(v, w); for (i = 1; i <= n; i++) print i, w[i]; print length(v), PROCINFO["version"] != "" }
