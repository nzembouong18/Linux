#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/lib.sh"
LAB_ID=23
LAB_REQUIRES=(cmd:python3 cmd:awk)

free_port() { python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()'; }

lab_cleanup() {
  local p
  [[ -d "$LAB_DIR" ]] || return 0
  for p in $(pgrep -f "^/usr/bin/prometheus-node-exporter .*127\.0\.0\.1:$(grep -o 'NODE_PORT=[0-9]*' "$LAB_DIR/ports.txt" 2>/dev/null | cut -d= -f2)" 2>/dev/null); do kill "$p" 2>/dev/null; done
  return 0
}

lab_setup() {
  cd "$LAB_DIR" || return 1
  lab_cleanup
  rm -rf donnees ./*.txt ./*.sh ./*.yml
  printf 'NODE_PORT=%s\n' "$(free_port)" > ports.txt
  mkdir -p donnees/sous
  echo aaa > donnees/a.txt; echo bbbb > donnees/b.txt; echo cc > donnees/sous/notes.txt
  echo log > donnees/c.log; echo readme > donnees/README
  awk 'BEGIN{for(i=1;i<=1000;i++){ s=200; if(i%50==0)s=500; else if(i%97==0)s=503; else if(i%13==0)s=404;
    rt=((i*37)%1000)/1000+0.01;
    printf "10.0.0.%d - - [12/Mar/2024:10:%02d:%02d +0000] \"GET /p%d HTTP/1.1\" %d %d %.3f\n", (i%250)+1, int(i/60)%60, i%60, i%20, s, 200+(i*13)%900, rt }}' > access.log
}

kvf() { grep -E "^$2=" "$1" 2>/dev/null | head -1 | cut -d= -f2-; }

# validateur du format d'exposition Prometheus (texte)
prom_valid() { python3 -c "$(cat <<'PY'
import re, sys
text = sys.stdin.read()
help_, typ, seen = set(), {}, set()
name_re = r'[a-zA-Z_:][a-zA-Z0-9_:]*'
for ln in text.splitlines():
    if not ln.strip(): continue
    m = re.match(r'# HELP (' + name_re + r') .+', ln)
    if m: help_.add(m.group(1)); continue
    m = re.match(r'# TYPE (' + name_re + r') (counter|gauge|histogram|summary|untyped)$', ln)
    if m: typ[m.group(1)] = m.group(2); continue
    if ln.startswith('#'): continue
    m = re.match(r'(' + name_re + r')(\{([a-zA-Z_][a-zA-Z0-9_]*="[^"]*"(,[a-zA-Z_][a-zA-Z0-9_]*="[^"]*")*)?\})? (-?[0-9.]+([eE][+-]?[0-9]+)?|NaN|\+Inf|-Inf)$', ln)
    if not m: print("ligne invalide:", ln); sys.exit(1)
    n = m.group(1)
    for suf in ("_bucket", "_sum", "_count"):          # histogram / summary : suffixes rattachés au TYPE de base
        if n.endswith(suf) and typ.get(n[:-len(suf)]) in ("histogram", "summary"):
            n = n[:-len(suf)]; break
    if n not in help_ or n not in typ: print("HELP/TYPE manquant pour", n); sys.exit(1)
    seen.add(n)
sys.exit(0 if seen else 1)
PY
)"; }
prom_val() { # prom_val <nom[{labels}]> < texte → valeur
  python3 -c "import sys; k=sys.argv[1]
for l in sys.stdin:
    if l.startswith(k+' '): print(l.split()[-1]); break" "$1"
}

dur_ok() { python3 - "$1" "$2" <<'PY'
import re, sys
s, minimum = sys.argv[1], int(sys.argv[2])
m = re.fullmatch(r'(\d+)(s|m|h)', s.strip())
if not m: sys.exit(1)
sec = int(m.group(1)) * {'s': 1, 'm': 60, 'h': 3600}[m.group(2)]
sys.exit(0 if sec >= minimum else 1)
PY
}

lab_check() {
  cd "$LAB_DIR" || return 1
  # ---- A
  if command -v prometheus-node-exporter >/dev/null; then
    assert "A2 metrics.txt : format d'exposition valide" bash -c "$(declare -f prom_valid); prom_valid < metrics.txt"
    assert "A2 metrics.txt contient node_load1, node_cpu_seconds_total, node_memory_MemTotal_bytes" bash -c "grep -q '^node_load1 ' metrics.txt && grep -q '^node_cpu_seconds_total{' metrics.txt && grep -q '^node_memory_MemTotal_bytes ' metrics.txt"
    local real; real=$(awk '/^MemTotal:/{print $2*1024}' /proc/meminfo)
    assert_eq "A3 MEM_TOTAL_BYTES (entier, = /proc/meminfo)" "$real" "$(kvf infos.txt MEM_TOTAL_BYTES)"
    assert_eq "A3 TYPE_LOAD1" gauge "$(kvf infos.txt TYPE_LOAD1)"
    assert_eq "A3 TYPE_CPU" counter "$(kvf infos.txt TYPE_CPU)"
    local nc; nc=$(grep '^node_cpu_seconds_total{' metrics.txt 2>/dev/null | grep -o 'cpu="[0-9]*"' | sort -u | wc -l)
    assert_eq "A3 NB_COEURS (cohérent avec metrics.txt)" "$nc" "$(kvf infos.txt NB_COEURS)"
    assert "A3 NB_COEURS ≥ 1" bash -c "[[ ${nc:-0} -ge 1 ]]"
  else
    skip "A node_exporter (paquet prometheus-node-exporter absent)"
  fi
  # ---- B
  assert "B exporteur.sh exécutable" test -x exporteur.sh
  assert "B format d'exposition valide (HELP/TYPE/valeurs)" bash -c "$(declare -f prom_valid); ./exporteur.sh donnees | prom_valid"
  local out; out=$(./exporteur.sh donnees 2>/dev/null)
  assert_eq "B lab_up = 1" 1 "$(prom_val lab_up <<<"$out")"
  assert_eq "B lab_files (donnees/) = 5" 5 "$(prom_val lab_files <<<"$out")"
  assert_eq "B lab_size_bytes (donnees/)" "$(find donnees -type f -printf '%s\n' | awk '{s+=$1} END{print s}')" "$(prom_val lab_size_bytes <<<"$out")"
  assert_eq "B lab_files_by_ext{ext=\"txt\"} = 3" 3 "$(prom_val 'lab_files_by_ext{ext="txt"}' <<<"$out")"
  assert_eq "B lab_files_by_ext{ext=\"none\"} = 1" 1 "$(prom_val 'lab_files_by_ext{ext="none"}' <<<"$out")"
  assert "B TYPE lab_files = gauge" grep -q '^# TYPE lab_files gauge$' <<<"$out"
  local t; t=$(mktemp -d); touch "$t/1.log" "$t/2.log" "$t/3.log" "$t/x.csv" "$t/y"; echo 12345 > "$t/y"
  local o2; o2=$(./exporteur.sh "$t" 2>/dev/null)
  assert_eq "B autre dossier : 5 fichiers" 5 "$(prom_val lab_files <<<"$o2")"
  assert_eq "B autre dossier : ext log = 3" 3 "$(prom_val 'lab_files_by_ext{ext="log"}' <<<"$o2")"
  assert_eq "B autre dossier : ext csv = 1" 1 "$(prom_val 'lab_files_by_ext{ext="csv"}' <<<"$o2")"
  assert_eq "B autre dossier : taille = 6 octets" 6 "$(prom_val lab_size_bytes <<<"$o2")"
  rm -rf "$t"
  ./exporteur.sh /dossier/absent >/dev/null 2>&1; assert_eq "B dossier absent → code 1" 1 "$?"
  # ---- C
  assert "C check_disk.sh exécutable" test -x check_disk.sh
  cd_run() { # cd_run <pcent> args... → "rc|sortie"
    local p=$1; shift; local o; o=$(FAKE_PCENT=$p ./check_disk.sh "$@" 2>/dev/null); echo "$?|$o"; }
  assert_eq "C 42%  w80 c90 → 0 OK + perfdata" "0|DISK OK - 42% used|used=42%;80;90;0;100" "$(cd_run 42 -w 80 -c 90)"
  assert_eq "C 85%  → 1 WARNING" "1|DISK WARNING - 85% used|used=85%;80;90;0;100" "$(cd_run 85 -w 80 -c 90)"
  assert_eq "C 80%  (= seuil w) → 1" "1|DISK WARNING - 80% used|used=80%;80;90;0;100" "$(cd_run 80 -w 80 -c 90)"
  assert_eq "C 90%  (= seuil c) → 2 CRITICAL" "2|DISK CRITICAL - 90% used|used=90%;80;90;0;100" "$(cd_run 90 -w 80 -c 90)"
  assert_eq "C 99%  → 2" "2|DISK CRITICAL - 99% used|used=99%;80;90;0;100" "$(cd_run 99 -w 80 -c 90)"
  local r
  r=$(cd_run 50 -w abc -c 90); [[ $r == 3\|DISK\ UNKNOWN* ]] && ok "C -w abc → 3 UNKNOWN" || ko "C -w abc → 3 UNKNOWN (obtenu: $r)"
  r=$(cd_run 50 -w 90 -c 80); [[ $r == 3\|DISK\ UNKNOWN* ]] && ok "C w ≥ c → 3 UNKNOWN" || ko "C w ≥ c → 3 UNKNOWN (obtenu: $r)"
  r=$(cd_run 50); [[ $r == 3\|DISK\ UNKNOWN* ]] && ok "C sans -w/-c → 3 UNKNOWN" || ko "C sans -w/-c → 3 UNKNOWN (obtenu: $r)"
  ./check_disk.sh -w 99 -c 100 -p / >/dev/null 2>&1; rc=$?
  if [[ $rc -le 2 ]]; then ok "C df réel sur / : code 0, 1 ou 2"; else ko "C df réel sur / : code $rc"; fi
  ./check_disk.sh -w 80 -c 90 -p /chemin/absent >/dev/null 2>&1; assert_eq "C chemin absent → 3" 3 "$?"
  # ---- D
  yaml_ok() { python3 - "$1" <<'PY'
import sys, re, yaml
name = sys.argv[1]
d = yaml.safe_load(open("alertes.yml"))
rules = {r["alert"]: r for g in d["groups"] for r in g.get("rules", []) if "alert" in r}
r = rules.get(name)
if not r: sys.exit(1)
def secs(s):
    m = re.fullmatch(r'(\d+)(s|m|h)', str(s).strip()); return int(m.group(1)) * {'s':1,'m':60,'h':3600}[m.group(2)] if m else -1
e, f, sev = str(r.get("expr", "")), secs(r.get("for", "0s")), (r.get("labels") or {}).get("severity")
an = r.get("annotations") or {}
common = an.get("summary") and an.get("description")
checks = {
 "HostDown": re.search(r'\bup\s*==\s*0', e) and f >= 60 and sev == "critical",
 "HighCPU": "node_cpu_seconds_total" in e and "idle" in e and "rate(" in e and re.search(r'>\s*90', e) and f >= 300 and sev == "warning",
 "DiskAlmostFull": "node_filesystem_avail_bytes" in e and "node_filesystem_size_bytes" in e and re.search(r'>\s*0\.9|<\s*0\.1', e) and f >= 600 and sev == "warning",
 "MemoryLow": "node_memory_MemAvailable_bytes" in e and "node_memory_MemTotal_bytes" in e and re.search(r'<\s*0?\.1\b|<\s*10\b', e) and f >= 300 and sev in ("warning", "critical"),
}
sys.exit(0 if (common and checks[name]) else 1)
PY
  }
  if python3 -c 'import yaml' 2>/dev/null; then
    local a; for a in HostDown HighCPU DiskAlmostFull MemoryLow; do assert "D alerte $a (expr, for, severity, annotations)" yaml_ok "$a"; done
  else
    skip "D alertes.yml (PyYAML absent : apt install python3-yaml)"
  fi
  if command -v promtool >/dev/null; then assert "D promtool check rules" promtool check rules alertes.yml; fi
  # ---- E
  local T N5 s; T=$(wc -l < access.log); N5=$(awk '$(NF-2) ~ /^5/' access.log | wc -l); s=sli.txt
  assert_eq "E TOTAL" "$T" "$(kvf $s TOTAL)"
  assert_eq "E NB_5XX" "$N5" "$(kvf $s NB_5XX)"
  assert_eq "E TAUX_ERREUR_PCT" "$(awk -v n="$N5" -v t="$T" 'BEGIN{printf "%.2f", n/t*100}')" "$(kvf $s TAUX_ERREUR_PCT)"
  assert_eq "E DISPONIBILITE_PCT" "$(awk -v n="$N5" -v t="$T" 'BEGIN{printf "%.2f", 100-n/t*100}')" "$(kvf $s DISPONIBILITE_PCT)"
  local idx; idx=$(awk -v t="$T" 'BEGIN{x=0.95*t; print (x==int(x))?x:int(x)+1}')
  assert_eq "E P95_S" "$(awk '{print $NF}' access.log | sort -n | sed -n "${idx}p")" "$(kvf $s P95_S)"
  assert_eq "E BUDGET_MINUTES (99,5 % sur 30 j)" 216 "$(kvf $s BUDGET_MINUTES)"
  assert_eq "E SLO_RESPECTE" "$(awk -v n="$N5" -v t="$T" 'BEGIN{print (100-n/t*100>=99.5)?"oui":"non"}')" "$(kvf $s SLO_RESPECTE)"
  assert_eq "E GOLDEN_SIGNALS" "errors,latency,saturation,traffic" "$(kvf $s GOLDEN_SIGNALS | tr ',' '\n' | sort | paste -sd,)"
}

lab_solve() {
  cd "$LAB_DIR" || return 1
  # shellcheck disable=SC1091
  . ./ports.txt
  if command -v prometheus-node-exporter >/dev/null; then
    prometheus-node-exporter --web.listen-address="127.0.0.1:$NODE_PORT" --collector.disable-defaults --collector.cpu --collector.loadavg --collector.meminfo --collector.filesystem >/dev/null 2>&1 </dev/null &
    local exp=$! i
    for i in $(seq 1 30); do curl --noproxy '*' -s "http://127.0.0.1:$NODE_PORT/metrics" -o metrics.txt && grep -q '^node_load1 ' metrics.txt && break; sleep 0.3; done
    kill "$exp" 2>/dev/null
    { echo "MEM_TOTAL_BYTES=$(awk '/^node_memory_MemTotal_bytes /{printf "%.0f", $2}' metrics.txt)"
      echo "TYPE_LOAD1=$(awk '/^# TYPE node_load1 /{print $4}' metrics.txt)"
      echo "TYPE_CPU=$(awk '/^# TYPE node_cpu_seconds_total /{print $4}' metrics.txt)"
      echo "NB_COEURS=$(grep '^node_cpu_seconds_total{' metrics.txt | grep -o 'cpu="[0-9]*"' | sort -u | wc -l)"; } > infos.txt
  fi
  cat > exporteur.sh <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
dir=${1:-donnees}
[[ -d $dir ]] || { echo "Dossier introuvable: $dir" >&2; exit 1; }
files=$(find "$dir" -type f | wc -l)
size=$(find "$dir" -type f -printf '%s\n' | awk '{s+=$1} END{print s+0}')
echo '# HELP lab_up Indique que lexporteur fonctionne.'; echo '# TYPE lab_up gauge'; echo 'lab_up 1'
echo '# HELP lab_files Nombre de fichiers.'; echo '# TYPE lab_files gauge'; echo "lab_files $files"
echo '# HELP lab_size_bytes Taille totale en octets.'; echo '# TYPE lab_size_bytes gauge'; echo "lab_size_bytes $size"
echo '# HELP lab_files_by_ext Fichiers par extension.'; echo '# TYPE lab_files_by_ext gauge'
find "$dir" -type f -printf '%f\n' | awk '{ n=split($0,a,"."); e=(n>1 && a[1]!="")?a[n]:"none"; c[e]++ } END{for(e in c) printf "lab_files_by_ext{ext=\"%s\"} %d\n", e, c[e]}' | sort
EOS
  chmod +x exporteur.sh
  cat > check_disk.sh <<'EOS'
#!/usr/bin/env bash
unknown() { echo "DISK UNKNOWN - $1"; exit 3; }
W="" C="" P="/"
while getopts ":w:c:p:" o; do case $o in w) W=$OPTARG;; c) C=$OPTARG;; p) P=$OPTARG;; *) unknown "option invalide";; esac; done
[[ $W =~ ^[0-9]+$ && $C =~ ^[0-9]+$ ]] || unknown "-w et -c requis (entiers)"
(( W < C && C <= 100 )) || unknown "il faut w < c <= 100"
if [[ -n ${FAKE_PCENT:-} ]]; then U=$FAKE_PCENT
else [[ -e $P ]] || unknown "chemin absent: $P"; U=$(df --output=pcent "$P" 2>/dev/null | tail -1 | tr -dc 0-9); [[ -n $U ]] || unknown "df a échoué"; fi
if (( U >= C )); then s=CRITICAL; rc=2; elif (( U >= W )); then s=WARNING; rc=1; else s=OK; rc=0; fi
echo "DISK $s - ${U}% used|used=${U}%;${W};${C};0;100"; exit $rc
EOS
  chmod +x check_disk.sh
  cat > alertes.yml <<'EOS'
groups:
  - name: machines
    rules:
      - alert: HostDown
        expr: up == 0
        for: 2m
        labels: { severity: critical }
        annotations: { summary: "{{ $labels.instance }} injoignable", description: "La cible ne répond plus depuis 2 minutes." }
      - alert: HighCPU
        expr: 100 - (avg by (instance)(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 90
        for: 5m
        labels: { severity: warning }
        annotations: { summary: "CPU élevé sur {{ $labels.instance }}", description: "Plus de 90 % de CPU depuis 5 minutes." }
      - alert: DiskAlmostFull
        expr: (1 - node_filesystem_avail_bytes{fstype!~"tmpfs|overlay"} / node_filesystem_size_bytes) > 0.9
        for: 10m
        labels: { severity: warning }
        annotations: { summary: "Disque presque plein sur {{ $labels.instance }}", description: "Plus de 90 % utilisés depuis 10 minutes." }
      - alert: MemoryLow
        expr: node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes < 0.1
        for: 5m
        labels: { severity: critical }
        annotations: { summary: "Mémoire faible sur {{ $labels.instance }}", description: "Moins de 10 % de mémoire disponible depuis 5 minutes." }
EOS
  local T N5; T=$(wc -l < access.log); N5=$(awk '$(NF-2) ~ /^5/' access.log | wc -l)
  local idx; idx=$(awk -v t="$T" 'BEGIN{x=0.95*t; print (x==int(x))?x:int(x)+1}')
  { echo "TOTAL=$T"; echo "NB_5XX=$N5"
    echo "TAUX_ERREUR_PCT=$(awk -v n="$N5" -v t="$T" 'BEGIN{printf "%.2f", n/t*100}')"
    echo "DISPONIBILITE_PCT=$(awk -v n="$N5" -v t="$T" 'BEGIN{printf "%.2f", 100-n/t*100}')"
    echo "P95_S=$(awk '{print $NF}' access.log | sort -n | sed -n "${idx}p")"
    echo "BUDGET_MINUTES=216"
    echo "SLO_RESPECTE=$(awk -v n="$N5" -v t="$T" 'BEGIN{print (100-n/t*100>=99.5)?"oui":"non"}')"
    echo "GOLDEN_SIGNALS=latency,traffic,errors,saturation"; } > sli.txt
}

lab_main "$@"
