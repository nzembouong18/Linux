# Labo 24 — Exercice de reprise : sauvegardes vérifiées, bascule, keepalived et HAProxy

> **Durée** : 4 h · **Difficulté** : ⭐⭐⭐⭐ · **Prérequis** : module 24 · outils : `tar`, `sha256sum`, `keepalived`/`haproxy` (validation facultative)
> Tout est simulé dans des fichiers : aucun cluster réel n'est nécessaire.

## Contexte

Lundi 14 mars 2024, 16 h 30 : un administrateur supprime par erreur la base de données du site de l'entreprise. Vous êtes en charge de la reprise. Pour être prêts la prochaine fois, vous devrez aussi écrire la logique de basculement d'un couple de serveurs et la configuration de l'IP virtuelle (keepalived) et du répartiteur (HAProxy).

## Mise en place

```bash
./lab setup 24
cd ~/labs/24 && cat incident.txt && ls backups
```

## Partie A — Restaurer à partir de sauvegardes… *vérifiées*

Le dossier `backups/` contient une sauvegarde quotidienne (02 h 00) du site pour du 10 au 14 mars, et `SHA256SUMS` les empreintes enregistrées au moment de la sauvegarde. Attention : toutes ne sont pas saines.

1. Déterminez quelles sauvegardes sont **valides** : l'empreinte doit correspondre (`sha256sum -c`) **et** l'archive doit être lisible (`tar -tzf`).
2. **Restaurez** la dernière sauvegarde valide dans **`restauration/`** (sans toucher à `backups/`).
3. Rédigez **`rapport-pra.txt`** (`CLÉ=valeur`) :
   - `SAUVEGARDES_VALIDES` / `SAUVEGARDES_INVALIDES` : dates `AAAA-MM-JJ` séparées par des virgules, triées ;
   - `DERNIERE_VALIDE` : la date de la sauvegarde restaurée ;
   - `PERTE_DONNEES_HEURES` : durée entre cette sauvegarde (02:00) et l'incident (en heures, ex. `62.5`) ;
   - `RTO_REEL_MINUTES` : durée entre l'incident et le rétablissement du service ;
   - `RPO_RESPECTE`, `RTO_RESPECTE` : `oui` / `non` selon les objectifs de `incident.txt`.

## Partie B — Logique de basculement : `bascule.sh STATE_DIR`

Écrivez un script bash (exécutable) qui gère un couple actif/passif **`noeud1`** / **`noeud2`** à partir d'un dossier d'état :

- `STATE_DIR/noeud1.health`, `noeud2.health` : contiennent `up` ou `down` ;
- `STATE_DIR/vip` : nom du nœud qui porte l'IP virtuelle (`noeud1`, `noeud2` ou `none`) ;
- `STATE_DIR/<nœud>.fence` : s'il existe, le nœud est **isolé (fencing)** : considéré indisponible même s'il est `up`, jusqu'à ce qu'un administrateur supprime le fichier.

Un nœud est **disponible** si `health` vaut `up` **et** qu'il n'est pas isolé. Comportement (affichage sur la 1ʳᵉ ligne de stdout, puis code retour) :

| Situation | Sortie | Code | Effet |
|-----------|--------|-----:|-------|
| le porteur de la VIP est disponible | `OK: <nœud> actif` | 0 | rien (**pas de fail-back**) |
| le porteur est indisponible, l'autre disponible | `BASCULE: <ancien> -> <nouveau>` | 1 | isole l'ancien (écrit `<ancien>.fence`), VIP → nouveau |
| plus aucun nœud disponible | `PANNE TOTALE: aucun noeud disponible` | 2 | VIP inchangée |
| `vip` contient les deux nœuds (`noeud1,noeud2`) | `SPLIT-BRAIN: …` | 3 | **ne modifie rien** |
| `vip` vaut `none` | `ELECTION: <nœud>` (noeud1 prioritaire) ou `PANNE TOTALE…` | 0 / 2 | VIP → élu |
| dossier absent / sans argument | usage sur **stderr** | 64 | — |

## Partie C — Configurations

Dans `~/labs/24` :

