#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/lib.sh"
LAB_ID=20
LAB_REQUIRES=(root cmd:unshare cmd:chroot cmd:busybox cmd:python3)

CGROOT="${CGROOT:-/sys/fs/cgroup}"

lab_cleanup() {
  [[ -d "$LAB_DIR" ]] || return 0
  mountpoint -q "$LAB_DIR/overlay/merged" 2>/dev/null && as_root umount -l "$LAB_DIR/overlay/merged" 2>/dev/null
  if [[ -d "$CGROOT/lab20" ]]; then
    if [[ "$CGROOT" == /sys/fs/cgroup ]]; then as_root rmdir "$CGROOT/lab20" 2>/dev/null; else rm -rf "$CGROOT/lab20"; fi
  fi
  return 0
}

lab_setup() {
  cd "$LAB_DIR" || return 1
  lab_cleanup
  rm -rf rootfs overlay app ctr.sh limites.sh
  mkdir -p app
  cat > app/app.py <<'EOF'
import http.server, os
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        body = b"ok\n" if self.path == "/health" else b"Hello from the lab app\n"
        self.send_response(200); self.send_header("Content-Length", str(len(body))); self.end_headers(); self.wfile.write(body)
http.server.HTTPServer(("0.0.0.0", int(os.environ.get("PORT", "8000"))), H).serve_forever()
EOF
  printf 'gunicorn==22.0.0\n' > app/requirements.txt
}

cg_ok() { # v2 avec les contrôleurs nécessaires ?
  [[ -f "$CGROOT/cgroup.controllers" ]] && grep -qw memory "$CGROOT/cgroup.controllers" && grep -qw pids "$CGROOT/cgroup.controllers" && grep -qw cpu "$CGROOT/cgroup.controllers"
}
ctr() { as_root ./ctr.sh "$@"; }

