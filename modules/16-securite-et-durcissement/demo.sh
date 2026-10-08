#!/usr/bin/env bash
# Démo formateur — module 16 (≈ 45 min). Lecture seule sur le système réel ; écritures dans un répertoire temporaire.
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/demo-lib.sh"

demo_title "1. Surface d'attaque : qui écoute ?"
demo_run "ss -tulpn 2>/dev/null | head -8"
demo_run "systemctl list-units --type=service --state=running --no-pager --no-legend 2>/dev/null | head -5 || true"

demo_title "2. Audit des comptes"
demo_run "awk -F: '\$3==0 {print \"UID 0 :\", \$1}' /etc/passwd"
demo_run "awk -F: '\$3<1000 && \$3!=0 && \$7!~/(nologin|false|sync|shutdown|halt)\$/ {print \"shell réel (système):\", \$1, \$7}' /etc/passwd | head -5; true"
demo_run "[ -r /etc/shadow ] && awk -F: '\$2==\"\" {print \"SANS MOT DE PASSE:\", \$1}' /etc/shadow; echo '(aucun résultat = bon signe)'"
demo_run "getent group sudo adm docker wheel 2>/dev/null"
demo_run "grep -rhE 'NOPASSWD' /etc/sudoers /etc/sudoers.d 2>/dev/null; echo '--fin NOPASSWD--'"

demo_title "3. Fichiers dangereux"
demo_run "find /usr/bin /usr/sbin /bin -xdev -perm -4000 -type f 2>/dev/null | head -8"
demo_run "find /etc /usr -xdev -type f -perm -0002 2>/dev/null | head -3; echo '--world-writable sous /etc,/usr--'"
demo_run "ls -ld /tmp /var/tmp /dev/shm"

demo_title "4. Reproduire un défaut puis le corriger (umask, chmod)"
demo_run "mkdir srv && touch srv/config.php && chmod 666 srv/config.php && find srv -perm -0002"
demo_run "chmod 640 srv/config.php && find srv -perm -0002 | wc -l"

demo_title "5. Pare-feu nftables : valider AVANT d'appliquer"
demo_run "cat > fw.nft <<'EOF'
table inet filtre {
  chain input {
    type filter hook input priority 0; policy drop;
    ct state established,related accept
    iif \"lo\" accept
    tcp dport { 22, 80, 443 } accept
  }
}
EOF
nft -c -f fw.nft && echo 'syntaxe OK' || echo '(nft -c indisponible ici)'"
demo_run "sed 's/policy drop/policy dropp/' fw.nft > casse.nft; nft -c -f casse.nft 2>&1 | head -3 || true"
demo_show "sudo nft -f /etc/nftables.conf && sudo nft list ruleset"

demo_title "6. sysctl : lire et comparer"
demo_run "sysctl kernel.randomize_va_space kernel.kptr_restrict net.ipv4.tcp_syncookies net.ipv4.conf.all.rp_filter fs.protected_symlinks 2>/dev/null"
demo_run "printf 'net.ipv4.tcp_syncookies = 1\\nkernel.kptr_restrict = 2\\n' > 99-test.conf; cat 99-test.conf"
demo_show "sudo cp 99-test.conf /etc/sysctl.d/ && sudo sysctl --system"

demo_title "7. MAC : SELinux / AppArmor"
demo_run "(command -v getenforce >/dev/null && getenforce) || (command -v aa-status >/dev/null && aa-status --enabled && echo 'AppArmor actif') || echo 'ni SELinux ni AppArmor actifs dans ce conteneur'"
demo_show "sudo ausearch -m AVC -ts recent   |   sudo restorecon -Rv /srv/site   |   sudo aa-complain /usr/sbin/nginx"

demo_title "8. Mots de passe : politique"
demo_run "grep -vE '^\\s*(#|\$)' /etc/login.defs | grep -E 'PASS_(MAX|MIN|WARN)_DAYS|UMASK|ENCRYPT_METHOD'"
demo_run "grep -Ev '^\\s*(#|\$)' /etc/security/pwquality.conf 2>/dev/null | head -3; true"
demo_end
