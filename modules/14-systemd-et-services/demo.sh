#!/usr/bin/env bash
# Démo formateur — module 14 (≈ 40 min).
# Partie 1 (statique) : fonctionne partout. Partie 2 (live) : nécessite systemd en PID 1 + root (VM, conteneur « lab »).
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/demo-lib.sh"

demo_title "Version et type de gestionnaire"
demo_run "systemctl --version | head -1"
demo_run "ps -p 1 -o pid,comm"

demo_title "OnCalendar : valider et visualiser les prochaines exécutions"
demo_run "systemd-analyze calendar 'daily' | sed -n '1,2p'"
demo_run "systemd-analyze calendar 'Mon..Fri 08:00' --iterations=3 | grep -E 'Normalized|Next|elapse|left' | head -4"
demo_run "systemd-analyze calendar '*:0/15' --iterations=3 | grep -E 'Normalized|Next' | head -3"
demo_run "systemd-analyze calendar '*-*-01 00:00' | grep Normalized"

demo_title "Écrire une unité et la valider AVANT de l'installer"
demo_run "mkdir -p bin && printf '#!/bin/sh\\necho API ok\\nsleep 3600\\n' > bin/api.sh && chmod +x bin/api.sh && chmod 755 ."
demo_run "cat > demo-api.service <<EOF
[Unit]
Description=API de démonstration
After=network.target

[Service]
ExecStart=\$PWD/bin/api.sh
Restart=on-failure
RestartSec=2
DynamicUser=yes
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict

[Install]
WantedBy=multi-user.target
EOF
systemd-analyze verify ./demo-api.service && echo 'unité valide'"
demo_say "Une faute de frappe est détectée immédiatement :"
demo_run "sed 's/^Restart=/Restar=/; s#bin/api.sh#bin/introuvable.sh#' demo-api.service > bad.service; systemd-analyze verify ./bad.service 2>&1 | grep -v IPv6"

if [[ -d /run/systemd/system && $EUID -eq 0 ]]; then
  demo_title "LIVE — Unité transitoire avec systemd-run"
  demo_run "systemd-run --unit=demo-hello --collect --wait sh -c 'echo salut depuis systemd; sleep 1' 2>&1 | tail -3"
  demo_run "journalctl -u demo-hello --no-pager -o cat | tail -3"

  demo_title "LIVE — Installer, démarrer, tuer, observer le redémarrage"
  demo_run "cp demo-api.service /etc/systemd/system/ && systemctl daemon-reload && systemctl enable --now demo-api && sleep 1"
  demo_run "systemctl is-active demo-api; systemctl show demo-api -p MainPID,Restart,NRestarts"
  demo_run "systemctl kill -s KILL demo-api; sleep 3; systemctl show demo-api -p NRestarts,ActiveState"
  demo_run "journalctl -u demo-api --no-pager -n 6 -o short | cut -c1-110"
  demo_run "systemd-analyze security demo-api.service --no-pager | tail -2"
  demo_run "systemctl disable --now demo-api; rm -f /etc/systemd/system/demo-api.service; systemctl daemon-reload; systemctl list-units 'demo-*' --no-legend | wc -l"

  demo_title "LIVE — Timers"
  demo_run "systemctl list-timers --no-pager | head -5"
  demo_run "systemd-analyze blame --no-pager | head -5"
else
  demo_say "PID 1 n'est pas systemd (ou pas root) : voici les commandes de la partie live, à jouer sur la VM :"
  demo_show "sudo cp demo-api.service /etc/systemd/system/ && sudo systemctl daemon-reload && sudo systemctl enable --now demo-api"
  demo_show "sudo kill -9 \$(systemctl show -p MainPID --value demo-api)   # puis: systemctl status demo-api → redémarré"
  demo_show "journalctl -u demo-api -f   |   systemctl --failed   |   systemd-analyze blame"
fi
demo_end