lab_check() {
  cd "$LAB_DIR" || return 1
  # ---- A
  assert "A1 rootfs : dossiers de base" bash -c "cd rootfs && test -d bin -a -d proc -a -d sys -a -d dev -a -d etc -a -d tmp"
  assert "A1 rootfs/bin/busybox statique" bash -c "test -x rootfs/bin/busybox && ! ldd rootfs/bin/busybox >/dev/null 2>&1"
  assert "A1 applets utilisables DANS le rootfs (liens relatifs)" as_root chroot rootfs /bin/sh -c 'ls / >/dev/null'
  # ---- B
  assert "B2 ctr.sh exécutable" test -x ctr.sh
  assert_eq "B2 hostname isolé = ctr-lab" "ctr-lab" "$(ctr rootfs ctr-lab hostname 2>/dev/null)"
  assert "B2 hostname de l'hôte inchangé" bash -c "[[ \$(hostname) != ctr-lab ]]"
  assert_eq "B2 PID 1 dans le conteneur" 1 "$(ctr rootfs ctr-lab sh -c 'echo $$' 2>/dev/null)"
  local ls_out; ls_out=$(ctr rootfs ctr-lab ls / 2>/dev/null | tr '\n' ' ')
  assert "B2 / du conteneur = rootfs (bin présent)" bash -c "[[ ' $ls_out' == *' bin '* ]]"
  assert "B2 pas de /home ni /usr (système hôte invisible)" bash -c "[[ ' $ls_out' != *' home '* && ' $ls_out' != *' usr '* && ' $ls_out' != *' var '* ]]"
  assert_eq "B2 réseau isolé : une seule interface (lo)" 1 "$(ctr rootfs ctr-lab ip -o link 2>/dev/null | wc -l)"
  local ps_n; ps_n=$(ctr rootfs ctr-lab ps 2>/dev/null | wc -l)
  assert "B2 ps ne voit que les processus du conteneur (≤ 4 lignes)" bash -c "[[ $ps_n -ge 2 && $ps_n -le 4 ]]"
  ctr rootfs ctr-lab sh -c 'echo ecrit-dans-conteneur > /tmp/marque' 2>/dev/null
  assert_eq "B2 l'écriture dans /tmp atterrit dans rootfs/tmp" "ecrit-dans-conteneur" "$(cat rootfs/tmp/marque 2>/dev/null)"
  rm -f rootfs/tmp/marque
  ctr rootfs ctr-lab sh -c 'exit 7' 2>/dev/null; assert_eq "B2 code retour propagé" 7 "$?"
  ./ctr.sh >/dev/null 2>&1; assert_eq "B2 sans argument : code 1" 1 "$?"
  # ---- C
  assert "C3 overlay/merged est un point de montage" mountpoint -q overlay/merged
  assert_eq "C3 système de fichiers overlay" overlay "$(findmnt -no FSTYPE overlay/merged 2>/dev/null)"
  assert "C3 lowerdir = rootfs" bash -c "findmnt -no OPTIONS overlay/merged | grep -q 'lowerdir=$LAB_DIR/rootfs'"
  assert_eq "C3 nouveau.txt présent dans la couche haute (upper)" "couche haute" "$(cat overlay/upper/tmp/nouveau.txt 2>/dev/null)"
  assert "C3 suppression de bin/ls = whiteout (périphérique 0,0) dans upper" test -c overlay/upper/bin/ls
  assert "C3 couche basse intacte (rootfs/bin/ls existe, nouveau.txt absent)" bash -c "test -e rootfs/bin/ls && test ! -e rootfs/tmp/nouveau.txt"
  assert "C3 vu depuis merged : ls absent, nouveau.txt présent" bash -c "test ! -e overlay/merged/bin/ls && test -f overlay/merged/tmp/nouveau.txt"
  # ---- D
  if cg_ok; then
    assert "D4 limites.sh exécutable" test -x limites.sh
    as_root ./limites.sh true >/dev/null 2>&1
    local mem; mem=$(cat "$CGROOT/lab20/memory.max" 2>/dev/null)
    assert "D4 memory.max = 64 Mo" bash -c "[[ '$mem' == 67108864 || '$mem' == 64M ]]"
    assert_eq "D4 pids.max = 16" 16 "$(cat "$CGROOT/lab20/pids.max" 2>/dev/null)"
    assert_eq "D4 cpu.max = 50 %" "50000 100000" "$(cat "$CGROOT/lab20/cpu.max" 2>/dev/null)"
    if [[ "$CGROOT" == /sys/fs/cgroup ]]; then assert "D4 le processus lancé est bien dans le cgroup lab20" bash -c "as_root ./limites.sh cat /proc/self/cgroup 2>/dev/null | grep -q lab20" ; fi
  else
    skip "D4 cgroups v2 (contrôleurs cpu/memory/pids indisponibles sur cet hôte)"
  fi
  # ---- E
  local D=app/Dockerfile
  assert "E5 FROM avec tag épinglé léger (pas latest)" bash -c "grep -Eq '^FROM +[^ ]+:[^ ]*(slim|alpine|distroless|bookworm|bullseye)[^ ]*|^FROM +[^ ]+@sha256:' $D && ! grep -Eq '^FROM +[^: ]+( +[Aa][Ss] .*)?\$|^FROM +[^ ]+:latest' $D"
  assert "E5 WORKDIR" grep -Eq '^WORKDIR ' $D
  assert "E5 COPY requirements.txt avant COPY . ." bash -c "a=\$(grep -nE '^COPY +requirements' $D | head -1 | cut -d: -f1); b=\$(grep -nE '^COPY +\\. +' $D | head -1 | cut -d: -f1); [[ -n \$a && -n \$b && \$a -lt \$b ]]"
  assert "E5 pip install --no-cache-dir" grep -Eq 'pip install .*--no-cache-dir' $D
  assert "E5 pas de ADD" bash -c "! grep -Eq '^ADD ' $D"
  assert "E5 utilisateur créé puis USER non-root" bash -c "grep -Eq '(useradd|adduser|addgroup)' $D && u=\$(grep -E '^USER ' $D | tail -1 | awk '{print \$2}'); [[ -n \$u && \$u != root && \$u != 0 ]]"
  assert "E5 EXPOSE 8000" grep -Eq '^EXPOSE +8000' $D
  assert "E5 HEALTHCHECK" grep -Eq '^HEALTHCHECK ' $D
  assert "E5 CMD en forme exec (JSON)" grep -Eq '^(CMD|ENTRYPOINT) +\[' $D
  assert "E5 aucun secret en ENV" bash -c "! grep -Eiq '^ENV .*(PASSWORD|SECRET|TOKEN|KEY)=' $D"
  assert "E6 .dockerignore (.git et .env)" bash -c "grep -qx '.git/*' app/.dockerignore && grep -Eqx '\.env\*?|\*\.env' app/.dockerignore"
  if python3 -c 'import yaml' 2>/dev/null; then
    cy() { python3 - "$1" <<'PY'
import sys, yaml
d = yaml.safe_load(open("app/compose.yaml"))
s = d.get("services", {}); w = s.get("web", {}); b = s.get("db", {})
ok = {
 "ports": w.get("ports") == ["127.0.0.1:8000:8000"],
 "restart": w.get("restart") == "unless-stopped",
 "ro": w.get("read_only") is True,
 "cap": "ALL" in (w.get("cap_drop") or []),
 "nnp": any("no-new-privileges" in str(x) for x in (w.get("security_opt") or [])),
 "mem": bool(w.get("mem_limit") or ((w.get("deploy") or {}).get("resources") or {}).get("limits", {}).get("memory")),
 "build": "build" in w,
 "dbimg": str(b.get("image", "")).startswith("postgres:16"),
 "dbvol": any(str(v).split(":")[0] in (d.get("volumes") or {}) for v in (b.get("volumes") or [])),
 "dbhc": "healthcheck" in b,
 "dep": (w.get("depends_on") or {}).get("db", {}).get("condition") == "service_healthy" if isinstance(w.get("depends_on"), dict) else False,
 "pwd": "${DB_PASSWORD}" in str(b.get("environment", "")) and "${DB_PASSWORD}" in str(w.get("environment", "")),
}
sys.exit(0 if ok[sys.argv[1]] else 1)
PY
    }
    assert "E7 web publie 127.0.0.1:8000:8000" cy ports
    assert "E7 web : restart unless-stopped" cy restart
    assert "E7 web : read_only: true" cy ro
    assert "E7 web : cap_drop ALL" cy cap
    assert "E7 web : no-new-privileges" cy nnp
    assert "E7 web : limite mémoire" cy mem
    assert "E7 web : build local" cy build
    assert "E7 db : image postgres:16…" cy dbimg
    assert "E7 db : volume nommé déclaré" cy dbvol
    assert "E7 db : healthcheck" cy dbhc
    assert "E7 web dépend de db (service_healthy)" cy dep
    assert "E7 mot de passe via \${DB_PASSWORD} (web et db)" cy pwd
  else
    skip "E7 compose.yaml (PyYAML absent : apt install python3-yaml)"
  fi
}

