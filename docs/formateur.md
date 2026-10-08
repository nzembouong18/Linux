# Guide du formateur

Ce guide aide à animer la formation en présentiel, en distanciel ou en classe inversée.

## 1. Préparer la session

**Une semaine avant**
- Choisir le rythme ([parcours.md](parcours.md)) et le niveau de départ ; envoyer le lien du dépôt et les consignes d'installation ([lab-environment.md](lab-environment.md)).
- **Tester l'environnement** sur une machine neuve : `make validate` doit être vert (ou `make validate-05` pour un module).
- Prévoir pour chaque stagiaire : 4 Go de RAM libres, 20 Go de disque, Docker (ou VirtualBox) fonctionnel.

**Le jour J**
- Faire vérifier `./lab list` et `./lab setup 01 && ./lab solve 01 && ./lab check 01` (5 min) : on détecte tous les problèmes d'installation avant de commencer.
- Projeter le terminal en grand (police ≥ 18 pt), thème contrasté ; utiliser `tmux` pour partager l'écran si besoin.

## 2. Déroulé type d'un module (cours de 3 h)

| Temps | Activité |
|-------|----------|
| 0:00 – 0:10 | Rappel du module précédent, objectifs du jour (en-tête du cours) |
| 0:10 – 1:10 | **Cours + démonstration** : suivre `./lab demo NN` (sans `DEMO_FAST`), s'arrêter à chaque commande, demander aux stagiaires de **prédire** la sortie avant de l'exécuter |
| 1:10 – 1:20 | Pause |
| 1:20 – 2:30 | **Labo** en autonomie ou binôme ; le formateur circule ; `./lab check NN` donne le feedback immédiat |
| 2:30 – 2:50 | Correction collective des points difficiles, comparaison avec `./lab solve NN` (sur un poste de démonstration) |
| 2:50 – 3:00 | Quiz oral (3 questions), annonce du prochain module |

**Enregistrer les démonstrations** (facultatif) : `asciinema rec -c "./lab demo 05" demo05.cast` puis `asciinema play` ou `agg` pour un GIF.
`DEMO_SPEED=0.04 ./lab demo 05` ralentit la frappe ; `DEMO_FAST=1` supprime les pauses.

## 3. Conseils pédagogiques généraux

1. **Prédire avant d'exécuter** : « que va afficher cette commande ? » ancre les modèles mentaux.
2. **Faire échouer volontairement** (mauvais chemin, droit manquant) puis lire le message ensemble : apprendre à lire les erreurs est la compétence n° 1.
3. **Toujours montrer l'aide** : `man`, `--help`, `apropos` ; interdire le copier-coller aveugle (« expliquez-moi cette option »).
4. **Une notion à la fois** ; renvoyer à la fiche de synthèse en fin de module.
5. **Pair-programming / pair-ops** en labo : un « pilote » tape, un « navigateur » relit ; on échange toutes les 15 min.
6. **Sécurité d'abord** : rappeler, avant chaque module à risque (stockage, pare-feu, `rm`), de ne travailler que dans l'environnement jetable.
7. **Culture de la sauvegarde et du retour arrière** : snapshot de VM avant les labos 13, 16, 17, 21.

## 4. Notes par module (points clés, pièges, durées)

