# Module 17 — Réseau avancé : namespaces, routage, NAT, tunnels et capture de paquets

> **Niveau** : Avancé | **Durée** : 8 h (4 h cours + 4 h labo) | **Prérequis** : modules 11, 16
>
> **Objectifs** — À la fin de ce module vous saurez :
> - construire des topologies virtuelles (bridges, VLAN, veth, **network namespaces**) ;
> - configurer le **routage** (statique, multi-tables / policy routing) et activer le routage IP ;
> - mettre en œuvre **NAT** (SNAT/masquerade, DNAT/redirection de port) avec `nftables` ;
> - monter des **tunnels** (GRE, VXLAN, WireGuard) ;
> - **capturer et analyser** le trafic (`tcpdump`, `tshark`) ;
> - simuler des conditions réseau (`tc netem`) et mesurer (`iperf3`, `mtr`) ;
> - diagnostiquer MTU, ARP, conntrack et pertes de paquets.

---

## 1. Rappel : la pile réseau Linux

```text
 Application ── socket ──► TCP/UDP ──► IP (routage, netfilter) ──► qdisc (tc) ──► pilote ──► NIC
                                          ▲
                              hooks Netfilter : prerouting · input · forward · output · postrouting
```

Chaque paquet traverse les **hooks Netfilter** (filtrage, NAT). La décision de routage se fait entre `prerouting` et `input`/`forward`.

```text
 réseau ─► PREROUTING (DNAT) ─► routage ─┬─► INPUT ──► processus local
                                         └─► FORWARD ─► POSTROUTING (SNAT/masquerade) ─► réseau
 processus local ─► OUTPUT ─► routage ─► POSTROUTING
```

## 2. Périphériques réseau virtuels

| Type | Création | Usage |
|------|----------|-------|
| **veth** | `ip link add v0 type veth peer name v1` | « câble » virtuel entre deux interfaces (conteneurs, namespaces) |
| **bridge** | `ip link add br0 type bridge` | commutateur logiciel (couche 2) |
| **vlan** | `ip link add link eth0 name eth0.10 type vlan id 10` | segmentation 802.1Q |
| **bond** | `ip link add bond0 type bond mode 802.3ad` | agrégation / redondance de liens |
| **dummy** | `ip link add d0 type dummy` | interface factice (tests, services) |
| **macvlan / ipvlan** | `ip link add mv0 link eth0 type macvlan mode bridge` | plusieurs MAC/IP sur un lien |
| **tun/tap** | `ip tuntap add dev tap0 mode tap` | VPN, VM |
| **gre / vxlan / wireguard** | voir §6 | tunnels |

```bash
ip link add br0 type bridge && ip link set br0 up
ip link set eth1 master br0                  # branche une interface sur le bridge
bridge link ; bridge fdb show br br0         # ports et table MAC
bridge vlan add dev eth1 vid 10              # VLAN filtering sur bridge
```

## 3. Network namespaces : des piles réseau isolées

Un **namespace réseau** possède ses propres interfaces, tables de routage, règles de pare-feu et ports. C'est la brique de base des **conteneurs** (module 20) et un laboratoire parfait pour tester sans matériel.

```bash
sudo ip netns add ns1
sudo ip netns list
sudo ip netns exec ns1 ip addr             # exécute une commande DANS le namespace
sudo ip -n ns1 link set lo up              # forme courte : -n
sudo ip netns exec ns1 bash                # shell dans le namespace
sudo ip netns del ns1
```

### Topologie « client — routeur — serveur »

```text
  ┌─────────┐ 10.0.1.0/24 ┌──────────────┐ 10.0.2.0/24 ┌─────────┐
  │   ns-a  │.2─────────.1│    ns-r      │.1─────────.2│  ns-b   │
  │ va      │             │ ra       rb  │             │ vb      │
  └─────────┘             └──────────────┘             └─────────┘
       default via 10.0.1.1    ip_forward=1        default via 10.0.2.1
```