lab_solve() {
  cd "$LAB_DIR" || return 1
  mkdir -p rootfs/{bin,proc,sys,dev,etc,tmp,root}
  cp "$(command -v busybox)" rootfs/bin/ && as_root chroot rootfs /bin/busybox --install -s /bin
  cat > ctr.sh <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
[[ $# -ge 3 ]] || { echo "Usage: $0 ROOTFS HOSTNAME CMD [ARGS...]" >&2; exit 1; }
root=$(realpath "$1"); host=$2; shift 2
exec unshare --uts --pid --ipc --mount --net --fork --mount-proc="$root/proc" \
  chroot "$root" /bin/sh -c 'hostname "$1"; shift; exec "$@"' _ "$host" "$@"
EOS
  chmod +x ctr.sh
  mkdir -p overlay/{upper,work,merged}
  as_root mount -t overlay overlay -o "lowerdir=$PWD/rootfs,upperdir=$PWD/overlay/upper,workdir=$PWD/overlay/work" "$PWD/overlay/merged"
  echo "couche haute" | as_root tee overlay/merged/tmp/nouveau.txt >/dev/null
  as_root rm overlay/merged/bin/ls
  cat > limites.sh <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
CG=${CGROOT:-/sys/fs/cgroup}
[[ $# -ge 1 ]] || { echo "Usage: $0 CMD..." >&2; exit 1; }
echo "+cpu +memory +pids" > "$CG/cgroup.subtree_control" 2>/dev/null || true
mkdir -p "$CG/lab20"
echo 64M > "$CG/lab20/memory.max"
echo 16 > "$CG/lab20/pids.max"
echo "50000 100000" > "$CG/lab20/cpu.max"
echo $$ > "$CG/lab20/cgroup.procs"
exec "$@"
EOS
  chmod +x limites.sh
  cat > app/Dockerfile <<'EOS'
FROM python:3.12-slim
ENV PYTHONUNBUFFERED=1
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
RUN useradd --system --no-create-home appuser && chown -R appuser /app
USER appuser
EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=3s CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health')"
CMD ["python", "app.py"]
EOS
  printf '.git\n.env\n__pycache__/\n' > app/.dockerignore
  cat > app/compose.yaml <<'EOS'
services:
  web:
    build: .
    ports:
      - "127.0.0.1:8000:8000"
    environment:
      DATABASE_URL: postgresql://app:${DB_PASSWORD}@db:5432/app
    depends_on:
      db:
        condition: service_healthy
    restart: unless-stopped
    read_only: true
    cap_drop: [ALL]
    security_opt: ["no-new-privileges:true"]
    mem_limit: 256m
  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: app
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_DB: app
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U app"]
      interval: 5s
      retries: 10
volumes:
  pgdata:
EOS
}

lab_main "$@"
