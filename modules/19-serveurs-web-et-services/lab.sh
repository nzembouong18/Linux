#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/lib.sh"
LAB_ID=19
LAB_REQUIRES=(cmd:nginx cmd:curl cmd:python3 cmd:openssl)

free_port() { python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()'; }
NGX_ARGS() { echo "-p $LAB_DIR/nginx -c $LAB_DIR/nginx/nginx.conf -e $LAB_DIR/nginx/logs/error.log"; }
# shellcheck disable=SC2046
ngx() { nginx $(NGX_ARGS) "$@"; }

lab_cleanup() {
  [[ -d "$LAB_DIR" ]] || return 0
  if [[ -f "$LAB_DIR/nginx/logs/nginx.pid" ]]; then kill "$(cat "$LAB_DIR/nginx/logs/nginx.pid")" 2>/dev/null; fi
  local f; for f in "$LAB_DIR"/.backend1.pid "$LAB_DIR"/.backend2.pid; do [[ -f "$f" ]] && kill "$(cat "$f")" 2>/dev/null; done
  return 0
}

lab_setup() {
  cd "$LAB_DIR" || return 1
  lab_cleanup
  rm -rf site nginx ports.txt backend.py .backend*.pid
  mkdir -p site/admin nginx/logs nginx/temp
  local tok; tok="WEB-$(head -c 5 /dev/urandom | od -An -tx1 | tr -d ' \n')"
  echo "<html><body><h1>Accueil</h1><p>jeton: $tok</p></body></html>" > site/index.html
  echo "$tok" > .token
  for i in $(seq 1 400); do echo "Ligne $i : texte répétitif répétitif répétitif pour tester la compression gzip."; done > site/style.txt
  echo "<html><body><h1>Page introuvable (404 personnalisée)</h1></body></html>" > site/404.html
  echo "<html><body>Zone d'administration</body></html>" > site/admin/index.html
  echo "login ok" > site/login.txt
  if [[ -f /etc/nginx/mime.types ]]; then cp /etc/nginx/mime.types nginx/mime.types
  else printf 'types {\n text/html html;\n text/css css;\n text/plain txt;\n}\n' > nginx/mime.types; fi
  cat > backend.py <<'EOF'
import sys, http.server
port, name = int(sys.argv[1]), sys.argv[2]
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        body = f"backend={name} path={self.path} xff={self.headers.get('X-Forwarded-For','-')} host={self.headers.get('Host','-')}\n".encode()
        self.send_response(200); self.send_header('Content-Type', 'text/plain')
        self.send_header('Content-Length', str(len(body))); self.end_headers(); self.wfile.write(body)
    def log_message(self, *a): pass
http.server.ThreadingHTTPServer(('127.0.0.1', port), H).serve_forever()
EOF
  local hp b1 b2; hp=$(free_port); b1=$(free_port); b2=$(free_port)
  printf 'HTTP_PORT=%s\nBACKEND1=%s\nBACKEND2=%s\n' "$hp" "$b1" "$b2" > ports.txt
  nohup python3 backend.py "$b1" 1 >/dev/null 2>&1 </dev/null & echo $! > .backend1.pid
  nohup python3 backend.py "$b2" 2 >/dev/null 2>&1 </dev/null & echo $! > .backend2.pid
  # En root, les workers passent par défaut en « nobody » et ne pourraient pas lire ~/labs (700) : on garde l'identité courante
  local userline=""; [[ $EUID -eq 0 ]] && userline="user root;"
  cat > nginx/nginx.conf <<EOF
# Squelette fourni : à compléter selon le cahier des charges (modules/19-serveurs-web-et-services/LAB.md)
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
    access_log logs/access.log;

    server {
        listen 127.0.0.1:$hp;
        root $LAB_DIR/site;
        location / { try_files \$uri \$uri/ =404; }
    }
}
EOF
  sleep 0.5
}

