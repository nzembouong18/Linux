# Module 02 — Le terminal, le shell et la navigation dans l'arborescence

> **Niveau** : Débutant | **Durée** : 3 h (1 h 30 cours + 1 h 30 labo) | **Prérequis** : module 01
>
> **Objectifs** — À la fin de ce module vous saurez :
> - expliquer la différence entre terminal, shell et console ;
> - décomposer une commande (programme, options, arguments) ;
> - vous repérer dans l'arborescence FHS et comprendre le rôle des répertoires standards ;
> - utiliser chemins absolus et relatifs avec aisance ;
> - lire une sortie `ls -l` et identifier les types de fichiers ;
> - gagner du temps avec la complétion, l'historique et les raccourcis clavier.

---

## 1. Terminal, shell, console : ne pas confondre

| Terme | Définition |
|-------|-----------|
| **Terminal** (émulateur) | La fenêtre graphique (GNOME Terminal, Konsole, Windows Terminal, iTerm2…) qui affiche du texte et capture le clavier |
| **Shell** | Le **programme** qui lit vos commandes, les interprète et lance d'autres programmes. Le plus courant : **bash**. Autres : zsh, fish, dash, sh |
| **Console** | Terminal « physique » ou virtuel directement relié au noyau (`Ctrl+Alt+F3`) |
| **TTY / PTS** | Les périphériques noyau derrière : `/dev/tty1` (console), `/dev/pts/0` (terminal graphique/SSH) |

```bash
echo $0              # le shell courant (ex. -bash)
tty                  # le périphérique de terminal (ex. /dev/pts/0)
cat /etc/shells      # shells installés / autorisés
```

### Anatomie du prompt

```text
student@lab:~/projet$
   │     │   │     └─ $ = utilisateur normal   (# = root)
   │     │   └─ répertoire courant (~ = répertoire personnel)
   │     └─ nom de machine
   └─ nom d'utilisateur
```

## 2. Anatomie d'une commande

```text
 ls   -l   -h   /var/log
 │    │    │    └─ argument  (sur quoi agir)
 │    └────┴─ options    (comment agir) — combinables : -lh
 └─ commande (programme, alias, fonction ou builtin)
```

- **Options courtes** : `-l`, `-a` (combinables : `-la`). **Options longues** : `--all`, `--human-readable`.
- `--` marque la fin des options : `rm -- -fichier-bizarre`.
- Plusieurs commandes sur une ligne : `cmd1 ; cmd2` (toujours), `cmd1 && cmd2` (si succès), `cmd1 || cmd2` (si échec).
- Ligne trop longue : continuez avec `\` en fin de ligne.
- Commentaire : `# ignoré par le shell`.

### Quelle commande va s'exécuter ?

Le shell cherche dans l'ordre : **alias → fonction → builtin → programme dans `$PATH`**.

```bash
type ls cd echo grep       # alias, builtin ou fichier ?
echo "$PATH"               # liste des dossiers où chercher les programmes
which -a python3           # toutes les occurrences dans le PATH
```

`PATH` est une liste de répertoires séparés par `:`. Si une commande « n'est pas trouvée » (`command not found`), c'est qu'elle n'est pas installée ou pas dans le `PATH`.

## 3. L'arborescence Linux (FHS)

Sous Linux il n'y a **pas de lecteurs `C:`, `D:`** : tout part d'une racine unique `/`. Les disques, clés USB et partages réseau sont **montés** dans cette arborescence (module 13).

```text
/
├── bin → usr/bin     commandes essentielles (ls, cp, cat)
├── boot              noyau, initramfs, GRUB
├── dev               fichiers de périphériques (sda, null, tty…)
├── etc               configuration du système (fichiers texte !)
├── home              répertoires personnels (/home/alice)
├── lib → usr/lib     bibliothèques partagées
├── media, mnt        points de montage (supports amovibles / temporaires)
├── opt               logiciels tiers autonomes
├── proc              fenêtre sur le noyau et les processus (virtuel)
├── root              répertoire personnel de root
├── run               données volatiles d'exécution (PID, sockets)
├── sbin → usr/sbin   commandes d'administration
├── srv               données servies (web, ftp…)
├── sys               matériel et pilotes (virtuel)
├── tmp               fichiers temporaires (vidés au redémarrage)
├── usr               programmes et données partagés (lecture seule en principe)
└── var               données variables : logs (/var/log), cache, spool, bases
```

Repères indispensables pour un administrateur :