```bash
for n in a b r; do sudo ip netns add ns-$n; sudo ip -n ns-$n link set lo up; done
sudo ip link add va type veth peer name ra
sudo ip link set va netns ns-a ; sudo ip link set ra netns ns-r
sudo ip link add vb type veth peer name rb
sudo ip link set vb netns ns-b ; sudo ip link set rb netns ns-r

sudo ip -n ns-a addr add 10.0.1.2/24 dev va ; sudo ip -n ns-a link set va up
sudo ip -n ns-r addr add 10.0.1.1/24 dev ra ; sudo ip -n ns-r link set ra up
sudo ip -n ns-r addr add 10.0.2.1/24 dev rb ; sudo ip -n ns-r link set rb up
sudo ip -n ns-b addr add 10.0.2.2/24 dev vb ; sudo ip -n ns-b link set vb up
sudo ip -n ns-a route add default via 10.0.1.1
sudo ip -n ns-b route add default via 10.0.2.1

sudo ip netns exec ns-a ping -c1 10.0.2.2           # ✘ : le routeur ne route pas encore
sudo ip netns exec ns-r sysctl -w net.ipv4.ip_forward=1
sudo ip netns exec ns-a ping -c1 10.0.2.2           # ✔
```

## 4. Routage avancé

```bash
ip route add 192.168.50.0/24 via 10.0.0.254 dev eth0 metric 100
ip route add blackhole 203.0.113.0/24            # route « trou noir »
ip route add default via 10.0.0.1 dev eth0 metric 50
ip route add default via 10.1.0.1 dev eth1 metric 100      # route de secours (métrique plus haute)
ip route show table all | head
ip route get 8.8.8.8 from 10.0.1.2 iif eth0       # simulation de décision de routage
```

### Routage par politique (*policy routing*) : plusieurs tables

```bash
echo "200 isp2" | sudo tee -a /etc/iproute2/rt_tables
sudo ip route add default via 10.1.0.1 dev eth1 table isp2
sudo ip rule add from 10.1.0.50/32 table isp2 priority 1000       # ce qui vient de cette IP sort par ISP2
sudo ip rule add fwmark 0x2 table isp2                             # ou selon une marque posée par nftables
ip rule show
```

Routage dynamique : **FRRouting** (OSPF, BGP, RIP) pour les grands réseaux ; **Bird** ; **keepalived** (VRRP : IP virtuelle flottante, module 24).

## 5. NAT avec nftables

| NAT | Rôle | Exemple |
|-----|------|---------|
| **SNAT / masquerade** | réécrit l'adresse *source* des paquets sortants (partage de connexion) | LAN privé → Internet |
| **DNAT** | réécrit l'adresse/port *destination* des paquets entrants (redirection de port) | publier un service interne |

```nft
table ip nat {
    chain prerouting  { type nat hook prerouting  priority dstnat; policy accept;
        iifname "eth0" tcp dport 8080 dnat to 10.0.2.2:80       # DNAT : port 8080 public → serveur interne
    }
    chain postrouting { type nat hook postrouting priority srcnat; policy accept;
        oifname "eth0" ip saddr 10.0.0.0/8 masquerade           # SNAT dynamique
    }
}
table inet filtre {
    chain forward { type filter hook forward priority 0; policy drop;
        ct state established,related accept
        iifname "eth1" oifname "eth0" accept                    # LAN → WAN
        iifname "eth0" ip daddr 10.0.2.2 tcp dport 80 ct status dnat accept   # seulement ce qui est DNATé
    }
}
```
```bash
sudo sysctl -w net.ipv4.ip_forward=1        # + /etc/sysctl.d/ pour la persistance
sudo conntrack -L | head                    # table de suivi de connexions (paquet conntrack)
sudo conntrack -S                           # statistiques (insert_failed, drop → table pleine ?)
sudo nft list ruleset ; sudo nft monitor trace    # trace d'un paquet à travers les règles
```
Traçage d'un paquet : `nft insert rule inet filtre input meta nftrace set 1` puis `nft monitor trace`.

## 6. Tunnels et VPN

### GRE / VXLAN

```bash
ip tunnel add gre1 mode gre remote 203.0.113.2 local 198.51.100.1 ttl 255
ip addr add 172.16.0.1/30 dev gre1 && ip link set gre1 up
# VXLAN : réseau de couche 2 sur du réseau de couche 3 (clouds, conteneurs, Kubernetes)
ip link add vxlan100 type vxlan id 100 dstport 4789 remote 203.0.113.2 local 198.51.100.1 dev eth0
```

