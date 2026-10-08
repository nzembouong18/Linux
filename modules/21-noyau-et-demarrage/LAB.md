# Labo 21 — Noyau, GRUB, modules, udev et analyse d'un démarrage

> **Durée** : 3 h · **Difficulté** : ⭐⭐⭐ · **Prérequis** : module 21 · aucun droit root requis (on travaille sur des **copies** de fichiers de configuration)

## Contexte

Un serveur vient de planter puis de redémarrer. Vous devez : relever l'identité du noyau, préparer la configuration de GRUB pour un accès console série, définir les modules à charger/interdire, écrire une règle udev pour une clé USB d'administration et analyser un extrait de `dmesg` pour retrouver la cause du plantage.

## Mise en place

```bash
./lab setup 21
cd ~/labs/21 && ls -R
```

## Partie A — Identité du noyau (`systeme.txt`)

Écrivez `KLÉ=valeur` pour la machine **sur laquelle vous travaillez** :

| Clé | Valeur |
|-----|--------|
| `KERNEL` | version du noyau en cours (`uname -r`) |
| `ARCH` | architecture (`uname -m`) |
| `PAGESIZE` | taille de page mémoire en octets (`getconf PAGESIZE`) |
| `PID_MAX` | valeur de `kernel.pid_max` |
| `NB_MODULES` | nombre de modules noyau chargés (`0` si aucun / non disponible) |
| `BOOT_MODE` | `UEFI` si `/sys/firmware/efi` existe, sinon `BIOS` |

## Partie B — Configuration de GRUB (`grub/default`)

Éditez la **copie** `grub/default` de `/etc/default/grub` pour :
- `GRUB_TIMEOUT_STYLE=menu` ; `GRUB_TIMEOUT=5` ;
- `GRUB_CMDLINE_LINUX_DEFAULT="console=tty0 console=ttyS0,115200n8"` (plus de `quiet splash`) ;
- `GRUB_CMDLINE_LINUX="net.ifnames=0 biosdevname=0"` ;
- `GRUB_DISABLE_OS_PROBER=true` (la ligne est commentée : activez-la) ;
- ajoutez `GRUB_TERMINAL="console serial"` et `GRUB_SERIAL_COMMAND="serial --speed=115200"`.

## Partie C — Modules (`modprobe.d/` et `modules-load.d/`)

Créez dans `etc/` (arborescence de travail) :
- `etc/modules-load.d/lab.conf` : charger au démarrage `br_netfilter` et `overlay` (un par ligne) ;
- `etc/modprobe.d/lab.conf` : `blacklist pcspkr`, `install pcspkr /bin/false`, et `options loop max_loop=16`.

## Partie D — udev (`etc/udev/rules.d/99-cle-lab.rules`)

Une règle `SUBSYSTEM=="block"` pour la clé d'administration (`ID_VENDOR_ID=0951`, `ID_MODEL_ID=1666`) qui crée le lien `/dev/clef-lab`, avec `GROUP="plugdev"` et `MODE="0660"`.

## Partie E — Analyse de `boot.log` (extrait de `dmesg`) → `analyse.txt`

| Clé | Contenu |
|-----|---------|
| `KERNEL_BOOT` | version du noyau qui a démarré (ligne `Linux version`) |
| `DISQUE_EN_ERREUR` | périphérique cité dans l'erreur `EXT4-fs error` |
| `PROCESSUS_TUE` | nom du processus tué par le OOM killer |
| `PID_TUE` | son PID |
| `UNITE_ECHEC` | description de l'unité systemd en échec (ligne `Failed to start …`, sans le point final) |
| `PROFIL_APPARMOR` | profil AppArmor qui a refusé un accès (`profile="…"`) |
| `NB_LIGNES_ANOMALIE` | nombre de lignes contenant (sans tenir compte de la casse) `error`, `failed`, `denied` ou `out of memory` |

## Partie F — Récupération (`reponses.txt`)

