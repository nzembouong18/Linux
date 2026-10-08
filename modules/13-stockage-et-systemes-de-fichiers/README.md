# Module 13 — Stockage : disques, partitions, systèmes de fichiers, LVM, RAID, chiffrement

> **Niveau** : Intermédiaire | **Durée** : 6 h (3 h cours + 3 h labo) | **Prérequis** : modules 02, 03, 06
>
> **Objectifs** — À la fin de ce module vous saurez :
> - identifier disques et partitions (`lsblk`, `blkid`, `/dev/disk/by-*`) ;
> - partitionner (MBR/GPT), formater (ext4, XFS), monter et configurer `/etc/fstab` ;
> - superviser l'espace et réparer un système de fichiers ;
> - gérer le swap ;
> - utiliser **LVM** (volumes logiques, extension à chaud, instantanés) ;
> - connaître RAID logiciel (`mdadm`) et chiffrement **LUKS** ;
> - diagnostiquer les problèmes courants (disque plein, inodes, montage échoué).

> ⚠️ **Danger** : les commandes de ce module peuvent détruire des données. Dans les labos on travaille **uniquement sur des fichiers images** (périphériques *loop*). Sur une vraie machine, vérifiez trois fois le nom du disque (`lsblk`) avant `mkfs`, `dd`, `wipefs`, `parted`.

---

## 1. Du matériel au fichier : la pile de stockage

```text
 Application     open("/data/fichier.txt")
      │
 Système de fichiers (ext4, XFS, Btrfs…)   ← organise noms, droits, inodes, journal
      │
 [ LUKS (chiffrement) ]  [ LVM ]  [ RAID md ]   ← couches optionnelles, empilables
      │
 Partition (/dev/sda1, /dev/nvme0n1p2)     ← découpage de la table de partitions (GPT/MBR)
      │
 Périphérique bloc (/dev/sda, /dev/nvme0n1, /dev/vda)   ← disque physique ou virtuel
      │
 Contrôleur : SATA / SAS / NVMe / virtio / iSCSI / SAN
```

### Nommage des périphériques

| Nom | Type |
|-----|------|
| `/dev/sda`, `sdb`… | disque SATA/SAS/USB (SCSI) ; partitions `sda1`, `sda2` |
| `/dev/nvme0n1` | SSD NVMe ; partitions `nvme0n1p1`, `p2` |
| `/dev/vda`, `/dev/xvda` | disque virtuel (KVM/Xen) |
| `/dev/mapper/vg-lv`, `/dev/vg/lv` | volume LVM / chiffré |
| `/dev/md0` | RAID logiciel |
| `/dev/loop0` | fichier présenté comme disque |
| `/dev/sr0` | lecteur optique |

**Les noms `sdX` peuvent changer d'un démarrage à l'autre.** Pour les montages persistants, utilisez **UUID** ou **LABEL** (`/dev/disk/by-uuid/`, `by-label/`, `by-id/`).

## 2. Inventaire

```bash
lsblk                         # arbre des disques/partitions/LVM
lsblk -f                      # + système de fichiers, LABEL, UUID, point de montage
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL
sudo blkid                    # UUID, LABEL, TYPE de chaque périphérique
sudo fdisk -l                 # tables de partitions
findmnt                       # arbre des montages ; findmnt /data ; findmnt -t ext4
df -hT                        # espace par système de fichiers monté (+type)
cat /proc/partitions /proc/mounts
sudo smartctl -a /dev/sda     # santé SMART (paquet smartmontools)
sudo hdparm -I /dev/sda       # infos disque
```

## 3. Partitionnement

| | MBR (msdos) | GPT |
|---|-------------|-----|
| Taille max de disque | 2 TiB | 9,4 ZB |
| Partitions | 4 primaires (ou 3 + 1 étendue) | 128 par défaut |
| Démarrage | BIOS (Legacy) | UEFI (partition ESP FAT32) — fonctionne aussi en BIOS avec `bios_grub` |

**Utilisez GPT** pour tout nouveau disque.