### WireGuard (VPN moderne : noyau, simple, rapide)

```bash
sudo apt install wireguard
wg genkey | tee priv.key | wg pubkey > pub.key
```
```ini
# /etc/wireguard/wg0.conf  (serveur)
[Interface]
Address = 10.99.0.1/24
ListenPort = 51820
PrivateKey = <clé privée du serveur>
PostUp   = nft add rule inet filtre forward iifname wg0 accept
[Peer]
PublicKey = <clé publique du client>
AllowedIPs = 10.99.0.2/32
```
```bash
sudo wg-quick up wg0 ; sudo wg show ; sudo systemctl enable --now wg-quick@wg0
```
Le champ `AllowedIPs` fait à la fois **routage** et **filtre** (cryptokey routing). Alternatives : OpenVPN, IPsec (strongSwan), tunnels SSH (module 12).

## 7. Capture et analyse de paquets

```bash
sudo tcpdump -D                                      # interfaces disponibles
sudo tcpdump -ni eth0                                # -n : pas de résolution DNS ; -i : interface
sudo tcpdump -ni eth0 host 10.0.0.5 and port 443
sudo tcpdump -ni any icmp                            # ping : toutes interfaces
sudo tcpdump -ni eth0 'tcp[tcpflags] & tcp-syn != 0' # paquets SYN (début de connexions)
sudo tcpdump -ni eth0 -c 100 -w capture.pcap         # enregistre 100 paquets (analyse dans Wireshark)
tcpdump -nr capture.pcap 'port 53'                   # relire avec un filtre
tcpdump -nr capture.pcap -A | less                   # affiche le contenu ASCII (HTTP en clair…)
tshark -r capture.pcap -Y 'http.request' -T fields -e ip.src -e http.host -e http.request.uri
```

Filtres BPF : `host`, `net 10.0.0.0/8`, `src`, `dst`, `port`, `portrange 8000-8100`, `tcp`, `udp`, `icmp`, `arp`, combinés par `and`, `or`, `not`.

### Lire une poignée de main TCP

```text
10:00:00.000 IP 10.0.1.2.43210 > 10.0.2.2.8080: Flags [S],  seq 100               ← SYN
10:00:00.000 IP 10.0.2.2.8080 > 10.0.1.2.43210: Flags [S.], seq 700, ack 101      ← SYN-ACK
10:00:00.001 IP 10.0.1.2.43210 > 10.0.2.2.8080: Flags [.],  ack 701               ← ACK
10:00:00.001 IP 10.0.1.2.43210 > 10.0.2.2.8080: Flags [P.], seq 101:180           ← données (PSH)
... Flags [F.] ... Flags [R.] (reset : port fermé ou connexion refusée)
```
Reconnaître : SYN sans réponse (pare-feu qui `drop`), RST immédiat (port fermé / `reject`), retransmissions (perte), `ICMP unreachable`, requêtes ARP sans réponse (couche 2).

## 8. Simuler et mesurer

```bash
# Dégradation volontaire du réseau (tests de résilience)
sudo tc qdisc add dev eth0 root netem delay 100ms 20ms loss 1% rate 10mbit
sudo tc qdisc show dev eth0
sudo tc qdisc del dev eth0 root                 # retirer

# Mesures
iperf3 -s                                       # serveur
iperf3 -c serveur -t 10 -P 4                    # client : débit TCP (4 flux) ; -u pour UDP
mtr -rwzc 20 example.org                        # perte et latence par saut
ping -M do -s 1472 -c2 hôte                     # test MTU (1472 + 28 = 1500) ; fragmentation interdite
ss -ti dst 10.0.2.2                             # infos TCP : rtt, cwnd, retransmissions
ethtool eth0 ; ethtool -S eth0 | grep -i err    # vitesse/duplex, compteurs d'erreurs
```

## 9. Services réseau d'infrastructure (aperçu)

