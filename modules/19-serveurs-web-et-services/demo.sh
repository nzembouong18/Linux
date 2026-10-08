#!/usr/bin/env bash
# Démo formateur — module 19 (≈ 45 min). nginx éphémère (préfixe privé), aucun accès à /etc/nginx.
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/demo-lib.sh"
command -v nginx >/dev/null || { demo_say "nginx absent (apt install nginx) — démonstration théorique."; exit 0; }
PIDS=()
cleanup() {
  [[ -f "$DEMO_DIR/n/logs/nginx.pid" ]] && kill "$(cat "$DEMO_DIR/n/logs/nginx.pid")" 2>/dev/null
  for p in "${PIDS[@]}"; do kill "$p" 2>/dev/null; done
  cd /; rm -rf "$DEMO_DIR"
}
trap cleanup EXIT
fp() { python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()'; }
P=$(fp); B1=$(fp); B2=$(fp)
mkdir -p n/logs n/temp site/img
echo "<h1>Bienvenue</h1>" > site/index.html; echo "png" > site/img/a.png; echo "png" > site/autre.png; echo "page 404 perso" > site/404.html
cat > be.py <<'EOF'
import sys, http.server
port, name = int(sys.argv[1]), sys.argv[2]
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        b = f"serveur {name} a recu {self.path} (X-Forwarded-For={self.headers.get('X-Forwarded-For','-')})\n".encode()
        self.send_response(200); self.send_header('Content-Length', str(len(b))); self.end_headers(); self.wfile.write(b)
    def log_message(self, *a): pass
http.server.ThreadingHTTPServer(('127.0.0.1', port), H).serve_forever()
EOF
python3 be.py "$B1" A >/dev/null 2>&1 </dev/null & PIDS+=($!)
python3 be.py "$B2" B >/dev/null 2>&1 </dev/null & PIDS+=($!)
USERLINE=""; [[ $EUID -eq 0 ]] && USERLINE="user root;"   # en root, workers « nobody » ne liraient pas le dossier temporaire (700)
cat > n/nginx.conf <<EOF
$USERLINE
worker_processes 1; pid logs/nginx.pid; error_log logs/error.log;
events { worker_connections 64; }
http {
  include /etc/nginx/mime.types;
  server_tokens off;
  client_body_temp_path temp/c; proxy_temp_path temp/p; fastcgi_temp_path temp/f; uwsgi_temp_path temp/u; scgi_temp_path temp/s;
  access_log logs/access.log;
  upstream app { server 127.0.0.1:$B1; server 127.0.0.1:$B2; }
  server {
    listen 127.0.0.1:$P;
    root $DEMO_DIR/site;
    error_page 404 /404.html;
    location / { try_files \$uri \$uri/ =404; }
    location ^~ /img/ { add_header X-Zone "prefixe-prioritaire"; }
    location ~* \.png\$ { add_header X-Zone "regex-png"; }
    location = /exact { return 200 "exact\n"; }
    location /api/ { proxy_pass http://app/; proxy_set_header X-Forwarded-For \$remote_addr; }
    location = /vieux { return 301 /nouveau; }
  }
}
EOF
N="nginx -p $DEMO_DIR/n -c $DEMO_DIR/n/nginx.conf -e $DEMO_DIR/n/logs/error.log"
C="curl --noproxy '*' -s"

demo_title "Valider puis démarrer"
demo_run "$N -t"
demo_run "$N && sleep 0.5 && ss -ltn 'sport = :$P' | tail -1"
demo_run "$C -D - http://127.0.0.1:$P/ | head -8"
demo_say "server_tokens off → « Server: nginx » sans numéro de version."

demo_title "Sélection des location : exact, préfixe prioritaire, regex"
demo_run "$C http://127.0.0.1:$P/exact"
demo_run "$C -I http://127.0.0.1:$P/img/a.png | grep -i x-zone"
demo_say "^~ /img/ gagne contre la regex .png : le préfixe prioritaire coupe l'évaluation des regex."
demo_run "$C -I http://127.0.0.1:$P/autre.png | grep -i -E 'x-zone|HTTP'"

demo_title "Erreurs et redirections"
demo_run "$C -o /dev/null -w '%{http_code}\\n' http://127.0.0.1:$P/absent; $C http://127.0.0.1:$P/absent"
demo_run "$C -I http://127.0.0.1:$P/vieux | grep -i -E 'HTTP|location'"

demo_title "Reverse proxy et round-robin"
demo_run "for i in 1 2 3 4; do $C http://127.0.0.1:$P/api/produits; done"
demo_say "Chaque requête alterne A/B ; le préfixe /api est retiré par le / final du proxy_pass."
demo_run "kill ${PIDS[0]}; sleep 0.3; for i in 1 2 3; do $C -o /dev/null -w '%{http_code} ' http://127.0.0.1:$P/api/x; done; echo"
demo_say "Un backend en panne : nginx tente l'autre (proxy_next_upstream par défaut: error timeout) — les 502 éventuels montrent l'intérêt de max_fails/proxy_next_upstream."

demo_title "Journaux et analyse rapide"
demo_run "awk '{print \$9}' n/logs/access.log | sort | uniq -c | sort -rn"
demo_run "tail -2 n/logs/error.log | cut -c1-120"

demo_title "Config cassée : nginx -t protège la production"
demo_run "sed -i 's/server_tokens off;/server_tokens off/' n/nginx.conf; $N -t 2>&1 | head -3"
demo_run "sed -i 's/server_tokens off$/server_tokens off;/' n/nginx.conf; $N -t 2>&1 | tail -1; $N -s reload && echo 'rechargé sans coupure'"
demo_end