```bash
sudo fdisk /dev/sdb             # interactif (MBR/GPT) : g (GPT)  n (nouvelle)  t (type)  p (afficher)  w (écrire)  q
sudo parted /dev/sdb --script mklabel gpt mkpart data ext4 1MiB 100%     # scriptable
sudo sgdisk -n1:0:0 -t1:8300 /dev/sdb                                    # gdisk en ligne de commande
sudo partprobe /dev/sdb         # demande au noyau de relire la table
sudo wipefs -a /dev/sdb         # efface les signatures (⚠ destructif)
```

Alignement : commencez les partitions à **1 MiB** (SSD, RAID).

## 4. Systèmes de fichiers

| FS | Points forts | Remarques |
|----|-------------|-----------|
| **ext4** | stable, universel, journalisé, extensible et réductible | défaut Debian/Ubuntu |
| **XFS** | très gros volumes, parallélisme, rapide | défaut RHEL ; **s'agrandit mais ne se réduit pas** |
| **Btrfs** | instantanés, sous-volumes, compression, checksums | défaut Fedora/openSUSE |
| **ZFS** | pools, checksums, instantanés, RAID-Z | hors noyau (OpenZFS) |
| **vfat / exFAT** | compatibilité Windows/UEFI/clés USB | pas de droits Unix |
| **NTFS** | disques Windows | `ntfs-3g` |
| **tmpfs** | en RAM (`/tmp`, `/run`, `/dev/shm`) | volatil |
| **NFS / CIFS** | réseau | voir §12 |

**Journalisation** : le FS écrit d'abord ses intentions dans un journal ; après une coupure, il rejoue le journal au lieu de scanner tout le disque.

```bash
sudo mkfs.ext4 -L DONNEES /dev/sdb1          # crée un ext4 (⚠ efface)
sudo mkfs.ext4 -m 1 -L SAUVEGARDE /dev/sdb2  # -m : % de blocs réservés à root (défaut 5 %)
sudo mkfs.xfs -L WEB /dev/sdb3
sudo mkfs.vfat -F32 -n USB /dev/sdc1
sudo mkswap /dev/sdb4                        # zone de swap
```

Inspection / réglages :

```bash
sudo dumpe2fs -h /dev/sdb1                  # superbloc ext4 : taille de bloc, inodes, état, dernier montage
sudo tune2fs -L NOUVEAU /dev/sdb1           # changer le label
sudo tune2fs -m 1 /dev/sdb1                 # changer le % réservé
sudo tune2fs -l /dev/sdb1 | grep -i 'block size'
sudo xfs_info /mnt/web
```

## 5. Montage

```bash
sudo mkdir -p /data
sudo mount /dev/sdb1 /data                    # montage manuel
sudo mount -o ro,noexec,nosuid,nodev /dev/sdb1 /data
sudo mount UUID=1234-ABCD /data
sudo mount -o loop disque.img /mnt/img        # monte un fichier image
sudo mount -o remount,rw /data                # change les options à chaud
sudo mount --bind /srv/web /var/www/web       # même contenu à un 2e endroit (bind mount)
sudo umount /data                             # ou umount /dev/sdb1
sudo umount -l /data                          # démontage « paresseux » (dernier recours)
sudo fuser -vm /data ; sudo lsof +f -- /data  # qui empêche le démontage (« target is busy ») ?
```

Options courantes : `defaults` (rw, suid, dev, exec, auto, nouser, async) · `ro` · `noexec` · `nosuid` · `nodev` · `noatime` (réduit les écritures) · `discard` · `nofail` · `x-systemd.automount`.

> Durcissement : montez `/tmp`, `/var/tmp`, `/dev/shm`, les partages utilisateurs avec `noexec,nosuid,nodev` si possible.

### `/etc/fstab` — montages permanents

```text
# <fs>                                      <point>   <type>  <options>            <dump> <fsck>
UUID=2c1b6d8e-1111-4a2b-9c3d-aaaabbbbcccc   /         ext4    errors=remount-ro    0      1
UUID=7A3F-12CD                              /boot/efi vfat    umask=0077           0      1
UUID=5e7f…                                  /data     ext4    defaults,noatime     0      2
LABEL=SAUVEGARDE                            /backup   ext4    noexec,nosuid,nofail 0      2
/swapfile                                   none      swap    sw                   0      0
srv:/export/home                            /home     nfs     _netdev,nofail       0      0
```