| Je cherche… | Où regarder |
|-------------|-------------|
| La config d'un service | `/etc/<service>/` |
| Les journaux | `/var/log/` |
| Mes documents | `/home/<moi>` |
| L'état d'un processus | `/proc/<PID>/` |
| Les disques | `/dev/sd*`, `/dev/nvme*` |
| Les données d'une base ou d'un site | `/var/lib/…`, `/srv/…`, `/var/www/` |

## 4. Se déplacer : chemins absolus et relatifs

| Chemin | Signification |
|--------|---------------|
| `/` | La racine |
| `~` | Mon répertoire personnel (`$HOME`) — `~alice` = celui d'alice |
| `.` | Le répertoire courant |
| `..` | Le répertoire parent |
| `-` (avec `cd`) | Le répertoire précédent |

- **Absolu** : commence par `/` → `/var/log/syslog` (valable de n'importe où).
- **Relatif** : dépend du répertoire courant → `../log/syslog`, `./script.sh`.

```bash
pwd                  # où suis-je ?  (print working directory)
cd /var/log          # chemin absolu
cd ..                # remonter d'un niveau
cd ../../etc         # relatif : deux niveaux plus haut puis etc
cd                   # sans argument = retour au HOME (comme cd ~)
cd -                 # retour au répertoire précédent
pushd /etc; popd     # pile de répertoires
```

Exemple : depuis `/home/alice/projet/src`, aller dans `/home/alice/docs` :
- absolu : `cd /home/alice/docs`
- relatif : `cd ../../docs`
- avec le HOME : `cd ~/docs`

## 5. Lister : `ls` en profondeur

```bash
ls                   # contenu du répertoire courant
ls -l                # format long (permissions, propriétaire, taille, date)
ls -a                # inclut les fichiers cachés (commençant par .)
ls -A                # idem sans . et ..
ls -lh               # tailles lisibles (K, M, G)
ls -lt               # tri par date (récent d'abord) ; -r inverse
ls -lS               # tri par taille décroissante
ls -R                # récursif
ls -d */             # seulement les répertoires
ls -ld /etc          # infos sur le répertoire lui-même (pas son contenu)
ls -li               # affiche aussi l'inode
tree -L 2            # vue arborescente (paquet « tree »)
```

### Lire `ls -l`

```text
-rwxr-xr-- 2 alice dev 4096 Mar 12 09:30 script.sh
│└┬┘└┬┘└┬┘ │  │     │   │      │          └─ nom
│ │  │  │  │  │     │   │      └─ date de dernière modification
│ │  │  │  │  │     │   └─ taille en octets
│ │  │  │  │  │     └─ groupe propriétaire
│ │  │  │  │  └─ utilisateur propriétaire
│ │  │  │  └─ nombre de liens durs
│ │  │  └─ droits « autres » (r--)
│ │  └─ droits du groupe (r-x)
│ └─ droits du propriétaire (rwx)
└─ type : - fichier · d répertoire · l lien symbolique · c périph. caractère · b périph. bloc · s socket · p tube nommé
```

Les permissions sont étudiées au module 06.

## 6. Identifier la nature d'un fichier

L'extension n'a **aucune valeur** pour Linux : c'est le contenu qui compte.

```bash
file /bin/ls /etc/passwd /usr/share/doc   # type réel (ELF, texte, répertoire…)
stat /etc/passwd                          # inode, taille, droits, 3 horodatages
wc -l /etc/passwd                         # nombre de lignes
```

Les trois horodatages : **atime** (accès), **mtime** (modification du contenu), **ctime** (changement de métadonnées).

## 7. Globbing (jokers) — aperçu

Le shell développe les motifs **avant** de lancer la commande :

| Motif | Correspond à |
|-------|--------------|
| `*` | n'importe quelle suite de caractères (même vide) |
| `?` | exactement un caractère |
| `[abc]` `[a-z]` `[!0-9]` | un caractère de l'ensemble / intervalle / hors ensemble |
| `{a,b,c}` | liste (développement d'accolades) |

```bash
ls /etc/*.conf          # tous les .conf directement dans /etc
ls /var/log/syslog.?    # syslog.1, syslog.2…
ls file[0-9].txt        # file0.txt … file9.txt
echo {1..5}             # 1 2 3 4 5
```

## 8. Travailler vite : complétion, historique, raccourcis

| Raccourci | Action |
|-----------|--------|
| `Tab` / `Tab Tab` | Complète / liste les possibilités |
| `↑` `↓` | Parcourt l'historique |
| `Ctrl+R` | **Recherche incrémentale** dans l'historique |
| `Ctrl+A` / `Ctrl+E` | Début / fin de ligne |
| `Alt+B` / `Alt+F` | Mot précédent / suivant |
| `Ctrl+W` | Efface le mot avant le curseur |
| `Ctrl+U` / `Ctrl+K` | Efface avant / après le curseur |
| `Ctrl+L` | Efface l'écran (≈ `clear`) |
| `Ctrl+C` | **Interrompt** la commande en cours |
| `Ctrl+D` | Fin d'entrée (quitte le shell) |
| `Ctrl+Z` | Suspend la commande (voir module 07) |
| `!!` | Répète la dernière commande (`sudo !!`) |
| `!$` | Dernier argument de la commande précédente |
| `history` | Liste l'historique ; `!42` relance la ligne 42 |

## 9. Variables d'environnement et alias — premier contact

```bash
echo "$HOME $USER $PWD $SHELL"      # variables prédéfinies
MON_NOM="Alice"; echo "Bonjour $MON_NOM"
export EDITOR=nano                   # visible par les programmes lancés depuis ce shell
env | sort | head                    # variables exportées
alias ll='ls -lah'                   # raccourci pour la session
unalias ll
```

Pour rendre un alias **permanent**, ajoutez-le à `~/.bashrc` puis `source ~/.bashrc`.

## 10. Erreurs fréquentes du débutant

| Symptôme | Cause probable |
|----------|----------------|
| `No such file or directory` | Faute de frappe, mauvais répertoire courant, chemin relatif vs absolu |
| `command not found` | Programme absent ou pas dans le `PATH` ; pour un script local, tapez `./script.sh` |
| `Permission denied` | Droits insuffisants (module 06) |
| Le prompt a disparu après `cat` | `cat` attend l'entrée : `Ctrl+C` ou `Ctrl+D` |
| Espaces dans un nom | Entourez de guillemets : `cd "Mes Documents"` |

## 11. Résumé

- Terminal ≠ shell ≠ console. Le shell interprète, cherche les commandes dans `$PATH`.
- Une commande : `programme [options] [arguments]` ; `&&`, `||`, `;` pour enchaîner.
- Arborescence unique `/` ; **`/etc`** config, **`/var/log`** logs, **`/home`** utilisateurs, **`/proc`** noyau.
- `pwd`, `cd`, `ls -lah`, `tree`, `file`, `stat` : outils de navigation et d'inspection.
- Productivité : `Tab`, `Ctrl+R`, `!!`, `Ctrl+A/E/W/U`.

## 12. Quiz

1. Quelle commande affiche le répertoire courant ?
2. Depuis `/usr/share/doc`, comment atteindre `/etc` avec un chemin relatif ?
3. Que contient `/proc` ? Et `/etc` ?
4. Que signifie `drwxr-x---` en début de ligne `ls -l` ?
5. Comment lister **tous** les fichiers, cachés compris, avec tailles lisibles ?
6. Quelle différence entre `cmd1 && cmd2` et `cmd1 ; cmd2` ?
7. Pourquoi `./script.sh` plutôt que `script.sh` ?
8. Comment retrouver une commande tapée il y a trois heures contenant « rsync » ?

<details><summary>Réponses</summary>

1. `pwd`
2. `cd ../../../etc`
3. `/proc` : pseudo-système de fichiers exposant noyau et processus ; `/etc` : fichiers de configuration.
4. Un **d**ossier ; propriétaire `rwx`, groupe `r-x`, autres aucun droit.
5. `ls -lah` (ou `ls -lAh` pour exclure `.` et `..`).
6. Avec `&&`, `cmd2` ne s'exécute que si `cmd1` a réussi ; avec `;` toujours.
7. Le répertoire courant n'est normalement pas dans `$PATH` ; `./` indique explicitement le chemin.
8. `Ctrl+R` puis taper `rsync`, ou `history | grep rsync`.
</details>

## 13. Pour aller plus loin

- `man hier` : description officielle de la hiérarchie des fichiers.
- Filesystem Hierarchy Standard : <https://refspecs.linuxfoundation.org/fhs.shtml>
- Essayez `zsh` + oh-my-zsh ou `fish` — sans en faire votre shell de script.

➡️ **Labo** : [LAB.md](LAB.md) · **Démo** : `./lab demo 02` · **Suivant** : [03 — Fichiers et répertoires](../03-fichiers-et-repertoires/README.md)
