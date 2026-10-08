#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/lib.sh"
LAB_ID=12
LAB_REQUIRES=(cmd:sshd cmd:ssh cmd:ssh-keygen cmd:rsync cmd:curl cmd:python3 cmd:ss)

lab_cleanup() {
  local f
  for f in "$LAB_DIR/serveur/sshd.pid" "$LAB_DIR/.webpid"; do
    [[ -f "$f" ]] && kill "$(cat "$f")" 2>/dev/null
  done
  # tunnel éventuel de l'étudiant (motif ancré sur « ssh … -L 28080: »)
  local p; for p in $(pgrep -f '^ssh .*-L ?28080:'); do kill "$p" 2>/dev/null; done
  return 0
}

lab_setup() {
  cd "$LAB_DIR" || return 1
  lab_cleanup
  rm -rf serveur projet rapport.dat id_lab* ssh_config known_hosts *.txt sshd_config.durci
  mkdir -p serveur/depot/projet www projet/sous-dossier
  [[ $EUID -eq 0 ]] && mkdir -p /run/sshd
  # --- fichiers métier
  head -c 20000 /dev/urandom > rapport.dat
  echo "alpha" > projet/a.txt; echo "beta" > projet/b.txt; echo "gamma" > projet/sous-dossier/c.txt
  echo "à supprimer" > serveur/depot/projet/obsolete.txt
  # --- serveur sshd privé
  ssh-keygen -q -t ed25519 -N '' -f serveur/ssh_host_ed25519_key
  : > serveur/authorized_keys; chmod 600 serveur/authorized_keys
  local port; port=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()')
  echo "$port" > serveur/PORT
  cat > serveur/sshd_config <<EOF
Port $port
ListenAddress 127.0.0.1
HostKey $LAB_DIR/serveur/ssh_host_ed25519_key
PidFile $LAB_DIR/serveur/sshd.pid
AuthorizedKeysFile $LAB_DIR/serveur/authorized_keys
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
UsePAM no
# StrictModes désactivé : le serveur de labo vit hors de /etc et de ~ (un parent comme /tmp serait refusé)
StrictModes no
PermitRootLogin prohibit-password
AllowUsers $(id -un)
AllowTcpForwarding yes
Subsystem sftp internal-sftp
LogLevel VERBOSE
EOF
  /usr/sbin/sshd -f "$LAB_DIR/serveur/sshd_config" -E "$LAB_DIR/serveur/sshd.log" || die "sshd n'a pas démarré (voir serveur/sshd.log)"
  # --- petit service web pour le tunnel
  echo "<html><body>BIENVENUE sur le service interne. Jeton: TUNNEL-$(head -c 5 /dev/urandom | od -An -tx1 | tr -d ' \n')</body></html>" > www/index.html
  local wport; wport=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()')
  nohup python3 -m http.server "$wport" --bind 127.0.0.1 --directory "$LAB_DIR/www" >/dev/null 2>&1 </dev/null &
  echo $! > .webpid
  echo "$wport" > .webport
  sleep 0.5
}

lab_check() {
  cd "$LAB_DIR" || return 1
  local me; me=$(id -un)
  local S="ssh -F ssh_config -o BatchMode=yes -o ConnectTimeout=5"
  assert "1. clé privée id_lab (ed25519)" bash -c "head -1 id_lab | grep -q 'BEGIN OPENSSH PRIVATE KEY' && ssh-keygen -lf id_lab.pub | grep -q ED25519"
  assert_mode "1. id_lab en 600" 600 id_lab
  assert "2. clé publique autorisée dans serveur/authorized_keys" bash -c "grep -qF \"\$(cut -d' ' -f1,2 id_lab.pub)\" serveur/authorized_keys"
  assert_mode "2. authorized_keys en 600" 600 serveur/authorized_keys
  assert "3. ssh_config : alias labsrv, port, IdentitiesOnly" bash -c "grep -Eq '^Host +labsrv' ssh_config && grep -Eq \"Port +$(cat serveur/PORT)\" ssh_config && grep -Eqi 'IdentitiesOnly +yes' ssh_config"
  assert "3. connexion 'ssh -F ssh_config labsrv true' réussit" $S labsrv true
  assert_eq "4. distant.txt = uname -n distant" "$(uname -n)" "$(tr -d '\n' < distant.txt 2>/dev/null)"
  assert "5. scp : rapport.dat identique dans serveur/depot" cmp -s rapport.dat serveur/depot/rapport.dat
  assert "6. rsync : projet/ == depot/projet/ (obsolete.txt supprimé)" diff -r projet serveur/depot/projet
  assert "6. obsolete.txt a disparu" test ! -e serveur/depot/projet/obsolete.txt
  local tok; tok=$(grep -o 'TUNNEL-[0-9a-f]*' www/index.html)
  assert_grep "7. tunnel.txt contient le jeton du service interne" "$tok" tunnel.txt
  local d=sshd_config.durci
  assert_grep "8. PermitRootLogin no" '^PermitRootLogin +no' $d
  assert_grep "8. PasswordAuthentication no" '^PasswordAuthentication +no' $d
  assert_grep "8. PubkeyAuthentication yes" '^PubkeyAuthentication +yes' $d
  assert_grep "8. MaxAuthTries 3" '^MaxAuthTries +[1-3]$' $d
  assert_grep "8. X11Forwarding no" '^X11Forwarding +no' $d
  assert_grep "8. AllowUsers $me" "^AllowUsers +.*\\b$me\\b" $d
}

lab_solve() {
  cd "$LAB_DIR" || return 1
  local me; me=$(id -un)
  ssh-keygen -q -t ed25519 -f id_lab -N ''
  cat id_lab.pub >> serveur/authorized_keys; chmod 600 serveur/authorized_keys
  cat > ssh_config <<EOF
Host labsrv
    HostName 127.0.0.1
    Port $(cat serveur/PORT)
    User $me
    IdentityFile $PWD/id_lab
    IdentitiesOnly yes
    UserKnownHostsFile $PWD/known_hosts
    StrictHostKeyChecking accept-new
EOF
  ssh -F ssh_config labsrv 'uname -n' > distant.txt
  scp -q -F ssh_config rapport.dat "labsrv:$PWD/serveur/depot/rapport.dat"
  rsync -a --delete -e 'ssh -F ssh_config' projet/ "labsrv:$PWD/serveur/depot/projet/"
  local web p=""
  for p in $(ss -ltnH | awk '{print $4}' | sed 's/.*://'); do
    curl --noproxy "*" -s -m1 "http://127.0.0.1:$p/" | grep -q BIENVENUE && { web=$p; break; }
  done
  ssh -F ssh_config -f -N -L "28080:127.0.0.1:$web" labsrv
  sleep 1
  curl --noproxy "*" -s http://127.0.0.1:28080/ > tunnel.txt
  cat > sshd_config.durci <<EOF
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
MaxAuthTries 3
X11Forwarding no
AllowUsers $me
EOF
}

lab_main "$@"
