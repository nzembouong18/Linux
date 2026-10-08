# Aide-mémoire 3 — Avancé et professionnel (modules 16-25)

## Sécurité
```bash
sudo ss -tulpn · find / -xdev -perm -4000 -type f · find / -xdev -type f -perm -0002
awk -F: '$3==0' /etc/passwd · sudo awk -F: '$2==""' /etc/shadow · sudo grep -r NOPASSWD /etc/sudoers*
sudo nft -c -f f.nft (vérifier) · sudo nft -f f.nft · sudo nft list ruleset · sudo ufw status verbose
sudo fail2ban-client status sshd · sudo sshd -t · sudo lynis audit system
getenforce · ausearch -m AVC -ts recent · restorecon -Rv /chemin · aa-status · aa-complain /usr/sbin/x
sudo auditctl -w /etc/passwd -p wa -k identite · sudo ausearch -k identite -i
```
nftables minimal : `table inet f { chain input { type filter hook input priority 0; policy drop; ct state established,related accept; iif "lo" accept; tcp dport {22,80,443} accept } }`

## Réseau avancé
```bash
sudo ip netns add ns1 · sudo ip netns exec ns1 cmd · sudo ip -n ns1 addr
sudo ip link add va type veth peer name vb · sudo ip link set va netns ns1
sudo ip link add br0 type bridge · ip link set eth1 master br0 · bridge link
sudo sysctl -w net.ipv4.ip_forward=1 · nft add rule ip nat post oifname eth0 masquerade
tcpdump -ni any host 10.0.0.5 and port 443 · tcpdump -nr f.pcap · tc qdisc add dev eth0 root netem delay 100ms loss 1%
ip rule add from 10.1.0.50 table 200 · wg show · iperf3 -c srv · conntrack -L
```

## Performance et dépannage
```bash
uptime · vmstat 1 5 · mpstat -P ALL 1 3 · pidstat 1 3 · iostat -xz 1 3 · free -m · sar -n DEV 1 3
dmesg -T | tail · journalctl -k | grep -i oom · ps aux --sort=-%mem | head
ls /proc/PID/fd | wc -l · lsof -p PID · lsof +L1 · strace -c -p PID · strace -f -tt -T -o t.txt cmd · perf top
```
Méthode **USE** (Utilisation, Saturation, Erreurs) par ressource ; un seul changement à la fois ; mesurer avant/après.

## Web (nginx)
```bash
sudo nginx -t · sudo systemctl reload nginx · sudo nginx -T · curl -I -H 'Host: site' http://127.0.0.1/
# location : = exact > ^~ préfixe prioritaire > ~ regex > préfixe le plus long
# proxy_pass http://app/;  (slash final = retire le préfixe)  ·  limit_req_zone … rate=5r/s · add_header … always
certbot --nginx -d exemple.org · openssl x509 -in c.pem -noout -dates -subject · ab -n 1000 -c 20 URL
```
Codes : 301/302 redirection · 401 non authentifié · 403 interdit · 404 · 429 trop de requêtes · 502 backend KO · 504 délai.

## Conteneurs
```bash
sudo unshare --uts --pid --ipc --mount --net --fork --mount-proc chroot rootfs /bin/sh
sudo mount -t overlay overlay -o lowerdir=l,upperdir=u,workdir=w m
docker run -d --name web -p 127.0.0.1:8080:80 --read-only --cap-drop ALL -m 256m --cpus 0.5 nginx:1.27-alpine
docker ps -a · docker logs -f x · docker exec -it x sh · docker inspect x · docker compose up -d --build · docker system df
```
Dockerfile : tag épinglé · `COPY` des dépendances avant le code · `USER` non-root · `HEALTHCHECK` · `CMD ["…"]` exec · pas de secrets.

## Noyau et démarrage
```bash
uname -r · lsmod · modinfo m · sudo modprobe m · cat /proc/cmdline · sudo update-grub · sudo update-initramfs -u
# GRUB : e → ajouter systemd.unit=rescue.target | rw init=/bin/bash → Ctrl+X ; RHEL : rd.break + touch /.autorelabel
udevadm info -a -n /dev/sdb · udevadm monitor · udevadm verify r.rules · dmesg -T --level=err,warn · journalctl -k -b -1
```

## Ansible / Terraform / cloud-init
```bash
ansible-inventory --graph · ansible all -m ping · ansible-playbook site.yml --syntax-check | --check --diff | -e var=x | --limit h | --tags t
ansible-vault create|encrypt|view|edit f · ansible-vault encrypt_string 'x' --name v · ansible-doc module
terraform init · fmt · validate · plan · apply · destroy       cloud-init status --long · cloud-init schema --config-file u.yaml
```
Idempotence : 2ᵉ passage = `changed=0`.

## Supervision (Prometheus)
```promql
up == 0
100 - avg by(instance)(rate(node_cpu_seconds_total{mode="idle"}[5m]))*100
(1 - node_memory_MemAvailable_bytes/node_memory_MemTotal_bytes)*100
sum(rate(http_requests_total{code=~"5.."}[5m])) / sum(rate(http_requests_total[5m]))
histogram_quantile(0.95, sum by(le)(rate(http_request_duration_seconds_bucket[5m])))
predict_linear(node_filesystem_avail_bytes[6h], 4*3600) < 0
```
Plugin Nagios : codes `0 OK · 1 WARNING · 2 CRITICAL · 3 UNKNOWN`, `texte|label=val;warn;crit;min;max`. SLO 99,9 %/30 j = 43,2 min de budget.
`promtool check rules|config f` · `amtool alert` · `curl localhost:9100/metrics`

## HA et PRA
Disponibilité : `99 %`=3,65 j/an · `99,9 %`=8,76 h · `99,99 %`=52,6 min. Série : produit ; parallèle : `1-(1-a)(1-b)`.
Quorum = ⌊n/2⌋+1 · fencing (STONITH) contre le split-brain · `keepalived -t -f f` · `haproxy -c -f f` · `pcs status`.
Sauvegardes : **3-2-1(-1-0)**, vérifier (`sha256sum -c`, `tar -tzf`), **tester la restauration** et mesurer le RTO.
