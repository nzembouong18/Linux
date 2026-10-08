#!/usr/bin/env bash
# Démo formateur — module 24 (≈ 45 min).
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/demo-lib.sh"

demo_title "Calcul de disponibilité : série vs parallèle"
demo_run "awk 'BEGIN{a=0.99; printf \"1 composant   : %.4f %%\\n\", a*100; printf \"2 en série    : %.4f %%\\n\", a*a*100; printf \"2 en parallèle: %.4f %%\\n\", (1-(1-a)*(1-a))*100}'"
demo_run "awk 'BEGIN{for(i=2;i<=5;i++){a=1-10^(-i); printf \"%2d neuf(s) → %8.2f min d indisponibilité / an\\n\", i, (1-a)*365*24*60}}'"
demo_run "awk 'BEGIN{for(n=3;n<=6;n++) printf \"cluster de %d noeuds : quorum %d, tolère %d panne(s)\\n\", n, int(n/2)+1, n-(int(n/2)+1)}'"
demo_say "Avec 4 nœuds, on tolère 1 panne comme avec 3 : le nombre pair n'apporte rien (et 2/2 bloque)."

demo_title "Sauvegardes : vérifier avant de croire"
demo_run "mkdir -p src bak && for i in 1 2 3; do echo \"donnee \$i\" > src/f\$i.txt; done"
demo_run "for d in lun mar mer; do echo \"v-\$d\" > src/version.txt; tar -czf bak/site-\$d.tgz src; done; sha256sum bak/*.tgz > SHA256SUMS; ls bak"
demo_say "Simulons une corruption silencieuse de la sauvegarde de mardi et une archive tronquée mercredi :"
demo_run "printf 'X' >> bak/site-mar.tgz; truncate -s 40 bak/site-mer.tgz"
demo_run "sha256sum -c SHA256SUMS 2>&1 | sed 's/^/  /'"
demo_run "for f in bak/*.tgz; do tar -tzf \$f >/dev/null 2>&1 && echo \"\$f lisible\" || echo \"\$f ILLISIBLE\"; done"
demo_say "Seule 'lun' est saine : c'est elle qu'on restaure — et le RPO réel s'en trouve allongé."

demo_title "Une logique de basculement avec fencing (simulation)"
demo_run "mkdir etat && echo up > etat/noeud1.health && echo up > etat/noeud2.health && echo noeud1 > etat/vip"
cat > bascule.sh <<'EOF'
#!/usr/bin/env bash
d=$1
avail() { [[ $(cat "$d/$1.health") == up && ! -e "$d/$1.fence" ]]; }
owner=$(cat "$d/vip"); [[ $owner == noeud1 ]] && o=noeud2 || o=noeud1
avail "$owner" && { echo "OK: $owner actif"; exit 0; }
avail "$o" && { echo fenced > "$d/$owner.fence"; echo "$o" > "$d/vip"; echo "BASCULE: $owner -> $o"; exit 1; }
echo "PANNE TOTALE"; exit 2
EOF
chmod +x bascule.sh
demo_run "./bascule.sh etat; echo \"rc=\$?\""
demo_run "echo down > etat/noeud1.health; ./bascule.sh etat; echo \"rc=\$?\"; cat etat/vip; ls etat"
demo_run "echo up > etat/noeud1.health; ./bascule.sh etat; echo \"(noeud1 revenu mais isolé, pas de fail-back) rc=\$?\""
demo_run "echo down > etat/noeud2.health; ./bascule.sh etat; echo \"rc=\$?\""

demo_title "Configurations keepalived / HAProxy : valider avant de déployer"
demo_run "printf 'global_defs {\\n  enable_script_security\\n  script_user root\\n}\\nvrrp_script chk {\\n  script \"/usr/bin/pgrep haproxy\"\\n  interval 2\\n  weight -60\\n}\\nvrrp_instance VI {\\n  state MASTER\\n  interface eth0\\n  virtual_router_id 51\\n  priority 150\\n  virtual_ipaddress {\\n    192.168.50.100/24\\n  }\\n  track_script {\\n    chk\\n  }\\n}\\n' > ka.conf"
if command -v keepalived >/dev/null; then
  demo_run "keepalived -t -f ka.conf; echo \"rc=\$?\""
  demo_run "sed 's/priority/priorityy/' ka.conf > ka-casse.conf; keepalived -t -f ka-casse.conf 2>&1 | head -2"
fi
demo_say "Priorité effective du MASTER si le script échoue : 150 − 60 = 90 < 100 (BACKUP) → la VIP bascule."
if command -v haproxy >/dev/null; then
  demo_run "printf 'defaults\\n  mode http\\n  timeout connect 5s\\n  timeout client 30s\\n  timeout server 30s\\nfrontend web\\n  bind *:8080\\n  default_backend app\\nbackend app\\n  balance roundrobin\\n  option httpchk GET /health\\n  server a1 10.0.0.11:8080 check\\n  server a2 10.0.0.12:8080 check\\n  server a3 10.0.0.13:8080 check backup\\n' > hp.cfg; haproxy -c -f hp.cfg"
fi
demo_end
