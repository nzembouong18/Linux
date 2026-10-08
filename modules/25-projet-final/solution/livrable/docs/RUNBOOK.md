# Runbook — exploitation de l'application Tickets

Chaque fiche suit le schéma : **Symptômes → Diagnostic → Actions → Vérification → Escalade**.

## 1. Le service Tickets est arrêté (HTTP 502 depuis nginx)

**Symptômes** : alerte `HostDown`/sonde CRITICAL, nginx répond 502 Bad Gateway.

**Diagnostic**
1. `systemctl status tickets` — état et code de sortie ;
2. `journalctl -u tickets -n 100 --no-pager` — dernière erreur ;
3. `ss -ltnp | grep 8000` — le port est-il à l'écoute ? ;
4. `systemd-analyze verify /etc/systemd/system/tickets.service` si une modification récente est suspectée.

**Actions**
1. `sudo systemctl restart tickets` ;
2. si l'échec persiste : lire l'erreur (droits sur `/var/lib/tickets`, variable manquante dans `/etc/tickets/tickets.env`), corriger **dans le dépôt**, redéployer ;
3. dernier recours : revenir à la version précédente (`git revert` + playbook).

**Vérification** : `tickets-healthcheck -u http://127.0.0.1/health` retourne OK ; `curl -I http://127.0.0.1/`.

**Escalade** : si le service retombe plus de 3 fois en 10 minutes, prévenir l'astreinte applicative.

## 2. Disque plein

**Symptômes** : alerte `DiskAlmostFull` (> 90 %), écritures en erreur (`No space left on device`).

**Diagnostic**
1. `df -h` puis `df -i` (inodes) ;
2. `du -xh --max-depth=1 /var | sort -h | tail` ;
3. `sudo lsof +L1` — fichiers supprimés mais encore ouverts.

**Actions**
1. `journalctl --vacuum-size=500M` ; vérifier la rotation (`logrotate -d /etc/logrotate.d/nginx`) ;
2. supprimer les sauvegardes obsolètes **après** vérification qu'une copie hors site existe ;
3. redémarrer le processus qui retient un fichier supprimé ; étendre le volume si la tendance l'exige.

**Vérification** : occupation < 80 %, `systemctl --failed` vide.

## 3. Erreurs 5xx ou lenteurs (nginx)

**Symptômes** : taux de 5xx > 2 %, latence p95 > 1 s, sonde WARNING/CRITICAL.

**Diagnostic**
1. `tail -n 200 /var/log/nginx/tickets-access.log` — champs `rt=` (durée) et `up=` (backend) ;
2. `awk '{print $9}' /var/log/nginx/tickets-access.log | sort | uniq -c | sort -rn` — répartition des codes ;
3. `top`/`vmstat 1 5` — saturation CPU, mémoire ou I/O ; `journalctl -u tickets -p err`.

**Actions** : relancer le service ; si un pic de trafic légitime est en cause, relever temporairement la limite `limit_req` (via le dépôt) ; si une régression suit un déploiement, revenir en arrière.

**Vérification** : taux d'erreurs revenu sous le seuil pendant 15 minutes.

## 4. Sauvegarde en échec

**Diagnostic** : `journalctl -u tickets-backup.service`, code de sortie (3 source, 4 destination, 5 archive illisible), espace libre sur la destination.
**Actions** : corriger la cause, relancer `tickets-backup`, vérifier `sha256sum -c SHA256SUMS` dans le dossier de destination.
**Escalade** : deux échecs consécutifs = incident (RPO menacé) → prévenir le responsable exploitation.
