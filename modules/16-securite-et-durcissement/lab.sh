#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/lib.sh"
LAB_ID=16
LAB_REQUIRES=(cmd:find cmd:awk)

lab_setup() {
  cd "$LAB_DIR" || return 1
  rm -rf srv audit.txt pare-feu.nft 99-durcissement.conf
  local s=srv
  mkdir -p $s/etc/ssh $s/etc/sudoers.d $s/etc/cron.d $s/usr/bin $s/usr/local/bin $s/var/www/uploads $s/home/alice/.ssh $s/tmp
  cat > $s/etc/passwd <<'EOF'
root:x:0:0:root:/root:/bin/bash
toor:x:0:0:backdoor:/root:/bin/bash
daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin
sync:x:4:65534:sync:/bin:/bin/sync
svc:x:998:998:service:/var/lib/svc:/bin/bash
www-data:x:33:33:www-data:/var/www:/usr/sbin/nologin
alice:x:1000:1000:Alice:/home/alice:/bin/bash
bob:x:1001:1001:Bob:/home/bob:/bin/bash
EOF
  cat > $s/etc/shadow <<'EOF'
root:$6$salt$Zr0FJu2xV9d6hRoot:19000:0:99999:7:::
toor:$6$salt$AAAAAAAAAAAAAAAAAAAAAA:19000:0:99999:7:::
daemon:*:19000:0:99999:7:::
sync:*:19000:0:99999:7:::
svc:!:19000:0:99999:7:::
www-data:*:19000:0:99999:7:::
alice:$6$salt$Nk3Kq8Alice:19000:0:90:7:::
bob::19000:0:99999:7:::
EOF
  chmod 640 $s/etc/shadow
  cat > $s/etc/ssh/sshd_config <<'EOF'
Port 22
PermitRootLogin yes
PasswordAuthentication yes
PermitEmptyPasswords yes
X11Forwarding yes
MaxAuthTries 10
UsePAM yes
Subsystem sftp /usr/lib/openssh/sftp-server
EOF
  cat > $s/etc/sudoers.d/dev <<'EOF'
%dev ALL=(ALL) NOPASSWD: ALL
EOF
  chmod 640 $s/etc/sudoers.d/dev
  printf '*/5 * * * * root /usr/local/bin/outil --sauvegarde\n' > $s/etc/cron.d/backup; chmod 666 $s/etc/cron.d/backup
  printf '# <fs> <point> <type> <options> <dump> <pass>\nUUID=1111-2222 / ext4 errors=remount-ro 0 1\ntmpfs /tmp tmpfs defaults 0 0\n' > $s/etc/fstab
  printf '#!/bin/sh\necho outil\n' > $s/usr/local/bin/outil; chmod 4755 $s/usr/local/bin/outil
  printf '#!/bin/sh\necho passwd\n' > $s/usr/bin/legit-passwd; chmod 4755 $s/usr/bin/legit-passwd
  echo '<?php $db_password = "S3cr3t!";' > $s/var/www/config.php; chmod 666 $s/var/www/config.php
  chmod 777 $s/var/www/uploads
  chmod 1777 $s/tmp
  chmod 700 $s/home/alice/.ssh
  printf -- '-----BEGIN OPENSSH PRIVATE KEY-----\nfaux-contenu\n-----END OPENSSH PRIVATE KEY-----\n' > $s/home/alice/.ssh/id_rsa; chmod 644 $s/home/alice/.ssh/id_rsa
  echo "ssh-ed25519 AAAA faux alice@pc" > $s/home/alice/.ssh/authorized_keys; chmod 600 $s/home/alice/.ssh/authorized_keys
}

sorted_list() { tr ',' '\n' <<<"$1" | grep . | sort | paste -sd,; }
nft_usable() { local t; t=$(mktemp); echo 'table inet labtest { }' > "$t"; as_root nft -c -f "$t" >/dev/null 2>&1; local rc=$?; rm -f "$t"; return $rc; }
sysval() { grep -E "^[[:space:]]*$1[[:space:]]*=" 99-durcissement.conf 2>/dev/null | tail -1 | sed -E 's/^[^=]*=[[:space:]]*//; s/[[:space:]]+$//'; }

