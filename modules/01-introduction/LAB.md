# Labo 01 — Fiche d'identité d'un système

> **Durée** : 30 min · **Difficulté** : ⭐ · **Prérequis** : environnement du module 01 opérationnel

## Contexte

Votre responsable vous demande de documenter le serveur sur lequel vous travaillez avant toute intervention. Vous devez produire une **fiche d'identité** exacte au format `CLÉ=valeur`.

## Mise en place

```bash
./lab setup 01
cd ~/labs/01
```

## Tâches

Créez le fichier `~/labs/01/rapport.txt` contenant **exactement** ces 8 lignes (une clé par ligne, format `CLÉ=valeur`, sans espace autour du `=`) :

| Clé | Valeur attendue | Commande suggérée |
|-----|-----------------|-------------------|
| `HOSTNAME` | nom de la machine | `hostname` |
| `USER` | utilisateur courant | `whoami` |
| `KERNEL` | version du noyau (ex. `6.8.0-45-generic`) | `uname -r` |
| `ARCH` | architecture (ex. `x86_64`) | `uname -m` |
| `DISTRO` | `PRETTY_NAME` de `/etc/os-release` (sans guillemets) | `grep` / `source` |
| `CPUS` | nombre de cœurs | `nproc` |
| `MEM_MB` | mémoire totale en Mo (arrondi, ±5 % toléré) | `free -m` |
| `HOME_DIR` | répertoire personnel | `echo $HOME` |

Ensuite, créez `~/labs/01/aide.txt` contenant **la 1ʳᵉ ligne de la section NAME** de la page de manuel de `tar` (utilisez `whatis tar` ou `man tar | head`) — le fichier doit contenir le mot `tar`.

## Validation

```bash
./lab check 01
```

<details><summary>💡 Indices</summary>

- Combinez des commandes avec `$(commande)` : `echo "KERNEL=$(uname -r)"`.
- Redirigez avec `>` (création) et `>>` (ajout) — vu en détail au module 05.
- Pour la distribution : `. /etc/os-release; echo "$PRETTY_NAME"`.
- Mémoire : `free -m | awk '/^Mem:/{print $2}'`.
</details>

<details><summary>✅ Solution</summary>

```bash
cd ~/labs/01
{
  echo "HOSTNAME=$(hostname)"
  echo "USER=$(whoami)"
  echo "KERNEL=$(uname -r)"
  echo "ARCH=$(uname -m)"
  echo "DISTRO=$(. /etc/os-release; echo "$PRETTY_NAME")"
  echo "CPUS=$(nproc)"
  echo "MEM_MB=$(free -m | awk '/^Mem:/{print $2}')"
  echo "HOME_DIR=$HOME"
} > rapport.txt
whatis tar > aide.txt
```
</details>

## Pour aller plus loin

1. Ajoutez la ligne `UPTIME=` avec `uptime -p`.
2. Affichez la charge moyenne des 5 dernières minutes seule (`awk` sur `/proc/loadavg`).
3. Trouvez dans le manuel de `ls` l'option qui trie par taille, puis testez-la.

## Nettoyage

```bash
./lab reset 01
```