1. **`keepalived-master.conf`** et **`keepalived-backup.conf`** : `global_defs` avec `enable_script_security` et `script_user root` ; `vrrp_script check_haproxy` (`script "/usr/bin/pgrep haproxy"`, `interval`, `weight -60`) ; `vrrp_instance VI_WEB` : `virtual_router_id 51`, `authentication` (PASS), VIP **`192.168.50.100/24`**, `track_script { check_haproxy }` ; le MASTER : `state MASTER`, `priority 150` ; le BACKUP : `state BACKUP`, `priority 100`. *(Vérifiez que la panne du script fait bien passer la priorité du MASTER sous celle du BACKUP.)*
2. **`haproxy.cfg`** : `frontend web` en `*:80` vers `backend app` : `balance roundrobin`, sonde `option httpchk GET /health`, deux serveurs `check` (`a1 10.0.0.11:8080`, `a2 10.0.0.12:8080`) **et** un serveur `backup` (`a3 10.0.0.13:8080`).

## Partie D — Conception (`reponses.txt`)

| Clé | Question |
|-----|----------|
| `QUORUM_5` | quorum (nombre minimal de votes) d'un cluster de 5 nœuds |
| `TOLERANCE_5` | combien de nœuds peuvent tomber sans perdre le quorum ? |
| `DISPO_PARALLELE` | disponibilité (en %) de deux composants indépendants à 99 % montés en parallèle |
| `PARADE_SPLIT_BRAIN` | mécanisme qui isole de force un nœud douteux (un mot : `fencing` ou `stonith`) |
| `INDISPO_999_HEURES` | indisponibilité annuelle maximale (en heures, 2 décimales) pour 99,9 % |
| `STRATEGIE_RTO_MIN` | stratégie de reprise offrant le RTO le plus faible (`sauvegarde`, `pilot light`, `warm standby` ou `actif/actif`) |

## Validation

```bash
./lab check 24
```

<details><summary>💡 Indices</summary>

- `sha256sum -c SHA256SUMS 2>&1 | grep -E 'OK|FAILED|ÉCHEC'` ; `tar -tzf backups/site-2024-03-13.tar.gz >/dev/null`.
- Durée : `date -d '2024-03-14 16:30' +%s` − `date -d '2024-03-12 02:00' +%s` → secondes.
- `tar -xzf backups/site-2024-03-12.tar.gz -C restauration`.
- Priorité effective du MASTER en panne : 150 + (−60) = 90 < 100.
- `keepalived -t -f fichier` et `haproxy -c -f haproxy.cfg` (si installés).
</details>

<details><summary>✅ Solution</summary>

```bash
cd ~/labs/24
# A
for f in backups/site-*.tar.gz; do d=${f##*site-}; d=${d%.tar.gz}
  if grep " $f\$" SHA256SUMS | sha256sum -c --status - 2>/dev/null && tar -tzf "$f" >/dev/null 2>&1; then v+=("$d"); else x+=("$d"); fi; done
mkdir -p restauration && tar -xzf backups/site-2024-03-12.tar.gz -C restauration
cat > rapport-pra.txt <<EOF
SAUVEGARDES_VALIDES=$(IFS=,; echo "${v[*]}")
SAUVEGARDES_INVALIDES=$(IFS=,; echo "${x[*]}")
DERNIERE_VALIDE=2024-03-12
PERTE_DONNEES_HEURES=$(awk -v a=$(date -d '2024-03-14 16:30' +%s) -v b=$(date -d '2024-03-12 02:00' +%s) 'BEGIN{printf "%.1f", (a-b)/3600}')
RTO_REEL_MINUTES=80
RPO_RESPECTE=non
RTO_RESPECTE=oui
EOF
# B
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
# C
mk() { cat > keepalived-$1.conf <<EOF
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
# D
cat > reponses.txt <<'EOF'
QUORUM_5=3
TOLERANCE_5=2
DISPO_PARALLELE=99.99
PARADE_SPLIT_BRAIN=fencing
INDISPO_999_HEURES=8.76
STRATEGIE_RTO_MIN=actif/actif
EOF
```
</details>

## Pour aller plus loin

- Montez un vrai couple keepalived dans deux namespaces ou deux VM (Vagrant) et mesurez l'interruption avec `ping`.
- Ajoutez à `bascule.sh` un mode `--watch` (boucle toutes les 2 s) et une temporisation anti-*flapping* (2 échecs consécutifs avant bascule).
- Automatisez la vérification quotidienne des sauvegardes (script + timer systemd + alerte en cas d'échec).
- Rédigez le runbook « suppression accidentelle de la base » en 10 étapes.

## Nettoyage

```bash
./lab reset 24
```
