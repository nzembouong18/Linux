# Module 04 — Lire et éditer des fichiers texte (cat, less, tail, nano, vim)

> **Niveau** : Débutant | **Durée** : 3 h (1 h 30 cours + 1 h 30 labo) | **Prérequis** : module 03
>
> **Objectifs** — À la fin de ce module vous saurez :
> - afficher tout ou partie d'un fichier (`cat`, `head`, `tail`, `less`, `sed -n`) ;
> - suivre un journal en direct (`tail -f`) ;
> - éditer un fichier avec **nano** (simple) et **vim** (incontournable) ;
> - inspecter des fichiers binaires (`strings`, `xxd`) ;
> - configurer votre éditeur par défaut.

---

## 1. Afficher un fichier

| Commande | Usage | Exemple |
|----------|-------|---------|
| `cat` | Concatène et affiche | `cat /etc/hostname` |
| `cat -n` | Avec numéros de ligne | `cat -n script.sh` |
| `cat -A` | Montre les caractères invisibles (`$` fin de ligne, `^I` tabulation) | détecter CRLF Windows |
| `tac` | Affiche à l'envers (dernière ligne d'abord) | `tac journal.log` |
| `less` | **Paginateur** : navigation avant/arrière, recherche | `less /var/log/syslog` |
| `head -n 5` | N premières lignes | `head -n 5 f` (ou `head -5`) |
| `tail -n 5` | N dernières lignes | `tail -n 20 /var/log/auth.log` |
| `tail -n +10` | À partir de la ligne 10 | |
| `tail -f` | **Suit** les ajouts en temps réel | `tail -f /var/log/nginx/access.log` |
| `tail -F` | Comme `-f` mais survit à la rotation de logs | **à préférer** |
| `wc` | Compte `-l` lignes, `-w` mots, `-c` octets, `-m` caractères | `wc -l /etc/passwd` |
| `nl` | Numérote les lignes | `nl fichier` |

> ⚠️ N'utilisez pas `cat` sur un gros fichier ou un binaire : `less` ou `head`.

### Extraire des lignes précises

```bash
sed -n '10,14p' fichier          # lignes 10 à 14
head -n 14 fichier | tail -n 5   # idem avec deux commandes
sed -n '5p' fichier              # la ligne 5
awk 'NR>=10 && NR<=14' fichier   # avec awk
```

### Naviguer dans `less`

| Touche | Action |
|--------|--------|
| `Espace` / `b` | Page suivante / précédente |
| `j` `k` ou `↓` `↑` | Ligne suivante / précédente |
| `g` / `G` | Début / fin du fichier |
| `/motif` puis `n` / `N` | Recherche avant ; occurrence suivante / précédente |
| `?motif` | Recherche arrière |
| `&motif` | N'affiche que les lignes qui correspondent |
| `F` | Mode « suivi » comme `tail -f` (`Ctrl+C` pour revenir) |
| `-N` | Active les numéros de ligne |
| `q` | Quitter |

`journalctl`, `man`, `git log` utilisent `less` : ces touches vous serviront partout.

## 2. Éditer avec **nano** (le plus simple)

```bash
nano fichier.txt
```

Les raccourcis sont affichés en bas (`^` = `Ctrl`, `M-` = `Alt`) :

