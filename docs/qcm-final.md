# QCM final — 60 questions

15 questions par niveau. **Une seule réponse correcte** par question. Réponses et explications repliées en fin de chaque niveau. Durée conseillée : 1 minute par question.

---

## Niveau 1 — Débutant (modules 01 à 06)

**Q1.** Linux est, à proprement parler :
- A) un système d'exploitation complet
- B) un noyau (*kernel*)
- C) une distribution
- D) un interpréteur de commandes

**Q2.** Quelle commande affiche le répertoire courant ?
- A) `cd`
- B) `ls`
- C) `pwd`
- D) `where`

**Q3.** Depuis `/usr/share/doc`, quel chemin relatif mène à `/etc` ?
- A) `../etc`
- B) `../../etc`
- C) `../../../etc`
- D) `~/etc`

**Q4.** Quelle commande crée `a/b/c` même si `a` et `b` n'existent pas ?
- A) `mkdir a/b/c`
- B) `mkdir -p a/b/c`
- C) `touch a/b/c`
- D) `mkdir -r a/b/c`

**Q5.** Quelle commande supprime un dossier **non vide** ?
- A) `rmdir dossier`
- B) `rm dossier`
- C) `rm -r dossier`
- D) `del dossier`

**Q6.** Que fait `cmd > f 2>&1` ?
- A) envoie stdout dans `f` et stderr à l'écran
- B) envoie stdout **et** stderr dans `f`
- C) envoie stderr dans stdout puis l'écran
- D) ajoute stdout à la fin de `f`

**Q7.** Que produit `sort fichier | uniq -c | sort -rn` ?
- A) les lignes uniques triées par ordre alphabétique
- B) le nombre de lignes du fichier
- C) un classement des lignes par fréquence décroissante
- D) les doublons supprimés sans comptage

**Q8.** Que signifie le mode `750` ?
- A) `rwxr-x---`
- B) `rwxr-xr-x`
- C) `rw-r-----`
- D) `rwxrwx---`

**Q9.** Quelle commande ajoute le droit d'exécution **au propriétaire seulement** ?
- A) `chmod a+x f`
- B) `chmod u+x f`
- C) `chmod 777 f`
- D) `chmod +x -u f`

**Q10.** Comment ajouter `alice` au groupe `dev` **sans** la retirer de ses autres groupes ?
- A) `usermod -G dev alice`
- B) `usermod -aG dev alice`
- C) `groupadd dev alice`
- D) `chgrp dev alice`

**Q11.** Comment quitter `vim` sans enregistrer ?
- A) `:wq`
- B) `ZZ`
- C) `:q!`
- D) `Ctrl+X`

**Q12.** Que montre `ls -a` en plus de `ls` ?
- A) les tailles
- B) les fichiers cachés (commençant par `.`)
- C) les propriétaires
- D) les dossiers vides

**Q13.** Que contient `$?` ?
- A) le PID du shell
- B) le dernier argument de la commande précédente
- C) le code retour de la dernière commande
- D) le nombre d'arguments

**Q14.** Quelle commande crée un lien **symbolique** ?
- A) `ln a b`
- B) `ln -s a b`
- C) `link -s a b`
- D) `cp -l a b`

**Q15.** Que fait `grep -v erreur journal.log` ?
- A) affiche les lignes qui contiennent « erreur »
- B) affiche les lignes qui **ne** contiennent **pas** « erreur »
- C) affiche le numéro des lignes
- D) compte les lignes

<details><summary>Réponses — niveau 1</summary>

1. **B** — Linux est le noyau ; une distribution assemble noyau + outils.
2. **C** — `pwd` (*print working directory*).
3. **C** — trois niveaux à remonter : `doc` → `share` → `usr` → `/`, puis `etc`.
4. **B** — `-p` crée les parents manquants.
5. **C** — `rmdir` refuse un dossier non vide ; `rm -r` est récursif.
6. **B** — `2>&1` redirige stderr là où va stdout (le fichier), à condition d'être placé **après** `> f`.
7. **C** — tri, regroupement avec compte, tri numérique inverse.
8. **A** — 7 (rwx) propriétaire, 5 (r-x) groupe, 0 autres.
9. **B** — `u` = *user* (propriétaire).
10. **B** — `-a` (append) est indispensable avec `-G`.
11. **C** — `:q!` force la sortie sans sauvegarde.
12. **B** — option *all*.
13. **C** — 0 = succès.
14. **B** — `ln -s` ; `ln` seul crée un lien dur.
15. **B** — `-v` inverse la correspondance.
</details>

---

## Niveau 2 — Intermédiaire (modules 07 à 15)

