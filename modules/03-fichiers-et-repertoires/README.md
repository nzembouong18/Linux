# Module 03 — Créer, copier, déplacer, trouver : la gestion des fichiers

> **Niveau** : Débutant | **Durée** : 3 h (1 h 30 cours + 1 h 30 labo) | **Prérequis** : module 02
>
> **Objectifs** — À la fin de ce module vous saurez :
> - créer, copier, déplacer et supprimer fichiers et répertoires en toute sécurité ;
> - maîtriser globbing, développement d'accolades et guillemets ;
> - comprendre inodes, liens durs et liens symboliques ;
> - rechercher des fichiers avec `find` / `locate` et agir sur les résultats ;
> - mesurer l'occupation disque avec `du` et `df`.

---

## 1. Créer

```bash
touch notes.txt                 # crée un fichier vide (ou met à jour sa date s'il existe)
touch a.txt b.txt c.txt         # plusieurs d'un coup
mkdir projet                    # crée un répertoire
mkdir -p projet/src/app/core    # -p : crée toute la chaîne, sans erreur si existe déjà
mkdir -m 750 prive              # avec des droits précis
echo "Bonjour" > salut.txt      # crée via redirection (module 05)
```

## 2. Copier

```bash
cp source.txt destination.txt          # copie un fichier
cp source.txt dossier/                 # copie dans un dossier (garde le nom)
cp -r projet/ sauvegarde/              # -r : récursif (obligatoire pour un dossier)
cp -a projet/ sauvegarde/              # -a : archive = récursif + droits, dates, liens, propriétaire
cp -i a b                              # -i : demande confirmation avant d'écraser
cp -n a b                              # -n : n'écrase jamais
cp -u a b                              # -u : copie si la source est plus récente
cp -v a b                              # -v : verbeux
cp --backup=numbered a b               # garde b.~1~ avant d'écraser
```

⚠️ Piège classique : `cp -r projet/ copie/` crée `copie/projet` **si `copie` existe déjà**, sinon `copie` est la copie. Vérifiez avec `ls`.

## 3. Déplacer et renommer

`mv` sert aux deux : **renommer = déplacer vers un autre nom**.

```bash
mv ancien.txt nouveau.txt         # renomme
mv fichier.txt ~/archives/        # déplace
mv *.log logs/                    # plusieurs fichiers vers un dossier
mv -i a b ; mv -n a b             # confirmation / pas d'écrasement
mv -t destination/ f1 f2 f3       # -t : la destination d'abord (pratique avec xargs)
```

