#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/lib.sh"
LAB_ID=11
LAB_REQUIRES=(cmd:ip cmd:ss cmd:curl cmd:python3)

lab_cleanup() {
  [[ -f "$LAB_DIR/.pid" ]] && kill "$(cat "$LAB_DIR/.pid")" 2>/dev/null
  return 0
}

lab_setup() {
  cd "$LAB_DIR" || return 1
  lab_cleanup
  mkdir -p www
  local token; token="SECRET-$(head -c 6 /dev/urandom | od -An -tx1 | tr -d ' \n')"
  echo "<html><body>Bienvenue. Code: $token</body></html>" > www/index.html
  echo "$token" > .token
  local port
  port=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()')
  echo "$port" > .port
  # flux entièrement détachés : sinon un « $(...) » appelant resterait bloqué en attendant la fermeture du tube
  nohup python3 -m http.server "$port" --bind 127.0.0.1 --directory "$LAB_DIR/www" >/dev/null 2>&1 </dev/null &
  echo $! > .pid
  local i; for i in $(seq 1 30); do curl --noproxy "*" -s -m1 "http://127.0.0.1:$port/" >/dev/null 2>&1 && break; sleep 0.2; done
}

lab_check() {
  cd "$LAB_DIR" || return 1
  local r=reponses_reseau.txt get; get() { grep -E "^$1=" "$r" 2>/dev/null | head -1 | cut -d= -f2-; }
  local py; py() { python3 -c "import ipaddress as i
n=i.ip_network('192.168.10.77/26',strict=False); h=list(n.hosts())
$1" 2>/dev/null; }
  assert_eq "RESEAU"          "$(py 'print(n.network_address)')"   "$(get RESEAU)"
  assert_eq "BROADCAST"       "$(py 'print(n.broadcast_address)')" "$(get BROADCAST)"
  assert_eq "PREMIER_HOTE"    "$(py 'print(h[0])')"                "$(get PREMIER_HOTE)"
  assert_eq "DERNIER_HOTE"    "$(py 'print(h[-1])')"               "$(get DERNIER_HOTE)"
  assert_eq "NB_HOTES"        "62"            "$(get NB_HOTES)"
  assert_eq "MASQUE_20"       "255.255.240.0" "$(get MASQUE_20)"
  assert_eq "RESEAU_Q3"       "10.1.0.0"      "$(get RESEAU_Q3)"
  assert_eq "NB_SOUS_RESEAUX" "4"             "$(get NB_SOUS_RESEAUX)"
  assert_eq "PRIVEE_172_20"   "oui"           "$(get PRIVEE_172_20)"
  assert_eq "PRIVEE_172_32"   "non"           "$(get PRIVEE_172_32)"
  assert_eq "PREFIXE_100"     "25"            "$(get PREFIXE_100)"

  local port token; port=$(cat .port 2>/dev/null); token=$(cat .token 2>/dev/null)
  assert "le serveur de test tourne toujours (./lab setup 11 sinon)" curl --noproxy "*" -s -m2 "http://127.0.0.1:$port/"
  assert_eq "B1 port.txt" "$port" "$(tr -d ' \n' < port.txt 2>/dev/null)"
  assert_grep "B2 page.txt contient le code secret" "$token" page.txt
  assert_eq "B3 statut.txt" "200" "$(tr -d ' \n' < statut.txt 2>/dev/null)"
  assert_eq "B4 code404.txt" "404" "$(tr -d ' \n' < code404.txt 2>/dev/null)"
  assert_eq "B5 loopback.txt" "127.0.0.1" "$(tr -d ' \n' < loopback.txt 2>/dev/null)"
  local gw; gw=$(ip route show default 2>/dev/null | awk '{print $3; exit}'); gw=${gw:-aucune}
  assert_eq "B6 passerelle.txt" "$gw" "$(tr -d ' \n' < passerelle.txt 2>/dev/null)"
  assert_eq "B7 localhost.txt" "$(getent ahostsv4 localhost | awk 'NR==1{print $1}')" "$(tr -d ' \n' < localhost.txt 2>/dev/null)"
  assert_eq "B8 ecoute_local.txt" "oui" "$(tr -d ' \n' < ecoute_local.txt 2>/dev/null)"
}

lab_solve() {
  cd "$LAB_DIR" || return 1
  python3 - <<'PY' > reponses_reseau.txt
import ipaddress as i
n = i.ip_network('192.168.10.77/26', strict=False)
h = list(n.hosts())
print(f"RESEAU={n.network_address}\nBROADCAST={n.broadcast_address}\nPREMIER_HOTE={h[0]}\nDERNIER_HOTE={h[-1]}\nNB_HOTES={len(h)}")
print(f"MASQUE_20={i.ip_network('0.0.0.0/20').netmask}")
print(f"RESEAU_Q3={i.ip_network('10.1.2.3/16', strict=False).network_address}")
print("NB_SOUS_RESEAUX=4")
print("PRIVEE_172_20=" + ("oui" if i.ip_address('172.20.5.9').is_private else "non"))
print("PRIVEE_172_32=" + ("oui" if i.ip_address('172.32.0.1').is_private else "non"))
print("PREFIXE_100=25")
PY
  local port p
  port=""
  for p in $(ss -ltnH | awk '$4 ~ /^127\.0\.0\.1:/ {sub(".*:","",$4); print $4}'); do
    if curl --noproxy "*" -s -m1 "http://127.0.0.1:$p/" | grep -q SECRET; then port=$p; break; fi
  done
  echo "$port" > port.txt
  curl --noproxy "*" -s "http://127.0.0.1:$port/" > page.txt
  curl --noproxy "*" -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$port/index.html" > statut.txt
  curl --noproxy "*" -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$port/page-qui-nexiste-pas" > code404.txt
  ip -4 -o addr show lo | awk '{print $4}' | cut -d/ -f1 > loopback.txt
  local gw; gw=$(ip route show default | awk '{print $3; exit}'); echo "${gw:-aucune}" > passerelle.txt
  getent ahostsv4 localhost | awk 'NR==1{print $1}' > localhost.txt
  if ss -ltnH "sport = :$port" | grep -q '127.0.0.1:'; then echo oui > ecoute_local.txt; else echo non > ecoute_local.txt; fi
}

lab_main "$@"