lab_check() {
  cd "$LAB_DIR" || return 1
  local a; a() { grep -E "^$1=" audit.txt 2>/dev/null | head -1 | cut -d= -f2-; }
  # --- A : audit de l'état initial (valeurs de référence figées)
  assert_eq "A UID0" "root,toor" "$(sorted_list "$(a UID0)")"
  assert_eq "A SANS_MDP" "bob" "$(sorted_list "$(a SANS_MDP)")"
  assert_eq "A SHELL_SERVICE" "svc" "$(sorted_list "$(a SHELL_SERVICE)")"
  assert_eq "A SUID" "usr/bin/legit-passwd,usr/local/bin/outil" "$(sorted_list "$(a SUID)")"
  assert_eq "A WORLD_WRITABLE" "etc/cron.d/backup,var/www/config.php,var/www/uploads" "$(sorted_list "$(a WORLD_WRITABLE)")"
  assert_eq "A SSH_PROBLEMES" "5" "$(a SSH_PROBLEMES)"
  assert_eq "A NOPASSWD" "%dev" "$(a NOPASSWD)"
  assert_eq "A CLE_EXPOSEE" "home/alice/.ssh/id_rsa" "$(a CLE_EXPOSEE)"

  # --- B : corrections
  local s=srv
  assert_mode "B1 clé privée en 600" 600 $s/home/alice/.ssh/id_rsa
  assert "B2 outil sans setuid" bash -c "! find $s/usr/local/bin/outil -perm -4000 | grep -q ."
  assert "B2 legit-passwd conserve son setuid" find $s/usr/bin/legit-passwd -perm -4000
  assert "B3 plus aucun fichier world-writable (hors sticky)" bash -c "[[ -z \$(find $s ! -type l -perm -0002 ! -perm -1000) ]]"
  assert "B3 tmp/ garde son sticky bit" find $s/tmp -perm -1000
  assert "B3 config.php toujours en place" test -f $s/var/www/config.php
  local ssh=$s/etc/ssh/sshd_config
  assert_grep "B4 PermitRootLogin no/prohibit-password" '^PermitRootLogin[[:space:]]+(no|prohibit-password)' $ssh
  assert_grep "B4 PasswordAuthentication no" '^PasswordAuthentication[[:space:]]+no' $ssh
  assert_grep "B4 PermitEmptyPasswords no" '^PermitEmptyPasswords[[:space:]]+no' $ssh
  assert_grep "B4 X11Forwarding no" '^X11Forwarding[[:space:]]+no' $ssh
  assert_grep "B4 MaxAuthTries ≤ 4" '^MaxAuthTries[[:space:]]+[1-4][[:space:]]*$' $ssh
  assert_grep "B4 autres lignes conservées (UsePAM, Subsystem)" '^UsePAM yes' $ssh
  assert "B5 toor supprimé (passwd et shadow)" bash -c "! grep -q '^toor:' $s/etc/passwd $s/etc/shadow"
  assert "B5 bob verrouillé (champ mot de passe non vide)" bash -c "awk -F: '\$1==\"bob\" && \$2 != \"\" {f=1} END{exit !f}' $s/etc/shadow"
  assert "B5 svc en nologin" bash -c "grep '^svc:' $s/etc/passwd | grep -q ':/usr/sbin/nologin\$'"
  assert "B5 alice et root intacts" bash -c "grep -q '^alice:x:1000' $s/etc/passwd && grep -q '^root:x:0:0' $s/etc/passwd"
  assert "B6 plus de NOPASSWD dans sudoers.d" bash -c "! grep -rq NOPASSWD $s/etc/sudoers.d"
  assert "B6 %dev limité à systemctl restart nginx" bash -c "grep -Eq '^%dev[[:space:]]+ALL=\(root\)[[:space:]]+/usr/bin/systemctl restart nginx[[:space:]]*\$' $s/etc/sudoers.d/dev"
  assert "B7 /tmp en noexec,nosuid,nodev" bash -c "awk '\$2==\"/tmp\" && \$4 ~ /noexec/ && \$4 ~ /nosuid/ && \$4 ~ /nodev/ {f=1} END{exit !f}' $s/etc/fstab"

  # --- C : pare-feu
  local f=pare-feu.nft
  assert_grep "C8 chaîne input en policy drop" 'hook input[^}]*policy drop' $f
  assert_grep "C8 established,related" 'ct state[^;]*established[^;]*related[^;]*accept|ct state[^;]*related[^;]*established[^;]*accept' $f
  assert_grep "C8 loopback" '(iif|iifname)[[:space:]]+"?lo"?[[:space:]]+accept' $f
  assert_grep "C8 SSH (22)" 'tcp dport[^#\n]*\b22\b' $f
  assert "C8 HTTP et HTTPS (80, 443)" bash -c "grep -Eq 'dport[^#]*\b80\b' $f && grep -Eq 'dport[^#]*\b443\b' $f"
  assert_grep "C8 ping limité (limit rate)" 'echo-request[^#]*limit rate|limit rate[^#]*echo-request' $f
  if nft_usable; then assert "C8 nft -c -f : syntaxe valide" as_root nft -c -f $f; else skip "C8 validation nft -c (nftables inutilisable ici)"; fi
  # --- C : sysctl
  assert_eq "C9 tcp_syncookies" 1 "$(sysval net.ipv4.tcp_syncookies)"
  assert_eq "C9 rp_filter" 1 "$(sysval net.ipv4.conf.all.rp_filter)"
  assert_eq "C9 accept_redirects" 0 "$(sysval net.ipv4.conf.all.accept_redirects)"
  assert_eq "C9 send_redirects" 0 "$(sysval net.ipv4.conf.all.send_redirects)"
  assert_eq "C9 randomize_va_space" 2 "$(sysval kernel.randomize_va_space)"
  local k p; k=$(sysval kernel.kptr_restrict); p=$(sysval kernel.yama.ptrace_scope)
  if [[ "$k" =~ ^[0-9]+$ && $k -ge 1 ]]; then ok "C9 kptr_restrict ≥ 1"; else ko "C9 kptr_restrict ≥ 1 (obtenu '$k')"; fi
  if [[ "$p" =~ ^[0-9]+$ && $p -ge 1 ]]; then ok "C9 ptrace_scope ≥ 1"; else ko "C9 ptrace_scope ≥ 1 (obtenu '$p')"; fi
  assert_eq "C9 protected_symlinks" 1 "$(sysval fs.protected_symlinks)"
  assert_eq "C9 protected_hardlinks" 1 "$(sysval fs.protected_hardlinks)"
}

