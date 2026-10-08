# Labo 11 — Calculs réseau et enquête sur un service local

> **Durée** : 2 h 30 · **Difficulté** : ⭐⭐ · **Prérequis** : module 11 · outils : `ip`, `ss`, `curl`, `python3`

## Contexte

Votre équipe prépare un plan d'adressage et un collègue vous signale « un petit service web tourne sur la machine mais personne ne sait sur quel port ». Vous devez **calculer** les sous-réseaux puis **enquêter** avec les outils réseau.

## Mise en place

```bash
./lab setup 11
cd ~/labs/11 && ls -a
```

Le labo lance un mini serveur web sur `127.0.0.1` avec un **port aléatoire** (que vous devez découvrir !).

## Partie A — Plan d'adressage (`reponses_reseau.txt`)

Écrivez dans `reponses_reseau.txt` les lignes `CLÉ=valeur` suivantes (à la main ou avec un outil de calcul) :

| Clé | Question |
|-----|----------|
| `RESEAU` | adresse réseau de `192.168.10.77/26` |
| `BROADCAST` | adresse de diffusion de `192.168.10.77/26` |
| `PREMIER_HOTE` | première adresse utilisable de ce réseau |
| `DERNIER_HOTE` | dernière adresse utilisable |
| `NB_HOTES` | nombre d'hôtes utilisables |
| `MASQUE_20` | masque décimal d'un `/20` |
| `RESEAU_Q3` | adresse réseau de `10.1.2.3/16` |
| `NB_SOUS_RESEAUX` | combien de sous-réseaux `/26` dans un `/24` ? |
| `PRIVEE_172_20` | `172.20.5.9` est-elle privée ? (`oui`/`non`) |
| `PRIVEE_172_32` | `172.32.0.1` est-elle privée ? (`oui`/`non`) |
| `PREFIXE_100` | plus grand préfixe CIDR (`/n`, donnez `n`) permettant d'héberger au moins 100 hôtes |

## Partie B — Enquête sur la machine

1. `port.txt` : le **port TCP** sur lequel écoute le serveur Python (trouvez-le avec `ss`).
2. `page.txt` : le **contenu** de la page d'accueil du serveur (avec `curl`). Elle contient un code secret.
3. `statut.txt` : le **code HTTP** obtenu pour `/index.html` (nombre seul).
4. `code404.txt` : le code HTTP obtenu pour `/page-qui-nexiste-pas`.
5. `loopback.txt` : l'adresse IPv4 de l'interface `lo` (avec `ip`), sans masque.
6. `passerelle.txt` : l'adresse de la passerelle par défaut (`ip route`), ou `aucune` s'il n'y en a pas.
7. `localhost.txt` : l'adresse IPv4 à laquelle le **système** résout le nom `localhost` (`getent`).
8. `ecoute_local.txt` : écrivez `oui` si le serveur n'écoute **que** sur `127.0.0.1` (donc injoignable depuis un autre hôte), `non` sinon.

## Validation

```bash
./lab check 11
```

<details><summary>💡 Indices</summary>

- Partie A : `python3 -c "import ipaddress as i; n=i.ip_network('192.168.10.77/26', strict=False); print(n.network_address, n.broadcast_address)"`, ou `ipcalc`.
- `ss -ltnp | grep python`
- `curl -s http://127.0.0.1:PORT/` · `curl -s -o /dev/null -w '%{http_code}' URL`
- `ip -4 -o addr show lo` · `ip route show default` · `getent ahostsv4 localhost`
</details>

<details><summary>✅ Solution</summary>

```bash
cd ~/labs/11
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
PORT=$(ss -ltnH | awk '$4 ~ /^127\.0\.0\.1:/ {sub(".*:","",$4); print $4}' | while read p; do curl -s -m1 "http://127.0.0.1:$p/" | grep -q SECRET && echo $p; done | head -1)
echo "$PORT" > port.txt
curl -s "http://127.0.0.1:$PORT/" > page.txt
curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/index.html" > statut.txt
curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/page-qui-nexiste-pas" > code404.txt
ip -4 -o addr show lo | awk '{print $4}' | cut -d/ -f1 > loopback.txt
ip route show default | awk '{print $3; exit}' | grep . > passerelle.txt || echo aucune > passerelle.txt
getent ahostsv4 localhost | awk 'NR==1{print $1}' > localhost.txt
ss -ltnH "sport = :$PORT" | grep -q '127.0.0.1:' && echo oui > ecoute_local.txt || echo non > ecoute_local.txt
```
</details>

## Pour aller plus loin

- Montrez avec `ip route get 1.1.1.1` l'interface et l'IP source utilisées.
- Changez le serveur pour qu'il écoute sur `0.0.0.0` et constatez le changement dans `ss`.
- Ajoutez dans `/etc/hosts` l'entrée `127.0.0.1 monsite.lab` et testez `curl http://monsite.lab:PORT/`.

## Nettoyage

```bash
./lab reset 11     # arrête le serveur de test
```
