#!/usr/bin/env bash
# Démo formateur — module 21 (≈ 40 min). Lecture seule sur le système.
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/demo-lib.sh"

demo_title "Quel noyau, quel mode de boot ?"
demo_run "uname -r; cat /proc/version | cut -c1-90"
demo_run "[ -d /sys/firmware/efi ] && echo 'UEFI' || echo 'BIOS (ou conteneur/VM sans EFI)'"
demo_run "cat /proc/cmdline 2>/dev/null || echo '(pas de /proc/cmdline dans ce conteneur)'"
demo_run "ps -p 1 -o pid,comm"

demo_title "Modules noyau"
demo_run "lsmod 2>/dev/null | head -5 || echo '(lsmod indisponible)'"
demo_run "wc -l < /proc/modules 2>/dev/null"
demo_run "modinfo -F description loop 2>/dev/null; modinfo -p loop 2>/dev/null | head -3"
demo_run "ls /lib/modules/\$(uname -r) 2>/dev/null | head -4"
demo_run "modprobe -c 2>/dev/null | grep -E '^blacklist' | head -3"
demo_run "ls /etc/modprobe.d /etc/modules-load.d 2>/dev/null"

demo_title "Paramètres du noyau à chaud"
demo_run "sysctl kernel.pid_max vm.swappiness kernel.hostname 2>/dev/null"
demo_run "cat /proc/sys/kernel/tainted"
demo_run "getconf PAGESIZE; getconf _NPROCESSORS_ONLN"

demo_title "Lire un extrait de dmesg : repérer les anomalies"
demo_run "cat > boot.log <<'EOF'
[    1.204113] usb 1-1: device descriptor read/64, error -71
[    5.330012] EXT4-fs error (device sdb1): ext4_find_entry:1455: inode #2: reading directory lblock 0
[    7.001234] systemd[1]: Failed to start Network Manager.
[   12.004455] Out of memory: Killed process 4242 (java) total-vm:8123456kB
[   20.500000] audit: apparmor=\"DENIED\" operation=\"open\" profile=\"/usr/sbin/nginx\" name=\"/etc/secret\"
EOF
grep -n -i -E 'error|failed|denied|out of memory' boot.log | cut -c1-110"
demo_run "grep -o 'Killed process [0-9]* ([a-z]*)' boot.log"
demo_run "dmesg -T --level=err,warn 2>&1 | tail -3"

demo_title "GRUB : modifier une copie et comprendre le flux"
demo_run "printf 'GRUB_TIMEOUT=0\\nGRUB_CMDLINE_LINUX_DEFAULT=\"quiet splash\"\\n#GRUB_DISABLE_OS_PROBER=true\\n' > default"
demo_run "sed -i -e 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=5/' -e 's/quiet splash/console=ttyS0,115200n8/' -e 's/^#GRUB_DISABLE_OS_PROBER/GRUB_DISABLE_OS_PROBER/' default && cat default"
demo_show "sudo cp default /etc/default/grub && sudo update-grub && grep -c ttyS0 /boot/grub/grub.cfg"
demo_show "# Au menu GRUB : touche e → ajouter 'systemd.unit=rescue.target' ou 'rw init=/bin/bash' → Ctrl+X"

demo_title "udev : écrire et valider une règle"
demo_run "echo 'SUBSYSTEM==\"block\", ENV{ID_VENDOR_ID}==\"0951\", ENV{ID_MODEL_ID}==\"1666\", SYMLINK+=\"clef-lab\", GROUP=\"plugdev\", MODE=\"0660\"' > 99-cle.rules; cat 99-cle.rules"
demo_run "udevadm verify 99-cle.rules 2>&1 | tail -2 || true"
demo_run "udevadm info --version 2>/dev/null || udevadm --version"
demo_show "udevadm monitor --udev   |   udevadm info -a -n /dev/sdb   |   sudo udevadm control --reload && sudo udevadm trigger"
demo_end