| Module | À insister | Pièges fréquents des apprenants | Astuce |
|--------|------------|---------------------------------|--------|
| **01** Introduction | noyau ≠ distribution ; `man` ; code retour `$?` | confondre terminal/shell ; peur de casser | Montrer `uname`, `/etc/os-release`, `/proc` : « tout est fichier » |
| **02** Navigation | FHS, chemins absolus/relatifs, `ls -l` | `cd` sans argument, oublier `-a` pour les fichiers cachés | Jeu : retrouver un fichier en 3 commandes |
| **03** Fichiers | `cp -a`, guillemets, liens durs/symboliques, `find -exec` | `rm -rf` avec joker, espaces dans les noms | Démontrer la perte de `rm` : pas de corbeille |
| **04** Édition | vim : modes ; `tail -F` ; `sed -i` | rester bloqué dans vim | `vimtutor` en classe, 15 min |
| **05** Pipes | stdout/stderr, `2>&1` (ordre), `sort|uniq -c` | `sort f > f` vide le fichier ; `uniq` sans `sort` | Construire un pipeline *pas à pas* |
| **06** Permissions | octal, `x` sur dossier, setgid, ACL, sudo | `chmod 777`, `usermod -G` sans `-a` | Faire tester `sudo -u autreuser` |
| **07** Processus | signaux (TERM avant KILL), états D/Z, `nice` | confondre load et CPU ; vouloir tuer un zombie | `kill -STOP/-CONT` en direct |
| **08** Paquets | `apt` vs `dpkg`, dépôts signés, `hold` | oublier `apt update`, mélanger pip/apt | Construire le `.deb` ensemble |
| **09** Bash | `"$@"`, `set -euo pipefail`, `trap`, `shellcheck` | variables sans guillemets, `for f in $(ls)` | Passer chaque script au `shellcheck` |
| **10** Texte | regex ERE, sed s///, awk champs, jq | gourmandise `.*`, `sed -i` sans sauvegarde | Tester les regex avec `grep -Eo` |
| **11** Réseau | CIDR, `ip`, `ss`, DNS, méthode bas→haut | calcul de sous-réseaux, `127.0.0.1` vs `0.0.0.0` | Feuille de calcul des masques sur tableau |
| **12** SSH | clés, `known_hosts`, droits `~/.ssh`, rsync `/` final | droits de `authorized_keys`, perte d'accès après durcissement | Garder une 2ᵉ session ouverte |
| **13** Stockage | UUID, `fstab` + `mount -a`, LVM, **jamais sur un vrai disque** | `mkfs` sur le mauvais périphérique | Images loop uniquement ; snapshot VM |
| **14** systemd | unités, `daemon-reload`, journal, timers vs cron | oublier `daemon-reload`, chemins non absolus | `systemd-analyze verify` systématique |
| **15** Logs/backups | `tar -C`, `logrotate -d`, `--link-dest`, **tester la restauration** | archives en chemins absolus | Corrompre une archive volontairement |
| **16** Sécurité | moindre privilège, `nft -c`, SELinux sans le désactiver | `ufw enable` avant d'autoriser SSH | Toujours un filet de sécurité (`at now+5min`) |
| **17** Réseau avancé | namespaces, forward, NAT, `tcpdump` | oublier `ip_forward`, `oifname` du NAT | Dessiner la topologie avant de taper |
| **18** Performance | USE, 60 secondes, `vmstat`, `strace -c` | tuer au `-9` systématiquement, optimiser sans mesurer | « Un seul changement à la fois » |
| **19** Web | `location`, `proxy_pass` (slash final), 502/504 | `return` avant `limit_req`, droits des workers | `nginx -t` avant tout reload |
| **20** Conteneurs | namespaces/cgroups, Dockerfile, non-root | croire que c'est une VM ; secrets dans l'image | Construire le conteneur à la main d'abord |
| **21** Noyau/boot | boot en 6 étapes, GRUB, modules, récupération | éditer `grub.cfg`, oublier `update-grub` | VM + snapshot pour tester la récupération |
| **22** IaC | idempotence, handlers, Vault | `shell` partout, secrets en clair | Rejouer le playbook **deux fois** |
| **23** Supervision | golden signals, `for:`, SLO | alertes bruyantes, cardinalité des labels | Faire écrire un runbook par alerte |
| **24** HA/PRA | RPO/RTO, quorum, fencing, vérifier les sauvegardes | « RAID = sauvegarde » | Corrompre une sauvegarde en direct |
| **25** Projet | intégration, tests, soutenance | Ansible écrit trop tôt, docs oubliées | Jalons : mi-parcours à 50 % du temps |

## 5. Gérer les niveaux hétérogènes
- **Rapides** : « pour aller plus loin » de chaque labo, challenges de scripts, rédaction de runbooks.
- **En difficulté** : binôme avec un plus avancé, `./lab solve` autorisé *après* 20 min d'effort, reprise de la démo.
- **Débutants complets** : insister sur modules 01-06 (compter 30 h) avant 07.

## 6. Évaluation
Voir [evaluation.md](evaluation.md) : labos vérifiés automatiquement, QCM, projet final noté sur grille, soutenance.

## 7. Dépannage rapide en séance
- Un stagiaire coincé sur un labo : `./lab check NN` indique précisément la ligne ✘ ; demander « qu'avez-vous essayé ? » avant de dévoiler l'indice.
- Machine saturée : `./lab reset NN` libère processus, montages, namespaces.
- Panne d'environnement : recréer le conteneur (`docker compose down -v && docker compose up -d`) – 2 minutes.

## 8. Adapter ou étendre la formation
Voir [CONTRIBUTING.md](../CONTRIBUTING.md) : un module = `README.md` + `LAB.md` + `lab.sh` + `demo.sh`, validé par la CI (`make validate`).
