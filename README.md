# upterm-ports

Recipes and patches that build Unix tools for the UP-Term AmigaOS kit. Part of the upterm source tree.

`make kit-stage` copies the programs of every checked package to `build/kit/userland/bin` and writes `build/kit/userland/SOURCES.txt` there (package, version, URL, sha256, licence); the vtcon kit does not read it (`make dist` in vtcon does not use it).
