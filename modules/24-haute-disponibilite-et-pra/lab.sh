#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/lib.sh"
LAB_ID=24
LAB_REQUIRES=(cmd:tar cmd:sha256sum cmd:date)

lab_setup() {
  cd "$LAB_DIR" || return 1
  rm -rf backups restauration .attendu ./*.txt bascule.sh keepalived-*.conf haproxy.cfg SHA256SUMS
  mkdir -p backups
  local d tmp; tmp=$(mktemp -d)
  : > SHA256SUMS
  for d in 10 11 12 13 14; do
    rm -rf "${tmp:?}/site"; mkdir -p "$tmp/site/db" "$tmp/site/uploads"
    echo "<h1>Site de l'entreprise — version du 2024-03-$d</h1>" > "$tmp/site/index.html"
    seq 1 $(((d - 9) * 100)) | sed "s/.*/INSERT INTO clients VALUES (&, 'client&', '2024-03-$d');/" > "$tmp/site/db/dump.sql"
    echo "document du $d" > "$tmp/site/uploads/doc-$d.txt"
    tar -czf "backups/site-2024-03-$d.tar.gz" -C "$tmp" site
    (sha256sum "backups/site-2024-03-$d.tar.gz") >> SHA256SUMS
    [[ $d == 12 ]] && sha256sum "$tmp/site/db/dump.sql" | cut -d' ' -f1 > .attendu
  done
  # corruption : 13 → octet ajouté après calcul de l'empreinte ; 14 → archive tronquée
  printf 'X' >> backups/site-2024-03-13.tar.gz
  local sz; sz=$(stat -c %s backups/site-2024-03-14.tar.gz); truncate -s $((sz / 2)) backups/site-2024-03-14.tar.gz
  rm -rf "$tmp"
  cat > incident.txt <<'EOF'
Incident constaté le 2024-03-14 à 16:30 : suppression accidentelle de la base de données du site.
Début de la restauration : 16:45
Service rétabli : 17:50
Objectifs contractuels : RPO = 24 h ; RTO = 4 h
EOF
}

kv() { grep -E "^$2=" "$1" 2>/dev/null | head -1 | cut -d= -f2-; }

mkstate() { # mkstate <health1> <health2> <vip> → chemin du dossier d'état
  local s; s=$(mktemp -d)
  echo "$1" > "$s/noeud1.health"; echo "$2" > "$s/noeud2.health"; echo "$3" > "$s/vip"; echo "$s"
}
run_b() { local o; o=$(./bascule.sh "$1" 2>/dev/null); echo "$?|$o"; }

