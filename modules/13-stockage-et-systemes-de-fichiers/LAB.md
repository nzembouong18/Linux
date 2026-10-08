# Labo 13 — Disques, systèmes de fichiers, montages, fstab et LVM (sur fichiers images)

> **Durée** : 3 h · **Difficulté** : ⭐⭐⭐ · **Prérequis** : module 13 · **Droits** : `root`/`sudo` + périphériques *loop*
> Tout se passe sur des **fichiers images** : aucun vrai disque n'est touché.

## Contexte

Un nouveau serveur de fichiers doit recevoir deux volumes (données et sauvegarde) puis un volume LVM extensible. Vous préparez l'ensemble sur des « disques » virtuels avant de le reproduire en production.

## Mise en place

```bash
./lab setup 13
cd ~/labs/13 && ls -R
```

## Partie A — Images et systèmes de fichiers

1. Créez le fichier image **`disque1.img`** de **64 MiB** (fichier *sparse* : `truncate`) et formatez-le en **ext4** avec le label **`DONNEES`**.
2. Créez **`disque2.img`** de **32 MiB**, formaté en **ext4**, label **`SAUVEGARDE`**, avec **1 %** de blocs réservés (`-m 1`).
3. Écrivez dans `infos.txt` :
   ```
   UUID_DONNEES=<UUID du système de fichiers de disque1.img>
   UUID_SAUVEGARDE=<UUID de disque2.img>
   TAILLE_BLOC=<taille de bloc en octets de disque1.img>
   ```

## Partie B — Montages

4. Montez `disque1.img` sur **`mnt/donnees`** et `disque2.img` sur **`mnt/sauvegarde`** avec les options **`noexec,nosuid,nodev`** (montage *loop*).
5. Créez `mnt/donnees/hello.txt` contenant `bonjour stockage`, puis copiez-le dans `mnt/sauvegarde/`.
6. Relevez les options de montage réelles de la sauvegarde : `findmnt -no OPTIONS mnt/sauvegarde > mount.txt`.
7. Écrivez **`fstab.lab`** : les deux lignes que vous ajouteriez à `/etc/fstab` pour rendre ces montages permanents (6 champs, par **UUID**, chemins **absolus** des points de montage, type `ext4`, options `loop,defaults` pour les données et `loop,noexec,nosuid,nodev,nofail` pour la sauvegarde, `0 2`). *(On n'édite pas le vrai `/etc/fstab` dans ce labo.)*
8. **Démontez** `mnt/sauvegarde`, puis vérifiez son système de fichiers **sans le modifier** : `e2fsck -fn disque2.img > fsck.txt 2>&1`. **`mnt/donnees` doit rester monté.**

## Partie C — LVM

9. Créez `pv1.img` et `pv2.img` (64 MiB chacun), associez-les à des périphériques loop (`losetup -f --show`), initialisez-les en **PV** et créez le groupe **`labvg`** contenant les deux.
10. *(si le noyau supporte device-mapper — sinon cette étape est ignorée par le correcteur)* Créez un LV **`labdata`** de **60 MiB**, formatez-le en ext4, montez-le sur **`mnt/lvm`**, créez-y un fichier, puis **agrandissez-le à chaud de +20 MiB** avec le système de fichiers (`lvextend -r`).
11. Écrivez dans `lvm.txt` : `VG_TAILLE_MIB=<taille du VG en MiB, partie entière>` (`vgs --units m`).

## Validation

```bash
./lab check 13
```

<details><summary>💡 Indices</summary>

- `truncate -s 64M disque1.img && mkfs.ext4 -q -L DONNEES disque1.img`
- `blkid -p -s UUID -o value disque1.img` · `dumpe2fs -h disque1.img | grep 'Block size'`
- `sudo mount -o loop,noexec,nosuid,nodev disque2.img mnt/sauvegarde`
- `fstab.lab` : `UUID=… /root/labs/13/mnt/donnees ext4 loop,defaults 0 2`
- `LOOP=$(sudo losetup -f --show pv1.img)` ; `sudo pvcreate $LOOP …` ; `sudo vgcreate labvg $L1 $L2`
- `sudo lvcreate -L 60M -n labdata labvg` · `sudo lvextend -r -L +20M /dev/labvg/labdata`
</details>

<details><summary>✅ Solution</summary>

```bash
cd ~/labs/13
truncate -s 64M disque1.img; mkfs.ext4 -q -L DONNEES disque1.img
truncate -s 32M disque2.img; mkfs.ext4 -q -m 1 -L SAUVEGARDE disque2.img
{ echo "UUID_DONNEES=$(blkid -p -s UUID -o value disque1.img)"
  echo "UUID_SAUVEGARDE=$(blkid -p -s UUID -o value disque2.img)"
  echo "TAILLE_BLOC=$(dumpe2fs -h disque1.img 2>/dev/null | awk -F: '/^Block size/{gsub(/ /,"",$2); print $2}')"; } > infos.txt
sudo mount -o loop,noexec,nosuid,nodev disque1.img mnt/donnees
sudo mount -o loop,noexec,nosuid,nodev disque2.img mnt/sauvegarde
echo "bonjour stockage" | sudo tee mnt/donnees/hello.txt
sudo cp mnt/donnees/hello.txt mnt/sauvegarde/
findmnt -no OPTIONS mnt/sauvegarde > mount.txt
. ./infos.txt
cat > fstab.lab <<EOF
UUID=$UUID_DONNEES $PWD/mnt/donnees ext4 loop,defaults 0 2
UUID=$UUID_SAUVEGARDE $PWD/mnt/sauvegarde ext4 loop,noexec,nosuid,nodev,nofail 0 2
EOF
sudo umount mnt/sauvegarde
e2fsck -fn disque2.img > fsck.txt 2>&1
truncate -s 64M pv1.img pv2.img
L1=$(sudo losetup -f --show pv1.img); L2=$(sudo losetup -f --show pv2.img)
sudo pvcreate $L1 $L2 && sudo vgcreate labvg $L1 $L2
sudo lvcreate -L 60M -n labdata labvg && sudo mkfs.ext4 -q /dev/labvg/labdata
sudo mount /dev/labvg/labdata mnt/lvm && echo ok | sudo tee mnt/lvm/test.txt
sudo lvextend -r -L +20M /dev/labvg/labdata
echo "VG_TAILLE_MIB=$(sudo vgs --noheadings --units m --nosuffix -o vg_size labvg | awk '{printf "%d", $1}')" > lvm.txt
```
</details>

## Pour aller plus loin

- Ajoutez un 3ᵉ PV au VG (`vgextend`), puis déplacez les données d'un PV à l'autre avec `pvmove`.
- Remplissez `mnt/donnees` avec des milliers de petits fichiers et comparez `df -h` et `df -i`.
- Simulez la panne d'un RAID 1 avec `mdadm` sur deux images loop.
- Chiffrez une image avec `cryptsetup luksFormat`, ouvrez-la, formatez-la, montez-la.

## Nettoyage

```bash
./lab reset 13     # démonte tout, supprime LVM de test, détache les loops
```
