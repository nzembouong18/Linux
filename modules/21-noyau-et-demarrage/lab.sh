#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/lib.sh"
LAB_ID=21

lab_setup() {
  cd "$LAB_DIR" || return 1
  rm -rf grub etc ./*.txt boot.log
  mkdir -p grub
  cat > grub/default <<'EOF'
# If you change this file, run 'update-grub' afterwards to update /boot/grub/grub.cfg.
GRUB_DEFAULT=0
GRUB_TIMEOUT_STYLE=hidden
GRUB_TIMEOUT=0
GRUB_DISTRIBUTOR=`lsb_release -i -s 2> /dev/null || echo Debian`
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"
GRUB_CMDLINE_LINUX=""
#GRUB_DISABLE_OS_PROBER=true
EOF
  cat > boot.log <<'EOF'
[    0.000000] Linux version 6.8.0-45-generic (buildd@lcy02-amd64-103) (x86_64-linux-gnu-gcc-13 (Ubuntu 13.2.0-23ubuntu4) 13.2.0) #45-Ubuntu SMP PREEMPT_DYNAMIC
[    0.000000] Command line: BOOT_IMAGE=/vmlinuz-6.8.0-45-generic root=UUID=2c1b6d8e-1111-4a2b-9c3d-aaaabbbbcccc ro quiet splash
[    0.412000] x2apic: enabled by BIOS
[    1.204113] usb 1-1: device descriptor read/64, error -71
[    1.804200] usb 1-1: new high-speed USB device number 3 using xhci_hcd
[    2.511002] EXT4-fs (sda2): mounted filesystem with ordered data mode. Quota mode: none.
[    3.102003] ata2.00: exception Emask 0x0 SAct 0x0 SErr 0x0 action 0x0
[    3.102009] ata2.00: failed command: READ FPDMA QUEUED
[    4.250010] systemd[1]: Started Journal Service.
[    5.330012] EXT4-fs error (device sdb1): ext4_find_entry:1455: inode #2: comm ls: reading directory lblock 0
[    5.330020] EXT4-fs (sdb1): Remounting filesystem read-only
[    7.001234] systemd[1]: Failed to start Network Manager.
[    7.001300] systemd[1]: Dependency failed for Network Manager Wait Online.
[    9.600001] eth0: link up, 1000Mbps, full-duplex
[   12.004455] Out of memory: Killed process 4242 (java) total-vm:8123456kB, anon-rss:7000000kB, file-rss:0kB, shmem-rss:0kB
[   12.100000] oom_reaper: reaped process 4242 (java), now anon-rss:0kB, file-rss:0kB, shmem-rss:0kB
[   20.500000] audit: type=1400 audit(1710000000.123:77): apparmor="DENIED" operation="open" profile="/usr/sbin/nginx" name="/etc/secret" pid=900 comm="nginx" requested_mask="r" denied_mask="r" fsuid=33 ouid=0
[   25.000000] IPv6: ADDRCONF(NETDEV_CHANGE): eth0: link becomes ready
EOF
}

# --- helpers
kv() { grep -E "^$2=" "$1" 2>/dev/null | head -1 | cut -d= -f2-; }
gv() { grep -E "^$1=" grub/default 2>/dev/null | tail -1 | cut -d= -f2-; }

lab_check() {
  cd "$LAB_DIR" || return 1
  # ---- A
  local f=systeme.txt nbm bm
  nbm=$(wc -l < /proc/modules 2>/dev/null || echo 0); nbm=${nbm// /}
  bm=BIOS; [[ -d /sys/firmware/efi ]] && bm=UEFI
  assert_eq "A KERNEL"     "$(uname -r)" "$(kv $f KERNEL)"
  assert_eq "A ARCH"       "$(uname -m)" "$(kv $f ARCH)"
  assert_eq "A PAGESIZE"   "$(getconf PAGESIZE)" "$(kv $f PAGESIZE)"
  assert_eq "A PID_MAX"    "$(sysctl -n kernel.pid_max 2>/dev/null || cat /proc/sys/kernel/pid_max)" "$(kv $f PID_MAX)"
  assert_eq "A NB_MODULES" "$nbm" "$(kv $f NB_MODULES)"
  assert_eq "A BOOT_MODE"  "$bm" "$(kv $f BOOT_MODE)"
  # ---- B
  assert_eq "B GRUB_TIMEOUT_STYLE" menu "$(gv GRUB_TIMEOUT_STYLE)"
  assert_eq "B GRUB_TIMEOUT" 5 "$(gv GRUB_TIMEOUT)"
  assert_eq "B GRUB_CMDLINE_LINUX_DEFAULT" '"console=tty0 console=ttyS0,115200n8"' "$(gv GRUB_CMDLINE_LINUX_DEFAULT)"
  assert_eq "B GRUB_CMDLINE_LINUX" '"net.ifnames=0 biosdevname=0"' "$(gv GRUB_CMDLINE_LINUX)"
  assert_eq "B GRUB_DISABLE_OS_PROBER actif" true "$(gv GRUB_DISABLE_OS_PROBER)"
  assert_eq "B GRUB_TERMINAL" '"console serial"' "$(gv GRUB_TERMINAL)"
  assert_eq "B GRUB_SERIAL_COMMAND" '"serial --speed=115200"' "$(gv GRUB_SERIAL_COMMAND)"
  assert "B GRUB_TIMEOUT_STYLE défini une seule fois" bash -c "[[ \$(grep -c '^GRUB_TIMEOUT_STYLE=' grub/default) -eq 1 ]]"
  # ---- C
  assert "C modules-load.d : br_netfilter et overlay" bash -c "grep -qx br_netfilter etc/modules-load.d/lab.conf && grep -qx overlay etc/modules-load.d/lab.conf"
  assert "C modprobe.d : blacklist pcspkr" grep -Eq '^blacklist[[:space:]]+pcspkr[[:space:]]*$' etc/modprobe.d/lab.conf
  assert "C modprobe.d : install pcspkr /bin/false" grep -Eq '^install[[:space:]]+pcspkr[[:space:]]+/bin/(false|true)[[:space:]]*$' etc/modprobe.d/lab.conf
  assert "C modprobe.d : options loop max_loop=16" grep -Eq '^options[[:space:]]+loop[[:space:]]+max_loop=16[[:space:]]*$' etc/modprobe.d/lab.conf
  # ---- D
  local r=etc/udev/rules.d/99-cle-lab.rules
  assert_grep "D règle SUBSYSTEM==\"block\"" 'SUBSYSTEM=="block"' $r
  assert_grep "D ID_VENDOR_ID 0951" 'ENV\{ID_VENDOR_ID\}=="0951"' $r
  assert_grep "D ID_MODEL_ID 1666" 'ENV\{ID_MODEL_ID\}=="1666"' $r
  assert_grep "D SYMLINK+=\"clef-lab\"" 'SYMLINK\+="clef-lab"' $r
  assert_grep "D GROUP=\"plugdev\"" 'GROUP="plugdev"' $r
  assert_grep "D MODE=\"0660\"" 'MODE="0660"' $r
  if udevadm verify --help >/dev/null 2>&1; then
    assert "D udevadm verify : syntaxe valide" udevadm verify "$r"
  else
    skip "D udevadm verify (udevadm trop ancien)"
  fi
  # ---- E
  local a=analyse.txt
  assert_eq "E KERNEL_BOOT" "6.8.0-45-generic" "$(kv $a KERNEL_BOOT)"
  assert_eq "E DISQUE_EN_ERREUR" sdb1 "$(kv $a DISQUE_EN_ERREUR)"
  assert_eq "E PROCESSUS_TUE" java "$(kv $a PROCESSUS_TUE)"
  assert_eq "E PID_TUE" 4242 "$(kv $a PID_TUE)"
  assert_eq "E UNITE_ECHEC" "Network Manager" "$(kv $a UNITE_ECHEC)"
  assert_eq "E PROFIL_APPARMOR" /usr/sbin/nginx "$(kv $a PROFIL_APPARMOR)"
  assert_eq "E NB_LIGNES_ANOMALIE" "$(grep -c -i -E 'error|failed|denied|out of memory' boot.log)" "$(kv $a NB_LIGNES_ANOMALIE)"
  # ---- F
  local q=reponses.txt
  assert "F PARAM_SHELL_ROOT" bash -c "[[ \$(grep '^PARAM_SHELL_ROOT=' $q | cut -d= -f2-) == init=/bin/bash ]]"
  assert "F PARAM_SECOURS" bash -c "grep '^PARAM_SECOURS=' $q | cut -d= -f2- | grep -Eqx 'systemd.unit=rescue.target|single|1'"
  assert "F CMD_GRUB_DEBIAN" bash -c "grep '^CMD_GRUB_DEBIAN=' $q | cut -d= -f2- | grep -Eq '^(sudo )?(update-grub|grub-mkconfig -o /boot/grub/grub.cfg)\$'"
  assert "F CMD_GRUB_RHEL" bash -c "grep '^CMD_GRUB_RHEL=' $q | cut -d= -f2- | grep -Eq 'grub2-mkconfig'"
  assert "F CMD_INITRAMFS" bash -c "grep '^CMD_INITRAMFS=' $q | cut -d= -f2- | grep -Eq '^(sudo )?update-initramfs -u( -k all)?\$'"
  assert "F FICHIER_GRUB" bash -c "[[ \$(grep '^FICHIER_GRUB=' $q | cut -d= -f2-) == /etc/default/grub ]]"
}

lab_solve() {
  cd "$LAB_DIR" || return 1
  { echo "KERNEL=$(uname -r)"; echo "ARCH=$(uname -m)"; echo "PAGESIZE=$(getconf PAGESIZE)"
    echo "PID_MAX=$(sysctl -n kernel.pid_max 2>/dev/null || cat /proc/sys/kernel/pid_max)"
    echo "NB_MODULES=$(wc -l < /proc/modules 2>/dev/null || echo 0)"
    echo "BOOT_MODE=$([ -d /sys/firmware/efi ] && echo UEFI || echo BIOS)"; } | sed 's/= */=/' > systeme.txt
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
}

lab_main "$@"
