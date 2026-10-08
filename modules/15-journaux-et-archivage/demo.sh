#!/usr/bin/env bash
# Démo formateur — module 15 (≈ 30 min)
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/demo-lib.sh"

demo_title "Les journaux sur cette machine"
demo_run "ls /var/log | head -12"
demo_run "journalctl --no-pager -n 3 2>&1 | cut -c1-100 | head -3 || true"
demo_run "logger -t demo-formation 'bonjour depuis logger' ; echo 'message envoyé (visible dans journalctl -t demo-formation / syslog)'"

demo_title "tar : créer, lister, extraire"
demo_run "mkdir -p donnees/docs donnees/cache && echo a > donnees/docs/a.txt && echo b > donnees/docs/b.tmp && echo c > donnees/cache/c.dat && echo cfg > donnees/.config"
demo_run "tar -czf sauv.tgz --exclude='*.tmp' --exclude=cache donnees && tar -tzf sauv.tgz"
demo_run "mkdir restore && tar -xzf sauv.tgz -C restore && diff -r -x '*.tmp' -x cache donnees restore/donnees && echo 'restauration identique'"
demo_run "tar -tzf sauv.tgz | head -2; echo 'et une archive suspecte :'; (cd /tmp && tar -cf \"$DEMO_DIR/piege.tar\" --transform='s#^#../#' -C \"$DEMO_DIR\" donnees/.config 2>/dev/null); tar -tf piege.tar"

demo_title "Compresseurs : taille et temps"
demo_run "for i in \$(seq 1 40000); do echo \"2024-03-12 10:00:\$((i%60)) INFO id=\$i user=u\$((i%37)) status=200\"; done > app.log; ls -l app.log | awk '{print \$5, \$9}'"
demo_run "for c in 'gzip -9' 'bzip2 -9' 'xz -6' 'zstd -19'; do s=\$(date +%s.%N); \$c -kf app.log 2>/dev/null; e=\$(date +%s.%N); printf '%-10s %8d octets  %.2fs\\n' \"\$c\" \"\$(stat -c %s app.log.\$(case \${c%% *} in gzip) echo gz;; bzip2) echo bz2;; xz) echo xz;; zstd) echo zst;; esac))\" \"\$(echo \"\$e - \$s\" | bc)\"; done"
demo_run "zcat app.log.gz | head -1; zgrep -c 'user=u1 ' app.log.gz"

demo_title "Intégrité : sha256sum"
demo_run "sha256sum sauv.tgz > SHA256SUMS && sha256sum -c SHA256SUMS"
demo_run "printf 'x' >> sauv.tgz; sha256sum -c SHA256SUMS 2>&1 | tail -2"

demo_title "Snapshots par liens durs avec rsync --link-dest"
demo_run "mkdir -p src && echo stable > src/a.txt && echo v1 > src/b.txt && seq 1 2000 > src/gros.txt"
demo_run "rsync -a src/ snaps/jour1/ 2>/dev/null || (mkdir -p snaps && rsync -a src/ snaps/jour1/)"
demo_run "echo v2-modifie > src/b.txt; rsync -a --delete --link-dest=\$PWD/snaps/jour1 src/ snaps/jour2/"
demo_run "ls -li snaps/jour1 snaps/jour2 | awk 'NF>8 {print \$1, \$2, \$NF}'"
demo_say "Même numéro d'inode = même données sur disque pour a.txt et gros.txt ; b.txt a un nouvel inode."
demo_run "du -sh snaps/jour1 snaps/jour2 snaps"

demo_title "logrotate en simulation"
demo_run "mkdir -p j && seq 1 100 > j/app.log && printf '%s/j/app.log {\\n  daily\\n  rotate 3\\n  compress\\n  delaycompress\\n  missingok\\n  notifempty\\n  create 0640 \$(id -un) \$(id -gn)\\n}\\n' \"\$PWD\" > rot.conf && chmod 644 rot.conf"
demo_run "logrotate -d -s \$PWD/state rot.conf 2>&1 | grep -E 'rotating pattern|considering'"
demo_run "logrotate -f -s \$PWD/state rot.conf; ls -l j"
demo_run "logrotate -f -s \$PWD/state rot.conf; ls j"
demo_end
