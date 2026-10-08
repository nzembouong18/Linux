# Module 21 — Noyau, démarrage (boot), modules, udev et récupération

> **Niveau** : Avancé | **Durée** : 6 h (3 h cours + 3 h labo) | **Prérequis** : modules 13, 14, 16
>
> **Objectifs** — À la fin de ce module vous saurez :
> - décrire le **processus de démarrage** de Linux du firmware à la session utilisateur ;
> - configurer **GRUB** et les paramètres du noyau ;
> - gérer les **modules noyau** (`lsmod`, `modprobe`, blacklist, options) et `initramfs` ;
> - comprendre **udev** et écrire des règles de périphériques ;
> - lire les messages du noyau (`dmesg`, `journalctl -k`) pour diagnostiquer ;
> - **réparer** un système qui ne démarre pas (mode secours, mot de passe root perdu, `fstab` cassé, GRUB) ;
> - connaître les étapes de compilation et de mise à jour du noyau.

---

## 1. Le processus de démarrage

```text
 1. Firmware        BIOS (MBR)  ou  UEFI (partition ESP FAT32, /boot/efi)       ← POST, matériel
        │
 2. Chargeur        GRUB2 (menu, choix du noyau, paramètres)  /  systemd-boot
        │           charge : vmlinuz (noyau) + initrd/initramfs
 3. Noyau           décompression, initialise CPU/mémoire/pilotes, monte l'initramfs
        │
 4. initramfs       mini-système en RAM : charge les pilotes du stockage (NVMe, RAID, LVM, LUKS),
        │           déverrouille/monte la racine « / » réelle
 5. init = systemd  PID 1 : monte les systèmes de fichiers (fstab), démarre les unités
        │           jusqu'à la cible par défaut  (default.target → multi-user / graphical)
 6. Connexion       getty/sshd/gdm → session utilisateur
```

```bash
[ -d /sys/firmware/efi ] && echo UEFI || echo BIOS          # mode de démarrage
cat /proc/cmdline                                           # paramètres passés au noyau
systemd-analyze ; systemd-analyze blame | head              # durée par étape / par unité
journalctl -b -p warning                                    # avertissements du démarrage courant
journalctl --list-boots                                     # démarrages précédents (journal persistant requis)
last -x | head                                              # reboots/arrêts
```

Arrêt/redémarrage : `systemctl reboot`, `systemctl poweroff`, `shutdown -r +10 "maintenance"`, `shutdown -c`. Redémarrage rapide du noyau sans firmware : `kexec`.

## 2. GRUB2

```bash
sudo nano /etc/default/grub              # NE PAS éditer /boot/grub/grub.cfg (généré)
sudo update-grub                         # Debian/Ubuntu : régénère /boot/grub/grub.cfg
sudo grub2-mkconfig -o /boot/grub2/grub.cfg          # RHEL (BIOS) ; UEFI : /boot/efi/EFI/<distro>/grub.cfg
sudo grub-install /dev/sda               # (BIOS) réinstalle le chargeur dans le MBR
sudo grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ubuntu      # (UEFI)
sudo grubby --update-kernel=ALL --args="console=ttyS0"   # RHEL : modifier les paramètres de tous les noyaux
```

`/etc/default/grub` :

```ini
GRUB_DEFAULT=0                          # entrée par défaut (ou "saved" avec GRUB_SAVEDEFAULT=true)
GRUB_TIMEOUT_STYLE=menu                 # menu | hidden
GRUB_TIMEOUT=5                          # secondes avant démarrage automatique
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"      # paramètres des démarrages normaux
GRUB_CMDLINE_LINUX="net.ifnames=0"             # paramètres de TOUS les modes (y compris recovery)
GRUB_DISABLE_OS_PROBER=false            # détecte Windows etc. pour le menu
GRUB_TERMINAL="console serial"          # + GRUB_SERIAL_COMMAND="serial --speed=115200"
```

### Paramètres du noyau utiles (à la volée : dans GRUB, touche `e` puis `Ctrl+X`)