**Q16.** Quel signal ne peut **ni** être intercepté **ni** ignoré par le processus ?
- A) SIGTERM (15)
- B) SIGHUP (1)
- C) SIGKILL (9)
- D) SIGINT (2)

**Q17.** Un processus affiche l'état `Z` dans `ps`. Il s'agit :
- A) d'un processus endormi
- B) d'un zombie (terminé, non récolté par son parent)
- C) d'un processus suspendu
- D) d'un processus en attente d'I/O disque

**Q18.** Que fait `apt update` ?
- A) installe les mises à jour
- B) rafraîchit la liste des paquets disponibles dans les dépôts
- C) supprime les paquets inutiles
- D) met à jour le noyau

**Q19.** Si `f=/data/rapport.txt`, que vaut `${f%.txt}.bak` ?
- A) `/data/rapport.txt.bak`
- B) `rapport.bak`
- C) `/data/rapport.bak`
- D) `.bak`

**Q20.** Que fait `set -e` dans un script Bash ?
- A) exporte toutes les variables
- B) arrête le script à la première commande qui échoue
- C) affiche chaque commande exécutée
- D) interdit les variables non définies

**Q21.** Que fait `sed 's/a/b/g'` ?
- A) remplace la première occurrence de `a` du fichier
- B) remplace toutes les occurrences de `a` par `b` sur chaque ligne
- C) supprime les lignes contenant `a`
- D) remplace `b` par `a`

**Q22.** Que fait `awk -F';' '{print $3}' f.csv` ?
- A) affiche la 3ᵉ ligne
- B) affiche la 3ᵉ colonne (séparateur `;`)
- C) affiche les 3 premiers caractères
- D) compte les champs

**Q23.** Combien d'hôtes utilisables dans un réseau `/27` ?
- A) 32
- B) 30
- C) 62
- D) 14

**Q24.** Quelle commande liste les sockets TCP/UDP en écoute avec le processus propriétaire ?
- A) `ip addr`
- B) `ss -tulpn`
- C) `ping -c1`
- D) `netstat -r`

**Q25.** Quels droits doit avoir une clé SSH privée ?
- A) `644`
- B) `777`
- C) `600`
- D) `664`

**Q26.** Que fait `rsync -a src/ dest/` par rapport à `rsync -a src dest/` ?
- A) rien de différent
- B) le premier copie le **contenu** de `src` dans `dest` ; le second crée `dest/src`
- C) le premier supprime la source
- D) le second est plus rapide

**Q27.** Pourquoi monter par **UUID** dans `/etc/fstab` ?
- A) c'est plus court
- B) les noms `/dev/sdX` peuvent changer d'un démarrage à l'autre
- C) c'est obligatoire pour ext4
- D) cela chiffre le disque

**Q28.** Dans LVM, quel est l'ordre de la pile (du disque au système de fichiers) ?
- A) LV → VG → PV
- B) VG → PV → LV
- C) PV → VG → LV
- D) PV → LV → VG

**Q29.** Après modification d'un fichier d'unité systemd, que faut-il lancer ?
- A) `systemctl reboot`
- B) `systemctl daemon-reload`
- C) `systemctl enable --all`
- D) `systemctl isolate`

**Q30.** Que signifie `0 8 * * 1-5` en cron ?
- A) à 08:00 tous les jours
- B) à 08:00 du lundi au vendredi
- C) toutes les 8 minutes
- D) à 08:00 le 1ᵉʳ de chaque mois

<details><summary>Réponses — niveau 2</summary>

16. **C** — SIGKILL et SIGSTOP sont traités par le noyau.
17. **B** — il faut agir sur le parent (`wait()`).
18. **B** — `apt upgrade` installe ; `update` met à jour les index.
19. **C** — `%` retire le plus court suffixe correspondant.
20. **B** — `-e` = *errexit* (attention aux contextes `if`, `&&`).
21. **B** — `g` = global sur la ligne.
22. **B** — `-F` définit le séparateur de champs.
23. **B** — 2⁵ − 2 = 30.
24. **B** — `-t` TCP, `-u` UDP, `-l` écoute, `-p` processus, `-n` numérique.
25. **C** — `600` (SSH refuse une clé lisible par d'autres).
26. **B** — le `/` final change la sémantique.
27. **B** — UUID stable.
28. **C** — Physical Volume → Volume Group → Logical Volume.
29. **B** — systemd relit les fichiers d'unités.
30. **B** — minute 0, heure 8, jours de semaine 1-5.
</details>

---

## Niveau 3 — Avancé (modules 16 à 21)

**Q31.** Que signifie `policy drop` sur la chaîne `input` d'un pare-feu nftables ?
- A) tout le trafic entrant est accepté sauf exceptions
- B) tout le trafic entrant non explicitement autorisé est rejeté
- C) le trafic sortant est bloqué
- D) les paquets sont journalisés

