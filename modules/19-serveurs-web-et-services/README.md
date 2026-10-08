# Module 19 — Serveurs web, reverse proxy, TLS et services applicatifs

> **Niveau** : Avancé | **Durée** : 7 h (3 h cours + 4 h labo) | **Prérequis** : modules 11, 14, 16
>
> **Objectifs** — À la fin de ce module vous saurez :
> - expliquer HTTP (méthodes, codes, en-têtes) et l'architecture d'un serveur web ;
> - installer et configurer **nginx** : serveurs virtuels, `location`, fichiers statiques, redirections ;
> - mettre en place un **reverse proxy** et un **répartiteur de charge** ;
> - sécuriser : TLS (Let's Encrypt), en-têtes de sécurité, limitation de débit, authentification ;
> - optimiser (gzip, cache, `keepalive`) et journaliser ;
> - diagnostiquer les erreurs classiques (403, 404, 502, 504) ;
> - situer Apache, HAProxy, PHP-FPM, bases de données et caches dans une architecture.

---

## 1. HTTP en 10 minutes

```text
Client                                              Serveur
  │  GET /produits?page=2 HTTP/1.1                    │
  │  Host: www.example.org                            │
  │  Accept-Encoding: gzip                            │
  │  User-Agent: curl/8.5                             │
  │ ─────────────────────────────────────────────────►│
  │                                                   │
  │  HTTP/1.1 200 OK                                  │
  │  Content-Type: text/html; charset=utf-8           │
  │  Content-Encoding: gzip                           │
  │  Cache-Control: max-age=3600                      │
  │ ◄─────────────────────────────────────────────────│
  │  <corps de la réponse>                            │
```

| Méthode | Usage | Idempotente |
|---------|-------|:-----------:|
| GET | lire une ressource | oui |
| POST | créer / déclencher | non |
| PUT / PATCH | remplacer / modifier | oui / non |
| DELETE | supprimer | oui |
| HEAD / OPTIONS | en-têtes seuls / capacités (CORS) | oui |

| Famille | Exemples |
|---------|----------|
| **2xx** succès | 200 OK, 201 Created, 204 No Content |
| **3xx** redirection | 301 permanente, 302/307 temporaire, 304 Not Modified |
| **4xx** erreur client | 400, 401 (non authentifié), 403 (interdit), 404, 405, 429 (trop de requêtes) |
| **5xx** erreur serveur | 500, 502 Bad Gateway, 503 Service Unavailable, 504 Gateway Timeout |

HTTP/1.1 : connexions persistantes (*keep-alive*). HTTP/2 : multiplexage, compression d'en-têtes. HTTP/3 : QUIC (UDP). **HTTPS** = HTTP dans TLS.

```bash
curl -v http://localhost/                     # requête + réponse détaillées
curl -I http://localhost/                     # seulement les en-têtes
curl -s -o /dev/null -w '%{http_code} %{time_total}s %{size_download}B\n' URL
curl -H 'Host: www.example.org' http://127.0.0.1/      # tester un vhost sans DNS
curl -D - -o /dev/null -H 'Accept-Encoding: gzip' URL  # en-têtes d'une réponse compressée
curl -u user:pass URL ; curl -L URL (suit les redirections) ; curl -k (ignore le certificat : tests seulement !)
```

## 2. Architecture des serveurs web

| | **nginx** | **Apache httpd** |
|---|-----------|------------------|
| Modèle | événementiel asynchrone (quelques workers, des milliers de connexions) | MPM `event`/`worker`/`prefork` |
| Atouts | fichiers statiques, reverse proxy, répartition de charge, faible mémoire | modules riches, `.htaccess` par dossier, écosystème historique |
| Config | fichiers `nginx.conf` + `conf.d`/`sites-enabled` | `apache2.conf`, `a2ensite`, `a2enmod` |

Architecture classique moderne :

```text
 Internet ─► [ Pare-feu ] ─► [ nginx / HAProxy ] ─┬─► appli 1 (Python/Java/Node/PHP-FPM) ─┐
                 TLS, cache, limites, WAF         ├─► appli 2                            ├─► PostgreSQL / Redis
                                                  └─► statiques (CDN, disque)            ┘
```

## 3. nginx : installation et structure

```bash
sudo apt install nginx            # Debian/Ubuntu    ·    sudo dnf install nginx   # RHEL
sudo systemctl enable --now nginx
nginx -v ; nginx -V               # version / options de compilation
sudo nginx -t                     # TESTE la configuration (toujours avant un reload)
sudo systemctl reload nginx       # rechargement sans coupure
```

| Chemin | Rôle |
|--------|------|
| `/etc/nginx/nginx.conf` | configuration principale |
| `/etc/nginx/conf.d/*.conf` | fragments (RHEL, Docker) |
| `/etc/nginx/sites-available/` + `sites-enabled/` | vhosts (Debian) : on active par lien symbolique |
| `/var/log/nginx/access.log`, `error.log` | journaux |
| `/usr/share/nginx/html`, `/var/www/html` | racine par défaut |

### Anatomie de la configuration (contextes imbriqués)

```nginx
user www-data;
worker_processes auto;                         # 1 par cœur
pid /run/nginx.pid;
events { worker_connections 1024; }

http {                                         # contexte http
    include       mime.types;
    default_type  application/octet-stream;
    sendfile      on;
    keepalive_timeout 65;
    server_tokens off;                         # cache la version

    log_format main '$remote_addr [$time_local] "$request" $status $body_bytes_sent '
                    'rt=$request_time up=$upstream_addr ua="$http_user_agent"';
    access_log /var/log/nginx/access.log main;

    server {                                   # un « virtual host »
        listen 80;
        server_name www.example.org example.org;
        root /var/www/example;
        index index.html;

        location / {                           # selon l'URL demandée
            try_files $uri $uri/ =404;
        }
        location /images/ { expires 30d; }
        error_page 404 /404.html;
    }
}
```

Une directive se termine par `;`. Les directives sont **héritées** du contexte parent et **surchargées** localement (attention : `add_header`/`proxy_set_header` d'un niveau inférieur **remplacent** ceux du niveau supérieur au lieu de s'ajouter).

### Choix du `server` puis du `location`

- **server** : `listen` (IP:port) puis `server_name` (en-tête `Host`) ; à défaut, le `default_server`.
- **location** — ordre d'évaluation :
  1. `location = /exact` : correspondance exacte (arrêt immédiat) ;
  2. `location ^~ /prefixe` : préfixe prioritaire (pas de regex ensuite) ;
  3. `location ~ \.php$` / `~*` (insensible à la casse) : **regex**, premier qui correspond dans l'ordre du fichier ;
  4. `location /prefixe` : préfixe **le plus long**.

```nginx
location = /          { return 200 "accueil\n"; }
location ^~ /static/  { root /srv/assets; }               # /static/a.css → /srv/assets/static/a.css
location ~* \.(jpg|png|css)$ { expires 7d; }
location /docs/       { alias /srv/documentation/; }       # alias remplace le préfixe : /docs/a → /srv/documentation/a
location /            { try_files $uri $uri/ /index.html; }   # SPA
```
`root` **ajoute** l'URL au chemin ; `alias` **remplace** la partie préfixe (piège classique : slash final).

### Redirections et réécritures

```nginx
return 301 https://$host$request_uri;                       # HTTP → HTTPS
location = /ancien { return 301 /nouveau; }
rewrite ^/blog/(\d+)$ /articles/$1 permanent;
server { listen 80; server_name www.example.org; return 301 https://example.org$request_uri; }
```

## 4. Reverse proxy et répartition de charge

```nginx
upstream application {
    least_conn;                                  # ou ip_hash; (défaut : round-robin)
    server 10.0.0.11:8080 weight=3 max_fails=3 fail_timeout=10s;
    server 10.0.0.12:8080;
    server 10.0.0.13:8080 backup;                # utilisé seulement si les autres tombent
    keepalive 32;
}
server {
    listen 80;
    location /api/ {
        proxy_pass http://application/;          # le "/" final retire le préfixe /api/
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 3s;
        proxy_read_timeout    30s;
        proxy_next_upstream error timeout http_502 http_503;   # reprend sur un autre serveur
    }
    location /ws/ {                               # WebSocket
        proxy_pass http://application;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

| Algorithme | Principe |
|------------|----------|
| round-robin | tour à tour (poids possibles) |
| `least_conn` | vers le serveur le moins chargé |
| `ip_hash` | même client → même serveur (affinité simple) |
| `hash $request_uri consistent` | cache distribué |

L'application derrière un proxy voit l'IP du proxy : elle doit lire `X-Forwarded-For`/`X-Real-IP` (et ne leur faire confiance que si le proxy est de confiance).

### Cache

```nginx
proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=cache:10m max_size=1g inactive=60m;
location / {
    proxy_cache cache;
    proxy_cache_valid 200 301 10m;
    proxy_cache_use_stale error timeout updating;
    add_header X-Cache-Status $upstream_cache_status;
    proxy_pass http://application;
}
```

## 5. TLS / HTTPS

```bash
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d example.org -d www.example.org       # obtient + installe un certificat Let's Encrypt
sudo certbot renew --dry-run ; systemctl list-timers | grep certbot     # renouvellement automatique (90 jours)
```

Configuration manuelle recommandée :

```nginx
server {
    listen 443 ssl;
    http2 on;
    server_name example.org;
    ssl_certificate     /etc/letsencrypt/live/example.org/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/example.org/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_stapling on; ssl_stapling_verify on;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;   # HSTS
}
```

```bash
# Certificat auto-signé (tests uniquement)
openssl req -x509 -newkey rsa:4096 -nodes -keyout key.pem -out cert.pem -days 365 -subj "/CN=localhost"
openssl x509 -in cert.pem -noout -subject -dates -issuer
echo | openssl s_client -connect example.org:443 -servername example.org 2>/dev/null | openssl x509 -noout -dates -subject
curl -vI https://example.org 2>&1 | grep -E 'SSL|subject|expire'
```
Une chaîne complète = certificat serveur + intermédiaires (`fullchain.pem`). Surveillez l'expiration (supervision, module 23). Évaluation externe : *SSL Labs*, `testssl.sh`.

## 6. Sécurité et robustesse

```nginx
server_tokens off;
add_header X-Content-Type-Options nosniff always;
add_header X-Frame-Options DENY always;
add_header Referrer-Policy strict-origin-when-cross-origin always;
add_header Content-Security-Policy "default-src 'self'" always;

# Limiter le débit (anti brute-force / abus)
limit_req_zone $binary_remote_addr zone=login:10m rate=5r/m;
limit_conn_zone $binary_remote_addr zone=perip:10m;
location = /login { limit_req zone=login burst=3 nodelay; limit_req_status 429; proxy_pass http://application; }
location /download/ { limit_conn perip 2; limit_rate 500k; }

# Contrôle d'accès
location /admin/ {
    allow 10.0.0.0/8; deny all;                           # par IP
    auth_basic "Zone admin";                              # ou par mot de passe
    auth_basic_user_file /etc/nginx/htpasswd;
}
# Taille / délais
client_max_body_size 10m;  client_body_timeout 10s;  send_timeout 10s;
# Interdire les fichiers sensibles
location ~ /\.(?!well-known) { deny all; }
```
```bash
openssl passwd -apr1                       # génère un hachage pour le fichier htpasswd (ou : htpasswd -c f user)
```
En production : WAF (ModSecurity, Coraza), fail2ban sur le journal nginx, mises à jour, utilisateur non-root pour les workers.

## 7. Performances

```nginx
gzip on; gzip_comp_level 5; gzip_min_length 256; gzip_types text/plain text/css application/json application/javascript image/svg+xml;
sendfile on; tcp_nopush on; tcp_nodelay on;
open_file_cache max=2000 inactive=20s;
location ~* \.(css|js|png|jpg|svg|woff2)$ { expires 30d; add_header Cache-Control "public, immutable"; }
```
```bash
ab -n 2000 -c 50 http://127.0.0.1/            # test de charge rapide (ApacheBench)
wrk -t4 -c100 -d30s http://127.0.0.1/         # plus précis
```
Systèmes : `worker_rlimit_nofile`, `ulimit -n`, `net.core.somaxconn`.

## 8. PHP-FPM, applications et services

```nginx
location ~ \.php$ {
    include snippets/fastcgi-php.conf;
    fastcgi_pass unix:/run/php/php8.3-fpm.sock;
}
```
- **Python** : `gunicorn`/`uvicorn` derrière nginx (`proxy_pass http://unix:/run/app.sock;`) géré par une **unité systemd** (module 14).
- **Node.js** : `pm2` ou systemd ; **Java** : jar Spring Boot en service systemd.
- **Bases de données** : PostgreSQL (`sudo apt install postgresql`, `sudo -u postgres psql`, `pg_hba.conf`, `pg_dump`), MariaDB (`mysql_secure_installation`), Redis (`redis-cli ping`). Ne les exposez **jamais** sur Internet ; pare-feu + `listen_addresses`.
- **Messagerie** : Postfix (SPF, DKIM, DMARC) ; **fichiers** : Samba/NFS (module 13).

## 9. Apache httpd (essentiel)

```bash
sudo apt install apache2
sudo a2enmod rewrite ssl proxy proxy_http headers ; sudo a2ensite example.conf ; sudo a2dissite 000-default
sudo apachectl configtest && sudo systemctl reload apache2
```
```apache
<VirtualHost *:80>
    ServerName www.example.org
    DocumentRoot /var/www/example
    <Directory /var/www/example>
        Options -Indexes +FollowSymLinks
        AllowOverride None
        Require all granted
    </Directory>
    ProxyPass /api/ http://127.0.0.1:8080/
    ProxyPassReverse /api/ http://127.0.0.1:8080/
    ErrorLog ${APACHE_LOG_DIR}/example-error.log
    CustomLog ${APACHE_LOG_DIR}/example-access.log combined
</VirtualHost>
```
`.htaccess` : pratique mais coûteux (relu à chaque requête) → préférez la config centrale (`AllowOverride None`).

## 10. HAProxy (aperçu)

```text
frontend https_in
    bind :443 ssl crt /etc/haproxy/certs/site.pem
    default_backend app
backend app
    balance leastconn
    option httpchk GET /health
    server a1 10.0.0.11:8080 check
    server a2 10.0.0.12:8080 check
```
HAProxy excelle en répartition L4/L7 avec vérifications de santé actives, statistiques et haute disponibilité (avec keepalived, module 24).

## 11. Dépannage

| Erreur | Causes fréquentes | Commandes |
|--------|-------------------|-----------|
| **403 Forbidden** | droits (le user de nginx doit **traverser** tous les dossiers parents : `x`), pas d'`index`, `deny`, SELinux (`restorecon`) | `namei -l /var/www/site/index.html`, `ls -Z` |
| **404 Not Found** | mauvais `root`/`alias`, `try_files`, casse | `nginx -T \| grep -n root`, `error.log` |
| **502 Bad Gateway** | application arrêtée/crashée, mauvais port/socket, SELinux (`httpd_can_network_connect`) | `ss -ltnp`, `curl` direct sur le backend, `journalctl -u app` |
| **504 Gateway Timeout** | application trop lente, `proxy_read_timeout` | durée côté appli, `$upstream_response_time` |
| **413** | `client_max_body_size` trop petit | |
| **Config non prise en compte** | pas de `reload`, mauvais fichier (`nginx -T` affiche la config effective) | `sudo nginx -T` |
| **Port déjà utilisé** | autre service | `ss -ltnp \| grep :80` |
| **Certificat expiré** | renouvellement en échec | `certbot renew`, `journalctl -u certbot` |

```bash
sudo tail -F /var/log/nginx/error.log
sudo nginx -T | less                      # configuration effective complète (includes développés)
awk '{print $9}' /var/log/nginx/access.log | sort | uniq -c | sort -rn     # codes HTTP
awk '$9 ~ /^5/ {print $7}' /var/log/nginx/access.log | sort | uniq -c | sort -rn | head      # URL en erreur 5xx
```

## 12. Résumé

- HTTP : méthodes, codes (2xx/3xx/4xx/5xx), en-têtes ; `curl -v/-I/-w` pour tester.
- nginx : `http > server > location` ; ordre de sélection des `location` (`=`, `^~`, regex, préfixe le plus long) ; `root` vs `alias` ; **`nginx -t` puis reload**.
- Reverse proxy : `upstream`, `proxy_pass`, en-têtes `Host`/`X-Forwarded-*`, timeouts, répartition (round-robin, `least_conn`, `ip_hash`).
- Sécurité : TLS (certbot), HSTS, en-têtes, `limit_req`, `auth_basic`, `server_tokens off`.
- Perf : gzip, cache, `sendfile`, `keepalive`, tests `ab`/`wrk`.
- Diagnostic : 403 (droits/SELinux), 404 (root), 502 (backend), 504 (lenteur) ; `error.log`.

## 13. Quiz

1. Quelle différence entre un code 301 et 302 ? Entre 502 et 504 ?
2. Dans `location /api/ { proxy_pass http://app/; }` que devient `/api/users` pour le backend ? Et avec `proxy_pass http://app;` ?
3. Quel `location` gagne : `location /images/` ou `location ~* \.png$` pour `/images/a.png` ?
4. Pourquoi `nginx -t` avant `reload` ?
5. Comment l'application connaît-elle l'IP réelle du client derrière un reverse proxy ?
6. Quel mécanisme limite à 5 requêtes par minute une page de connexion ?
7. Vous obtenez 502 : quelles trois vérifications ?
8. Quelle différence entre `root` et `alias` ?

<details><summary>Réponses</summary>

1. 301 : redirection permanente (mise en cache par les navigateurs/SEO) ; 302 : temporaire. 502 : réponse invalide/absence de réponse du backend ; 504 : le backend a dépassé le délai.
2. `/users` (le préfixe est retiré à cause du `/` final) ; avec `http://app;` : `/api/users`.
3. Le `location` regex `~*` (évalué après le préfixe, il l'emporte) — sauf si le préfixe est `^~`.
4. Une configuration invalide empêcherait le rechargement ; `-t` valide la syntaxe sans impacter le service.
5. En-têtes `X-Forwarded-For` / `X-Real-IP` posés par le proxy (et configuration de confiance côté appli).
6. `limit_req_zone … rate=5r/m` + `limit_req zone=… burst=…` sur la `location`.
7. Backend démarré ? (`ss -ltnp`), joignable en direct (`curl` vers upstream), logs applicatifs / `error.log` nginx ; SELinux/pare-feu.
8. `root` concatène le chemin de l'URL à la racine ; `alias` remplace le préfixe de la `location` par le chemin donné.
</details>

➡️ **Labo** : [LAB.md](LAB.md) · **Démo** : `./lab demo 19` · **Suivant** : [20 — Conteneurs et namespaces](../20-conteneurs-et-namespaces/README.md)
