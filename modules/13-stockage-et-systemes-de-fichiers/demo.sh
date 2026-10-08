#!/usr/bin/env bash
# Démo formateur — module 13 (≈ 35 min). Travaille sur des images : aucun vrai disque touché.
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/demo-lib.sh"

demo_title "Inventaire des périphériques"
demo_run "lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS 2>/dev/null | head -8"
demo_run "df -hT -x tmpfs -x devtmpfs -x overlay 2>/dev/null | head -5"
demo_run "findmnt -t ext4,xfs,btrfs 2>/dev/null | head -5"
demo_run "df -i / | tail -1"

demo_title "Fabriquer un « disque » de 32 MiB et le formater"
demo_run "truncate -s 32M disque.img && ls -ls disque.img"
demo_say "ls -s montre 0 bloc réellement alloué : fichier sparse."
demo_run "mkfs.ext4 -q -L DEMO disque.img && ls -ls disque.img"
demo_run "blkid -p disque.img"
demo_run "dumpe2fs -h disque.img 2>/dev/null | grep -E 'volume name|Block size|Block count|Reserved block|Inode count|features' | cut -c1-90"
demo_run "tune2fs -m 1 disque.img | tail -1"

if [[ $EUID -eq 0 ]] && losetup -f >/dev/null 2>&1; then
  demo_title "Monter, écrire, options, démonter"
  demo_run "mkdir mnt && mount -o loop,noexec,nosuid disque.img mnt && findmnt -no SOURCE,FSTYPE,OPTIONS mnt | cut -c1-80"
  demo_run "echo 'bonjour' > mnt/hello.txt; printf '#!/bin/sh\\necho exec\\n' > mnt/prog.sh; chmod +x mnt/prog.sh; ls -l mnt"
  demo_run "mnt/prog.sh 2>&1 | head -1"
  demo_say "noexec interdit l'exécution depuis ce volume."
  demo_run "df -h mnt | tail -1"
  demo_run "cd /tmp && umount '$DEMO_DIR/mnt' && cd '$DEMO_DIR' && mountpoint mnt; true"
  demo_run "mount -o loop,ro disque.img mnt && cat mnt/hello.txt && umount mnt"

  demo_title "Vérification (fsck) d'un système démonté"
  demo_run "e2fsck -fn disque.img | tail -2"

  demo_title "LVM : PV → VG (sur 2 images loop)"
  demo_run "truncate -s 64M pv1.img pv2.img; L1=\$(losetup -f --show pv1.img); L2=\$(losetup -f --show pv2.img); echo \$L1 \$L2 > loops"
  demo_run "pvcreate -q -y \$(cat loops) >/dev/null && vgcreate -q demovg \$(cat loops) >/dev/null; pvs --units m 2>/dev/null | grep -E 'PV|loop'; vgs --units m demovg"
  if dmsetup targets 2>/dev/null | grep -qw linear; then
    demo_run "lvcreate -q -y -L 40M -n web demovg >/dev/null && mkfs.ext4 -q /dev/demovg/web && lvs demovg"
    demo_run "lvextend -q -r -L +20M /dev/demovg/web >/dev/null; lvs --units m demovg"
  else
    demo_say "(noyau sans device-mapper : on montre les commandes lvcreate/lvextend sans les exécuter)"
    demo_show "lvcreate -L 40M -n web demovg && lvextend -r -L +20M /dev/demovg/web"
  fi
  demo_run "vgremove -ff -y demovg >/dev/null 2>&1; for d in \$(cat loops); do pvremove -ff -y \$d >/dev/null 2>&1; losetup -d \$d; done; echo nettoyé"
else
  demo_say "(pas de root/loop : montrer mount, fstab, LVM en mode commentaire)"
fi

demo_title "fstab : lire et valider"
demo_run "grep -v '^#' /etc/fstab | head -5"
demo_run "findmnt --verify 2>&1 | tail -3"
demo_show "echo 'UUID=xxxx /data ext4 defaults,nofail 0 2' | sudo tee -a /etc/fstab && sudo systemctl daemon-reload && sudo mount -a"
demo_end
