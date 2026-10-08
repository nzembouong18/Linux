# Labo 08 — Construire, installer, mettre à jour et verrouiller un paquet

> **Durée** : 1 h 15 · **Difficulté** : ⭐⭐ · **Prérequis** : module 08 · **Droits** : `root`/`sudo` · **Système** : Debian/Ubuntu
> *(Aucun accès Internet requis : on travaille avec un paquet local.)*

## Contexte

Votre équipe a écrit un petit outil `bonjour`. Vous devez le **packager**, l'installer proprement, publier une version corrigée, puis la **verrouiller** pour qu'aucune mise à jour automatique ne la remplace.

## Mise en place

```bash
./lab setup 08
cd ~/labs/08 && find monpaquet -type f
```

## Tâches

Travaillez dans `~/labs/08`.

1. **Construire** le paquet `1.0` : `monpaquet_1.0_all.deb` à partir du dossier `monpaquet/` (option `--root-owner-group` pour des fichiers appartenant à root).
2. **Inspecter** ce `.deb` sans l'installer : écrivez dans `info.txt` la ligne `Version:` et la ligne `Package:` extraites de `dpkg-deb -I`.
3. **Installer** le paquet (`sudo dpkg -i` ou `sudo apt install ./…`). Vérifiez que la commande `bonjour` fonctionne.
4. Écrivez dans `fichiers.txt` la liste des fichiers installés (`dpkg -L`) et dans `proprietaire.txt` le **nom du paquet** propriétaire de `/usr/local/bin/bonjour` (`dpkg -S`) — le fichier ne doit contenir que le nom du paquet.
5. **Publier la 1.1** : dans `monpaquet/DEBIAN/control` passez à `Version: 1.1` et modifiez le script `bonjour` pour qu'il affiche aussi `version 1.1` ; reconstruisez `monpaquet_1.1_all.deb` et mettez à jour le paquet installé.
6. **Verrouillez** `monpaquet` avec `apt-mark hold`.
7. Écrivez dans `systeme.txt` : `BASH_PKG=<version du paquet bash installé>` (via `dpkg-query -W -f='${Version}' bash`).

## Validation

```bash
./lab check 08
```

<details><summary>💡 Indices</summary>

- `dpkg-deb --build --root-owner-group monpaquet monpaquet_1.0_all.deb`
- `dpkg-deb -I monpaquet_1.0_all.deb | grep -E '^ *(Package|Version):' | sed 's/^ *//'`
- `dpkg -S /usr/local/bin/bonjour | cut -d: -f1`
- `apt-mark hold monpaquet` ; vérifiez avec `apt-mark showhold`.
</details>

<details><summary>✅ Solution</summary>

```bash
cd ~/labs/08
dpkg-deb --build --root-owner-group monpaquet monpaquet_1.0_all.deb
dpkg-deb -I monpaquet_1.0_all.deb | grep -E '^ *(Package|Version):' | sed 's/^ *//' > info.txt
sudo dpkg -i monpaquet_1.0_all.deb
bonjour
dpkg -L monpaquet > fichiers.txt
dpkg -S /usr/local/bin/bonjour | cut -d: -f1 > proprietaire.txt

sed -i 's/^Version: .*/Version: 1.1/' monpaquet/DEBIAN/control
echo 'echo "version 1.1"' >> monpaquet/usr/local/bin/bonjour
dpkg-deb --build --root-owner-group monpaquet monpaquet_1.1_all.deb
sudo dpkg -i monpaquet_1.1_all.deb
sudo apt-mark hold monpaquet
echo "BASH_PKG=$(dpkg-query -W -f='${Version}' bash)" > systeme.txt
```
</details>

## Pour aller plus loin

- Ajoutez un script `postinst` qui écrit une ligne dans `/var/log/monpaquet.log` à l'installation.
- Ajoutez `Depends: curl` dans `control` et observez la différence entre `dpkg -i` et `apt install ./…` si `curl` est absent.
- Listez les 5 plus gros paquets installés : `dpkg-query -W -f='${Installed-Size}\t${Package}\n' | sort -rn | head -5`.
- Équivalent Red Hat : décrivez comment vous feriez avec `rpmbuild` et `dnf versionlock`.

## Nettoyage

```bash
./lab reset 08     # retire le verrou et désinstalle monpaquet
```
