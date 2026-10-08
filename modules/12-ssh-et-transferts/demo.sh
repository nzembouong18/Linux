#!/usr/bin/env bash
# Démo formateur — module 12 (≈ 30 min). Serveur sshd éphémère sur 127.0.0.1, sans toucher /etc/ssh.
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/demo-lib.sh"

for c in ssh ssh-keygen sshd rsync; do
  command -v "$c" >/dev/null || { demo_say "Outil manquant: $c (apt install openssh-client openssh-server rsync) — démo théorique."; exit 0; }
done
[[ $EUID -eq 0 ]] && mkdir -p /run/sshd
ME=$(id -un)

demo_title "Générer une paire de clés ed25519"
demo_run "ssh-keygen -q -t ed25519 -N '' -C 'demo@formation' -f ./id_demo && ls -l id_demo id_demo.pub | awk '{print \$1, \$NF}'"
demo_run "cut -c1-60 id_demo.pub; ssh-keygen -lf id_demo.pub"

demo_title "Un serveur sshd éphémère (clé uniquement)"
demo_run "ssh-keygen -q -t ed25519 -N '' -f ./host_key && cp id_demo.pub authorized_keys && chmod 600 authorized_keys"
PORT=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()')
cat > sshd_demo.conf <<EOF
Port $PORT
ListenAddress 127.0.0.1
HostKey $DEMO_DIR/host_key
PidFile $DEMO_DIR/sshd.pid
AuthorizedKeysFile $DEMO_DIR/authorized_keys
PasswordAuthentication no
UsePAM no
StrictModes no
AllowUsers $ME
Subsystem sftp internal-sftp
EOF
demo_run "/usr/sbin/sshd -t -f sshd_demo.conf && echo 'config valide'"
demo_run "/usr/sbin/sshd -f sshd_demo.conf -E sshd.log && sleep 0.5 && ss -ltn 'sport = :$PORT' | tail -1"
trap 'kill "$(cat "$DEMO_DIR/sshd.pid" 2>/dev/null)" 2>/dev/null; cd /; rm -rf "$DEMO_DIR"' EXIT
cat > cfg <<EOF
Host demo
    HostName 127.0.0.1
    Port $PORT
    User $ME
    IdentityFile $DEMO_DIR/id_demo
    IdentitiesOnly yes
    UserKnownHostsFile $DEMO_DIR/known_hosts
    StrictHostKeyChecking accept-new
EOF

demo_title "Connexion, commande distante, known_hosts"
demo_run "ssh -F cfg demo 'echo connecté en tant que \$(whoami) sur \$(uname -n)'"
demo_run "cut -c1-70 known_hosts"
demo_run "ssh -F cfg demo 'echo \$SSH_CONNECTION'"
demo_say "Sans la clé, le serveur refuse :"
demo_run "ssh -F cfg -o IdentityFile=/dev/null -o BatchMode=yes demo true 2>&1 | tail -1"

demo_title "Transferts : scp et rsync (observer le delta)"
demo_run "mkdir -p src dest && for i in 1 2 3; do seq 1 1000 > src/f\$i.txt; done"
demo_run "rsync -a -e 'ssh -F cfg' src/ demo:\$PWD/dest/ && ls dest"
demo_run "rsync -a --stats -e 'ssh -F cfg' src/ demo:\$PWD/dest/ | grep -E 'files transferred|Number of regular files transferred'"
demo_run "echo changement >> src/f2.txt; rsync -ai -e 'ssh -F cfg' src/ demo:\$PWD/dest/"
demo_run "rm src/f3.txt; rsync -ain --delete -e 'ssh -F cfg' src/ demo:\$PWD/dest/"
demo_say "-n = dry-run : on voit qu'il supprimerait f3.txt sans l'avoir fait."
demo_run "scp -q -F cfg src/f1.txt demo:\$PWD/dest/copie.txt && ls dest"

demo_title "Tunnel -L"
demo_run "mkdir w && echo 'service interne' > w/index.html"
demo_run "python3 -m http.server 18090 --bind 127.0.0.1 --directory w >/dev/null 2>&1 </dev/null & echo \$! > web.pid; sleep 0.7"
demo_run "ssh -F cfg -f -N -L 18091:127.0.0.1:18090 demo; sleep 0.7; curl --noproxy '*' -s http://127.0.0.1:18091/"
demo_run "kill \$(cat web.pid); for p in \$(pgrep -f '^ssh .*-L 18091'); do kill \$p; done; echo tunnel fermé"

demo_title "Durcissement : tester AVANT de recharger"
demo_run "printf 'PermitRootLogin no\\nPasswordAuthentication no\\nBadDirective yes\\n' > test.conf; /usr/sbin/sshd -t -f test.conf 2>&1 | head -2"
demo_end