**Q32.** SELinux bloque votre application. La bonne démarche est de :
- A) passer SELinux en `disabled`
- B) lire les refus (`ausearch -m AVC`), corriger contexte/booléen/port
- C) donner `chmod 777` aux fichiers
- D) supprimer le paquet `selinux`

**Q33.** Quel hook Netfilter applique le **masquerade** (SNAT) ?
- A) `prerouting`
- B) `input`
- C) `forward`
- D) `postrouting`

**Q34.** Un *network namespace* fournit :
- A) un disque isolé
- B) une pile réseau isolée (interfaces, routes, pare-feu, ports)
- C) un utilisateur isolé
- D) un noyau isolé

**Q35.** Sur une machine à 16 cœurs, un *load average* de 8 signifie :
- A) saturation totale
- B) environ 50 % de charge
- C) 8 processus bloqués
- D) 8 Go de RAM utilisés

**Q36.** Dans `vmstat`, une valeur élevée de `wa` indique :
- A) trop de processus utilisateurs
- B) une attente d'entrées/sorties (disque, NFS)
- C) du swap
- D) une saturation réseau

**Q37.** Dans nginx, `location /api/ { proxy_pass http://app/; }` : une requête `/api/users` arrive au backend en tant que :
- A) `/api/users`
- B) `/users`
- C) `/api/api/users`
- D) `/`

**Q38.** nginx renvoie **502 Bad Gateway** : la cause la plus probable est :
- A) le fichier demandé n'existe pas
- B) l'application derrière le proxy ne répond pas / est arrêtée
- C) un mot de passe erroné
- D) un certificat expiré

**Q39.** Du point de vue du noyau, un conteneur est :
- A) une machine virtuelle légère
- B) un processus isolé par des namespaces et limité par des cgroups
- C) un module noyau
- D) un système de fichiers

**Q40.** Dans un overlayfs, où atterrissent les écritures du conteneur ?
- A) dans la couche *lower*
- B) dans la couche *upper*
- C) dans `/proc`
- D) dans le registre d'images

**Q41.** Le rôle de l'initramfs est :
- A) afficher le menu de démarrage
- B) fournir un mini-système en RAM pour monter la vraie racine
- C) gérer les mots de passe
- D) installer les mises à jour

**Q42.** Le paramètre noyau `init=/bin/bash` sert à :
- A) accélérer le démarrage
- B) obtenir directement un shell root (récupération)
- C) activer SELinux
- D) charger un module

**Q43.** Quel composant crée les nœuds de `/dev` et applique des règles lors d'un branchement matériel ?
- A) cron
- B) udev
- C) rsyslog
- D) dbus

**Q44.** Où trouve-t-on la trace d'un processus tué par l'OOM killer ?
- A) `/etc/passwd`
- B) `dmesg` / `journalctl -k`
- C) `crontab -l`
- D) `/var/lib/dpkg/status`

**Q45.** Parmi ces pratiques de Dockerfile, laquelle est recommandée ?
- A) `FROM ubuntu:latest` et tourner en root
- B) tag épinglé, utilisateur non-root, `HEALTHCHECK`
- C) copier les secrets dans l'image
- D) un seul `RUN` par commande pour « plus de clarté »

<details><summary>Réponses — niveau 3</summary>

31. **B** — refuser par défaut, autoriser explicitement.
32. **B** — ne jamais désactiver par réflexe.
33. **D** — SNAT à la sortie, après la décision de routage.
34. **B** — base des conteneurs.
35. **B** — 8/16 = 50 %.
36. **B** — *iowait*.
37. **B** — le `/` final de `proxy_pass` retire le préfixe de la `location`.
38. **B** — 504 = délai dépassé ; 502 = réponse invalide / pas de réponse.
39. **B** — pas d'objet « conteneur » dans le noyau.
40. **B** — la *lower* est en lecture seule.
41. **B** — charge les pilotes stockage/LVM/LUKS.
42. **B** — procédure de récupération du mot de passe root (accès console).
43. **B** — `udevadm info/monitor/test`.
44. **B** — messages « Out of memory: Killed process ».
45. **B** — plus de sécurité et de reproductibilité.
</details>

---

## Niveau 4 — Professionnel (modules 22 à 25)

**Q46.** Qu'est-ce que l'**idempotence** d'un playbook Ansible ?
- A) il s'exécute plus vite la 2ᵉ fois
- B) l'appliquer plusieurs fois donne le même état, sans changement supplémentaire
- C) il ne modifie jamais rien
- D) il s'exécute en parallèle

