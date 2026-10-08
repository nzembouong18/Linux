# Module 11 — Réseau : les fondamentaux sous Linux

> **Niveau** : Intermédiaire | **Durée** : 5 h (2 h 30 cours + 2 h 30 labo) | **Prérequis** : modules 02–07
>
> **Objectifs** — À la fin de ce module vous saurez :
> - expliquer les couches TCP/IP et le parcours d'un paquet ;
> - calculer adresses, masques, sous-réseaux (CIDR) ;
> - inspecter et configurer interfaces, routes, ARP avec la suite `ip` ;
> - comprendre et tester la résolution DNS ;
> - observer les connexions et ports (`ss`, `lsof`) ; tester avec `curl`, `nc` ;
> - configurer le réseau de façon persistante (Netplan / NetworkManager) ;
> - appliquer une méthode de dépannage « de bas en haut ».

---

## 1. Modèle en couches

```text
 Modèle TCP/IP            Exemples                       Outils Linux
 ┌───────────────────┐
 │ 4 Application     │  HTTP, DNS, SSH, SMTP, TLS      curl, dig, ssh, openssl
 ├───────────────────┤
 │ 3 Transport       │  TCP (fiable), UDP (rapide)     ss, nc, nmap
 ├───────────────────┤
 │ 2 Internet (IP)   │  IPv4, IPv6, ICMP, routage      ip route, ping, traceroute
 ├───────────────────┤
 │ 1 Accès réseau    │  Ethernet, Wi-Fi, ARP, VLAN     ip link, ip neigh, ethtool
 └───────────────────┘
```

**Encapsulation** : les données applicatives sont placées dans un segment TCP, dans un paquet IP, dans une trame Ethernet. Chaque couche ajoute son en-tête.

| | TCP | UDP |
|---|-----|-----|
| Connexion | oui (poignée de main SYN, SYN-ACK, ACK) | non |
| Fiabilité / ordre | garantis (retransmissions) | non |
| Usage | HTTP(S), SSH, SMTP, bases de données | DNS, DHCP, VoIP, streaming, NTP |

### Ports courants à connaître

| Port | Service | Port | Service |
|-----:|---------|-----:|---------|
| 22 | SSH | 443 | HTTPS |
| 25 / 587 | SMTP | 53 | DNS (UDP/TCP) |
| 80 | HTTP | 123 | NTP (UDP) |
| 110 / 143 | POP3 / IMAP | 3306 | MySQL/MariaDB |
| 67-68 | DHCP (UDP) | 5432 | PostgreSQL |
| 389 / 636 | LDAP / LDAPS | 6379 | Redis |
| 3389 | RDP | 6443 | API Kubernetes |

Ports **0–1023** : « privilégiés » (il faut être root ou posséder `CAP_NET_BIND_SERVICE` pour y écouter). Liste : `/etc/services`.

## 2. Adressage IPv4 et CIDR

Une adresse IPv4 = 32 bits, notée en 4 octets (`192.168.10.77`). Un **masque** sépare la partie *réseau* de la partie *hôte*. Notation **CIDR** : `/n` = nombre de bits à 1 du masque.

```text
192.168.10.77 /26
11000000.10101000.00001010.01001101   adresse
11111111.11111111.11111111.11000000   masque /26 = 255.255.255.192
11000000.10101000.00001010.01000000   → réseau   192.168.10.64
                           01111111   → broadcast 192.168.10.127
hôtes utilisables : .65 à .126  → 2^(32-26) − 2 = 62
```

| CIDR | Masque | Adresses | Hôtes |
|-----:|--------|---------:|------:|
| /8 | 255.0.0.0 | 16 777 216 | 16 777 214 |
| /16 | 255.255.0.0 | 65 536 | 65 534 |
| /24 | 255.255.255.0 | 256 | 254 |
| /25 | 255.255.255.128 | 128 | 126 |
| /26 | 255.255.255.192 | 64 | 62 |
| /27 | 255.255.255.224 | 32 | 30 |
| /28 | 255.255.255.240 | 16 | 14 |
| /30 | 255.255.255.252 | 4 | 2 (liaisons point à point) |
| /32 | 255.255.255.255 | 1 | 1 (une seule machine) |

