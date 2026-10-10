#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/lib.sh"
LAB_ID=25
LAB_REQUIRES=(cmd:python3 cmd:nginx cmd:ansible-playbook cmd:ansible-vault cmd:systemd-analyze cmd:curl cmd:tar cmd:sha256sum)
MODDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

free_port() { python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()'; }

lab_cleanup() {
  [[ -d "$LAB_DIR" ]] || return 0
  if [[ -f "$LAB_DIR/nginx/logs/nginx.pid" ]]; then kill "$(cat "$LAB_DIR/nginx/logs/nginx.pid")" 2>/dev/null; fi
  [[ -f "$LAB_DIR/.app.pid" ]] && kill "$(cat "$LAB_DIR/.app.pid")" 2>/dev/null
  return 0
}

lab_setup() {
  cd "$LAB_DIR" || return 1
  lab_cleanup
  rm -rf livrable cible nginx app ports.txt .app.pid
  mkdir -p app livrable nginx/logs nginx/temp
  cp "$MODDIR/assets/app.py" app/app.py
  if [[ -f /etc/nginx/mime.types ]]; then cp /etc/nginx/mime.types nginx/mime.types
  else printf 'types {\n text/html html;\n text/plain txt;\n application/json json;\n}\n' > nginx/mime.types; fi
  echo "formation-lab" > .vault_pass; chmod 600 .vault_pass
  local ap wp; ap=$(free_port); wp=$(free_port)
  printf 'APP_PORT=%s\nWEB_PORT=%s\n' "$ap" "$wp" > ports.txt
  PORT=$ap nohup python3 "$LAB_DIR/app/app.py" >/dev/null 2>&1 </dev/null &
  echo $! > .app.pid
  cp "$MODDIR/LAB.md" CAHIER_DES_CHARGES.md
  cp "$MODDIR/grille-evaluation.md" GRILLE_EVALUATION.md
  local i; for i in $(seq 1 30); do curl --noproxy '*' -s -m1 "http://127.0.0.1:$ap/health" >/dev/null 2>&1 && break; sleep 0.2; done
}

# ---------------------------------------------------------------- helpers
SEC=""; S0P=0; S0F=0
sec_begin() { SEC=$1; S0P=$PASS; S0F=$FAIL; printf '\n%s── %s%s\n' "$C_BLD" "$1" "$C_OFF"; }
sec_end() { local p=$((PASS - S0P)) t=$((PASS - S0P + FAIL - S0F)); printf '  %s→ %s : %d/%d%s\n' "$C_BLU" "$SEC" "$p" "$t" "$C_OFF"; }

uget() { grep -E "^[[:space:]]*$2[[:space:]]*=" "$1" 2>/dev/null | grep -v '^[#;]' | sed -E "s/^[[:space:]]*$2[[:space:]]*=[[:space:]]*//"; }
words() { wc -w < "$1" 2>/dev/null | tr -d ' '; }
nft_usable() { local t; t=$(mktemp); echo 'table inet labtest { }' > "$t"; as_root nft -c -f "$t" >/dev/null 2>&1; local rc=$?; rm -f "$t"; return $rc; }
sysval() { grep -E "^[[:space:]]*$1[[:space:]]*=" livrable/security/sysctl.conf 2>/dev/null | tail -1 | sed -E 's/^[^=]*=[[:space:]]*//; s/[[:space:]]+$//'; }
pb() { PB_OUT=$(cd "$LAB_DIR/livrable/ansible" && ANSIBLE_FORCE_COLOR=0 ANSIBLE_NOCOWS=1 ANSIBLE_HOST_KEY_CHECKING=False ANSIBLE_INTERPRETER_PYTHON=auto_silent ANSIBLE_RETRY_FILES_ENABLED=False \
  ansible-playbook -i inventaire.ini --vault-password-file "$LAB_DIR/.vault_pass" -e "target_root=$LAB_DIR/cible" -e "app_port=$APP_PORT" "$@" 2>&1); PB_RC=$?; }
recap_sum() { awk -v f="$1" '/ : ok=/ { for (i=1;i<=NF;i++) if ($i ~ "^"f"=") { split($i,a,"="); s+=a[2] } } END{print s+0}' <<<"$PB_OUT"; }

lab_check() {
  cd "$LAB_DIR" || return 1
  # shellcheck disable=SC1091
  . ./ports.txt
  local L=livrable

  # ================= 1. systemd
  sec_begin "1. Unité systemd (tickets.service)"
  local U=$L/systemd/tickets.service
  assert "fichier présent et vérifié par systemd-analyze" bash -c "systemd-analyze verify '$LAB_DIR/$U' >/dev/null 2>&1"
  assert "Description et After=network" bash -c "grep -Eq '^Description=.+' $U && grep -Eq '^After=.*network' $U"
  assert "ExecStart = /usr/bin/python3 /opt/tickets/app.py" grep -Eq '^ExecStart=/usr/bin/python3 +/opt/tickets/app\.py' $U
  assert "utilisateur non-root (User=tickets ou DynamicUser)" bash -c "grep -Eq '^User=tickets\$|^DynamicUser=yes' $U"
  assert "Restart=on-failure/always et RestartSec 1-30" bash -c "grep -Eq '^Restart=(on-failure|always)' $U && n=\$(sed -n 's/^RestartSec=\([0-9]*\).*/\1/p' $U); [[ -n \$n && \$n -ge 1 && \$n -le 30 ]]"
  assert "EnvironmentFile=/etc/tickets/tickets.env" grep -Eq '^EnvironmentFile=-?/etc/tickets/tickets\.env' $U
  assert "WorkingDirectory=/opt/tickets" grep -Eq '^WorkingDirectory=/opt/tickets' $U
  local hard=0 d
  for d in '^NoNewPrivileges=(yes|true)' '^PrivateTmp=(yes|true)' '^PrivateDevices=(yes|true)' '^ProtectSystem=(strict|full)' '^ProtectHome=(yes|true|read-only)' '^ProtectKernelTunables=(yes|true)' '^ProtectControlGroups=(yes|true)' '^RestrictAddressFamilies=' '^CapabilityBoundingSet=' '^MemoryMax=' '^TasksMax=' '^LimitNOFILE='; do
    grep -Eq "$d" $U 2>/dev/null && hard=$((hard + 1))
  done
  if (( hard >= 6 )); then ok "durcissement : $hard directives (≥ 6 requises)"; else ko "durcissement : $hard directives (≥ 6 requises)"; fi
  assert "WantedBy=multi-user.target" grep -Eq '^WantedBy=multi-user\.target' $U
  sec_end

  # ================= 2. nginx
  sec_begin "2. Reverse proxy nginx (tickets.conf)"
  local W="$LAB_DIR/nginx/nginx.wrapper.conf" userline=""
  [[ $EUID -eq 0 ]] && userline="user root;"
  cat > "$W" <<EOF
$userline
worker_processes 1;
pid logs/nginx.pid;
error_log logs/error.log;
events { worker_connections 128; }
http {
    include mime.types;
    default_type application/octet-stream;
    client_body_temp_path temp/client; proxy_temp_path temp/proxy; fastcgi_temp_path temp/fcgi;
    uwsgi_temp_path temp/uwsgi; scgi_temp_path temp/scgi;
    include $LAB_DIR/livrable/nginx/tickets.conf;
}
EOF
  local NA=(-p "$LAB_DIR/nginx" -c "$W" -e "$LAB_DIR/nginx/logs/error.log")
  assert "nginx -t : configuration valide (incluse dans http{})" nginx "${NA[@]}" -t
  if [[ -f nginx/logs/nginx.pid ]]; then kill "$(cat nginx/logs/nginx.pid)" 2>/dev/null; sleep 0.4; fi
  rm -f nginx/logs/tickets-access.log
  nginx "${NA[@]}" >/dev/null 2>&1
  local C=(curl --noproxy '*' -s --max-time 5) base="http://127.0.0.1:$WEB_PORT" i
  for i in $(seq 1 25); do "${C[@]}" -o /dev/null "$base/health" && break; sleep 0.2; done
  assert "GET / → page de l'application (proxy vers $APP_PORT)" bash -c "curl --noproxy '*' -s '$base/' | grep -q '<h1>Tickets</h1>'"
  assert "GET /health → ok" bash -c "curl --noproxy '*' -s '$base/health' | grep -qx ok"
  local hdr; hdr=$("${C[@]}" -D - -o /dev/null "$base/" | tr -d '\r')
  assert "X-Content-Type-Options: nosniff" bash -c "grep -iq '^x-content-type-options: *nosniff' <<<\"\$1\"" _ "$hdr"
  assert "X-Frame-Options: DENY ou SAMEORIGIN" bash -c "grep -iEq '^x-frame-options: *(DENY|SAMEORIGIN)' <<<\"\$1\"" _ "$hdr"
  assert "Server: nginx sans version (server_tokens off)" bash -c "grep -iEq '^server: *nginx *\$' <<<\"\$1\"" _ "$hdr"
  local gz; gz=$("${C[@]}" -D - -o /dev/null -H 'Accept-Encoding: gzip' "$base/api/tickets" | tr -d '\r')
  assert "gzip sur /api/tickets (JSON)" bash -c "grep -iq '^content-encoding: *gzip' <<<\"\$1\"" _ "$gz"
  local who; who=$("${C[@]}" "$base/whoami")
  assert "X-Forwarded-For transmis à l'application" bash -c "grep -q '\"xff\": \"127.0.0.1\"' <<<\"\$1\"" _ "$who"
  assert "Host transmis à l'application" bash -c "grep -q '\"host\": \"127.0.0.1' <<<\"\$1\"" _ "$who"
  local codes=() n
  for n in $(seq 1 20); do codes+=("$("${C[@]}" -o /dev/null -w '%{http_code}' "$base/api/tickets")"); done
  assert "limite /api/ : premières requêtes acceptées (200)" bash -c "[[ '${codes[0]}' == 200 ]]"
  assert "limite /api/ : rafale refusée (429)" bash -c "printf '%s\n' ${codes[*]} | grep -q 429"
  sleep 1.5
  assert_eq "limite /api/ : service rétabli après la rafale" 200 "$("${C[@]}" -o /dev/null -w '%{http_code}' "$base/api/tickets")"
  sleep 0.3
  assert_grep "journal d'accès dédié : champ rt=" 'rt=[0-9.]+' nginx/logs/tickets-access.log
  assert_grep "journal d'accès dédié : champ up= (backend $APP_PORT)" "up=127\\.0\\.0\\.1:$APP_PORT" nginx/logs/tickets-access.log
  sec_end

  # ================= 3. sauvegarde
  sec_begin "3. Script de sauvegarde (backup.sh)"
  local B="$LAB_DIR/$L/scripts/backup.sh"
  assert "backup.sh exécutable, shebang bash, syntaxe valide" bash -c "test -x '$B' && head -1 '$B' | grep -q '^#!.*bash' && bash -n '$B'"
  if command -v shellcheck >/dev/null; then assert "backup.sh : shellcheck sans avertissement" shellcheck -S warning "$B"; fi
  local t; t=$(mktemp -d); mkdir -p "$t/src/sous"; echo un > "$t/src/a.txt"; echo deux > "$t/src/sous/b.txt"
  local out rc k
  for k in 1 2 3 4 5; do
    out=$(BACKUP_STAMP="2024010$k-000000" "$B" -n 3 "$t/src" "$t/dest" 2>/dev/null); rc=$?
    [[ $k -eq 1 ]] && { assert_eq "1ʳᵉ exécution : code 0" 0 "$rc"; assert_eq "stdout = chemin de l'archive" "$t/dest/tickets-20240101-000000.tar.gz" "$out"; assert "archive créée et lisible" tar -tzf "$t/dest/tickets-20240101-000000.tar.gz"; assert "l'archive contient src/a.txt et src/sous/b.txt" bash -c "tar -tzf '$t/dest/tickets-20240101-000000.tar.gz' | grep -q 'src/a.txt' && tar -tzf '$t/dest/tickets-20240101-000000.tar.gz' | grep -q 'src/sous/b.txt'"; assert_eq "SHA256SUMS : 1 ligne après la 1ʳᵉ sauvegarde" 1 "$(wc -l < "$t/dest/SHA256SUMS" 2>/dev/null | tr -d ' ')"; }
  done
  assert_eq "rétention -n 3 : 3 archives conservées" 3 "$(ls "$t/dest"/tickets-*.tar.gz 2>/dev/null | wc -l | tr -d ' ')"
  assert "rétention : ce sont les 3 plus récentes (03, 04, 05)" bash -c "ls '$t/dest' | grep -q 20240105 && ls '$t/dest' | grep -q 20240103 && ! ls '$t/dest' | grep -q 20240101"
  assert_eq "SHA256SUMS : 3 lignes après rotation" 3 "$(wc -l < "$t/dest/SHA256SUMS" | tr -d ' ')"
  assert "sha256sum -c SHA256SUMS réussit" bash -c "cd '$t/dest' && sha256sum -c --status SHA256SUMS"
  assert "restauration : archive la plus récente identique à src" bash -c "mkdir '$t/r' && tar -xzf '$t/dest/tickets-20240105-000000.tar.gz' -C '$t/r' && diff -r '$t/src' '$t/r/src'"
  out=$("$B" --dry-run -n 3 "$t/src" "$t/dest2" 2>/dev/null); rc=$?
  assert_eq "--dry-run : code 0" 0 "$rc"
  assert "--dry-run : message DRY-RUN et rien n'est créé" bash -c "[[ '$out' == DRY-RUN* ]] && ! ls '$t/dest2'/tickets-*.tar.gz 2>/dev/null | grep -q ."
  "$B" "$t/absent" "$t/dest3" >/dev/null 2>&1; assert_eq "source absente → code 3" 3 "$?"
  "$B" >/dev/null 2>&1; assert_eq "sans argument → code 1" 1 "$?"
  "$B" -n abc "$t/src" "$t/dest4" >/dev/null 2>&1; assert_eq "-n invalide → code 1" 1 "$?"
  : > "$t/fichier"; "$B" "$t/src" "$t/fichier/dest" >/dev/null 2>&1; assert_eq "destination inutilisable → code 4" 4 "$?"
  for k in 1 2 3 4 5 6 7 8 9; do BACKUP_STAMP="2025010$k-000000" "$B" "$t/src" "$t/dest5" >/dev/null 2>&1; done
  assert_eq "rétention par défaut = 7 archives" 7 "$(ls "$t/dest5"/tickets-*.tar.gz 2>/dev/null | wc -l | tr -d ' ')"
  rm -rf "$t"
  sec_end

  # ================= 4. supervision
  sec_begin "4. Sonde de supervision (healthcheck.sh)"
  local H="$LAB_DIR/$L/scripts/healthcheck.sh" A="http://127.0.0.1:$APP_PORT"
  assert "healthcheck.sh exécutable, shebang bash, syntaxe valide" bash -c "test -x '$H' && head -1 '$H' | grep -q '^#!.*bash' && bash -n '$H'"
  if command -v shellcheck >/dev/null; then assert "healthcheck.sh : shellcheck sans avertissement" shellcheck -S warning "$H"; fi
  hc() { local o; o=$("$H" "$@" 2>/dev/null); echo "$?|$o"; }
  local r
  r=$(hc -u "$A/health"); assert "OK : code 0, « HTTP OK - 200 in Nms|time=Nms;500;1000;0 »" bash -c "[[ '$r' =~ ^0\\|HTTP\\ OK\\ -\\ 200\\ in\\ [0-9]+ms\\|time=[0-9]+ms\;500\;1000\;0\$ ]]"
  r=$(hc -u "$A/slow?ms=700" -w 500 -c 1500); assert "lent (700 ms) : WARNING, code 1" bash -c "[[ '$r' == 1\\|HTTP\\ WARNING* ]]"
  r=$(hc -u "$A/slow?ms=1300" -w 500 -c 1000); assert "très lent (1300 ms) : CRITICAL, code 2" bash -c "[[ '$r' == 2\\|HTTP\\ CRITICAL* ]]"
  r=$(hc -u "$A/error"); assert "statut 500 : CRITICAL, code 2" bash -c "[[ '$r' == 2\\|HTTP\\ CRITICAL* ]]"
  r=$(hc -u "http://127.0.0.1:1/health" -t 2); assert "port fermé : CRITICAL, code 2" bash -c "[[ '$r' == 2\\|HTTP\\ CRITICAL* ]]"
  r=$(hc -u "$A/slow?ms=3000" -t 1); assert "délai dépassé (-t 1) : CRITICAL, code 2" bash -c "[[ '$r' == 2\\|HTTP\\ CRITICAL* ]]"
  r=$(hc); assert "sans -u : UNKNOWN, code 3" bash -c "[[ '$r' == 3\\|HTTP\\ UNKNOWN* ]]"
  r=$(hc -u "$A/health" -w 900 -c 100); assert "w ≥ c : UNKNOWN, code 3" bash -c "[[ '$r' == 3\\|HTTP\\ UNKNOWN* ]]"
  r=$(hc -u "$A/health" -w abc); assert "valeur non numérique : UNKNOWN, code 3" bash -c "[[ '$r' == 3\\|HTTP\\ UNKNOWN* ]]"
  sec_end

  # ================= 5. sécurité
  sec_begin "5. Sécurité (nftables, sshd, sysctl)"
  local F=$L/security/nftables.conf
  assert "nftables : chaîne input en policy drop" grep -Eq 'hook input[^}]*policy drop' $F
  assert "nftables : established,related et loopback" bash -c "grep -Eq 'ct state[^;]*established[^;]*related[^;]*accept|ct state[^;]*related[^;]*established[^;]*accept' $F && grep -Eq '(iif|iifname)[[:space:]]+\"?lo\"?[[:space:]]+accept' $F"
  assert "nftables : SSH (22) restreint à des adresses d'administration" grep -Eq 'tcp dport (22|\{[^}]*\b22\b[^}]*\})[[:space:]]+ip saddr|ip saddr[^#]*tcp dport 22' $F
  assert "nftables : HTTP et HTTPS (80, 443)" bash -c "grep -Eq 'dport[^#]*\\b80\\b' $F && grep -Eq 'dport[^#]*\\b443\\b' $F"
  assert "nftables : ping limité (limit rate)" grep -Eq 'echo-request[^#]*limit rate|limit rate[^#]*echo-request' $F
  assert "nftables : le port applicatif $APP_PORT n'est PAS ouvert" bash -c "! grep -v '^[[:space:]]*#' $F | grep -qw '$APP_PORT'"
  if nft_usable; then assert "nft -c -f : syntaxe valide" as_root nft -c -f "$F"; else skip "nft -c (nftables inutilisable ici)"; fi
  local S=$L/security/sshd_99-tickets.conf
  assert "sshd : PermitRootLogin no" grep -Eq '^PermitRootLogin[[:space:]]+(no|prohibit-password)' $S
  assert "sshd : PasswordAuthentication no" grep -Eq '^PasswordAuthentication[[:space:]]+no' $S
  assert "sshd : MaxAuthTries ≤ 4" grep -Eq '^MaxAuthTries[[:space:]]+[1-4][[:space:]]*$' $S
  assert "sshd : X11Forwarding no" grep -Eq '^X11Forwarding[[:space:]]+no' $S
  assert "sshd : liste blanche (AllowUsers/AllowGroups)" grep -Eq '^Allow(Users|Groups)[[:space:]]+[^ ]+' $S
  assert_eq "sysctl : tcp_syncookies" 1 "$(sysval net.ipv4.tcp_syncookies)"
  assert_eq "sysctl : rp_filter" 1 "$(sysval net.ipv4.conf.all.rp_filter)"
  assert_eq "sysctl : accept_redirects" 0 "$(sysval net.ipv4.conf.all.accept_redirects)"
  assert_eq "sysctl : send_redirects" 0 "$(sysval net.ipv4.conf.all.send_redirects)"
  assert_eq "sysctl : randomize_va_space" 2 "$(sysval kernel.randomize_va_space)"
  local k p; k=$(sysval kernel.kptr_restrict); p=$(sysval kernel.yama.ptrace_scope)
  if [[ "$k" =~ ^[0-9]+$ && $k -ge 1 ]]; then ok "sysctl : kptr_restrict ≥ 1"; else ko "sysctl : kptr_restrict ≥ 1"; fi
  if [[ "$p" =~ ^[0-9]+$ && $p -ge 1 ]]; then ok "sysctl : ptrace_scope ≥ 1"; else ko "sysctl : ptrace_scope ≥ 1"; fi
  assert_eq "sysctl : protected_symlinks" 1 "$(sysval fs.protected_symlinks)"
  assert_eq "sysctl : protected_hardlinks" 1 "$(sysval fs.protected_hardlinks)"
  sec_end

  # ================= 6. Ansible
  sec_begin "6. Déploiement Ansible (idempotent, Vault)"
  local AD=$L/ansible
  assert "fichiers : inventaire.ini, site.yml, template env, vault" bash -c "test -s $AD/inventaire.ini && test -s $AD/site.yml && test -s $AD/group_vars/all/vault.yml && ls $AD/templates/* >/dev/null 2>&1"
  assert "vault.yml chiffré (\$ANSIBLE_VAULT)" bash -c "head -1 $AD/group_vars/all/vault.yml | grep -q '^\$ANSIBLE_VAULT;'"
  assert "vault.yml contient vault_secret_key (déchiffrable avec .vault_pass)" bash -c "ansible-vault view $AD/group_vars/all/vault.yml --vault-password-file .vault_pass 2>&1 | grep -q vault_secret_key"
  pb site.yml --syntax-check; assert_eq "site.yml : --syntax-check" 0 "$PB_RC"
  rm -rf cible; pb site.yml
  assert_eq "1ʳᵉ exécution : code 0 et failed=0" "0:0" "$PB_RC:$(recap_sum failed)"
  assert "1ʳᵉ exécution : des changements" bash -c "[[ $(recap_sum changed) -gt 0 ]]"
  local T="$LAB_DIR/cible"
  chk() { # chk <chemin relatif> <mode> <source>
    local f="$T/$1"
    assert_mode "déployé : $1 en $2" "$2" "$f"
    [[ -z "${3:-}" ]] || assert "déployé : $1 identique à $3" cmp -s "$f" "$LAB_DIR/$L/$3"
  }
  chk etc/systemd/system/tickets.service 644 systemd/tickets.service
  chk etc/nginx/conf.d/tickets.conf 644 nginx/tickets.conf
  chk usr/local/bin/tickets-backup 755 scripts/backup.sh
  chk usr/local/bin/tickets-healthcheck 755 scripts/healthcheck.sh
  chk etc/ssh/sshd_config.d/99-tickets.conf 644 security/sshd_99-tickets.conf
  chk etc/nftables.conf 600 security/nftables.conf
  chk etc/sysctl.d/99-tickets.conf 644 security/sysctl.conf
  chk etc/tickets/tickets.env 640
  assert_grep "tickets.env : PORT=$APP_PORT" "^PORT=$APP_PORT\$" "$T/etc/tickets/tickets.env"
  assert_grep "tickets.env : SECRET_KEY déchiffrée (non vide, pas de gabarit)" '^SECRET_KEY=[^{ ]{6,}$' "$T/etc/tickets/tickets.env"
  assert "handlers : drapeaux de rechargement écrits au 1er déploiement" bash -c "test -f '$T/var/run/systemd-reload.flag' && test -f '$T/var/run/nginx-reload.flag'"
  rm -f "$T"/var/run/*.flag
  pb site.yml
  assert_eq "2ᵉ exécution : idempotence (changed=0)" 0 "$(recap_sum changed)"
  assert "2ᵉ exécution : handlers non déclenchés" bash -c "! ls '$T'/var/run/*.flag >/dev/null 2>&1"
  sec_end

  # ================= 7. documentation
  sec_begin "7. Documentation (README, RUNBOOK, PRA)"
  local D=$L/docs
  assert "README.md : sections Architecture, Installation, Exploitation" bash -c "grep -Eiq '^#+ .*architecture' $D/README.md && grep -Eiq '^#+ .*installation' $D/README.md && grep -Eiq '^#+ .*exploitation' $D/README.md"
  assert "README.md : schéma (bloc de code) et ≥ 150 mots" bash -c "grep -q '^\`\`\`' $D/README.md && [[ $(words $D/README.md) -ge 150 ]]"
  assert "README.md : cite nginx, systemd/tickets.service et sauvegarde" bash -c "grep -Eiq 'nginx' $D/README.md && grep -Eiq 'systemd|tickets\\.service' $D/README.md && grep -Eiq 'sauvegarde|backup' $D/README.md"
  assert "RUNBOOK.md : ≥ 3 incidents documentés (## titres)" bash -c "[[ \$(grep -c '^## ' $D/RUNBOOK.md) -ge 3 ]]"
  assert "RUNBOOK.md : chaque incident a Diagnostic et Actions" bash -c "[[ \$(grep -Eic 'diagnostic' $D/RUNBOOK.md) -ge 3 && \$(grep -Eic 'actions?' $D/RUNBOOK.md) -ge 3 ]]"
  assert "RUNBOOK.md : commandes concrètes (journalctl/systemctl/ss) et ≥ 250 mots" bash -c "grep -q 'journalctl' $D/RUNBOOK.md && grep -q 'systemctl' $D/RUNBOOK.md && [[ $(words $D/RUNBOOK.md) -ge 250 ]]"
  assert "PRA.md : RPO et RTO chiffrés" bash -c "grep -Eiq 'RPO.*[0-9]' $D/PRA.md && grep -Eiq 'RTO.*[0-9]' $D/PRA.md"
  assert "PRA.md : restauration, tests de restauration, contacts" bash -c "grep -Eiq 'restaur' $D/PRA.md && grep -Eiq 'test' $D/PRA.md && grep -Eiq 'contact' $D/PRA.md"
  assert "PRA.md : ≥ 200 mots" bash -c "[[ $(words $D/PRA.md) -ge 200 ]]"
  sec_end

  # ================= 8. hygiène du dépôt
  sec_begin "8. Hygiène du dépôt et des secrets"
  assert ".gitignore : *.env, .vault_pass, cible/" bash -c "grep -qx '\*\.env' $L/.gitignore && grep -qx '\.vault_pass' $L/.gitignore && grep -Eqx 'cible/?' $L/.gitignore"
  assert "aucune clé privée dans le livrable" bash -c "! grep -rIlE 'BEGIN ([A-Z]+ )?PRIVATE KEY' $L"
  assert "aucun secret en clair (SECRET_KEY=…, password=…)" bash -c "! grep -rIE '(SECRET_KEY|PASSWORD|passwd)[[:space:]]*[=:][[:space:]]*[\"'\\'']?[A-Za-z0-9]{6,}' $L --exclude-dir=group_vars"
  assert "aucun fichier vault.yml en clair" bash -c "for f in \$(find $L -name 'vault*.yml'); do head -1 \$f | grep -q '^\$ANSIBLE_VAULT;' || exit 1; done"
  sec_end
}

lab_solve() {
  cd "$LAB_DIR" || return 1
  # shellcheck disable=SC1091
  . ./ports.txt
  rm -rf livrable; cp -r "$MODDIR/solution/livrable" livrable
  sed -i "s/@APP_PORT@/$APP_PORT/g; s/@WEB_PORT@/$WEB_PORT/g" livrable/nginx/tickets.conf
  mkdir -p livrable/ansible/group_vars/all
  echo 'vault_secret_key: "k3y-Tickets-2024-prod"' > livrable/ansible/group_vars/all/vault.yml
  ansible-vault encrypt livrable/ansible/group_vars/all/vault.yml --vault-password-file .vault_pass >/dev/null 2>&1
}

lab_main "$@"