lab_check() {
  cd "$LAB_DIR" || return 1
  # ---- A
  local r=rapport-pra.txt
  assert_eq "A1 SAUVEGARDES_VALIDES" "2024-03-10,2024-03-11,2024-03-12" "$(kv $r SAUVEGARDES_VALIDES | tr ',' '\n' | sort | paste -sd,)"
  assert_eq "A1 SAUVEGARDES_INVALIDES" "2024-03-13,2024-03-14" "$(kv $r SAUVEGARDES_INVALIDES | tr ',' '\n' | sort | paste -sd,)"
  assert_eq "A1 DERNIERE_VALIDE" 2024-03-12 "$(kv $r DERNIERE_VALIDE)"
  assert "A2 restauration/site/index.html (version du 12)" grep -q 'version du 2024-03-12' restauration/site/index.html
  assert_eq "A2 dump.sql restauré = celui de la sauvegarde du 12" "$(cat .attendu)" "$(sha256sum restauration/site/db/dump.sql 2>/dev/null | cut -d' ' -f1)"
  assert "A2 backups/ intact (5 archives)" bash -c "[[ \$(ls backups | wc -l) -eq 5 ]]"
  assert_eq "A3 PERTE_DONNEES_HEURES" "62.5" "$(kv $r PERTE_DONNEES_HEURES)"
  assert_eq "A3 RTO_REEL_MINUTES" 80 "$(kv $r RTO_REEL_MINUTES)"
  assert_eq "A3 RPO_RESPECTE (62,5 h > 24 h)" non "$(kv $r RPO_RESPECTE)"
  assert_eq "A3 RTO_RESPECTE (80 min ≤ 4 h)" oui "$(kv $r RTO_RESPECTE)"
  # ---- B
  assert "B bascule.sh exécutable" test -x bascule.sh
  local s o rc
  s=$(mkstate up up noeud1);   assert_eq "B OK : porteur sain" "0|OK: noeud1 actif" "$(run_b "$s")"
  s=$(mkstate down up noeud1)
  assert_eq "B basculement noeud1 → noeud2" "1|BASCULE: noeud1 -> noeud2" "$(run_b "$s")"
  assert_eq "B VIP → noeud2" noeud2 "$(cat "$s/vip")"
  assert "B ancien porteur isolé (fence)" test -e "$s/noeud1.fence"
  assert_eq "B 2ᵉ passage : stable (OK noeud2)" "0|OK: noeud2 actif" "$(run_b "$s")"
  echo up > "$s/noeud1.health"
  assert_eq "B noeud1 revient : PAS de fail-back" "0|OK: noeud2 actif" "$(run_b "$s")"
  assert_eq "B VIP reste sur noeud2" noeud2 "$(cat "$s/vip")"
  echo down > "$s/noeud2.health"
  assert_eq "B noeud2 tombe, noeud1 est encore isolé → panne totale" "2|PANNE TOTALE: aucun noeud disponible" "$(run_b "$s")"
  assert_eq "B VIP inchangée lors de la panne totale" noeud2 "$(cat "$s/vip")"
  rm -f "$s/noeud1.fence"
  assert_eq "B fence levé : bascule noeud2 → noeud1" "1|BASCULE: noeud2 -> noeud1" "$(run_b "$s")"
  rm -rf "$s"
  s=$(mkstate down down noeud1); assert_eq "B deux nœuds KO → panne totale" "2|PANNE TOTALE: aucun noeud disponible" "$(run_b "$s")"; rm -rf "$s"
  s=$(mkstate up up "noeud1,noeud2"); o=$(run_b "$s")
  assert "B split-brain : code 3 et message SPLIT-BRAIN" bash -c "[[ '$o' == 3\|SPLIT-BRAIN* ]]"
  assert_eq "B split-brain : rien n'est modifié" "noeud1,noeud2" "$(cat "$s/vip")"; rm -rf "$s"
  s=$(mkstate up up none);  assert_eq "B élection (noeud1 prioritaire)" "0|ELECTION: noeud1" "$(run_b "$s")"; rm -rf "$s"
  s=$(mkstate down up none); assert_eq "B élection du seul nœud sain" "0|ELECTION: noeud2" "$(run_b "$s")"; rm -rf "$s"
  ./bascule.sh >/dev/null 2>&1; assert_eq "B sans argument : code 64" 64 "$?"
  ./bascule.sh /dossier/absent >/dev/null 2>&1; assert_eq "B dossier absent : code 64" 64 "$?"

  # ---- C
  local kf n pr
  for kf in master backup; do
    local f=keepalived-$kf.conf
    assert "C $f : enable_script_security + script_user" bash -c "grep -Eq '^[[:space:]]*enable_script_security' $f && grep -Eq '^[[:space:]]*script_user[[:space:]]+root' $f"
    assert "C $f : vrrp_script check_haproxy (interval, weight négatif)" bash -c "grep -Eq 'vrrp_script[[:space:]]+check_haproxy' $f && grep -Eq '^[[:space:]]*interval[[:space:]]+[0-9]+' $f && grep -Eq '^[[:space:]]*weight[[:space:]]+-[0-9]+' $f"
    assert "C $f : virtual_router_id 51, VIP 192.168.50.100/24" bash -c "grep -Eq '^[[:space:]]*virtual_router_id[[:space:]]+51' $f && grep -Eq '^[[:space:]]*192\.168\.50\.100/24' $f"
    assert "C $f : authentication PASS" bash -c "grep -Eq 'auth_type[[:space:]]+PASS' $f && grep -Eq 'auth_pass[[:space:]]+[^ ]+' $f"
    assert "C $f : track_script { check_haproxy }" bash -c "tr '\n' ' ' < $f | grep -Eq 'track_script[[:space:]]*\{[[:space:]]*check_haproxy[[:space:]]*\}'"
  done
  assert "C master : state MASTER, priority 150" bash -c "grep -Eq '^[[:space:]]*state[[:space:]]+MASTER' keepalived-master.conf && grep -Eq '^[[:space:]]*priority[[:space:]]+150' keepalived-master.conf"
  assert "C backup : state BACKUP, priority 100" bash -c "grep -Eq '^[[:space:]]*state[[:space:]]+BACKUP' keepalived-backup.conf && grep -Eq '^[[:space:]]*priority[[:space:]]+100' keepalived-backup.conf"
  pr=$(awk '/^[[:space:]]*priority/{print $2; exit}' keepalived-master.conf 2>/dev/null); n=$(awk '/^[[:space:]]*weight/{print $2; exit}' keepalived-master.conf 2>/dev/null)
  local bp; bp=$(awk '/^[[:space:]]*priority/{print $2; exit}' keepalived-backup.conf 2>/dev/null)
  if [[ "$pr" =~ ^[0-9]+$ && "$n" =~ ^-[0-9]+$ && "$bp" =~ ^[0-9]+$ ]] && (( pr + n < bp )); then ok "C la panne du script fait passer le MASTER sous le BACKUP ($pr$n < $bp)"; else ko "C la panne du script doit faire passer la priorité du MASTER sous celle du BACKUP"; fi
  if command -v keepalived >/dev/null; then
    ka_ok() { local o rc; o=$(as_root keepalived -t -f "$1" 2>&1); rc=$?; [[ $rc -eq 0 && ! $o =~ (Unknown\ keyword|SECURITY|rror) ]]; }
    assert "C keepalived -t : keepalived-master.conf valide" ka_ok keepalived-master.conf
    assert "C keepalived -t : keepalived-backup.conf valide" ka_ok keepalived-backup.conf
  fi
  local h=haproxy.cfg
  assert "C haproxy : frontend web en :80 → backend app" bash -c "grep -Eq '^frontend[[:space:]]+web' $h && grep -Eq 'bind[[:space:]]+(\*|0\.0\.0\.0)?:80' $h && grep -Eq 'default_backend[[:space:]]+app' $h && grep -Eq '^backend[[:space:]]+app' $h"
  assert "C haproxy : balance roundrobin" grep -Eq '^[[:space:]]*balance[[:space:]]+roundrobin' $h
  assert "C haproxy : option httpchk GET /health" grep -Eq '^[[:space:]]*option[[:space:]]+httpchk[[:space:]]+GET[[:space:]]+/health' $h
  assert "C haproxy : a1 et a2 avec check" bash -c "grep -Eq 'server[[:space:]]+a1[[:space:]]+10\.0\.0\.11:8080.*check' $h && grep -Eq 'server[[:space:]]+a2[[:space:]]+10\.0\.0\.12:8080.*check' $h"
  assert "C haproxy : a3 en backup" grep -Eq 'server[[:space:]]+a3[[:space:]]+10\.0\.0\.13:8080.*check.*backup|server[[:space:]]+a3[[:space:]]+10\.0\.0\.13:8080.*backup.*check' $h
  if command -v haproxy >/dev/null; then assert "C haproxy -c : configuration valide" haproxy -c -f $h; fi
  # ---- D
  local q=reponses.txt
  assert_eq "D QUORUM_5" 3 "$(kv $q QUORUM_5)"
  assert_eq "D TOLERANCE_5" 2 "$(kv $q TOLERANCE_5)"
  assert_eq "D DISPO_PARALLELE" 99.99 "$(kv $q DISPO_PARALLELE | tr -d '%')"
  assert "D PARADE_SPLIT_BRAIN" bash -c "grep -E '^PARADE_SPLIT_BRAIN=' $q | cut -d= -f2 | grep -Eiqx 'fencing|stonith'"
  assert_eq "D INDISPO_999_HEURES" 8.76 "$(kv $q INDISPO_999_HEURES)"
  assert "D STRATEGIE_RTO_MIN" bash -c "grep -E '^STRATEGIE_RTO_MIN=' $q | cut -d= -f2 | grep -Eiqx 'actif/actif|actif-actif|active-active|actif actif'"
}