**Plages privées (RFC 1918)**, non routées sur Internet : `10.0.0.0/8` · `172.16.0.0/12` (172.16 → 172.31) · `192.168.0.0/16`. Autres : `127.0.0.0/8` (loopback), `169.254.0.0/16` (lien local / APIPA), `100.64.0.0/10` (CGNAT), `224.0.0.0/4` (multicast).

Outils de calcul : `ipcalc 192.168.10.77/26`, `sipcalc`, ou Python :

```bash
python3 -c "import ipaddress as i; n=i.ip_network('192.168.10.77/26',strict=False); print(n, n.netmask, n.broadcast_address, n.num_addresses-2)"
```

**IPv6** : 128 bits en hexadécimal (`2001:db8::1/64`), pas de broadcast, adresses de lien local `fe80::/10`, auto-configuration SLAAC. Les commandes sont les mêmes (`ip -6`, `ping -6`, `ss -6`).

## 3. La suite `ip` (iproute2)

> `ifconfig`, `route`, `netstat`, `arp` sont **obsolètes** (paquet net-tools) : utilisez `ip` et `ss`.

```bash
ip -br addr                    # résumé (-br brief) des interfaces et adresses
ip addr show eth0              # détail d'une interface
ip -4 -o addr show             # une ligne par adresse IPv4
ip link                        # couche 2 : état, MAC, MTU
ip -s link show eth0           # statistiques (erreurs, paquets perdus)
ip route                       # table de routage
ip route get 8.8.8.8           # quelle route/interface/source sera utilisée ?
ip neigh                       # table ARP/NDP (voisins)
```

### Configuration à chaud (non persistante : perdue au redémarrage)

```bash
sudo ip link set eth0 up
sudo ip addr add 192.168.50.10/24 dev eth0
sudo ip addr del 192.168.50.10/24 dev eth0
sudo ip route add 10.20.0.0/16 via 192.168.50.1
sudo ip route add default via 192.168.50.1
sudo ip route del 10.20.0.0/16
sudo ip link set eth0 mtu 1400
```

### La table de routage

```text
$ ip route
default via 192.168.1.1 dev eth0 proto dhcp src 192.168.1.50 metric 100
192.168.1.0/24 dev eth0 proto kernel scope link src 192.168.1.50
```

Pour chaque paquet, le noyau choisit la route **la plus spécifique** (plus grand préfixe) ; sinon la route par défaut (`default` = `0.0.0.0/0`) vers la **passerelle**. Pour qu'une machine **route** pour d'autres : `sysctl -w net.ipv4.ip_forward=1`.

## 4. DNS : noms ↔ adresses

```text
Application ──► resolver (libc) ──► /etc/hosts ? ──► cache local (systemd-resolved) ──► serveur DNS (/etc/resolv.conf)
```

L'ordre est défini par `/etc/nsswitch.conf` (`hosts: files dns`).

```bash
cat /etc/hosts                          # correspondances locales
cat /etc/resolv.conf                    # serveurs DNS (souvent 127.0.0.53 = systemd-resolved)
resolvectl status                       # DNS réels par interface (systemd-resolved)
getent hosts www.example.org            # résolution comme le ferait une application
dig example.org                         # requête DNS détaillée
dig +short example.org A                # IPv4 seulement
dig +short example.org MX               # serveurs de messagerie
dig @1.1.1.1 example.org                # interroger un serveur précis
dig -x 93.184.216.34                    # résolution inverse
dig +trace example.org                  # suit la délégation depuis la racine
host example.org ; nslookup example.org
```

