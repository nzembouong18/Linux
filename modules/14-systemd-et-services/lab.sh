#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/lib.sh"
LAB_ID=14
LAB_REQUIRES=(cmd:systemd-analyze cmd:python3)

lab_setup() {
  cd "$LAB_DIR" || return 1
  rm -f ./*.service ./*.timer cron.txt reponses.txt
  mkdir -p bin
  cat > bin/api.sh <<'EOF'
#!/usr/bin/env bash
# Mini API de démonstration : écoute (simulée) sur $PORT
echo "API démarrée sur le port ${PORT:-8080}"
while true; do sleep 5; done
EOF
  cat > bin/sauvegarde.sh <<'EOF'
#!/usr/bin/env bash
echo "Sauvegarde exécutée le $(date)"
EOF
  chmod +x bin/api.sh bin/sauvegarde.sh
}

# --- helpers ----------------------------------------------------------------
uget() { grep -E "^$2[[:space:]]*=" "$1" 2>/dev/null | grep -v '^[#;]' | sed -E "s/^$2[[:space:]]*=[[:space:]]*//" ; }
uhas() { uget "$1" "$2" | grep -Eq "$3"; }
verify_ok() { systemd-analyze verify "$@" >/dev/null 2>&1; }
norm_cal() { systemd-analyze calendar "$1" 2>/dev/null | awk -F': *' '/Normalized form/ {print $2; exit}'; }

# Deux expressions cron déclenchent-elles aux mêmes instants (≈ 4 mois) ?
cron_equiv() {
  python3 - "$1" "$2" <<'PY'
import sys
from datetime import date, timedelta
MON = {n: i + 1 for i, n in enumerate("jan feb mar apr may jun jul aug sep oct nov dec".split())}
DOW = {n: i for i, n in enumerate("sun mon tue wed thu fri sat".split())}
ALIAS = {"@daily": "0 0 * * *", "@midnight": "0 0 * * *", "@hourly": "0 * * * *",
         "@weekly": "0 0 * * 0", "@monthly": "0 0 1 * *", "@yearly": "0 0 1 1 *", "@annually": "0 0 1 1 *"}
def val(t, names):
    t = t.lower()
    return names[t] if t in names else int(t)
def field(f, lo, hi, names):
    out = set()
    for part in f.split(","):
        step = 1
        if "/" in part:
            part, st = part.split("/"); step = int(st)
        if part == "*": a, b = lo, hi
        elif "-" in part:
            x, y = part.split("-"); a, b = val(x, names), val(y, names)
        else:
            a = val(part, names); b = hi if step > 1 else a
        out.update(range(a, b + 1, step))
    return out
def fires(expr):
    expr = ALIAS.get(expr.strip().lower(), expr)
    p = expr.split()
    if len(p) != 5: raise ValueError("5 champs attendus")
    mi, ho = field(p[0], 0, 59, {}), field(p[1], 0, 23, {})
    dom, mo, dw = field(p[2], 1, 31, {}), field(p[3], 1, 12, MON), field(p[4], 0, 7, DOW)
    if 7 in dw: dw.add(0)
    dstar, wstar = p[2].startswith("*"), p[4].startswith("*")
    res = set(); d = date(2024, 1, 1)
    for _ in range(120):
        w = (d.weekday() + 1) % 7
        ok_dom, ok_dow = d.day in dom, w in dw
        day_ok = (ok_dom and ok_dow) if (dstar or wstar) else (ok_dom or ok_dow)
        if (dstar and wstar): day_ok = True
        elif dstar: day_ok = ok_dow
        elif wstar: day_ok = ok_dom
        if d.month in mo and day_ok:
            for h in ho:
                for m in mi: res.add((d.toordinal(), h, m))
        d += timedelta(days=1)
    return res
try:
    sys.exit(0 if fires(sys.argv[1]) == fires(sys.argv[2]) else 1)
except Exception:
    sys.exit(2)
PY
}

lab_check() {
  cd "$LAB_DIR" || return 1
  local A=labapi.service B=labsauvegarde.service T=labsauvegarde.timer

  # ---- A
  assert "A labapi.service existe et se vérifie (systemd-analyze verify)" verify_ok "$LAB_DIR/$A"
  assert "A After= réseau" uhas $A After 'network(-online)?\.target'
  assert "A Description renseignée" uhas $A Description '.+'
  assert "A Type=simple" bash -c "! grep -E '^Type *=' $A | grep -qv simple"
  assert_eq "A ExecStart = bin/api.sh (chemin absolu)" "$LAB_DIR/bin/api.sh" "$(uget $A ExecStart | awk '{print $1}' | sed 's/^[@+!-]*//')"
  assert "A Restart=on-failure (ou always)" uhas $A Restart '^(on-failure|always)$'
  local rs; rs=$(uget $A RestartSec | tr -dc 0-9)
  if [[ -n "$rs" && "$rs" -ge 2 && "$rs" -le 10 ]]; then ok "A RestartSec entre 2 et 10 s"; else ko "A RestartSec entre 2 et 10 s (obtenu '${rs}')"; fi
  assert "A exécution non-root (User= ≠ root ou DynamicUser=yes)" bash -c "grep -Eq '^DynamicUser *= *yes' $A || { u=\$(grep -E '^User *=' $A | head -1 | sed -E 's/^User *= *//'); [[ -n \$u && \$u != root && \$u != 0 ]]; }"
  assert "A Environment PORT=8080" uhas $A Environment 'PORT=8080'
  assert "A NoNewPrivileges=yes" uhas $A NoNewPrivileges '^(yes|true|1)$'
  assert "A PrivateTmp=yes" uhas $A PrivateTmp '^(yes|true|1)$'
  assert "A ProtectSystem=strict|full" uhas $A ProtectSystem '^(strict|full|true)$'
  assert "A WantedBy=multi-user.target" uhas $A WantedBy 'multi-user\.target'

  # ---- B
  assert "B labsauvegarde.service + timer se vérifient" verify_ok "$LAB_DIR/$B" "$LAB_DIR/$T"
  assert "B service Type=oneshot" uhas $B Type '^oneshot$'
  assert_eq "B ExecStart = bin/sauvegarde.sh (absolu)" "$LAB_DIR/bin/sauvegarde.sh" "$(uget $B ExecStart | awk '{print $1}' | sed 's/^[@+!-]*//')"
  assert_eq "B OnCalendar = tous les jours à 02:30" "$(norm_cal '*-*-* 02:30:00')" "$(norm_cal "$(uget $T OnCalendar | head -1)")"
  assert "B Persistent=true" uhas $T Persistent '^(true|yes|1)$'
  assert "B timer WantedBy=timers.target" uhas $T WantedBy 'timers\.target'

  # ---- C
  local c; c() { grep -E "^$1=" cron.txt 2>/dev/null | head -1 | cut -d= -f2-; }
  check_cron() { # check_cron <clé> <référence>
    local mine; mine=$(c "$1")
    if [[ -n "$mine" ]] && cron_equiv "$mine" "$2"; then ok "C $1"; else ko "C $1 (obtenu: '${mine}')"; fi
  }
  check_cron TOUTES_15MIN '*/15 * * * *'
  check_cron QUOTIDIEN_0230 '30 2 * * *'
  check_cron SEMAINE_0800 '0 8 * * 1-5'
  check_cron MENSUEL '0 0 1 * *'
  check_cron DIMANCHE_23H '0 23 * * 0'
  check_cron DEUX_FOIS_PAR_JOUR '15 7,19 * * *'
  local line; line=$(c CRON_LIGNE)
  if [[ -n "$line" ]] && cron_equiv "$(echo "$line" | awk '{print $1,$2,$3,$4,$5}')" '45 18 * * 1-5'; then ok "C CRON_LIGNE : planification"; else ko "C CRON_LIGNE : planification (lun-ven 18:45)"; fi
  assert "C CRON_LIGNE : commande /opt/bin/rapport.sh" bash -c "echo '$line' | grep -q ' /opt/bin/rapport.sh'"
  assert "C CRON_LIGNE : sortie ajoutée (>>) à /var/log/rapport.log avec 2>&1" bash -c "echo '$line' | grep -Eq '>> */var/log/rapport.log +2>&1|&>> */var/log/rapport.log'"

  # ---- D
  local r; r() { grep -E "^$1=" reponses.txt 2>/dev/null | head -1 | cut -d= -f2-; }
  assert_eq "D UNIT_ADMIN" "/etc/systemd/system" "$(r UNIT_ADMIN | sed 's#/$##')"
  assert "D UNIT_PAQUETS" bash -c "echo '$(r UNIT_PAQUETS)' | grep -Eq '^/(usr/)?lib/systemd/system/?$'"
  assert "D CMD_RELOAD" bash -c "echo '$(r CMD_RELOAD)' | grep -Eq '^(sudo )?systemctl daemon-reload$'"
  assert "D CMD_ECHECS" bash -c "echo '$(r CMD_ECHECS)' | grep -Eq 'systemctl (--failed|list-units +--failed)'"
  assert "D CMD_LOGS_SUIVRE" bash -c "v='$(r CMD_LOGS_SUIVRE)'; [[ \$v == journalctl* && \$v == *'-u'* && \$v == *labapi* && \$v == *'-f'* ]]"
  assert "D CMD_TIMERS" bash -c "echo '$(r CMD_TIMERS)' | grep -Eq 'systemctl +list-timers'"
  assert "D SIGNAL_ARRET" bash -c "echo '$(r SIGNAL_ARRET)' | grep -Eiq '^(SIG)?TERM$|^15$'"
}

lab_solve() {
  cd "$LAB_DIR" || return 1
  cat > labapi.service <<EOF
[Unit]
Description=API du labo
After=network.target

[Service]
Type=simple
ExecStart=$PWD/bin/api.sh
Restart=on-failure
RestartSec=3
DynamicUser=yes
Environment=PORT=8080
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict

[Install]
WantedBy=multi-user.target
EOF
  cat > labsauvegarde.service <<EOF
[Unit]
Description=Sauvegarde du labo

[Service]
Type=oneshot
ExecStart=$PWD/bin/sauvegarde.sh
EOF
  cat > labsauvegarde.timer <<EOF
[Unit]
Description=Sauvegarde nocturne

[Timer]
OnCalendar=*-*-* 02:30:00
Persistent=true

[Install]
WantedBy=timers.target
EOF
  cat > cron.txt <<'EOF'
TOUTES_15MIN=*/15 * * * *
QUOTIDIEN_0230=30 2 * * *
SEMAINE_0800=0 8 * * 1-5
MENSUEL=0 0 1 * *
DIMANCHE_23H=0 23 * * 0
DEUX_FOIS_PAR_JOUR=15 7,19 * * *
CRON_LIGNE=45 18 * * 1-5 /opt/bin/rapport.sh >> /var/log/rapport.log 2>&1
EOF
  cat > reponses.txt <<'EOF'
UNIT_ADMIN=/etc/systemd/system
UNIT_PAQUETS=/usr/lib/systemd/system
CMD_RELOAD=systemctl daemon-reload
CMD_ECHECS=systemctl --failed
CMD_LOGS_SUIVRE=journalctl -u labapi.service -f
CMD_TIMERS=systemctl list-timers
SIGNAL_ARRET=SIGTERM
EOF
}

lab_main "$@"
