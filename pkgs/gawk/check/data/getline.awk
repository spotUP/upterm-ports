BEGIN { while (("echo one two" | getline line) > 0) print "got", line }
