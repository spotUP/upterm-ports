# builds a two-commit repository with fixed names and dates, then runs tig on it
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=nogcfg TZ=UTC GIT_AUTHOR_DATE='2020-01-01T00:00:00+0000' GIT_COMMITTER_DATE='2020-01-01T00:00:00+0000'
g() { git -c user.name=Tester -c user.email=tester@example.com -c core.pager=cat -c gc.auto=0 -c init.defaultBranch=main "$@"; }
rm -rf repo
g init -q repo && cd repo && echo one > a.txt && g add a.txt && g commit -q -m first && echo two >> a.txt && g commit -q -a -m second
exec tig "$@"