lab_solve() {
  cd "$LAB_DIR" || return 1
  cat > audit.txt <<'EOF'
UID0=root,toor
SANS_MDP=bob
SHELL_SERVICE=svc
SUID=usr/bin/legit-passwd,usr/local/bin/outil
WORLD_WRITABLE=etc/cron.d/backup,var/www/config.php,var/www/uploads
SSH_PROBLEMES=5
NOPASSWD=%dev
CLE_EXPOSEE=home/alice/.ssh/id_rsa
EOF
  chmod 600 srv/home/alice/.ssh/id_rsa
  chmod u-s srv/usr/local/bin/outil
  chmod 755 srv/var/www/uploads; chmod 640 srv/var/www/config.php; chmod 644 srv/etc/cron.d/backup
  sed -i -e 's/^PermitRootLogin .*/PermitRootLogin no/' -e 's/^PasswordAuthentication .*/PasswordAuthentication no/' \
         -e 's/^PermitEmptyPasswords .*/PermitEmptyPasswords no/' -e 's/^X11Forwarding .*/X11Forwarding no/' \
         -e 's/^MaxAuthTries .*/MaxAuthTries 3/' srv/etc/ssh/sshd_config
  sed -i '/^toor:/d' srv/etc/passwd srv/etc/shadow
  sed -i 's/^bob::/bob:!:/' srv/etc/shadow
  sed -i 's#^\(svc:.*:\)/bin/bash$#\1/usr/sbin/nologin#' srv/etc/passwd
  echo '%dev ALL=(root) /usr/bin/systemctl restart nginx' > srv/etc/sudoers.d/dev
  sed -i 's#^\(tmpfs[[:space:]]\+/tmp[[:space:]]\+tmpfs[[:space:]]\+\)defaults#\1defaults,noexec,nosuid,nodev#' srv/etc/fstab
  cat > pare-feu.nft <<'EOF'
flush ruleset
table inet filtre {
    chain input {
        type filter hook input priority 0; policy drop;
        ct state invalid drop
        ct state established,related accept
        iif "lo" accept
        icmp type echo-request limit rate 5/second accept
        tcp dport 22 accept
        tcp dport { 80, 443 } accept
    }
    chain forward { type filter hook forward priority 0; policy drop; }
    chain output  { type filter hook output  priority 0; policy accept; }
}
EOF
  cat > 99-durcissement.conf <<'EOF'
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
kernel.randomize_va_space = 2
kernel.kptr_restrict = 2
kernel.yama.ptrace_scope = 1
fs.protected_symlinks = 1
fs.protected_hardlinks = 1
EOF
}

lab_main "$@"