**Q47.** Un *handler* Ansible s'exécute :
- A) à chaque tâche
- B) à la fin du play, si une tâche qui le notifie a changé quelque chose
- C) uniquement au premier déploiement
- D) avant les tâches

**Q48.** Ansible Vault sert à :
- A) sauvegarder les hôtes
- B) chiffrer des données sensibles (fichiers ou valeurs)
- C) lancer des tâches en parallèle
- D) vérifier la syntaxe YAML

**Q49.** `terraform plan` :
- A) crée l'infrastructure
- B) montre les changements prévus sans les appliquer
- C) détruit les ressources
- D) formate le code

**Q50.** Dans Prometheus, pour calculer un débit à partir d'un *counter* on utilise :
- A) `sum()`
- B) `rate()`
- C) `avg()`
- D) `up`

**Q51.** Un SLO de disponibilité de 99,9 % sur 30 jours correspond à un budget d'erreur d'environ :
- A) 4,3 min
- B) 43 min
- C) 7 h
- D) 72 h

**Q52.** Un plugin de supervision de type Nagios qui retourne le code **2** signale l'état :
- A) OK
- B) WARNING
- C) CRITICAL
- D) UNKNOWN

**Q53.** Dans une règle d'alerte Prometheus, `for: 5m` signifie :
- A) l'alerte est envoyée toutes les 5 minutes
- B) la condition doit rester vraie 5 minutes avant le déclenchement
- C) l'alerte expire après 5 minutes
- D) la métrique est collectée toutes les 5 minutes

**Q54.** Le **RPO** est :
- A) la durée maximale d'indisponibilité tolérée
- B) la perte de données maximale tolérée, exprimée en temps
- C) le nombre de copies de sauvegarde
- D) la taille du stockage

**Q55.** Le **RTO** est :
- A) la durée maximale d'interruption tolérée avant reprise
- B) la période entre deux sauvegardes
- C) le taux d'erreur maximal
- D) le nombre de serveurs

**Q56.** Quel est le quorum d'un cluster de **5** nœuds ?
- A) 2
- B) 3
- C) 4
- D) 5

**Q57.** Quelle technique empêche un *split-brain* en isolant de force un nœud douteux ?
- A) le *fencing* (STONITH)
- B) le *load balancing*
- C) la compression
- D) la rotation des journaux

**Q58.** La règle de sauvegarde **3-2-1** signifie :
- A) 3 jours, 2 semaines, 1 mois
- B) 3 copies, 2 supports différents, 1 copie hors site
- C) 3 serveurs, 2 sites, 1 administrateur
- D) 3 sauvegardes complètes, 2 incrémentales, 1 différentielle

**Q59.** Un « *dead man's switch* » pour une sauvegarde nocturne consiste à :
- A) supprimer les sauvegardes anciennes
- B) alerter lorsque le signal de fin de sauvegarde **n'arrive pas**
- C) chiffrer l'archive
- D) doubler l'espace disque

**Q60.** Dans une approche **GitOps** :
- A) les changements sont appliqués directement sur les serveurs
- B) le dépôt git est la source de vérité, les changements passent par revue puis déploiement automatisé
- C) git remplace la supervision
- D) on ne versionne que le code applicatif

<details><summary>Réponses — niveau 4</summary>

46. **B** — critère vérifiable : 2ᵉ passage `changed=0`.
47. **B** — évite les rechargements inutiles.
48. **B** — `ansible-vault encrypt`, `encrypt_string`.
49. **B** — toujours lire le plan avant `apply`.
50. **B** — `rate(metric[5m])` sur un counter.
51. **B** — 0,1 % de 43 200 min = 43,2 min.
52. **C** — 0 OK, 1 WARNING, 2 CRITICAL, 3 UNKNOWN.
53. **B** — filtre les pics transitoires.
54. **B** — détermine la fréquence de sauvegarde/réplication.
55. **A** — détermine les moyens de restauration.
56. **B** — ⌊5/2⌋ + 1 = 3.
57. **A** — *Shoot The Other Node In The Head*.
58. **B** — idéalement avec une copie immuable/hors ligne en plus.
59. **B** — l'absence de signal est elle-même l'alerte.
60. **B** — traçabilité, revue, reproductibilité.
</details>

---

## Grille de correction

| Score | Appréciation |
|:-----:|--------------|
| 54-60 | Excellent — niveau professionnel |
| 45-53 | Très bon — solide, quelques révisions ciblées |
| 36-44 | Bon — acquis fondamentaux, approfondir les modules manqués |
| < 36  | À consolider — reprendre les modules des questions ratées (voir [parcours.md](parcours.md)) |
