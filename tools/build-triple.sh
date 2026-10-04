#!/bin/sh
# The build machine's triple, for configure --build (cross builds need it
# named, or configure guesses it is not cross compiling).
for g in /opt/homebrew/share/automake-*/config.guess /usr/share/automake-*/config.guess; do
	[ -x "$g" ] && exec "$g"
done
echo "$(uname -m)-apple-darwin"