Champs : *1* périphérique (UUID recommandé) · *2* point de montage · *3* type · *4* options · *5* `dump` (0) · *6* ordre `fsck` (1 pour `/`, 2 pour les autres, 0 jamais).

```bash
sudo findmnt --verify            # valide /etc/fstab (syntaxe, périphériques)
sudo mount -a                    # monte tout ce qui est dans fstab : TEST OBLIGATOIRE avant reboot
sudo systemctl daemon-reload     # après modification de fstab (systemd régénère les .mount)
```

> 🔴 Une ligne `fstab` erronée **sans `nofail`** peut empêcher le démarrage (mode d'urgence). Testez avec `mount -a`, ajoutez `nofail` aux disques non critiques.

Alternative moderne : unités systemd `.mount` / `.automount` (module 14).

## 6. Espace disque et inodes

```bash
df -hT                          # utilisation par FS
df -i                           # inodes : un FS peut être « plein » avec 0 % d'espace utilisé !
du -sh /var/* 2>/dev/null | sort -h | tail
du -xh --max-depth=1 / | sort -h | tail   # -x : ne pas traverser d'autres FS
ncdu -x /                       # explorateur interactif
sudo lsof +L1                   # fichiers supprimés mais encore ouverts (espace non libéré)
```

| Symptôme | Cause / action |
|----------|----------------|
| `No space left on device` mais `df` montre de la place | inodes épuisés (`df -i`) : beaucoup de petits fichiers (sessions, mails, cache) |
| Espace pas libéré après `rm` | un processus garde le fichier ouvert : `lsof +L1`, redémarrer le service |
| `/var/log` énorme | `journalctl --vacuum-size=500M`, `logrotate` (module 15) |
| `/` plein à cause des paquets | `apt clean`, `apt autoremove --purge`, anciens noyaux |
| Docker | `docker system df`, `docker system prune` |

Quotas utilisateurs : options `usrquota,grpquota`, `quotacheck`, `edquota`, `repquota` (voir `man quota`).

## 7. Vérification et réparation

```bash
sudo umount /dev/sdb1                # JAMAIS de fsck sur un FS monté en écriture
sudo fsck -f /dev/sdb1               # (ext*) ; -n = lecture seule, -y = répond oui à tout, -p = automatique
sudo e2fsck -fn disque.img           # vérification sans modification
sudo xfs_repair -n /dev/sdb3         # XFS (démonter d'abord)
sudo mount -o ro /dev/sdb1 /mnt      # lecture seule pour sauver les données avant réparation
```

Recommandation : avant toute réparation d'un disque défaillant, **copiez l'image** (`ddrescue /dev/sdb disque.img journal.log`) et réparez la copie.

## 8. Swap

```bash
free -h ; swapon --show ; cat /proc/swaps
sudo fallocate -l 2G /swapfile && sudo chmod 600 /swapfile
sudo mkswap /swapfile && sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
sudo swapoff /swapfile
sysctl vm.swappiness              # tendance à swapper (60 par défaut ; 10 pour un serveur de BD)
```
`zram` (swap compressé en RAM) : paquet `zram-tools` / `systemd-zram-generator`.

## 9. LVM — Logical Volume Manager

LVM abstrait les disques physiques pour redimensionner et regrouper à chaud :

```text
 Disques/partitions    /dev/sdb1   /dev/sdc1               ← PV  (Physical Volume)
                          └────┬──────┘
 Groupe de volumes        VG « data »   (pool d'espace)    ← VG  (Volume Group)
                      ┌───────┼────────┐
 Volumes logiques    LV web  LV db   (libre)               ← LV  (Logical Volume) /dev/data/web
                       │       │
                     ext4     xfs   → montés dans /var/www, /var/lib/postgresql
```

```bash
sudo pvcreate /dev/sdb1 /dev/sdc1            # initialise des PV
sudo vgcreate data /dev/sdb1 /dev/sdc1       # crée le VG
sudo lvcreate -L 20G -n web data             # LV de 20 Go ; -l 100%FREE pour tout l'espace libre
sudo mkfs.ext4 /dev/data/web
sudo mount /dev/data/web /var/www

sudo pvs ; sudo vgs ; sudo lvs               # résumé ;  pvdisplay / vgdisplay / lvdisplay : détail

# ----- Agrandir À CHAUD
sudo lvextend -r -L +10G /dev/data/web       # -r : étend aussi le système de fichiers (resize2fs / xfs_growfs)
sudo vgextend data /dev/sdd1                 # ajouter un disque au VG si plus d'espace libre

# ----- Réduire (ext4 uniquement, démonté, sauvegarde préalable !)
sudo umount /var/www && sudo e2fsck -f /dev/data/web
sudo lvreduce -r -L 15G /dev/data/web

# ----- Instantanés
sudo lvcreate -s -L 5G -n web_snap /dev/data/web     # snapshot (copie-sur-écriture)
sudo lvconvert --merge /dev/data/web_snap            # revenir à l'état du snapshot
sudo lvremove /dev/data/web_snap

# ----- Migrer des données d'un disque à un autre à chaud
sudo pvmove /dev/sdb1 /dev/sde1 && sudo vgreduce data /dev/sdb1 && sudo pvremove /dev/sdb1
```

Cas fréquent — **agrandir `/`** sur Ubuntu Server (LVM par défaut) quand le disque virtuel a grossi :

```bash
sudo growpart /dev/vda 3          # agrandit la partition (cloud-utils)
sudo pvresize /dev/vda3
sudo lvextend -r -l +100%FREE /dev/ubuntu-vg/ubuntu-lv
```

Aussi : **thin provisioning** (`lvcreate --thinpool`), **cache** (`lvmcache`), **RAID LVM** (`--type raid1`).

## 10. RAID logiciel (`mdadm`)

| Niveau | Principe | Disques min | Tolérance | Capacité utile |
|-------:|----------|:-----------:|-----------|---------------|
| 0 | agrégat (stripe) | 2 | **aucune** | 100 % |
| 1 | miroir | 2 | n-1 disques | 50 % (2 disques) |
| 5 | parité distribuée | 3 | 1 disque | (n-1)/n |
| 6 | double parité | 4 | 2 disques | (n-2)/n |
| 10 | miroirs agrégés | 4 | 1 par miroir | 50 % |

> **RAID n'est pas une sauvegarde** : il protège d'une panne de disque, pas d'une suppression, d'un rançongiciel ou d'une erreur humaine.

```bash
sudo mdadm --create /dev/md0 --level=1 --raid-devices=2 /dev/sdb1 /dev/sdc1
cat /proc/mdstat ; sudo mdadm --detail /dev/md0
sudo mdadm --detail --scan | sudo tee -a /etc/mdadm/mdadm.conf && sudo update-initramfs -u
sudo mdadm /dev/md0 --fail /dev/sdb1 --remove /dev/sdb1      # simuler/traiter une panne
sudo mdadm /dev/md0 --add /dev/sdd1                          # ajouter un disque de remplacement (reconstruction)
```

## 11. Chiffrement avec LUKS

```bash
sudo cryptsetup luksFormat /dev/sdb1            # ⚠ efface ; demande une phrase secrète
sudo cryptsetup open /dev/sdb1 secret           # apparaît en /dev/mapper/secret
sudo mkfs.ext4 /dev/mapper/secret
sudo mount /dev/mapper/secret /mnt/secret
sudo umount /mnt/secret && sudo cryptsetup close secret
sudo cryptsetup luksDump /dev/sdb1              # en-tête, emplacements de clés
sudo cryptsetup luksAddKey /dev/sdb1            # ajouter une 2e phrase (sauvegardez l'en-tête : luksHeaderBackup)
# montage automatique : /etc/crypttab  (nom  périphérique  fichier-clé|none  options)
```

## 12. Stockage réseau (aperçu)

| Protocole | Usage | Exemple |
|-----------|-------|---------|
| **NFS** | partages Unix | `sudo mount -t nfs srv:/export /mnt` ; serveur : `/etc/exports` + `exportfs -ra` |
| **SMB/CIFS** | partages Windows | `sudo mount -t cifs //srv/partage /mnt -o username=alice` |
| **iSCSI** | disque bloc via IP | `iscsiadm` |
| **SSHFS** | dossier distant via SSH (FUSE) | `sshfs alice@srv:/data /mnt` |
| **Ceph, GlusterFS** | stockage distribué | clusters |

## 13. Performances et santé

```bash
iostat -xz 1 5            # (sysstat) %util, await, débit par périphérique
iotop -oPa                # processus qui écrivent/lisent
sudo smartctl -H /dev/sda # santé SMART globale
sudo fstrim -av           # SSD : libère les blocs inutilisés (timer fstrim.timer)
dd if=/dev/zero of=test bs=1M count=1024 oflag=direct status=progress    # test d'écriture grossier
fio --name=test --rw=randread --bs=4k --size=1G --iodepth=16 --runtime=30 --time_based   # mesures sérieuses
```

## 14. Aide-mémoire : ajouter un disque de données (procédure standard)

```bash
lsblk                                            # 1. identifier le nouveau disque (ex. /dev/sdb)
sudo parted /dev/sdb --script mklabel gpt mkpart data ext4 1MiB 100%     # 2. partitionner
sudo mkfs.ext4 -L DATA /dev/sdb1                 # 3. formater
sudo mkdir -p /data
sudo blkid /dev/sdb1                             # 4. relever l'UUID
echo 'UUID=<uuid> /data ext4 defaults,noatime,nofail 0 2' | sudo tee -a /etc/fstab
sudo systemctl daemon-reload && sudo mount -a    # 5. monter via fstab (valide la ligne)
findmnt /data && df -h /data                     # 6. vérifier
sudo chown -R appuser: /data                     # 7. droits
```

## 15. Résumé

- Pile : disque → partition (GPT) → [RAID/LVM/LUKS] → système de fichiers → montage.
- Identifiez avec `lsblk -f`/`blkid` ; montez **par UUID** ; testez `fstab` avec `mount -a` ; utilisez `nofail`.
- ext4 (réductible) vs XFS (non réductible) ; `df -h` **et** `df -i` ; `lsof +L1` pour l'espace fantôme.
- LVM : PV → VG → LV, `lvextend -r` pour agrandir à chaud, snapshots.
- RAID ≠ sauvegarde ; LUKS pour chiffrer au repos.
- `fsck`/`xfs_repair` uniquement sur FS **démonté**.

## 16. Quiz

1. Pourquoi préférer l'UUID à `/dev/sdb1` dans `fstab` ?
2. Que vérifie `findmnt --verify` ? Et pourquoi lancer `mount -a` avant un redémarrage ?
3. Un disque est « plein » alors que `df -h` indique 40 % d'utilisation : que testez-vous ?
4. Quelle différence de redimensionnement entre ext4 et XFS ?
5. Dans LVM, que signifient PV, VG, LV ? Comment agrandir un LV de 10 Go avec son FS à chaud ?
6. Pourquoi RAID 1 ne dispense-t-il pas de sauvegardes ?
7. Quelle option de `mount` empêche l'exécution de binaires sur un volume ?
8. Que fait `losetup` et à quoi cela sert-il dans une formation ?

<details><summary>Réponses</summary>

1. Les noms `sdX` peuvent changer (ordre de détection) ; l'UUID est stable.
2. La syntaxe et l'existence des sources de `/etc/fstab`. `mount -a` détecte les erreurs avant qu'elles n'empêchent le démarrage.
3. `df -i` (inodes épuisés) puis `lsof +L1` (fichiers supprimés mais ouverts).
4. ext4 peut s'agrandir et se réduire (démonté pour réduire) ; XFS ne peut que s'agrandir (`xfs_growfs`).
5. Physical Volume, Volume Group, Logical Volume. `lvextend -r -L +10G /dev/vg/lv`.
6. Le RAID protège d'une panne matérielle, pas de la suppression, de la corruption logique, d'un rançongiciel ni d'un sinistre.
7. `noexec` (avec `nosuid,nodev` pour un durcissement complet).
8. Associe un fichier à un périphérique bloc `/dev/loopN` pour manipuler des « disques » sans matériel.
</details>

➡️ **Labo** : [LAB.md](LAB.md) · **Démo** : `./lab demo 13` · **Suivant** : [14 — systemd, services, cron et timers](../14-systemd-et-services/README.md)
