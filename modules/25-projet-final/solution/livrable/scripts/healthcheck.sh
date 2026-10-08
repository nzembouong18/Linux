#!/usr/bin/env bash
# healthcheck.sh -u URL [-t TIMEOUT_S] [-w WARN_MS] [-c CRIT_MS]
# Plugin de supervision (contrat Nagios) : 0 OK · 1 WARNING · 2 CRITICAL · 3 UNKNOWN
unknown() { echo "HTTP UNKNOWN - $1"; exit 3; }

url="" t=5 w=500 c=1000
while getopts ":u:t:w:c:" o; do
  case $o in
    u) url=$OPTARG ;; t) t=$OPTARG ;; w) w=$OPTARG ;; c) c=$OPTARG ;;
    *) unknown "option invalide" ;;
  esac
done
[[ -n $url ]] || unknown "-u URL requis"
[[ $t =~ ^[0-9]+$ && $w =~ ^[0-9]+$ && $c =~ ^[0-9]+$ ]] || unknown "valeurs numériques attendues"
(( w < c )) || unknown "il faut w < c"
command -v curl >/dev/null || unknown "curl absent"

if ! out=$(curl --noproxy '*' -s -o /dev/null -m "$t" -w '%{http_code} %{time_total}' "$url" 2>/dev/null); then
  echo "HTTP CRITICAL - connexion impossible ou délai dépassé|time=0ms;$w;$c;0"
  exit 2
fi
code=${out%% *}
ms=$(awk -v s="${out##* }" 'BEGIN{printf "%d", s*1000}')
if [[ $code != 200 ]]; then
  echo "HTTP CRITICAL - statut $code en ${ms}ms|time=${ms}ms;$w;$c;0"
  exit 2
fi
if (( ms >= c )); then s=CRITICAL; rc=2; elif (( ms >= w )); then s=WARNING; rc=1; else s=OK; rc=0; fi
echo "HTTP $s - 200 in ${ms}ms|time=${ms}ms;$w;$c;0"
exit $rc