| Paramètre | Effet |
|-----------|-------|
| `quiet splash` | démarrage silencieux / graphique |
| `single`, `1`, `systemd.unit=rescue.target` | mode **secours** (mono-utilisateur) |
| `systemd.unit=emergency.target` | mode **urgence** (racine en lecture seule, minimal) |
| `systemd.unit=multi-user.target` | démarre sans interface graphique |
| `init=/bin/bash` | lance directement un shell root à la place de systemd |
| `rd.break` (RHEL) | s'arrête dans l'initramfs avant de monter la vraie racine |
| `nomodeset` | désactive le pilote graphique noyau (écran noir) |
| `console=ttyS0,115200n8` | console série (serveurs, VM, cloud) |
| `net.ifnames=0` | noms `eth0` plutôt que `ens3` |
| `ro` / `rw`, `root=UUID=…` | montage de la racine |
| `mem=2G`, `maxcpus=1`, `nosmp` | limites de test |
| `systemd.log_level=debug`, `debug` | verbosité |
| `selinux=0`, `enforcing=0`, `apparmor=0` | désactiver le MAC (diagnostic seulement) |
| `fsck.mode=force`, `fsck.repair=yes` | forcer le contrôle des disques |

## 3. Le noyau et ses modules

```bash
uname -r                          # version (ex. 6.8.0-45-generic)
cat /proc/version                 # compilateur, date
lsmod | head                      # modules chargés (taille, utilisation)
modinfo ext4                      # description, dépendances, paramètres d'un module
modinfo -p loop                   # paramètres seulement
sudo modprobe br_netfilter        # charge un module (+ dépendances)
sudo modprobe -r br_netfilter     # le décharge
sudo insmod fichier.ko ; sudo rmmod nom         # bas niveau (sans dépendances)
modprobe -c | grep blacklist      # configuration effective
ls /lib/modules/$(uname -r)/kernel/drivers/net | head
cat /sys/module/loop/parameters/max_loop        # paramètre en cours d'un module chargé
```

**Chargement au démarrage / options / liste noire**

```ini
# /etc/modules-load.d/reseau.conf       → chargé au boot par systemd-modules-load
br_netfilter
overlay

# /etc/modprobe.d/options.conf
options loop max_loop=16
options snd-hda-intel power_save=1
blacklist pcspkr                          # n'est plus chargé automatiquement
install pcspkr /bin/false                 # interdit même le chargement explicite
```
Après changement concernant le démarrage précoce : `sudo update-initramfs -u` (Debian/Ubuntu) ou `sudo dracut -f` (RHEL).

### initramfs

```bash
lsinitramfs /boot/initrd.img-$(uname -r) | head           # contenu (Debian)   ·   lsinitrd (RHEL)
sudo update-initramfs -u -k all           # régénère (après modif de crypttab, LVM, RAID, modules…)
sudo dracut -f --regenerate-all           # RHEL
```
Un initramfs incomplet = « kernel panic : unable to mount root fs » ou « waiting for root device ».

### Paramètres dynamiques : `/proc/sys` et `sysctl` (rappel module 16)

```bash
sysctl -a | wc -l ; sysctl vm.swappiness
sudo sysctl -w vm.swappiness=10                    # temporaire
echo 'vm.swappiness=10' | sudo tee /etc/sysctl.d/90-swap.conf && sudo sysctl --system      # persistant
```

### Messages du noyau

```bash
dmesg -T --level=err,warn                 # -T horodatage lisible
dmesg -w                                  # suivre (branchez une clé USB…)
journalctl -k -b                          # noyau, démarrage courant
journalctl -k -b -1 | tail                # démarrage précédent (après un plantage)
```
Rechercher : `Out of memory: Killed process`, `EXT4-fs error`, `I/O error`, `ata… failed command`, `Call Trace`, `segfault`, `Machine Check`, `tainted`. `cat /proc/sys/kernel/tainted` indique si le noyau a été « souillé » (module propriétaire, etc.).

Plantage noyau : **kernel panic** → `kdump` (paquet `kdump-tools`/`kexec-tools`) enregistre un vidage mémoire dans `/var/crash` pour analyse avec `crash`.

## 4. Matériel et udev

```bash
lscpu ; lsmem ; lspci -k ; lsusb ; lsblk
sudo dmidecode -t system -t memory | head -30      # BIOS, modèle, barrettes
sudo lshw -short
sensors                                           # températures (lm-sensors)
ls /sys/class/net /sys/block /sys/bus/usb/devices
```

**udev** crée les nœuds `/dev`, nomme les périphériques et applique des règles à chaque événement matériel (*uevent*).

```bash
udevadm monitor --udev --subsystem-match=block         # voir les événements en direct (branchez un disque)
udevadm info -a -n /dev/sdb | head -40                  # attributs du périphérique (pour écrire une règle)
udevadm info /dev/sdb1 | grep -E 'ID_FS|ID_SERIAL'
udevadm test /sys/class/block/sdb1                      # simule les règles
sudo udevadm control --reload && sudo udevadm trigger   # recharge et rejoue
udevadm verify /etc/udev/rules.d/99-usb.rules           # vérifie la syntaxe (systemd ≥ 254)
```