lab_check() {
  cd "$LAB_DIR" || return 1
  . ./ports.txt
  local base="http://127.0.0.1:$HTTP_PORT" tok; tok=$(cat .token)
  local C=(curl --noproxy '*' -s --max-time 5)
  assert "nginx -t : configuration valide" ngx -t
  # (re)démarrer nginx avec la configuration de l'étudiant
  if [[ -f nginx/logs/nginx.pid ]]; then kill "$(cat nginx/logs/nginx.pid)" 2>/dev/null; sleep 0.4; fi
  rm -f nginx/logs/access.log
  ngx >/dev/null 2>&1
  local i; for i in $(seq 1 25); do "${C[@]}" -o /dev/null "$base/" && break; sleep 0.2; done

  assert "1 GET / : page statique avec le jeton" bash -c "curl --noproxy '*' -s '$base/' | grep -q '$tok'"
  local srv; srv=$("${C[@]}" -D - -o /dev/null "$base/" | tr -d '\r' | awk -F': ' 'tolower($1)=="server"{print $2}')
  assert "1 en-tête Server sans numéro de version (server_tokens off)" bash -c "[[ '$srv' == nginx ]]"
  local code body
  code=$("${C[@]}" -o /tmp/.lab19.body -w '%{http_code}' "$base/introuvable"); body=$(cat /tmp/.lab19.body); rm -f /tmp/.lab19.body
  assert_eq "2 URL inconnue : statut 404" 404 "$code"
  assert "2 404 personnalisée (contenu de 404.html)" bash -c "[[ \"\$1\" == *'Page introuvable (404 personnalisée)'* ]]" _ "$body"

  # 3. API : 6 requêtes
  local r1 r2 b1=0 b2=0 out paths_ok=1 xff_ok=1 host_ok=1
  for i in 1 2 3 4 5 6; do
    out=$("${C[@]}" "$base/api/hello")
    [[ "$out" == *backend=1* ]] && b1=$((b1 + 1)); [[ "$out" == *backend=2* ]] && b2=$((b2 + 1))
    [[ "$out" == *"path=/hello "* ]] || paths_ok=0
    [[ "$out" == *"xff=127.0.0.1"* ]] || xff_ok=0
    [[ "$out" == *"host=127.0.0.1"* ]] || host_ok=0
  done
  assert_eq "3 round-robin : 3 réponses du backend 1" 3 "$b1"
  assert_eq "3 round-robin : 3 réponses du backend 2" 3 "$b2"
  assert_eq "3 préfixe /api retiré (le backend reçoit /hello)" 1 "$paths_ok"
  assert_eq "3 X-Forwarded-For transmis" 1 "$xff_ok"
  assert_eq "3 Host transmis" 1 "$host_ok"

  local loc; loc=$("${C[@]}" -D - -o /dev/null "$base/ancien" | tr -d '\r')
  assert "4 /ancien : statut 301" bash -c "head -1 <<<\"\$1\" | grep -q ' 301 '" _ "$loc"
  assert "4 /ancien : Location → /nouveau" bash -c "grep -i '^location:' <<<\"\$1\" | grep -q '/nouveau'" _ "$loc"

  local gz; gz=$("${C[@]}" -D - -o /dev/null -H 'Accept-Encoding: gzip' "$base/style.txt" | tr -d '\r')
  assert "5 gzip : Content-Encoding: gzip sur /style.txt" bash -c "grep -iq '^content-encoding: *gzip' <<<\"\$1\"" _ "$gz"

  local hdr; hdr=$("${C[@]}" -D - -o /dev/null "$base/" | tr -d '\r')
  assert "6 X-Content-Type-Options: nosniff" bash -c "grep -iq '^x-content-type-options: *nosniff' <<<\"\$1\"" _ "$hdr"
  assert "6 X-Frame-Options: DENY" bash -c "grep -iq '^x-frame-options: *DENY' <<<\"\$1\"" _ "$hdr"
  local h404; h404=$("${C[@]}" -D - -o /dev/null "$base/zzz" | tr -d '\r')
  assert "6 en-têtes présents aussi sur les erreurs (always)" bash -c "grep -iq '^x-frame-options: *DENY' <<<\"\$1\"" _ "$h404"

  local codes=() n; for n in $(seq 1 8); do codes+=("$("${C[@]}" -o /dev/null -w '%{http_code}' "$base/login")"); done
  assert "7 /login : première requête acceptée (200)" bash -c "[[ '${codes[0]}' == 200 ]]"
  assert "7 /login : les rafales sont refusées (429)" bash -c "printf '%s\n' ${codes[*]} | grep -q 429"
  assert "7 /login : corps « login ok »" bash -c "sleep 1.2; curl --noproxy '*' -s '$base/login' | grep -q 'login ok'"

  assert_eq "8 /admin/ sans identifiants : 401" 401 "$("${C[@]}" -o /dev/null -w '%{http_code}' "$base/admin/")"
  assert_eq "8 /admin/ avec admin:formation : 200" 200 "$("${C[@]}" -u admin:formation -o /dev/null -w '%{http_code}' "$base/admin/")"
  assert_eq "8 /admin/ mauvais mot de passe : 401" 401 "$("${C[@]}" -u admin:mauvais -o /dev/null -w '%{http_code}' "$base/admin/")"

  sleep 0.3
  assert_grep "9 access.log : champ rt=" 'rt=[0-9.]+' nginx/logs/access.log
  assert_grep "9 access.log : champ up= (adresse du backend)" 'up=127\.0\.0\.1:[0-9]+' nginx/logs/access.log
}

lab_solve() {
  cd "$LAB_DIR" || return 1
  . ./ports.txt
  echo "admin:$(openssl passwd -apr1 formation)" > nginx/htpasswd
  local userline=""; [[ $EUID -eq 0 ]] && userline="user root;"
  cat > nginx/nginx.conf <<EOF
$userline
worker_processes 1;
pid logs/nginx.pid;
error_log logs/error.log;
events { worker_connections 128; }
http {
    include mime.types;
    default_type application/octet-stream;
    server_tokens off;
    client_body_temp_path temp/client; proxy_temp_path temp/proxy; fastcgi_temp_path temp/fcgi;
    uwsgi_temp_path temp/uwsgi; scgi_temp_path temp/scgi;

    log_format main '\$remote_addr "\$request" \$status rt=\$request_time up=\$upstream_addr';
    access_log logs/access.log main;

    gzip on; gzip_min_length 256; gzip_types text/plain;
    limit_req_zone \$binary_remote_addr zone=login:1m rate=1r/s;

    upstream pool {
        server 127.0.0.1:$BACKEND1;
        server 127.0.0.1:$BACKEND2;
    }

    server {
        listen 127.0.0.1:$HTTP_PORT;
        root $PWD/site;
        add_header X-Content-Type-Options nosniff always;
        add_header X-Frame-Options DENY always;
        error_page 404 /404.html;
        location = /404.html { internal; }

        location / { try_files \$uri \$uri/ =404; }
        location /api/ {
            proxy_pass http://pool/;
            proxy_set_header Host \$http_host;
            proxy_set_header X-Forwarded-For \$remote_addr;
        }
        location = /ancien { return 301 /nouveau; }
        location = /login {
            limit_req zone=login;
            limit_req_status 429;
            default_type text/plain;
            try_files /login.txt =404;
        }
        location /admin/ {
            auth_basic "Zone admin";
            auth_basic_user_file $PWD/nginx/htpasswd;
        }
    }
}
EOF
  ngx -t 2>/dev/null
}

lab_main "$@"