| Raccourci | Action |
|-----------|--------|
| `Ctrl+O` puis `Entrée` | Enregistrer (*Write Out*) |
| `Ctrl+X` | Quitter (propose d'enregistrer) |
| `Ctrl+W` | Rechercher |
| `Ctrl+\` | Remplacer |
| `Ctrl+K` / `Ctrl+U` | Couper la ligne / coller |
| `Ctrl+_` | Aller à la ligne N |
| `M-U` / `M-E` | Annuler / refaire |

Idéal pour une modification rapide. Mais sur un serveur vous croiserez **vi/vim** presque systématiquement : apprenez-le.

## 3. Éditer avec **vim**

`vi` est installé partout (même en mode secours). `vim` = *Vi IMproved*. Il est déroutant car **modal**.

### Les 3 modes essentiels

```text
        i, a, o, I, A, O                 Esc
 NORMAL ───────────────────► INSERTION ─────────┐
   ▲  (déplacements, copier/coller,        (on tape du texte)  │
   │   suppression, commandes)                                  │
   │ Esc                                                        │
   └────────────────────────────────────────────────────────────┘
   │ :  /  ?
   ▼
 COMMANDE (ligne du bas) :w  :q  :wq  :q!  :%s/a/b/g
```

**Au démarrage vous êtes en mode NORMAL.** Si rien ne marche comme prévu : appuyez sur `Esc`.

### Survie en 2 minutes

| Besoin | Frappe |
|--------|--------|
| Commencer à écrire | `i` |
| Revenir en mode normal | `Esc` |
| **Enregistrer** | `:w` Entrée |
| **Enregistrer et quitter** | `:wq` ou `ZZ` |
| **Quitter sans enregistrer** | `:q!` |
| Annuler / Refaire | `u` / `Ctrl+R` |

### Déplacements (mode normal)

| Touche | Effet |
|--------|-------|
| `h j k l` | ← ↓ ↑ → |
| `w` / `b` | mot suivant / précédent |
| `0` / `^` / `$` | début de ligne / premier caractère / fin de ligne |
| `gg` / `G` / `42G` | début / fin / ligne 42 |
| `Ctrl+F` / `Ctrl+B` | page suivante / précédente |
| `%` | parenthèse/accolade correspondante |

### Entrer en insertion

`i` avant le curseur · `a` après · `I` début de ligne · `A` fin de ligne · `o` nouvelle ligne dessous · `O` dessus.

### Éditer (grammaire : *opérateur + mouvement*)

| Frappe | Effet |
|--------|-------|
| `x` | supprime le caractère |
| `dd` / `3dd` | supprime (coupe) 1 / 3 lignes |
| `dw` / `d$` / `d0` | supprime un mot / jusqu'à la fin / jusqu'au début de ligne |
| `yy` / `3yy` | copie (*yank*) 1 / 3 lignes |
| `p` / `P` | colle après / avant |
| `cw` | change un mot (supprime puis passe en insertion) |
| `cc` | change la ligne |
| `r` + caractère | remplace un caractère |
| `.` | **répète** la dernière modification |
| `>>` / `<<` | indente / désindente |
| `J` | joint la ligne suivante |

Les nombres se combinent : `d3w`, `5x`, `c2w`.

### Rechercher / remplacer

```vim
/motif          " cherche vers l'avant ; n / N pour naviguer
:%s/ancien/nouveau/g      " remplace partout
:%s/ancien/nouveau/gc     " avec confirmation
:10,20s/foo/bar/g         " seulement lignes 10 à 20
:set number               " numéros de ligne
:set ignorecase           " recherche insensible à la casse
```

### Sélection visuelle

`v` (caractères) · `V` (lignes) · `Ctrl+V` (bloc rectangulaire). Puis `d`, `y`, `>` …

### Plusieurs fichiers, fenêtres, shell

```vim
:e autre.txt         " ouvrir un autre fichier
:sp / :vsp fichier   " fenêtres haut/bas ou gauche/droite ; Ctrl+W puis flèche pour naviguer
:!ls                 " exécute une commande shell
:r !date             " insère la sortie d'une commande
:w !sudo tee %       " enregistre un fichier root oublié avec sudo
```

### Apprendre

```bash
vimtutor          # tutoriel interactif de 30 min : à faire absolument une fois
```

### Configuration minimale `~/.vimrc`

```vim
syntax on
set number
set tabstop=4 shiftwidth=4 expandtab
set hlsearch incsearch ignorecase smartcase
set background=dark
```

## 4. Définir son éditeur par défaut

```bash
export EDITOR=vim          # utilisé par git, crontab -e, visudo…
export VISUAL=vim
sudo update-alternatives --config editor      # Debian/Ubuntu : choix système
# à mettre dans ~/.bashrc pour le rendre permanent
```

Éditez toujours les fichiers sensibles avec leur outil dédié : `visudo` (sudoers), `vipw` (passwd), `crontab -e`, `systemctl edit`. Ils verrouillent et **valident la syntaxe**.

## 5. Éditer sans éditeur interactif (scripts)

```bash
sed -i 's/^port=.*/port=8080/' config.ini        # remplacement en place
sed -i.bak '/^#/d' fichier                       # supprime les commentaires (avec sauvegarde)
echo "nouvelle ligne" >> fichier                 # ajout en fin
printf 'a\nb\n' | tee -a fichier >/dev/null      # ajout via tee (utile avec sudo)
vim -es -c '%s/foo/bar/g' -c 'wq' fichier        # vim en mode scripté
```

## 6. Fichiers binaires et encodage

```bash
file inconnu                     # nature du fichier
strings /bin/ls | head           # chaînes lisibles d'un binaire
xxd fichier | head               # dump hexadécimal  (hexdump -C, od -c)
file -i texte.txt                # encodage (utf-8, iso-8859-1…)
iconv -f ISO-8859-1 -t UTF-8 in.txt > out.txt     # conversion d'encodage
dos2unix script.sh               # fins de ligne Windows (CRLF) → Unix (LF)
```

Un script copié depuis Windows avec des `\r` génère l'erreur mystérieuse `bad interpreter: /bin/bash^M`.

## 7. Résumé

- Lire : `cat`, `less` (recherche `/`), `head`, `tail -F`, `wc`, `sed -n 'a,bp'`.
- Éditer : **nano** pour dépanner, **vim** à connaître : `i`, `Esc`, `:wq`, `:q!`, `dd`, `yy`, `p`, `/`, `:%s///g`, `u`.
- `visudo`, `vipw`, `crontab -e` : éditeurs sécurisés dédiés.
- `sed -i` pour modifier en script ; `EDITOR` pour choisir son outil.

## 8. Quiz

1. Comment voir les 20 dernières lignes d'un journal et continuer à suivre les ajouts, même après rotation ?
2. Dans `less`, comment chercher « error » puis aller à l'occurrence suivante ?
3. Vous ouvrez vim et rien ne se passe quand vous tapez : pourquoi ? Que faire ?
4. Comment quitter vim sans sauvegarder ? En sauvegardant ?
5. Quelle séquence supprime 3 lignes puis les colle plus bas ?
6. Quelle commande remplace `foo` par `bar` dans tout le fichier ?
7. Pourquoi utiliser `visudo` plutôt que `nano /etc/sudoers` ?
8. Comment afficher les lignes 100 à 120 de `app.log` ?

<details><summary>Réponses</summary>

1. `tail -n 20 -F /var/log/app.log`
2. `/error` Entrée, puis `n` (`N` pour revenir).
3. Vous êtes en mode normal : appuyez sur `i` pour passer en insertion (`Esc` pour en sortir).
4. `:q!` ; `:wq` (ou `ZZ`).
5. `3dd`, déplacement, `p`.
6. `:%s/foo/bar/g`
7. `visudo` verrouille le fichier et vérifie la syntaxe (une erreur dans sudoers peut vous priver de root).
8. `sed -n '100,120p' app.log`
</details>

➡️ **Labo** : [LAB.md](LAB.md) · **Démo** : `./lab demo 04` · **Suivant** : [05 — Redirections, pipes et filtres](../05-redirections-pipes-filtres/README.md)