| Enregistrement | Rôle |
|----------------|------|
| **A** / **AAAA** | nom → IPv4 / IPv6 |
| **CNAME** | alias vers un autre nom |
| **MX** | serveurs de messagerie |
| **NS** | serveurs de noms de la zone |
| **TXT** | texte (SPF, DKIM, vérifications) |
| **PTR** | adresse → nom (inverse) |
| **SOA** | autorité sur la zone |

Piège : `ping` fonctionne par IP mais pas par nom ⇒ problème **DNS**, pas de connectivité.

## 5. Ports, sockets et connexions : `ss`

```bash
ss -tuln                # TCP + UDP, en écoute (listening), numérique
ss -tulpn               # + processus propriétaire (root pour voir tous)
ss -tn state established    # connexions établies
ss -tn dst :443         # filtres sur destination
ss -s                   # statistiques résumées
ss -ltn '( sport = :22 )'
lsof -i :80 ; lsof -iTCP -sTCP:LISTEN -P -n
```

Lire une ligne : `LISTEN 0 4096 127.0.0.1:5432 0.0.0.0:* users:(("postgres",pid=912,fd=6))`
- `127.0.0.1:5432` : n'écoute que **en local** ; `0.0.0.0:5432` ou `*:5432` : sur **toutes** les interfaces IPv4 ; `[::]:80` : IPv6 (souvent aussi IPv4).
- Un service « démarré mais injoignable » : vérifier l'**adresse d'écoute**, puis le pare-feu.

## 6. Tester la connectivité

```bash
ping -c 4 8.8.8.8                    # ICMP : joignabilité + latence
ping -c 4 example.org                # + résolution DNS
traceroute example.org               # chemin saut par saut (ou: tracepath, mtr -rwc 10 example.org)
mtr -rwc 10 example.org              # ping + traceroute continu (très utile)
curl -I https://example.org          # en-têtes HTTP seulement
curl -s -o /dev/null -w '%{http_code} %{time_total}s\n' https://example.org
curl -v https://example.org          # détail de la connexion/TLS
curl -fsSL -o fichier URL            # télécharger (f: échoue sur erreur HTTP, L: suit les redirections)
curl --resolve example.org:443:10.0.0.5 https://example.org      # forcer l'IP sans toucher au DNS
curl -X POST -H 'Content-Type: application/json' -d '{"a":1}' http://localhost:8080/api
wget -c URL                          # téléchargement reprenable
nc -zv hôte 22                       # le port 22 est-il ouvert ? (nc = netcat)
nc -l 9000                           # écouter sur le port 9000 (test rapide)
echo "test" | nc hôte 9000           # envoyer
timeout 3 bash -c '</dev/tcp/hôte/22' && echo ouvert     # sans netcat, avec bash seul
openssl s_client -connect example.org:443 -servername example.org </dev/null | openssl x509 -noout -dates -subject
```

## 7. Configuration persistante

### Ubuntu Server : Netplan (YAML) — `/etc/netplan/*.yaml`

```yaml
network:
  version: 2
  renderer: networkd          # ou NetworkManager sur poste de travail
  ethernets:
    ens3:
      dhcp4: false
      addresses: [192.168.50.10/24]
      routes:
        - to: default
          via: 192.168.50.1
      nameservers:
        addresses: [1.1.1.1, 9.9.9.9]
        search: [lab.local]
```
```bash
sudo netplan try        # applique avec retour arrière automatique après 120 s si vous perdez la main
sudo netplan apply
```

### NetworkManager (RHEL, Fedora, postes de travail)

```bash
nmcli device status
nmcli connection show
sudo nmcli con mod "System eth0" ipv4.addresses 192.168.50.10/24 ipv4.gateway 192.168.50.1 \
     ipv4.dns "1.1.1.1" ipv4.method manual
sudo nmcli con up "System eth0"
nmtui                    # interface texte
```

### Nom de machine

```bash
hostnamectl                                   # état
sudo hostnamectl set-hostname web01.lab.local
```

### Fichiers `/etc/hosts` : résolution locale rapide

```text
127.0.0.1   localhost
192.168.50.20  db01.lab.local db01
```