| Service | Logiciels | Notes |
|---------|-----------|-------|
| DHCP | `isc-dhcp-server`, `kea`, `dnsmasq` | pools, réservations par MAC, options (passerelle, DNS) |
| DNS | `bind9`, `unbound` (résolveur), `dnsmasq`, `coredns` | zones, forwarders, DNSSEC |
| NTP | `chrony`, `systemd-timesyncd` | `chronyc tracking` ; la dérive d'horloge casse TLS, Kerberos, journaux |
| Proxy / LB | `nginx`, `haproxy` | module 19 |
| Sécurité | `fail2ban`, `nftables`, `suricata` (IDS) | module 16 |

## 10. Dépannage avancé

| Symptôme | Piste |
|----------|-------|
| Ping OK, TCP bloqué | pare-feu, MTU (PMTUD cassé, tunnels) : `ping -M do -s`, baisser le MSS (`tcp option maxseg size set rt mtu`) |
| Connexions lentes / blocages après un moment | table `conntrack` saturée : `sysctl net.netfilter.nf_conntrack_max`, `dmesg \| grep conntrack` |
| Paquets reçus mais pas de réponse | `rp_filter`, routage asymétrique : `ip route get IP from SRC iif IF` |
| Doublons d'IP / instabilité | conflit d'adresse : `arping -D -I eth0 10.0.0.5` |
| Pas de forward | `net.ipv4.ip_forward`, règle `forward` du pare-feu |
| NAT ne marche pas | règle `postrouting` sur la **bonne interface de sortie**, retour via la même passerelle |
| Perte intermittente | `ethtool -S`, `ip -s link`, câblage, `tc qdisc` oubliée |

## 11. Résumé

- Netfilter : prerouting → routage → input/forward → postrouting ; NAT = réécriture d'adresses (SNAT/masquerade, DNAT).
- **Namespaces + veth + bridge** = laboratoire réseau complet sans matériel (et base des conteneurs).
- Routeur Linux : `ip_forward=1`, routes, règles `forward`, éventuellement `masquerade`.
- Tunnels : GRE, VXLAN, **WireGuard** (`wg`, `AllowedIPs`).
- `tcpdump -ni IF filtre -w fichier.pcap` pour voir la vérité ; `tc netem` pour dégrader ; `iperf3`/`mtr` pour mesurer.

## 12. Quiz

1. Que fait `ip netns exec ns1 ip addr` ?
2. Un hôte d'un LAN privé n'atteint pas Internet à travers votre routeur Linux : citez 4 vérifications.
3. Différence entre SNAT et DNAT ? Dans quels hooks s'appliquent-ils ?
4. Comment capturer les 50 premiers paquets ICMP sur `eth0` dans un fichier ?
5. Que signifie un `RST` en réponse à un `SYN` ? Et l'absence de toute réponse ?
6. À quoi sert `ip rule add from 10.1.0.50 table isp2` ?
7. Comment ajouter 100 ms de latence et 1 % de pertes sur une interface pour un test ?
8. Quelle commande teste si la MTU 1500 est praticable sans fragmentation ?

<details><summary>Réponses</summary>

1. Affiche les adresses des interfaces **du namespace** `ns1`.
2. `net.ipv4.ip_forward=1`, règle `forward` autorisant, règle `masquerade` en `postrouting` sur l'interface de sortie, route par défaut du client vers le routeur (et DNS). Éventuellement `rp_filter`/conntrack.
3. SNAT réécrit la source (postrouting) ; DNAT réécrit la destination (prerouting).
4. `sudo tcpdump -ni eth0 -c 50 -w icmp.pcap icmp`
5. RST : port fermé (ou `reject`) ; silence : paquet filtré par `drop` ou machine/route injoignable.
6. Router le trafic issu de cette IP selon la table `isp2` (routage par politique, multi-fournisseur).
7. `sudo tc qdisc add dev eth0 root netem delay 100ms loss 1%`
8. `ping -M do -s 1472 -c2 hôte` (1472 + 28 octets d'en-têtes = 1500).
</details>

➡️ **Labo** : [LAB.md](LAB.md) · **Démo** : `./lab demo 17` · **Suivant** : [18 — Performance et dépannage](../18-performance-et-depannage/README.md)
