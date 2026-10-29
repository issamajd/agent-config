#!/bin/zsh
# Average CPU of an app and of its simulator's compositor (backboardd) over a window.
# usage: sim-cpu.sh <simulator udid> <app executable name> <seconds> [label]
udid=$1; exe=$2; secs=$3; label=${4:-window}
ld=$(pgrep -f "launchd_sim .*$udid")
app=$(ps -axo pid=,ppid=,command= | awk -v p="$ld" -v e="$exe" '$2==p && $3 ~ ("\\.app/" e "$") {print $1}')
bb=$(ps -axo pid=,ppid=,command= | awk -v p="$ld" '$2==p && /backboardd$/ {print $1}')
[[ -n $app && -n $bb ]] || { echo "App or simulator not running." >&2; exit 2; }
t() { ps -o time= -p $1 | tr -d ' ' | awk -F: '{ if (NF==2) print $1*60+$2; else print $1*3600+$2*60+$3 }'; }
a0=$(t $app); b0=$(t $bb)
perl -e "select(undef,undef,undef,$secs)"
a1=$(t $app); b1=$(t $bb)
awk -v l="$label" -v a0=$a0 -v a1=$a1 -v b0=$b0 -v b1=$b1 -v s=$secs \
  'BEGIN{printf "%-30s app %6.1f%%   compositor %6.1f%%   (%ds)\n", l, 100*(a1-a0)/s, 100*(b1-b0)/s, s}'