## 8. NAT, pare-feu : aperçu

- **NAT** (traduction d'adresses) : un routeur remplace l'adresse source privée par sa propre adresse publique (`MASQUERADE`) ; table de suivi de connexions (*conntrack*).
- **Pare-feu** : `nftables` (moderne), `ufw` (simple, Ubuntu), `firewalld` (RHEL) — module 16 et 17.

## 9. Méthode de dépannage « de bas en haut »

| # | Question | Commande | Si ça échoue |
|---|----------|----------|--------------|
| 1 | Le lien est-il actif ? | `ip -br link` | câble, VM, driver, `ip link set up` |
| 2 | Ai-je une adresse IP valide ? | `ip -br addr` | DHCP, config statique |
| 3 | Ai-je une route par défaut ? | `ip route` | passerelle absente |
| 4 | La passerelle répond-elle ? | `ping -c2 $(ip route show default | awk '{print $3}')` | couche 2 : VLAN, ARP (`ip neigh`) |
| 5 | Internet par IP ? | `ping -c2 1.1.1.1` | routage amont, NAT, pare-feu |
| 6 | Le DNS fonctionne-t-il ? | `getent hosts example.org` / `dig` | `resolv.conf`, `resolvectl` |
| 7 | Le port est-il ouvert ? | `nc -zv hôte port` | pare-feu, service arrêté |
| 8 | Le service répond-il correctement ? | `curl -v` | configuration applicative, TLS |
| 9 | Que voit-on sur le fil ? | `sudo tcpdump -ni eth0 port 80` | analyse précise (module 17) |

## 10. Résumé

- TCP/IP : 4 couches ; TCP fiable, UDP rapide. Ports bien connus : 22, 53, 80, 443…
- CIDR : `/n` ⇒ 2^(32−n) adresses ; privées : 10/8, 172.16/12, 192.168/16.
- `ip -br addr`, `ip route`, `ip neigh`, `ss -tulpn`, `dig`, `curl`, `nc -zv`, `mtr`.
- Persistant : Netplan (Ubuntu) / nmcli (RHEL) ; DNS via `resolv.conf` / `resolvectl`.
- Dépannage ordonné : lien → IP → route → passerelle → Internet → DNS → port → application.

## 11. Quiz

1. Combien d'hôtes dans un `/27` ? Quel est son masque ?
2. `172.20.5.4` est-elle une adresse privée ? Et `172.32.0.1` ?
3. Quelle commande indique la route que prendra un paquet vers `8.8.8.8` ?
4. Un service écoute sur `127.0.0.1:8080`. Un collègue sur le réseau peut-il s'y connecter ?
5. Que signifie « `ping 8.8.8.8` OK mais `ping google.com` échoue » ?
6. Quelle est la différence entre `ip addr add` et la configuration Netplan ?
7. Comment tester l'ouverture du port 443 d'un serveur sans outil spécial ?
8. À quoi sert `/etc/nsswitch.conf` ?

<details><summary>Réponses</summary>

1. 30 hôtes (32 adresses − 2) ; masque 255.255.255.224.
2. Oui (172.16.0.0–172.31.255.255). Non (hors plage /12).
3. `ip route get 8.8.8.8`
4. Non : l'écoute est limitée à la boucle locale. Il faut écouter sur `0.0.0.0` ou l'IP externe.
5. La connectivité IP fonctionne mais la résolution DNS est en panne.
6. `ip addr add` est temporaire (perdu au redémarrage) ; Netplan est persistant.
7. `nc -zv serveur 443` ou `timeout 3 bash -c '</dev/tcp/serveur/443'` ou `curl -v telnet://serveur:443`.
8. À définir l'ordre des sources de résolution (fichiers, DNS, mdns…) pour `hosts`, `passwd`, `group`…
</details>

➡️ **Labo** : [LAB.md](LAB.md) · **Démo** : `./lab demo 11` · **Suivant** : [12 — SSH et transferts](../12-ssh-et-transferts/README.md)
