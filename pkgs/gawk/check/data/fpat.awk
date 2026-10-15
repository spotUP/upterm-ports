BEGIN { FPAT = "([^,]+)|(\"[^\"]+\")"; $0 = "a,\"b,c\",d"; print NF, $2 }
