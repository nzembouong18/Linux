#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/lib.sh"
LAB_ID=17
LAB_REQUIRES=(root netns cmd:ip cmd:nft cmd:tcpdump cmd:curl cmd:python3)
NS=(lab17-a lab17-b lab17-r)

lab_cleanup() {
  local n p
  for n in "${NS[@]}"; do
    if ip netns list 2>/dev/null | grep -qw "$n"; then
      for p in $(as_root ip netns pids "$n" 2>/dev/null); do as_root kill "$p" 2>/dev/null; done
      as_root ip netns del "$n" 2>/dev/null
    fi
  done
  return 0
}

lab_setup() {
  cd "$LAB_DIR" || return 1
  lab_cleanup
  rm -rf ./*.txt capture.pcap serveur.log www
  mkdir -p www
  echo "<html><body>Serveur interne lab17 — jeton: NS-$(head -c 5 /dev/urandom | od -An -tx1 | tr -d ' \n')</body></html>" > www/index.html
  cat > plan.txt <<'EOF'
Plan d'adressage du labo 17
  lab17-a : 10.17.1.2/24   passerelle 10.17.1.1
  lab17-r : 10.17.1.1/24 (côté a)  et  10.17.2.1/24 (côté b)   ip_forward=1
  lab17-b : 10.17.2.2/24   passerelle 10.17.2.1   serveur web :8080
EOF
}

nsx() { as_root ip netns exec "$@"; }

lab_check() {
  cd "$LAB_DIR" || return 1
  local n
  for n in "${NS[@]}"; do assert "1 namespace $n existe" bash -c "ip netns list | grep -qw $n"; done
  has_addr() { as_root ip -n "$1" -4 -o addr show 2>/dev/null | grep -q "inet $2 "; }
  assert "1 lab17-a : 10.17.1.2/24" has_addr lab17-a 10.17.1.2/24
  assert "1 lab17-r : 10.17.1.1/24 et 10.17.2.1/24" bash -c "$(declare -f has_addr as_root); has_addr lab17-r 10.17.1.1/24 && has_addr lab17-r 10.17.2.1/24"
  assert "1 lab17-b : 10.17.2.2/24" has_addr lab17-b 10.17.2.2/24
  def_route() { as_root ip -n "$1" route show default 2>/dev/null | grep -q "via $2"; }
  assert "1 route par défaut de a via 10.17.1.1" def_route lab17-a 10.17.1.1
  assert "1 route par défaut de b via 10.17.2.1" def_route lab17-b 10.17.2.1
  assert_eq "2 ip_forward=1 dans lab17-r" 1 "$(nsx lab17-r sysctl -n net.ipv4.ip_forward 2>/dev/null)"
  assert "2 b → a : ping OK à travers le routeur (réponses d'écho non filtrées)" nsx lab17-b ping -c1 -W2 10.17.1.2
  assert "5 a → b : ping BLOQUÉ par le pare-feu du routeur" bash -c "! $(declare -f as_root nsx) ; ! nsx lab17-a ping -c1 -W1 10.17.2.2 >/dev/null 2>&1"
  local rules; rules=$(nsx lab17-r nft list ruleset 2>/dev/null)
  assert "5 nft : règle drop icmp echo-request depuis 10.17.1.0/24" bash -c "echo \"\$1\" | tr '\n' ' ' | grep -Eq 'ip saddr 10\.17\.1\.0/24[^;]*icmp type echo-request[^;]*drop'" _ "$rules"
  assert "6 nft : masquerade sur l'interface côté b" bash -c "echo \"\$1\" | grep -Eq 'oifname \"?l17rb\"? .*masquerade|masquerade'" _ "$rules"
  local tok; tok=$(grep -o 'NS-[0-9a-f]*' www/index.html)
  assert_grep "4 page.txt contient le jeton du serveur" "$tok" page.txt
  # HTTP en direct : le routeur doit laisser passer le TCP, et le NAT doit être visible
  local before; before=$(wc -l < serveur.log 2>/dev/null || echo 0)
  local got; got=$(nsx lab17-a curl --noproxy '*' -s --max-time 3 http://10.17.2.2:8080/ 2>/dev/null)
  assert "4/5 HTTP a → b fonctionne (le pare-feu ne bloque que l'ICMP)" bash -c "echo \"\$1\" | grep -q '$tok'" _ "$got"
  sleep 0.4
  if tail -n +"$((before + 1))" serveur.log 2>/dev/null | grep -q '^10\.17\.2\.1 - - '; then ok "6 la requête de contrôle apparaît avec la source 10.17.2.1"; else ko "6 la requête de contrôle devrait apparaître avec la source 10.17.2.1"; fi
  assert_grep "4 serveur.log : requête d'origine vue depuis 10.17.1.2 (avant NAT)" '^10\.17\.1\.2 - - ' serveur.log
  assert "3 capture.pcap : ICMP echo request 10.17.1.2 > 10.17.2.2" bash -c "tcpdump -nr capture.pcap 2>/dev/null | grep -q '10.17.1.2 > 10.17.2.2: ICMP echo request'"
  assert_eq "7 IP_VUE_AVANT_NAT" 10.17.1.2 "$(grep -E '^IP_VUE_AVANT_NAT=' nat.txt 2>/dev/null | cut -d= -f2)"
  assert_eq "7 IP_VUE_APRES_NAT" 10.17.2.1 "$(grep -E '^IP_VUE_APRES_NAT=' nat.txt 2>/dev/null | cut -d= -f2)"
}

lab_solve() {
  cd "$LAB_DIR" || return 1
  local n
  for n in a b r; do as_root ip netns add lab17-$n; as_root ip -n lab17-$n link set lo up; done
  as_root ip link add l17a type veth peer name l17ra; as_root ip link set l17a netns lab17-a; as_root ip link set l17ra netns lab17-r
  as_root ip link add l17b type veth peer name l17rb; as_root ip link set l17b netns lab17-b; as_root ip link set l17rb netns lab17-r
  as_root ip -n lab17-a addr add 10.17.1.2/24 dev l17a;  as_root ip -n lab17-a link set l17a up
  as_root ip -n lab17-r addr add 10.17.1.1/24 dev l17ra; as_root ip -n lab17-r link set l17ra up
  as_root ip -n lab17-r addr add 10.17.2.1/24 dev l17rb; as_root ip -n lab17-r link set l17rb up
  as_root ip -n lab17-b addr add 10.17.2.2/24 dev l17b;  as_root ip -n lab17-b link set l17b up
  as_root ip -n lab17-a route add default via 10.17.1.1
  as_root ip -n lab17-b route add default via 10.17.2.1
  nsx lab17-r sysctl -qw net.ipv4.ip_forward=1
  nsx lab17-r tcpdump -ni l17ra -c 3 -w capture.pcap icmp >/dev/null 2>&1 &
  local cap=$!
  sleep 1; nsx lab17-a ping -c3 -W1 10.17.2.2 >/dev/null; wait "$cap" 2>/dev/null
  nsx lab17-b python3 -m http.server 8080 --bind 10.17.2.2 --directory "$PWD/www" >> serveur.log 2>&1 </dev/null &
  local i; for i in $(seq 1 50); do nsx lab17-b ss -ltn 2>/dev/null | grep -q ':8080 ' && break; sleep 0.2; done
  nsx lab17-a curl --noproxy '*' -s http://10.17.2.2:8080/ > page.txt
  nsx lab17-r nft add table inet fw
  nsx lab17-r nft add chain inet fw forward '{ type filter hook forward priority 0; }'
  nsx lab17-r nft add rule inet fw forward ip saddr 10.17.1.0/24 icmp type echo-request drop
  nsx lab17-r nft add table ip nat
  nsx lab17-r nft add chain ip nat post '{ type nat hook postrouting priority srcnat; }'
  nsx lab17-r nft add rule ip nat post oifname '"l17rb"' masquerade
  nsx lab17-a curl --noproxy '*' -s http://10.17.2.2:8080/ >/dev/null
  printf 'IP_VUE_AVANT_NAT=10.17.1.2\nIP_VUE_APRES_NAT=10.17.2.1\n' > nat.txt
}

lab_main "$@"