lab_solve() {
  cd "$LAB_DIR" || return 1
  local f d v=() x=()
  for f in backups/site-*.tar.gz; do d=${f##*site-}; d=${d%.tar.gz}
    if grep " $f\$" SHA256SUMS | sha256sum -c --status - 2>/dev/null && tar -tzf "$f" >/dev/null 2>&1; then v+=("$d"); else x+=("$d"); fi
  done
  mkdir -p restauration && tar -xzf backups/site-2024-03-12.tar.gz -C restauration
  cat > rapport-pra.txt <<EOF
SAUVEGARDES_VALIDES=$(IFS=,; echo "${v[*]}")
SAUVEGARDES_INVALIDES=$(IFS=,; echo "${x[*]}")
DERNIERE_VALIDE=2024-03-12
PERTE_DONNEES_HEURES=$(awk -v a="$(date -d '2024-03-14 16:30' +%s)" -v b="$(date -d '2024-03-12 02:00' +%s)" 'BEGIN{printf "%.1f", (a-b)/3600}')
RTO_REEL_MINUTES=80
RPO_RESPECTE=non
RTO_RESPECTE=oui
EOF
  cat > bascule.sh <<'EOS'
#!/usr/bin/env bash
set -u
d=${1:-}
[[ -n $d && -d $d ]] || { echo "Usage: $0 STATE_DIR" >&2; exit 64; }
avail() { [[ $(cat "$d/$1.health" 2>/dev/null) == up && ! -e "$d/$1.fence" ]]; }
other() { [[ $1 == noeud1 ]] && echo noeud2 || echo noeud1; }
owner=$(cat "$d/vip" 2>/dev/null || echo none)
if [[ $owner == *,* ]]; then echo "SPLIT-BRAIN: plusieurs noeuds revendiquent la VIP ($owner)"; exit 3; fi
if [[ $owner == none ]]; then
  for n in noeud1 noeud2; do avail "$n" && { echo "$n" > "$d/vip"; echo "ELECTION: $n"; exit 0; }; done
  echo "PANNE TOTALE: aucun noeud disponible"; exit 2
fi
avail "$owner" && { echo "OK: $owner actif"; exit 0; }
o=$(other "$owner")
if avail "$o"; then echo fenced > "$d/$owner.fence"; echo "$o" > "$d/vip"; echo "BASCULE: $owner -> $o"; exit 1; fi
echo "PANNE TOTALE: aucun noeud disponible"; exit 2
EOS
  chmod +x bascule.sh
  mk() { cat > "keepalived-$1.conf" <<EOF
global_defs {
    router_id LB_$1
    enable_script_security
    script_user root
}
vrrp_script check_haproxy {
    script "/usr/bin/pgrep haproxy"
    interval 2
    weight -60
}
vrrp_instance VI_WEB {
    state $2
    interface eth0
    virtual_router_id 51
    priority $3
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass S3cr3t12
    }
    virtual_ipaddress {
        192.168.50.100/24
    }
    track_script {
        check_haproxy
    }
}
EOF
  }
  mk master MASTER 150; mk backup BACKUP 100
  cat > haproxy.cfg <<'EOF'
global
    log /dev/log local0
defaults
    mode http
    timeout connect 5s
    timeout client 30s
    timeout server 30s
frontend web
    bind *:80
    default_backend app
backend app
    balance roundrobin
    option httpchk GET /health
    server a1 10.0.0.11:8080 check
    server a2 10.0.0.12:8080 check
    server a3 10.0.0.13:8080 check backup
EOF
  cat > reponses.txt <<'EOF'
QUORUM_5=3
TOLERANCE_5=2
DISPO_PARALLELE=99.99
PARADE_SPLIT_BRAIN=fencing
INDISPO_999_HEURES=8.76
STRATEGIE_RTO_MIN=actif/actif
EOF
}

lab_main "$@"