| Clé | Question |
|-----|----------|
| `PARAM_SHELL_ROOT` | paramètre noyau qui lance directement un shell root à la place de systemd |
| `PARAM_SECOURS` | paramètre qui démarre en mode secours (cible systemd) |
| `CMD_GRUB_DEBIAN` | commande qui régénère `grub.cfg` sous Debian/Ubuntu |
| `CMD_GRUB_RHEL` | commande équivalente sous RHEL (début de commande suffit) |
| `CMD_INITRAMFS` | commande qui régénère l'initramfs sous Debian/Ubuntu |
| `FICHIER_GRUB` | fichier **à éditer** pour changer la configuration de GRUB |

## Validation

```bash
./lab check 21
```

<details><summary>💡 Indices</summary>

- `sysctl -n kernel.pid_max` ; `wc -l < /proc/modules`.
- `sed -i` pour changer les lignes de `grub/default` ; pensez à retirer le `#` devant `GRUB_DISABLE_OS_PROBER`.
- `grep -m1 'Linux version' boot.log` ; `grep -c -i -E 'error|failed|denied|out of memory' boot.log`.
- `udevadm verify etc/udev/rules.d/99-cle-lab.rules` (si disponible).
</details>

<details><summary>✅ Solution</summary>

```bash
cd ~/labs/21
{ echo "KERNEL=$(uname -r)"; echo "ARCH=$(uname -m)"; echo "PAGESIZE=$(getconf PAGESIZE)"
  echo "PID_MAX=$(sysctl -n kernel.pid_max)"; echo "NB_MODULES=$(wc -l < /proc/modules 2>/dev/null || echo 0)"
  echo "BOOT_MODE=$([ -d /sys/firmware/efi ] && echo UEFI || echo BIOS)"; } > systeme.txt

cat > grub/default <<'EOF'
GRUB_DEFAULT=0
GRUB_TIMEOUT_STYLE=menu
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR=`lsb_release -i -s 2> /dev/null || echo Debian`
GRUB_CMDLINE_LINUX_DEFAULT="console=tty0 console=ttyS0,115200n8"
GRUB_CMDLINE_LINUX="net.ifnames=0 biosdevname=0"
GRUB_DISABLE_OS_PROBER=true
GRUB_TERMINAL="console serial"
GRUB_SERIAL_COMMAND="serial --speed=115200"
EOF

mkdir -p etc/modules-load.d etc/modprobe.d etc/udev/rules.d
printf 'br_netfilter\noverlay\n' > etc/modules-load.d/lab.conf
printf 'blacklist pcspkr\ninstall pcspkr /bin/false\noptions loop max_loop=16\n' > etc/modprobe.d/lab.conf
cat > etc/udev/rules.d/99-cle-lab.rules <<'EOF'
SUBSYSTEM=="block", ENV{ID_VENDOR_ID}=="0951", ENV{ID_MODEL_ID}=="1666", SYMLINK+="clef-lab", GROUP="plugdev", MODE="0660"
EOF

cat > analyse.txt <<'EOF'
KERNEL_BOOT=6.8.0-45-generic
DISQUE_EN_ERREUR=sdb1
PROCESSUS_TUE=java
PID_TUE=4242
UNITE_ECHEC=Network Manager
PROFIL_APPARMOR=/usr/sbin/nginx
EOF
echo "NB_LIGNES_ANOMALIE=$(grep -c -i -E 'error|failed|denied|out of memory' boot.log)" >> analyse.txt

cat > reponses.txt <<'EOF'
PARAM_SHELL_ROOT=init=/bin/bash
PARAM_SECOURS=systemd.unit=rescue.target
CMD_GRUB_DEBIAN=update-grub
CMD_GRUB_RHEL=grub2-mkconfig -o /boot/grub2/grub.cfg
CMD_INITRAMFS=update-initramfs -u
FICHIER_GRUB=/etc/default/grub
EOF
```
</details>

## Pour aller plus loin

- Sur une VM : modifiez réellement `/etc/default/grub`, lancez `update-grub` et vérifiez `grep ttyS0 /boot/grub/grub.cfg`.
- Provoquez volontairement une erreur de `fstab` sur une VM jetable et réparez-la depuis le mode d'urgence.
- Chargez/déchargez `dummy` (`modprobe dummy numdummies=2` puis `ip link`) et observez `lsmod`/`dmesg`.
- Écrivez un script qui compare `journalctl -k -b -1` et `-b 0` pour détecter les nouvelles erreurs.

## Nettoyage

```bash
./lab reset 21
```
