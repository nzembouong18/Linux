# Module 24 — Haute disponibilité, reprise d'activité (PRA) et résilience

> **Niveau** : Professionnel | **Durée** : 7 h (3 h cours + 4 h labo) | **Prérequis** : modules 13, 15, 17, 19, 23
>
> **Objectifs** — À la fin de ce module vous saurez :
> - définir **disponibilité**, **SPOF**, **RPO/RTO**, **PCA/PRA** et dimensionner une architecture en conséquence ;
> - concevoir une **haute disponibilité** (actif/passif, actif/actif, quorum, *fencing*, *split-brain*) ;
> - configurer **keepalived** (VRRP, IP virtuelle) et **HAProxy** (répartition + sondes de santé) ;
> - connaître **Pacemaker/Corosync**, la réplication de bases de données et de stockage ;
> - bâtir et **tester** un plan de reprise : sauvegardes vérifiées, restauration chronométrée, exercices ;
> - réagir à un incident majeur (rançongiciel, perte de site) avec méthode.

---

## 1. Vocabulaire

| Terme | Définition |
|-------|------------|
| **Disponibilité** | part du temps où le service est opérationnel : `(temps total − indisponibilité) / temps total` |
| **SPOF** (*Single Point Of Failure*) | composant dont la panne arrête tout le service |
| **HA** (haute disponibilité) | architecture qui **masque** les pannes (redondance + basculement automatique) |
| **PCA** (plan de continuité d'activité) | maintenir l'activité **pendant** l'incident |
| **PRA** (plan de reprise d'activité) | **redémarrer** après un sinistre (le plus souvent avec interruption) |
| **RPO** | perte de données maximale acceptable (en temps) |
| **RTO** | durée maximale d'interruption acceptable |
| **MTBF / MTTR** | temps moyen entre pannes / temps moyen de réparation |

| Disponibilité | Indisponibilité / an | / mois (30 j) |
|--------------:|---------------------:|--------------:|
| 99 % | 3 j 15 h | 7 h 12 |
| 99,9 % (« 3 neuf ») | 8 h 46 | 43 min |
| 99,99 % | 52 min 36 | 4 min 19 |
| 99,999 % | 5 min 16 | 26 s |

**Disponibilité en série / en parallèle** : composants en **série** → on multiplie (`0,99 × 0,99 = 98,01 %`, la chaîne est moins disponible que chaque maillon) ; composants **redondants en parallèle** → `1 − (1−a)×(1−a)` (deux serveurs à 99 % → 99,99 %), à condition que le basculement fonctionne et que les pannes soient **indépendantes** (pas le même rack, la même alimentation, le même hyperviseur, la même mise à jour).

> Chaque « neuf » supplémentaire coûte environ **dix fois plus cher** : définissez le besoin réel (RPO/RTO) avec les métiers avant de choisir l'architecture.

## 2. Stratégies de reprise après sinistre (du moins cher au plus rapide)

| Stratégie | Principe | RTO | RPO | Coût |
|-----------|----------|-----|-----|------|
| **Sauvegarde / restauration** | on restaure sur du matériel neuf | jours | heures-jour | € |
| **Pilot light** | noyau minimal (BD répliquée) toujours allumé, le reste démarré à la demande | heures | minutes | €€ |
| **Warm standby** | site secondaire réduit, en fonctionnement | minutes-heures | secondes-minutes | €€€ |
| **Actif/actif multi-sites** | plusieurs sites servent le trafic | ~0 | ~0 | €€€€ |

## 3. Éliminer les SPOF : couche par couche

```text
 Utilisateurs ── DNS (plusieurs enregistrements / DNS failover / anycast)
        │
   2 × répartiteurs HAProxy/nginx  ◄── IP virtuelle (VRRP, keepalived)
        │
   N × serveurs d'application sans état (derrière sondes de santé)
        │
   Base de données : primaire + réplicas (+ bascule automatique : Patroni, Galera, repmgr)
        │
   Stockage : RAID, réplication (DRBD, Ceph), snapshots, sauvegardes hors site
        │
   Infra : alimentation double (onduleurs), réseau redondant (bonding, 2 commutateurs), 2 baies/salles/sites
```
Règles : applications **sans état** (état en base ou cache partagé) ; sessions externalisées ; configuration reproductible (module 22) ; capacité N+1 (le service tient avec un nœud en moins).

## 4. Basculement : concepts clés

- **Actif/passif** : un nœud sert, l'autre attend ; au basculement il prend l'IP virtuelle et les services. Simple, capacité à moitié inutilisée.
- **Actif/actif** : tous servent (répartition de charge) ; plus efficace, plus complexe (état partagé, cohérence).
- **Détection de panne** : *heartbeat* (battements) + **sondes de santé applicatives** (pas seulement « le port répond » : `GET /health` vérifie la base).
- **Quorum** : un groupe n'agit que s'il contient la **majorité** des votes (`⌊n/2⌋ + 1`) : 3 nœuds → 2 ; 5 nœuds → 3. Nombre **impair** de nœuds (ou arbitre/witness).
- **Split-brain** : deux moitiés d'un cluster se croient actives (coupure réseau entre elles) et écrivent chacune → **corruption**. Parades : quorum, **fencing / STONITH** (« Shoot The Other Node In The Head » : éteindre l'autre nœud via IPMI/PDU/hyperviseur avant de reprendre ses ressources), ressources exclusives.
- **Fail-back** : retour au nœud préféré. Souvent **désactivé** (`nopreempt`) pour éviter un second basculement non maîtrisé.
- **Flapping** : basculements en boucle → temporisations, seuils (`fall`/`rise`), hystérésis.

## 5. keepalived : IP virtuelle (VRRP)

Deux répartiteurs partagent une **IP flottante**. Le nœud de plus haute **priorité** la porte ; si ses annonces VRRP (multicast 224.0.0.18, protocole 112) cessent, l'autre la reprend en 1–3 s et envoie un ARP gratuit.

`/etc/keepalived/keepalived.conf` sur le nœud **MASTER** :

```text
global_defs {
    router_id LB1
    enable_script_security
    script_user keepalived_script
}

vrrp_script check_haproxy {
    script "/usr/bin/pgrep haproxy"      # 0 = sain
    interval 2
    fall 2
    rise 2
    weight -60                           # si KO : priorité 150 - 60 = 90 < 100 → bascule
}

vrrp_instance VI_WEB {
    state MASTER                         # BACKUP sur l'autre nœud
    interface eth0
    virtual_router_id 51                 # identique sur les deux nœuds (unique par segment)
    priority 150                         # 100 sur le BACKUP
    advert_int 1
    nopreempt                            # (avec state BACKUP des deux côtés) pas de fail-back automatique
    authentication {
        auth_type PASS
        auth_pass S3cr3t12               # 8 caractères max
    }
    virtual_ipaddress {
        192.168.50.100/24 dev eth0
    }
    track_script {
        check_haproxy
    }
    notify_master "/usr/local/bin/notify.sh MASTER"
}
```
```bash
sudo keepalived -t -f /etc/keepalived/keepalived.conf    # teste la configuration
sudo systemctl enable --now keepalived
ip -br addr show eth0 | grep 192.168.50.100              # qui porte la VIP ?
journalctl -u keepalived -f                              # transitions MASTER/BACKUP/FAULT
sudo sysctl -w net.ipv4.ip_nonlocal_bind=1               # permet à HAProxy d'écouter sur la VIP même sur le nœud BACKUP
```
Test : arrêter `haproxy` ou le nœud MASTER → la VIP apparaît sur l'autre en quelques secondes ; `ping -t` depuis un client pour mesurer l'interruption.

## 6. HAProxy : répartition et sondes de santé

```text
global
    log /dev/log local0
    maxconn 4096
defaults
    mode http
    log global
    option httplog
    timeout connect 5s
    timeout client  30s
    timeout server  30s
    retries 2
frontend web
    bind *:80
    default_backend app
backend app
    balance roundrobin                          # ou leastconn
    option httpchk GET /health
    http-check expect status 200
    default-server inter 3s fall 3 rise 2
    server a1 10.0.0.11:8080 check
    server a2 10.0.0.12:8080 check
    server a3 10.0.0.13:8080 check backup       # n'est utilisé que si a1 et a2 sont KO
listen stats
    bind 127.0.0.1:8404
    stats enable
    stats uri /stats
```
```bash
haproxy -c -f /etc/haproxy/haproxy.cfg         # valider
sudo systemctl reload haproxy                  # rechargement sans coupure
echo "show servers state" | sudo socat stdio /run/haproxy/admin.sock
echo "disable server app/a1" | sudo socat stdio /run/haproxy/admin.sock      # sortir un serveur pour maintenance
```
Mise à jour sans coupure (*rolling*) : sortir `a1` → mettre à jour → vérifier `/health` → le remettre → passer à `a2`.

## 7. Clusters (Pacemaker/Corosync), bases et stockage répliqués

- **Corosync** : messagerie et quorum du cluster. **Pacemaker** : gestionnaire de ressources (IP, systemd, systèmes de fichiers, bases) avec contraintes d'ordre/colocation, *fencing* (`stonith`). Outil : `pcs`.
  ```bash
  sudo pcs cluster setup mon-cluster noeud1 noeud2 noeud3 --start --enable
  sudo pcs property set stonith-enabled=true
  sudo pcs resource create vip ocf:heartbeat:IPaddr2 ip=192.168.50.100 cidr_netmask=24 op monitor interval=10s
  sudo pcs resource create web systemd:nginx op monitor interval=10s
  sudo pcs constraint colocation add web with vip ; sudo pcs constraint order vip then web
  sudo pcs status ; sudo crm_mon -1
  ```
- **Réplication de stockage** : **DRBD** (miroir de blocs en réseau, « RAID 1 sur IP »), **Ceph/GlusterFS** (stockage distribué), SAN/NAS redondants.
- **PostgreSQL** : réplication par *streaming* (primaire + standby, synchrone ou asynchrone), bascule orchestrée par **Patroni** (avec etcd/Consul), sauvegardes **PITR** (*Point-In-Time Recovery* : base + journaux WAL archivés → restauration à la seconde près) avec `pgBackRest`/`barman`. **MariaDB** : réplication ou **Galera** (multi-maître synchrone, 3 nœuds minimum).
- **Compromis (théorème CAP)** : en cas de partition réseau, on choisit cohérence **ou** disponibilité ; la réplication synchrone limite la perte (RPO≈0) mais ajoute de la latence.

## 8. Sauvegardes qui sauvent vraiment

Principes déjà vus (module 15) et à pousser plus loin :

1. **3-2-1-1-0** : 3 copies, 2 supports, 1 hors site, **1 hors ligne ou immuable** (WORM, *object lock*, bande), **0 erreur** après vérification.
2. **Vérifier chaque sauvegarde** : somme de contrôle, `tar -tzf`, restauration d'essai automatique. Une sauvegarde non testée n'existe pas.
3. **Isoler** les sauvegardes des accès d'administration courants (rançongiciels qui chiffrent aussi les sauvegardes accessibles) ; comptes dédiés, *pull* plutôt que *push*.
4. **Chiffrer** et garder les clés **ailleurs** (coffre, papier dans un coffre-fort).
5. **Rétention** alignée sur le RPO et les obligations légales ; détection des anomalies (taille subitement différente).
6. **Documenter** la procédure de restauration, pas seulement de sauvegarde ; mesurer le **temps** de restauration réel = votre vrai RTO.

## 9. Le plan de reprise (PRA) et les exercices

**Contenu d'un PRA** : périmètre et criticité des services (classés en niveaux avec RPO/RTO), cellule de crise et rôles, **procédures pas à pas** (runbooks) testées, inventaire et dépendances (DNS, certificats, annuaire, licences, secrets), accès hors bande, contacts (internes, hébergeur, éditeurs), communication (clients, direction, régulateur), critères de déclenchement/retour à la normale.

**Tester** : 
- *Revue sur table* (tabletop) : on déroule un scénario de crise autour d'une table.
- *Exercice de restauration* : restaurer un service dans un environnement isolé et chronométrer.
- *Bascule contrôlée* : arrêter un nœud/un site en heures creuses.
- *Chaos engineering* (Chaos Monkey, `tc`, `kill`) en préproduction puis en production maîtrisée.
- Chaque exercice produit un **retour d'expérience** (écarts, correctifs, mise à jour des procédures).

### Scénario rançongiciel (ordre d'action)
1. **Isoler** (réseau/VLAN) sans éteindre brutalement ; 2. **préserver les preuves** ; 3. identifier l'étendue et la **date de compromission** ; 4. repartir de **sauvegardes saines antérieures** (vérifiées) sur une infrastructure propre ; 5. changer **tous** les secrets ; 6. corriger la faille d'entrée ; 7. notifier selon la loi (RGPD : 72 h) ; 8. post-mortem.

## 10. Résumé

- Disponibilité = fonction de la redondance ET des temps de détection/basculement ; éviter les **SPOF**, viser des composants indépendants.
- RPO → fréquence/réplication ; RTO → automatisation et entraînement ; la stratégie (sauvegarde, pilot light, warm standby, actif/actif) découle du besoin.
- Quorum (majorité), **fencing**, protection contre le **split-brain**, `nopreempt`.
- keepalived (VRRP + `track_script`) pour l'IP virtuelle, HAProxy (sondes `check`, `backup`), Pacemaker/Corosync pour les clusters, Patroni/Galera pour les bases.
- Sauvegardes **vérifiées** et **testées**, une copie immuable ; mesurer le RTO réel ; exercices réguliers.

## 11. Quiz

1. Deux serveurs de 99 % de disponibilité chacun, indépendants et en parallèle : disponibilité globale ?
2. Quel est le quorum d'un cluster de 5 nœuds ? Pourquoi éviter un nombre pair ?
3. Qu'est-ce que le split-brain et comment s'en protège-t-on ?
4. Sur quel nœud keepalived prend-il la VIP si le `track_script` du MASTER échoue avec `weight -60` ?
5. Que fait `option httpchk` dans HAProxy ? Que veut dire `backup` ?
6. Différence entre PCA et PRA ?
7. Pourquoi une sauvegarde accessible en écriture depuis le réseau de production est-elle risquée ?
8. Votre RPO est de 15 min : quelle technique ne convient pas ? (sauvegarde nocturne, réplication synchrone, archivage WAL continu)

<details><summary>Réponses</summary>

1. `1 − (0,01 × 0,01) = 99,99 %` (si le basculement est parfait).
2. 3 (majorité) ; avec un nombre pair, une partition 2/2 ne dégage aucune majorité (blocage) ou autorise deux moitiés (split-brain).
3. Deux parties du cluster se croient actives et écrivent simultanément ; quorum + fencing (STONITH) + ressources exclusives + arbitre.
4. Sa priorité passe à 150−60 = 90, inférieure à celle du BACKUP (100) : la VIP bascule.
5. Il envoie une requête HTTP applicative pour juger la santé du serveur ; `backup` = serveur de secours utilisé seulement si tous les autres sont indisponibles.
6. PCA : continuer l'activité pendant l'incident (HA, redondance) ; PRA : reprendre après un sinistre (restauration, site de secours).
7. Un rançongiciel/un attaquant avec accès à la production peut chiffrer ou supprimer aussi les sauvegardes ; il faut des copies isolées/immuables.
8. La sauvegarde nocturne (perte jusqu'à 24 h) ; il faut réplication ou archivage continu.
</details>

➡️ **Labo** : [LAB.md](LAB.md) · **Démo** : `./lab demo 24` · **Suivant** : [25 — Projet final](../25-projet-final/README.md)
