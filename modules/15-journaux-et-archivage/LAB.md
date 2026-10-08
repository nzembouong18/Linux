# Labo 15 — Archiver, compresser, faire tourner les logs et sauvegarder

> **Durée** : 2 h 30 · **Difficulté** : ⭐⭐ · **Prérequis** : module 15 · outils : `tar`, `gzip`, `bzip2`, `xz`, `rsync`, `logrotate`

## Contexte

Le serveur `donnees/` contient des documents à protéger. Vous devez produire une archive propre, comparer les compresseurs, mettre en place une rotation de journaux et un script de sauvegarde incrémentale par liens durs, puis répondre à quelques questions de stratégie.

## Mise en place

```bash
./lab setup 15
cd ~/labs/15 && find donnees | head -20 && wc -l journal/app.log
```

## Tâches (dans `~/labs/15`)

### A. Archive et restauration
1. Créez **`archive.tar.gz`** du dossier `donnees` avec des **chemins relatifs** (`donnees/…`), en **excluant** tous les fichiers `*.tmp` et le dossier `cache`. Les fichiers cachés doivent être inclus.
2. `stats.txt` : `NB_FICHIERS=<nombre de fichiers (hors dossiers) dans l'archive>` et `TAILLE_ARCHIVE=<taille en octets de archive.tar.gz>`.
3. **Restaurez** l'archive dans `restauration/` (sans écraser `donnees/`).
4. `sha256sum.txt` : empreintes SHA-256 de **tous** les fichiers restaurés (`sha256sum` sur chaque fichier sous `restauration/`, chemins relatifs à `~/labs/15`).

### B. Compression
5. Compressez `journal/app.log` avec **gzip -9**, **bzip2 -9** et **xz -9** en **conservant l'original** (`app.log.gz`, `app.log.bz2`, `app.log.xz` dans `journal/`).
6. `compare.txt` : `ORIGINAL_OCTETS=<taille de app.log>` et `MEILLEUR=<extension (gz, bz2 ou xz) du plus petit fichier>`.

### C. Rotation des journaux
7. Écrivez **`app.logrotate`** pour `~/labs/15/journal/app.log` (chemin **absolu**) : rotation **quotidienne**, **7** générations, **compression** avec `delaycompress`, `missingok`, `notifempty`, `create 0640 <votre utilisateur> <votre groupe>`. Testez avec `logrotate -d`.

### D. Sauvegarde incrémentale
8. Écrivez **`sauvegarde-rsync.sh SRC DESTDIR NOM`** :
   - crée `DESTDIR/NOM` avec `rsync -a --delete` ;
   - si `DESTDIR/latest` existe, utilise `--link-dest` vers l'ancienne sauvegarde ;
   - met à jour le lien symbolique `DESTDIR/latest` → `NOM` ;
   - affiche le chemin de la sauvegarde sur stdout ;
   - codes retour : `1` mauvais usage (arguments manquants), `3` source absente, `4` `NOM` existe déjà.
   Le correcteur le lancera deux fois, en modifiant la source entre les deux : les fichiers inchangés doivent être des **liens durs**.

### E. Stratégie (`reponses.txt`)
9. `COPIES`, `SUPPORTS`, `HORS_SITE` : les trois nombres de la règle **3-2-1**. `PERTE_MAX` : l'acronyme de la « perte de données maximale tolérée » ; `DUREE_REPRISE` : l'acronyme de la « durée maximale d'indisponibilité tolérée ».

## Validation

```bash
./lab check 15
```

<details><summary>💡 Indices</summary>

- `tar -czf archive.tar.gz --exclude='*.tmp' --exclude='cache' donnees`
- `tar -tzf archive.tar.gz | grep -vc '/$'` compte les fichiers (les dossiers finissent par `/`).
- `find restauration -type f -print0 | sort -z | xargs -0 sha256sum > sha256sum.txt`
- `gzip -k -9 journal/app.log` (idem `bzip2 -k -9`, `xz -k -9`)
- `rsync -a --delete --link-dest=<ancienne> "$SRC"/ "$DEST/$NAME"/`
</details>

<details><summary>✅ Solution</summary>

```bash
cd ~/labs/15
tar -czf archive.tar.gz --exclude='*.tmp' --exclude='cache' donnees
{ echo "NB_FICHIERS=$(tar -tzf archive.tar.gz | grep -vc '/$')"; echo "TAILLE_ARCHIVE=$(stat -c %s archive.tar.gz)"; } > stats.txt
mkdir -p restauration && tar -xzf archive.tar.gz -C restauration
find restauration -type f -print0 | sort -z | xargs -0 sha256sum > sha256sum.txt
gzip -k -9 journal/app.log; bzip2 -k -9 journal/app.log; xz -k -9 journal/app.log
best=$(ls -S journal/app.log.* | tail -1); echo "MEILLEUR=${best##*.}"   # plus petit fichier
{ echo "ORIGINAL_OCTETS=$(stat -c %s journal/app.log)"; echo "MEILLEUR=${best##*.}"; } > compare.txt
cat > app.logrotate <<EOF
$PWD/journal/app.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0640 $(id -un) $(id -gn)
}
EOF
logrotate -d -s /tmp/state-lab15 app.logrotate
cat > sauvegarde-rsync.sh <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
[[ $# -eq 3 ]] || { echo "Usage: $0 SRC DESTDIR NOM" >&2; exit 1; }
src=$1 dest=$2 name=$3
[[ -d $src ]] || { echo "Source absente: $src" >&2; exit 3; }
[[ ! -e $dest/$name ]] || { echo "Existe déjà: $dest/$name" >&2; exit 4; }
mkdir -p "$dest"
link=()
[[ -e $dest/latest ]] && link=(--link-dest="$(readlink -f "$dest/latest")")
rsync -a --delete "${link[@]}" "$src"/ "$dest/$name"/
ln -sfn "$name" "$dest/latest"
echo "$dest/$name"
EOS
chmod +x sauvegarde-rsync.sh
printf 'COPIES=3\nSUPPORTS=2\nHORS_SITE=1\nPERTE_MAX=RPO\nDUREE_REPRISE=RTO\n' > reponses.txt
```
</details>

## Pour aller plus loin

- Chiffrez l'archive avec `gpg -c archive.tar.gz` et vérifiez la restauration.
- Ajoutez une rétention (garder 5 sauvegardes) dans votre script.
- Comparez `zstd -19` et `xz -9` (temps avec `time`, taille).
- Planifiez votre script avec un timer systemd + `OnFailure=` (module 14).

## Nettoyage

```bash
./lab reset 15
```
