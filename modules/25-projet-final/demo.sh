#!/usr/bin/env bash
# Démo formateur — module 25 (≈ 30 min) : parcours de la solution de référence.
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/demo-lib.sh"
MODDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOL="$MODDIR/solution/livrable"
PIDS=()
cleanup() { for p in "${PIDS[@]}"; do kill "$p" 2>/dev/null; done; cd /; rm -rf "$DEMO_DIR"; }
trap cleanup EXIT
fp() { python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()'; }
AP=$(fp)
PORT=$AP python3 "$MODDIR/assets/app.py" >/dev/null 2>&1 </dev/null & PIDS+=($!)
for _ in $(seq 1 30); do curl --noproxy '*' -s -m1 "http://127.0.0.1:$AP/health" >/dev/null && break; sleep 0.2; done
cp -r "$SOL" livrable

demo_title "Le livrable de référence"
demo_run "cd livrable && find . -type f | sort"
demo_run "wc -l systemd/*.service nginx/*.conf scripts/*.sh security/* docs/*.md | tail -1"

demo_title "Unité systemd : validation et exposition"
demo_run "systemd-analyze verify ./systemd/tickets.service 2>&1 | grep -v IPv6; echo \"verify rc=\${PIPESTATUS[0]}\""
demo_run "grep -E '^(User|Restart|NoNewPrivileges|ProtectSystem|PrivateTmp|CapabilityBoundingSet|MemoryMax)' systemd/tickets.service"

demo_title "Script de sauvegarde : archive, empreinte, rotation"
demo_run "mkdir -p data/sous && echo ticket1 > data/a.txt && echo ticket2 > data/sous/b.txt"
demo_run "for i in 1 2 3 4; do BACKUP_STAMP=2024010\$i-000000 scripts/backup.sh -n 2 data /tmp/demo-bak-\$\$ ; done"
demo_run "ls /tmp/demo-bak-\$\$; cat /tmp/demo-bak-\$\$/SHA256SUMS | cut -c1-30,65-"
demo_run "(cd /tmp/demo-bak-\$\$ && sha256sum -c SHA256SUMS)"
demo_run "scripts/backup.sh --dry-run data /tmp/demo-bak2-\$\$; scripts/backup.sh nope /tmp/x; echo \"code retour: \$?\""
demo_run "rm -rf /tmp/demo-bak-\$\$"

demo_title "Sonde de supervision : contrat Nagios"
demo_run "scripts/healthcheck.sh -u http://127.0.0.1:$AP/health; echo \"rc=\$?\""
demo_run "scripts/healthcheck.sh -u 'http://127.0.0.1:$AP/slow?ms=700' -w 500 -c 1500; echo \"rc=\$?\""
demo_run "scripts/healthcheck.sh -u http://127.0.0.1:$AP/error; echo \"rc=\$?\""
demo_run "scripts/healthcheck.sh -u http://127.0.0.1:1/ -t 1; echo \"rc=\$?\""

demo_title "nftables : politique drop et port applicatif fermé"
demo_run "grep -c 'policy drop' security/nftables.conf; grep -n 'dport' security/nftables.conf"
demo_run "nft -c -f security/nftables.conf 2>&1 && echo 'syntaxe nftables OK' || echo '(nft -c indisponible ici)'"

demo_title "Ansible : idempotence en direct"
if command -v ansible-playbook >/dev/null; then
  cd "$DEMO_DIR/livrable/ansible" || exit 1
  echo "vault_secret_key: \"cle-demo-12345\"" > group_vars/all/vault.yml 2>/dev/null || { mkdir -p group_vars/all; echo "vault_secret_key: \"cle-demo-12345\"" > group_vars/all/vault.yml; }
  echo formation-lab > "$DEMO_DIR/vp"
  ansible-vault encrypt group_vars/all/vault.yml --vault-password-file "$DEMO_DIR/vp" >/dev/null 2>&1
  export ANSIBLE_NOCOWS=1 ANSIBLE_FORCE_COLOR=0 ANSIBLE_HOST_KEY_CHECKING=False ANSIBLE_INTERPRETER_PYTHON=auto_silent
  AP_CMD="ansible-playbook -i inventaire.ini site.yml --vault-password-file $DEMO_DIR/vp -e target_root=$DEMO_DIR/cible -e app_port=$AP"
  demo_run "head -2 group_vars/all/vault.yml | cut -c1-30"
  demo_run "$AP_CMD 2>&1 | grep -E 'RUNNING HANDLER|PLAY RECAP|ok='"
  demo_run "$AP_CMD 2>&1 | grep -E 'RUNNING HANDLER|PLAY RECAP|ok='"
  demo_say "2ᵉ passage : changed=0 et aucun handler → idempotent."
  demo_run "ls -l $DEMO_DIR/cible/etc/tickets/ $DEMO_DIR/cible/usr/local/bin | grep -v total"
  demo_run "cat $DEMO_DIR/cible/etc/tickets/tickets.env"
else
  demo_say "(ansible absent : apt install ansible-core)"
fi
demo_end
