#!/usr/bin/env bash
# Démo formateur — module 17 (≈ 45 min). Nécessite root + namespaces ; sinon, démonstration commentée.
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/demo-lib.sh"

if [[ $EUID -ne 0 ]] || ! ip netns add demo-probe 2>/dev/null; then
  demo_say "Pas de privilèges réseau : voici la démo sous forme de commandes à rejouer sur la VM."
  demo_show "sudo ip netns add ns-a; sudo ip link add va type veth peer name ra; sudo ip link set va netns ns-a"
  demo_show "sudo ip netns exec ns-r sysctl -w net.ipv4.ip_forward=1"
  demo_show "sudo ip netns exec ns-r tcpdump -ni ra -c3 icmp"
  exit 0
fi
ip netns del demo-probe
cleanup() { for n in da db dr; do ip netns del "demo-$n" 2>/dev/null; done; cd /; rm -rf "$DEMO_DIR"; }
trap cleanup EXIT

demo_title "Topologie : client — routeur — serveur"
demo_run "for n in da db dr; do ip netns add demo-\$n; ip -n demo-\$n link set lo up; done; ip netns list"
demo_run "ip link add dva type veth peer name dra && ip link set dva netns demo-da && ip link set dra netns demo-dr"
demo_run "ip link add dvb type veth peer name drb && ip link set dvb netns demo-db && ip link set drb netns demo-dr"
demo_run "ip -n demo-da addr add 10.77.1.2/24 dev dva && ip -n demo-da link set dva up && ip -n demo-da route add default via 10.77.1.1"
demo_run "ip -n demo-db addr add 10.77.2.2/24 dev dvb && ip -n demo-db link set dvb up && ip -n demo-db route add default via 10.77.2.1"
demo_run "ip -n demo-dr addr add 10.77.1.1/24 dev dra && ip -n demo-dr addr add 10.77.2.1/24 dev drb && ip -n demo-dr link set dra up && ip -n demo-dr link set drb up"
demo_run "ip -n demo-dr -br addr"

demo_title "Sans puis avec forwarding"
demo_run "ip netns exec demo-da ping -c1 -W1 10.77.2.2 2>&1 | tail -2"
demo_run "ip netns exec demo-dr sysctl -w net.ipv4.ip_forward=1"
demo_run "ip netns exec demo-da ping -c1 -W1 10.77.2.2 2>&1 | tail -2"
demo_run "ip netns exec demo-da ip route get 10.77.2.2"

demo_title "Voir la vérité : tcpdump côté routeur"
demo_run "(ip netns exec demo-dr tcpdump -ni dra -c4 icmp 2>&1 | grep -E 'ICMP' &) ; sleep 1; ip netns exec demo-da ping -c2 -W1 10.77.2.2 >/dev/null; sleep 1.5"

demo_title "Pare-feu : bloquer le ping de a vers b mais pas l'inverse"
demo_run "ip netns exec demo-dr nft add table inet fw && ip netns exec demo-dr nft add chain inet fw forward '{ type filter hook forward priority 0; }' && ip netns exec demo-dr nft add rule inet fw forward ip saddr 10.77.1.0/24 icmp type echo-request drop"
demo_run "ip netns exec demo-da ping -c1 -W1 10.77.2.2 2>&1 | tail -2"
demo_run "ip netns exec demo-db ping -c1 -W1 10.77.1.2 2>&1 | tail -2"

demo_title "NAT : ce que voit le serveur"
demo_run "mkdir w && echo hello > w/index.html && ip netns exec demo-db python3 -m http.server 8080 --bind 10.77.2.2 --directory w > srv.log 2>&1 </dev/null & sleep 1"
demo_run "ip netns exec demo-da curl --noproxy '*' -s http://10.77.2.2:8080/; tail -1 srv.log | cut -d' ' -f1"
demo_run "ip netns exec demo-dr nft add table ip nat && ip netns exec demo-dr nft add chain ip nat post '{ type nat hook postrouting priority srcnat; }' && ip netns exec demo-dr nft add rule ip nat post oifname drb masquerade"
demo_run "ip netns exec demo-da curl --noproxy '*' -s http://10.77.2.2:8080/; sleep 0.3; tail -1 srv.log | cut -d' ' -f1"
demo_run "ip netns exec demo-dr conntrack -L 2>/dev/null | head -2 || echo '(conntrack-tools non installé)'"
demo_run "ip netns exec demo-dr nft list ruleset | head -14"
demo_run "kill \$(ip netns pids demo-db) 2>/dev/null; true"

demo_title "Dégrader le réseau avec tc netem"
demo_run "ip netns exec demo-da tc qdisc add dev dva root netem delay 80ms 2>&1 | head -1; ip netns exec demo-da ping -c2 -W2 10.77.2.2 2>&1 | tail -2"
demo_end
