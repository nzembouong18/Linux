#!/usr/bin/env bash
# Démo formateur — module 23 (≈ 45 min).
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/demo-lib.sh"
PIDS=()
cleanup() { for p in "${PIDS[@]}"; do kill "$p" 2>/dev/null; done; cd /; rm -rf "$DEMO_DIR"; }
trap cleanup EXIT
fp() { python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()'; }

demo_title "Le format d'exposition Prometheus"
demo_run "printf '# HELP demo_requests_total Requetes traitees.\\n# TYPE demo_requests_total counter\\ndemo_requests_total{code=\"200\"} 1027\\ndemo_requests_total{code=\"500\"} 3\\n# HELP demo_temperature_celsius Temperature.\\n# TYPE demo_temperature_celsius gauge\\ndemo_temperature_celsius 21.5\\n' | tee metrics.prom"
demo_say "counter = cumulatif (on calcule rate()) ; gauge = valeur instantanée ; labels entre accolades."

if command -v prometheus-node-exporter >/dev/null; then
  PORT=$(fp)
  prometheus-node-exporter --web.listen-address="127.0.0.1:$PORT" --collector.disable-defaults --collector.cpu --collector.loadavg --collector.meminfo --collector.filesystem >/dev/null 2>&1 </dev/null &
  PIDS+=($!); sleep 2
  demo_title "node_exporter en direct"
  demo_run "curl --noproxy '*' -s http://127.0.0.1:$PORT/metrics | grep -E '^# (HELP|TYPE) node_load1|^node_load1 '"
  demo_run "curl --noproxy '*' -s http://127.0.0.1:$PORT/metrics | grep -E '^node_memory_Mem(Total|Available)_bytes'"
  demo_run "curl --noproxy '*' -s http://127.0.0.1:$PORT/metrics | awk '/^node_memory_MemTotal_bytes/{t=\$2} /^node_memory_MemAvailable_bytes/{a=\$2} END{printf \"mémoire utilisée: %.1f %%\\n\", (1-a/t)*100}'"
  demo_say "C'est exactement ce que calcule la requête PromQL (1 - MemAvailable/MemTotal) * 100."
  demo_run "curl --noproxy '*' -s http://127.0.0.1:$PORT/metrics | grep -c '^node_cpu_seconds_total'"
else
  demo_say "(prometheus-node-exporter non installé : apt install prometheus-node-exporter)"
fi

demo_title "Contrat d'un plugin Nagios : code retour + texte + perfdata"
demo_run "cat > check_load.sh <<'EOF'
#!/usr/bin/env bash
W=\${1:-2}; C=\${2:-4}
l=\$(cut -d' ' -f1 /proc/loadavg)
if   awk \"BEGIN{exit !(\$l >= \$C)}\"; then s=CRITICAL; rc=2
elif awk \"BEGIN{exit !(\$l >= \$W)}\"; then s=WARNING;  rc=1
else s=OK; rc=0; fi
echo \"LOAD \$s - load1=\$l|load1=\$l;\$W;\$C;0\"; exit \$rc
EOF
chmod +x check_load.sh"
demo_run "./check_load.sh 2 4; echo \"code retour = \$?\""
demo_run "./check_load.sh 0 0; echo \"code retour = \$?\""
demo_run "ls /usr/lib/nagios/plugins 2>/dev/null | head -5 || echo '(monitoring-plugins non installé)'"

demo_title "Règles d'alerte : écrire puis valider"
demo_run "cat > alertes.yml <<'EOF'
groups:
  - name: demo
    rules:
      - alert: HostDown
        expr: up == 0
        for: 2m
        labels: { severity: critical }
        annotations: { summary: \"{{ \$labels.instance }} injoignable\", description: \"Aucune réponse depuis 2 minutes.\" }
EOF
cat alertes.yml | head -4"
if command -v promtool >/dev/null; then
  demo_run "promtool check rules alertes.yml"
  demo_run "sed 's/for: 2m/pour: 2m/' alertes.yml > casse.yml; promtool check rules casse.yml 2>&1 | head -3"
  demo_run "echo 'node_load1 0.57' | promtool check metrics 2>&1 | head -3"
else
  demo_say "(promtool absent : apt install prometheus)"
fi

demo_title "SLI et budget d'erreur à partir d'un journal"
demo_run "awk 'BEGIN{for(i=1;i<=1000;i++){s=200; if(i%50==0)s=500; else if(i%97==0)s=503; printf \"10.0.0.1 - - [x] \\\"GET /p HTTP/1.1\\\" %d 100 %.3f\\n\", s, ((i*37)%1000)/1000+0.01}}' > access.log; wc -l < access.log"
demo_run "awk '\$(NF-2) ~ /^5/ {e++} END {printf \"erreurs 5xx: %d / %d = %.2f %%  → disponibilité %.2f %%\\n\", e, NR, e/NR*100, 100-e/NR*100}' access.log"
demo_run "awk '{print \$NF}' access.log | sort -n | sed -n '950p' | sed 's/^/p95 = /; s/\$/ s/'"
demo_run "awk 'BEGIN{printf \"Budget d erreur SLO 99.5 %% sur 30 j = %d minutes\\n\", 30*24*60*0.005}'"
demo_end
