# Labo 17 — Un routeur Linux avec namespaces : forwarding, pare-feu, NAT et capture

> **Durée** : 4 h · **Difficulté** : ⭐⭐⭐⭐ · **Prérequis** : module 17 · **Droits** : `root`/`sudo` avec `CAP_NET_ADMIN` (VM ou conteneur `--privileged`)
> Tout est virtuel (namespaces + veth) : votre vrai réseau n'est pas modifié.

## Contexte

Vous devez prouver qu'un serveur Linux peut jouer le rôle de **routeur / pare-feu / NAT** entre un réseau « clients » et un réseau « serveurs ». Vous construisez la maquette avec trois *network namespaces* :

```text
   lab17-a  (client)            lab17-r  (routeur)            lab17-b  (serveur)
  10.17.1.2/24 ─────── 10.17.1.1/24 │ 10.17.2.1/24 ─────── 10.17.2.2/24
   gw 10.17.1.1                    ip_forward=1                gw 10.17.2.1
                                                    serveur web : 10.17.2.2:8080
```

## Mise en place

```bash
./lab setup 17
cd ~/labs/17 && cat plan.txt && ls www
```

## Tâches (dans `~/labs/17`)

1. **Topologie** : créez les namespaces `lab17-a`, `lab17-b`, `lab17-r` (avec `lo` actif), deux paires **veth** (a↔r et b↔r), attribuez les adresses du plan, activez les interfaces, définissez les **routes par défaut** de `a` et `b` vers le routeur.
2. **Routage** : activez le **forwarding IPv4** dans `lab17-r` *(sans lui, a ne joint pas b)*. Vérifiez que `a` pingue `10.17.2.2`.
3. **Capture** : dans `lab17-r`, capturez avec `tcpdump` **3 paquets ICMP** sur l'interface côté `a` dans **`capture.pcap`** pendant que `a` envoie des pings vers `b`.
4. **Service** : lancez dans `lab17-b` le serveur web du dossier `www/` (`python3 -m http.server 8080 --bind 10.17.2.2 --directory ~/labs/17/www`), journal (stdout+stderr) **ajouté** à `serveur.log`. Depuis `lab17-a`, récupérez la page : `page.txt`. Le journal doit montrer le client `10.17.1.2`.
5. **Pare-feu** : dans `lab17-r`, avec `nftables`, **interdisez les pings (`echo-request`) venant de `10.17.1.0/24`** à travers le routeur — mais **pas le HTTP**. (Le ping de b vers a doit continuer à fonctionner : seule la requête d'écho venant de a est filtrée.)
6. **NAT** : toujours dans `lab17-r`, ajoutez du **masquerade** pour le trafic sortant par l'interface côté `b`. Refaites une requête HTTP depuis `a` : le journal du serveur doit maintenant montrer le client **`10.17.2.1`** (l'adresse du routeur) au lieu de `10.17.1.2`.
7. **Rapport** `nat.txt` :
   ```
   IP_VUE_AVANT_NAT=<adresse client vue par le serveur avant le NAT>
   IP_VUE_APRES_NAT=<adresse client vue par le serveur après le NAT>
   ```

## Validation

```bash
./lab check 17
```

<details><summary>💡 Indices</summary>

- `sudo ip link add l17a type veth peer name l17ra` · `sudo ip link set l17a netns lab17-a` · `sudo ip -n lab17-a addr add 10.17.1.2/24 dev l17a`
- `sudo ip netns exec lab17-r sysctl -w net.ipv4.ip_forward=1`
- `sudo ip netns exec lab17-r tcpdump -ni l17ra -c 3 -w capture.pcap icmp &` puis `sudo ip netns exec lab17-a ping -c3 10.17.2.2`
- Serveur : `sudo ip netns exec lab17-b python3 -m http.server 8080 --bind 10.17.2.2 --directory $PWD/www >> serveur.log 2>&1 &`
- nftables : `nft add table inet fw` · `nft add chain inet fw forward '{ type filter hook forward priority 0; }'` · `nft add rule inet fw forward ip saddr 10.17.1.0/24 icmp type echo-request drop`
- NAT : `nft add table ip nat` · `nft add chain ip nat post '{ type nat hook postrouting priority srcnat; }'` · `nft add rule ip nat post oifname "l17rb" masquerade` (tous deux via `ip netns exec lab17-r`)
</details>

<details><summary>✅ Solution</summary>

```bash
cd ~/labs/17
for n in a b r; do sudo ip netns add lab17-$n; sudo ip -n lab17-$n link set lo up; done
sudo ip link add l17a type veth peer name l17ra; sudo ip link set l17a netns lab17-a; sudo ip link set l17ra netns lab17-r
sudo ip link add l17b type veth peer name l17rb; sudo ip link set l17b netns lab17-b; sudo ip link set l17rb netns lab17-r
sudo ip -n lab17-a addr add 10.17.1.2/24 dev l17a;  sudo ip -n lab17-a link set l17a up
sudo ip -n lab17-r addr add 10.17.1.1/24 dev l17ra; sudo ip -n lab17-r link set l17ra up
sudo ip -n lab17-r addr add 10.17.2.1/24 dev l17rb; sudo ip -n lab17-r link set l17rb up
sudo ip -n lab17-b addr add 10.17.2.2/24 dev l17b;  sudo ip -n lab17-b link set l17b up
sudo ip -n lab17-a route add default via 10.17.1.1
sudo ip -n lab17-b route add default via 10.17.2.1
sudo ip netns exec lab17-r sysctl -w net.ipv4.ip_forward=1
sudo ip netns exec lab17-r tcpdump -ni l17ra -c 3 -w capture.pcap icmp 2>/dev/null &
sleep 1; sudo ip netns exec lab17-a ping -c3 10.17.2.2; wait
sudo ip netns exec lab17-b python3 -m http.server 8080 --bind 10.17.2.2 --directory $PWD/www >> serveur.log 2>&1 &
sleep 2; sudo ip netns exec lab17-a curl -s http://10.17.2.2:8080/ > page.txt
sudo ip netns exec lab17-r nft add table inet fw
sudo ip netns exec lab17-r nft add chain inet fw forward '{ type filter hook forward priority 0; }'
sudo ip netns exec lab17-r nft add rule inet fw forward ip saddr 10.17.1.0/24 icmp type echo-request drop
sudo ip netns exec lab17-r nft add table ip nat
sudo ip netns exec lab17-r nft add chain ip nat post '{ type nat hook postrouting priority srcnat; }'
sudo ip netns exec lab17-r nft add rule ip nat post oifname "l17rb" masquerade
sudo ip netns exec lab17-a curl -s http://10.17.2.2:8080/ > /dev/null
printf 'IP_VUE_AVANT_NAT=10.17.1.2\nIP_VUE_APRES_NAT=10.17.2.1\n' > nat.txt
```
</details>

## Pour aller plus loin

- Ajoutez un **DNAT** : le routeur écoute sur `10.17.1.1:80` et redirige vers `10.17.2.2:8080`.
- Remplacez les veth directes par un **bridge** dans `lab17-r` avec deux clients.
- Ajoutez `tc qdisc add dev l17rb root netem delay 50ms loss 5%` et mesurez avec `ping`/`curl -w`.
- Sauvegardez le jeu de règles dans un fichier `nft -f` rechargeable.

## Nettoyage

```bash
./lab reset 17     # arrête le serveur, supprime les namespaces
```