Sur un **même système de fichiers**, `mv` est instantané (il ne change que l'entrée de répertoire). Entre systèmes de fichiers, il copie puis supprime.

Renommage en masse : `rename 's/\.jpeg$/.jpg/' *.jpeg` (Perl) ou une boucle bash (module 09).

## 4. Supprimer — avec prudence

```bash
rm fichier.txt             # supprime un fichier (PAS de corbeille !)
rm -i fichier.txt          # confirme
rm -r dossier/             # supprime un dossier et son contenu
rm -rf dossier/            # force, sans confirmation, sans erreur — DANGEREUX
rmdir dossier_vide/        # ne supprime qu'un dossier VIDE (sécurisé)
rm -- -fichier-bizarre     # '--' : fin des options (nom commençant par -)
shred -u secret.txt        # écrase puis supprime (limité sur SSD/journalisé)
```

> 🔴 **Règles de survie**
> 1. **Il n'y a pas de corbeille** en ligne de commande. `rm` est définitif.
> 2. **Ne lancez jamais `rm -rf` avec une variable non vérifiée** : `rm -rf "$DIR/"*` avec `DIR` vide devient `rm -rf /*`. Utilisez `"${DIR:?variable vide}"`.
> 3. Avant un `rm` avec joker, faites d'abord **`ls` avec le même motif**.
> 4. Installez `trash-cli` (`trash-put`) pour un usage confortable en interactif.
> 5. `--preserve-root` (par défaut) protège `/`, pas le reste.

## 5. Jokers (globbing), accolades et guillemets

Le **shell** développe ces motifs *avant* d'exécuter la commande (`ls *.txt` devient `ls a.txt b.txt`).

| Motif | Exemple | Résultat |
|-------|---------|----------|
| `*` | `*.log` | tous les fichiers finissant par `.log` |
| `?` | `fic?.txt` | `fic1.txt`, `ficA.txt` |
| `[...]` | `rapport[0-9].pdf` | `rapport3.pdf` |
| `[!...]` | `[!.]*` | commence par autre chose que `.` |
| `{a,b}` | `cp config.{conf,bak}` | `cp config.conf config.bak` |
| `{1..10}` | `touch jour{01..31}.log` | 31 fichiers |

Les fichiers cachés (`.xxx`) **ne sont pas** inclus par `*` (utilisez `.[!.]*` ou `shopt -s dotglob`).

### Guillemets

| Syntaxe | Effet |
|---------|-------|
| `"…"` | Protège les espaces et jokers ; **variables et `$(…)` restent interprétés** |
| `'…'` | **Tout est littéral** |
| `\x` | Protège un seul caractère |
| `$'a\tb'` | Séquences d'échappement (tabulation, saut de ligne) |

```bash
nom="Mes Documents"
mkdir "$nom"            # OK : un seul argument
mkdir $nom              # ERREUR : crée « Mes » et « Documents »
echo "Dossier: $HOME"   # développe la variable
echo 'Dossier: $HOME'   # affiche littéralement $HOME
```

> **Règle d'or du scripting : toujours entourer les variables de guillemets doubles** (`"$var"`).

## 6. Inodes, liens durs et liens symboliques

Un fichier, c'est :
- des **données** sur le disque ;
- un **inode** : métadonnées (taille, droits, propriétaire, dates, emplacement des blocs) — **sans le nom** ;
- un ou plusieurs **noms** (entrées de répertoire) qui pointent vers l'inode.

```text
 répertoire            inode 4242               blocs de données
 ┌────────────┐       ┌───────────────┐       ┌───────────────┐
 │ a.txt → 4242 ├────►│ droits, taille │──────►│ « Bonjour »   │
 │ b.txt → 4242 ├────►│ liens : 2      │       └───────────────┘
 └────────────┘       └───────────────┘
        (liens durs : deux noms, un seul fichier)
```

```bash
ln source.txt dur.txt           # lien DUR : un 2e nom pour le même inode
ln -s source.txt symbolique     # lien SYMBOLIQUE : petit fichier contenant un chemin
ls -li source.txt dur.txt       # même numéro d'inode pour les liens durs
readlink -f symbolique          # cible finale
```

| | Lien dur | Lien symbolique |
|---|----------|-----------------|
| Pointe vers | l'inode | un chemin (texte) |
| Si la source est supprimée | le fichier survit (compteur de liens) | le lien est **cassé** (*dangling*) |
| Traverse les systèmes de fichiers | ❌ | ✅ |
| Sur un répertoire | ❌ | ✅ |
| Usage typique | sauvegardes incrémentales, `rsync --link-dest` | `/etc/alternatives`, versions (`current → v2`), raccourcis |

Un fichier n'est réellement supprimé que lorsque son **compteur de liens est 0 ET qu'aucun processus ne l'a ouvert**.

## 7. Rechercher : `find`, `locate`, `which`

### `find` — la recherche en temps réel

```text
find  <où chercher>  <critères>  <action>
```

```bash
find /etc -name "*.conf"                  # par nom (sensible à la casse ; -iname sinon)
find . -type f                            # f fichiers · d dossiers · l liens
find . -type d -empty                     # dossiers vides
find /var/log -size +10M                  # plus de 10 Mo (-size -1k : moins de 1 Ko)
find . -mtime -1                          # modifié il y a moins d'1 jour (+7 : il y a plus de 7 jours)
find . -mmin -30                          # modifié dans les 30 dernières minutes
find . -user alice -perm -o+w             # propriétaire alice, écriture pour autres
find . -newer reference.txt               # plus récent que ce fichier
find . -maxdepth 2 -name "*.sh"           # limite de profondeur
find . \( -name "*.jpg" -o -name "*.png" \)   # OU logique
find . -type f ! -name "*.txt"            # négation
```

**Actions** :

```bash
find . -name "*.tmp" -print                       # (par défaut) afficher
find . -name "*.tmp" -delete                      # supprimer (mettez -delete EN DERNIER)
find . -name "*.log" -exec gzip {} \;             # une exécution par fichier
find . -name "*.log" -exec gzip {} +              # regroupe : bien plus rapide
find . -type f -print0 | xargs -0 wc -l           # sûr avec espaces/accents dans les noms
find . -type f -printf '%s %p\n' | sort -n        # format personnalisé (taille, chemin)
```

### `locate` — recherche dans un index

```bash
sudo updatedb              # reconstruit la base (cron quotidien en général)
locate nginx.conf          # instantané, mais peut être périmé
```

### Autres

```bash
which python3        # chemin de l'exécutable dans le PATH
whereis ls           # binaire + page de man + sources
type -a ls           # alias/builtin/fichiers
```

## 8. Mesurer l'espace disque

```bash
df -h                       # espace par système de fichiers monté
df -hT /                    # avec le type (ext4, xfs…)
df -i                       # inodes (un disque peut être « plein » sans espace : plus d'inodes !)
du -sh /var/log             # taille totale d'un dossier
du -h --max-depth=1 /var | sort -h      # qui occupe la place ?
du -ah . | sort -rh | head -10          # 10 plus gros éléments
ncdu /var                   # explorateur interactif (paquet ncdu)
```

## 9. Comparer et inspecter

```bash
diff a.txt b.txt            # différences ligne à ligne
diff -u a.txt b.txt         # format unifié (patchs, git)
diff -r dir1 dir2           # compare deux arborescences
cmp a.bin b.bin             # comparaison octet à octet
md5sum fichier ; sha256sum fichier     # empreinte d'intégrité
sha256sum -c SHA256SUMS     # vérifie une liste d'empreintes
```

## 10. Cas pratiques

**Ranger des photos par extension**

```bash
mkdir -p tri/{jpg,png,autres}
mv *.jpg tri/jpg/ ; mv *.png tri/png/
```

**Trouver puis supprimer les vieux fichiers temporaires (avec contrôle)**

```bash
find /tmp -type f -mtime +7 -name "*.tmp"             # 1) on regarde
find /tmp -type f -mtime +7 -name "*.tmp" -delete     # 2) on supprime
```

**Sauvegarde rapide avant modification**

```bash
cp -a /etc/ssh/sshd_config{,.$(date +%F).bak}
```

## 11. Résumé

| Besoin | Commande |
|--------|----------|
| Créer | `touch`, `mkdir -p` |
| Copier | `cp -a` (dossier : `-r`/`-a`) |
| Renommer / déplacer | `mv` |
| Supprimer | `rm`, `rm -r`, `rmdir` (**sans corbeille**) |
| Liens | `ln` (dur), `ln -s` (symbolique) |
| Chercher | `find … -exec`, `locate` |
| Espace | `df -h`, `du -sh` |
| Comparer | `diff -u`, `sha256sum` |

## 12. Quiz

1. Quelle option de `mkdir` crée les répertoires parents manquants ?
2. Quelle est la différence entre `cp -r` et `cp -a` ?
3. Qu'est-ce qui distingue lien dur et lien symbolique si l'on supprime le fichier original ?
4. Écrivez la commande qui supprime tous les fichiers `.bak` de plus de 30 jours sous `/data`.
5. Pourquoi `rm -rf $DIR/*` est-il dangereux dans un script ? Comment le sécuriser ?
6. Comment copier `app.conf` en `app.conf.bak` sans retaper le nom ?
7. Un disque affiche 50 % d'espace libre mais « No space left on device » : quelle piste ?
8. Pourquoi `mv` est-il instantané dans le même système de fichiers ?

<details><summary>Réponses</summary>

1. `-p`
2. `-a` = `-r` + préserve droits, propriétaire, dates, liens symboliques (`-dR --preserve=all`).
3. Dur : le contenu reste accessible via l'autre nom. Symbolique : le lien est cassé.
4. `find /data -type f -name '*.bak' -mtime +30 -delete` (testez d'abord sans `-delete`).
5. Si `DIR` est vide → `rm -rf /*`. Utilisez `rm -rf -- "${DIR:?}"/*`.
6. `cp app.conf{,.bak}`
7. Épuisement des **inodes** : `df -i`.
8. Seule l'entrée de répertoire est modifiée, les données ne bougent pas.
</details>

➡️ **Labo** : [LAB.md](LAB.md) · **Démo** : `./lab demo 03` · **Suivant** : [04 — Lire et éditer](../04-lecture-et-edition/README.md)