`/etc/udev/rules.d/99-cle-lab.rules` (le préfixe numérique définit l'ordre ; `/etc` prime sur `/usr/lib/udev/rules.d`) :

```udev
# Clé USB identifiée par ses ID → lien /dev/clef-lab, droits 0660 groupe plugdev
SUBSYSTEM=="block", ENV{ID_VENDOR_ID}=="0951", ENV{ID_MODEL_ID}=="1666", SYMLINK+="clef-lab", GROUP="plugdev", MODE="0660"
# Exécuter une action à l'insertion (préférez une unité systemd via TAG+="systemd")
ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0951", RUN+="/usr/local/bin/clef-inseree.sh"
```
Opérateurs : `==` (test), `!=`, `=` (affecte), `+=` (ajoute), `:=` (affecte, final). Les noms réseau stables (`ens3`, `enp0s31f6`) viennent aussi d'udev/systemd (`net.ifnames`).

## 5. Récupération : quand ça ne démarre plus

### Arbre de décision

| Ce que vous voyez | Cause probable | Action |
|-------------------|----------------|--------|
| Rien (écran noir), pas de GRUB | firmware/ordre de boot, disque non détecté, ESP supprimée | BIOS/UEFI, live USB, `efibootmgr` |
| `grub rescue>` | `/boot/grub` introuvable (partition changée) | `ls`, `set root=(hd0,gpt2)`, `insmod normal`, `normal` ; puis `grub-install` + `update-grub` depuis un chroot |
| Kernel panic « unable to mount root fs » | initramfs/pilote manquant, mauvais `root=` | démarrer un ancien noyau (menu GRUB), `update-initramfs -u` |
| « You are in emergency mode » | `fstab` erroné, FS corrompu, disque absent | `journalctl -xb`, corriger `/etc/fstab`, `fsck`, `mount -o remount,rw /` |
| Boucle de redémarrage / service qui bloque | unité défaillante | `systemd.unit=rescue.target`, `systemctl mask` l'unité, journaux |
| Mot de passe root perdu | — | voir ci-dessous |
| Écran noir après le logo | pilote graphique | `nomodeset`, mode texte `systemd.unit=multi-user.target` |

### Réinitialiser le mot de passe root (accès physique/console requis)

```text
1. Au menu GRUB : touche e → ligne « linux … » → ajouter à la fin :   rw init=/bin/bash     (Ubuntu/Debian)
                                                                      rd.break               (RHEL ; ensuite : mount -o remount,rw /sysroot ; chroot /sysroot)
2. Ctrl+X pour démarrer
3. passwd root         (ou passwd utilisateur)
   RHEL + SELinux : touch /.autorelabel        ← indispensable, sinon la connexion échoue
4. exec /sbin/init     (ou  reboot -f)
```
> 🔐 C'est pourquoi la sécurité physique, **le chiffrement LUKS** et **un mot de passe GRUB / Secure Boot** comptent : qui a accès à la console sans disque chiffré a accès à tout.

### Réparer depuis un Live USB (chroot)

```bash
sudo mount /dev/sda2 /mnt                             # racine du système cassé
sudo mount /dev/sda1 /mnt/boot/efi                    # ESP (UEFI)
for d in dev dev/pts proc sys run; do sudo mount --bind /$d /mnt/$d; done
sudo chroot /mnt /bin/bash
  update-initramfs -u -k all ; update-grub ; grub-install /dev/sda ; passwd root ; nano /etc/fstab
exit ; sudo umount -R /mnt ; reboot
```
LVM : `vgchange -ay` avant de monter ; LUKS : `cryptsetup open /dev/sda3 cryptroot`.

### Garder un filet de sécurité
- Conserver **2 noyaux** (l'ancien reste sélectionnable dans GRUB) ; ne pas purger avant d'avoir validé le nouveau.
- Sauvegarder `/boot`, `/etc`, la table de partitions (`sfdisk -d /dev/sda > sda.pt`, `sgdisk --backup`).
- Hors-bande : console série / iDRAC / IPMI / console cloud / `virsh console`.
- Tester les redémarrages en fenêtre de maintenance ; `systemctl reboot --boot-loader-entry=…`.

## 6. Mettre à jour et compiler un noyau

```bash
apt list --installed 2>/dev/null | grep -E '^linux-image'        # noyaux installés
sudo apt install linux-generic-hwe-24.04                           # noyau plus récent (Ubuntu HWE)
sudo apt autoremove --purge                                        # supprime les anciens (garde le courant + 1)
sudo reboot ; uname -r                                             # vérifier après redémarrage
sudo canonical-livepatch status                                    # correctifs sans reboot (Ubuntu Pro)  ·  kpatch (RHEL)
```

**Compilation depuis les sources** (apprentissage, noyau sur mesure) :

```bash
sudo apt install build-essential libncurses-dev bison flex libssl-dev libelf-dev bc dwarves
wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.x.y.tar.xz && tar xf linux-6.x.y.tar.xz && cd linux-6.x.y
cp /boot/config-$(uname -r) .config && make olddefconfig         # reprend la config courante
make menuconfig                                                   # (optionnel) personnaliser
make -j"$(nproc)"                                                 # compile (longue)
sudo make modules_install && sudo make install                    # modules + noyau + initramfs + GRUB
sudo reboot
```
Modules hors arbre (pilotes propriétaires, VirtualBox, NVIDIA) : **DKMS** (`dkms status`) recompile automatiquement à chaque nouveau noyau. Le noyau est « libre/propre » si `/proc/sys/kernel/tainted` vaut 0.

## 7. Résumé

- Boot : firmware (UEFI/BIOS) → GRUB → noyau + initramfs → systemd → cible.
- GRUB : éditer **`/etc/default/grub`** puis `update-grub` ; paramètres noyau : `rescue.target`, `init=/bin/bash`, `console=`, `nomodeset`.
- Modules : `lsmod`, `modinfo`, `modprobe`, `/etc/modules-load.d`, `/etc/modprobe.d` (options, blacklist), `update-initramfs -u`.
- udev : règles dans `/etc/udev/rules.d`, `udevadm info/monitor/test`, `udevadm verify`.
- `dmesg -T`, `journalctl -k -b -1` pour comprendre ; `kdump` pour les panics.
- Récupération : mode secours/urgence, `fstab`, chroot depuis un Live USB, mot de passe root (`init=/bin/bash`), `grub-install`.
- Sécurité physique : LUKS + mot de passe GRUB/Secure Boot.

## 8. Quiz

1. Quel est le rôle de l'initramfs ?
2. Pourquoi ne faut-il pas éditer `/boot/grub/grub.cfg` directement ?
3. Comment empêcher le chargement automatique du module `pcspkr` ?
4. Un `fstab` erroné vous plonge en mode d'urgence : décrivez la correction.
5. Comment réinitialiser le mot de passe root sur Ubuntu avec accès console ?
6. À quoi sert `udevadm info -a -n /dev/sdb` ?
7. Où trouver les erreurs du noyau survenues avant le dernier redémarrage ?
8. Quelle protection rend la procédure de contournement du mot de passe root inutile pour l'attaquant ?

<details><summary>Réponses</summary>

1. Mini-système en RAM chargeant les pilotes nécessaires (stockage, RAID, LVM, LUKS) pour monter la vraie racine.
2. Il est généré par `update-grub`/`grub2-mkconfig` à partir de `/etc/default/grub` et `/etc/grub.d` ; vos modifications seraient écrasées.
3. `blacklist pcspkr` dans `/etc/modprobe.d/*.conf` (et `install pcspkr /bin/false` pour interdire tout chargement), puis `update-initramfs -u`.
4. `journalctl -xb` pour repérer la ligne ; `mount -o remount,rw /` ; corriger `/etc/fstab` (ou `nofail`) ; `systemctl daemon-reload` ; `mount -a` ; redémarrer.
5. GRUB `e` → ajouter `rw init=/bin/bash` → Ctrl+X → `passwd root` → `exec /sbin/init` (reboot).
6. À lister les attributs (vendeur, produit, série…) et leurs parents, pour écrire des règles `ATTRS{…}`/`ATTR{…}`.
7. `journalctl -k -b -1` (journal persistant) ou `/var/crash` et `kdump`.
8. Le chiffrement intégral du disque (LUKS) avec un mot de passe, accompagné de Secure Boot/mot de passe GRUB et de la sécurité physique.
</details>

➡️ **Labo** : [LAB.md](LAB.md) · **Démo** : `./lab demo 21` · **Suivant** : [22 — Automatisation et infrastructure as code](../22-automatisation-iac/README.md)
