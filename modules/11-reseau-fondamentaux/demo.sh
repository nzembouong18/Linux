#!/usr/bin/env bash
# Démo formateur — module 11 (≈ 30 min)
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/demo-lib.sh"

demo_title "Mes interfaces et mes routes"
demo_run "ip -br link"
demo_run "ip -br addr"
demo_run "ip route"
demo_run "ip route get 8.8.8.8 2>&1 | head -1"
demo_run "ip neigh | head -3"

demo_title "Calcul de sous-réseau (CIDR)"
demo_run "python3 -c \"import ipaddress as i; n=i.ip_network('192.168.10.77/26',strict=False); print('réseau',n.network_address,'masque',n.netmask,'broadcast',n.broadcast_address,'hôtes',n.num_addresses-2)\""
demo_run "python3 -c \"import ipaddress as i; print([str(s) for s in i.ip_network('192.168.10.0/24').subnets(new_prefix=26)])\""
demo_run "python3 -c \"import ipaddress as i; [print(a, i.ip_address(a).is_private) for a in ('10.1.1.1','172.20.1.1','172.32.1.1','192.168.0.1','8.8.8.8')]\""

demo_title "Résolution de noms"
demo_run "grep -E '^hosts' /etc/nsswitch.conf"
demo_run "head -3 /etc/hosts"
demo_run "getent hosts localhost"
demo_run "cat /etc/resolv.conf | grep -v '^#' | head -3"
demo_show "dig +short example.org A  |  dig +short example.org MX  |  dig +trace example.org"

demo_title "Ports et sockets : un serveur éphémère"
demo_run "mkdir www && echo '<h1>Bonjour</h1>' > www/index.html"
demo_run "python3 -m http.server 18080 --bind 127.0.0.1 --directory www >/dev/null 2>&1 </dev/null & SRV=\$!; sleep 1; ss -ltnp 'sport = :18080'"
demo_run "curl --noproxy '*' -s http://127.0.0.1:18080/"
demo_run "curl --noproxy '*' -s -o /dev/null -w 'code=%{http_code} temps=%{time_total}s\\n' http://127.0.0.1:18080/index.html"
demo_run "curl --noproxy '*' -s -o /dev/null -w 'code=%{http_code}\\n' http://127.0.0.1:18080/absent"
demo_run "curl --noproxy '*' -sI http://127.0.0.1:18080/ | head -3"
demo_run "nc -zv 127.0.0.1 18080 2>&1 | head -1; nc -zv 127.0.0.1 18081 2>&1 | head -1"
demo_run "timeout 2 bash -c '</dev/tcp/127.0.0.1/18080' && echo 'port ouvert (bash seul)'"
demo_run "kill \$SRV; sleep 0.3; echo \"sockets en écoute sur 18080 : \$(ss -ltnH 'sport = :18080' | wc -l)\""

demo_title "ping et latence"
demo_run "ping -c 2 -W 1 127.0.0.1 2>&1 | tail -3"
demo_end
