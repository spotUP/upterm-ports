# htop's own meters must show real values: run htop with its screen in a file, then look at the text.
# Prints the verdict to values.res (the case's file); the Mac and the rig must both write "ok".
(sleep 4; printf q) | htop > values.scr 2>/dev/null
e=$(printf '\033')
t=$(sed "s/$e[^a-zA-Z]*[a-zA-Z]//g" values.scr | tr -d '\r')
v=ok
echo "$t" | grep -q 'Tasks' || v=no-tasks-meter
echo "$t" | grep 'Tasks:' | grep -q 'Tasks: 0,' && v=tasks-0
echo "$t" | grep -q 'NaN' && v=mem-nan
echo "$t" | grep -q '(unknown)' && v=uptime-unknown
echo $v > values.res
