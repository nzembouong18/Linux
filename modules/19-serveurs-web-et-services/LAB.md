# Labo 19 — Construire une passerelle web nginx : statique, reverse proxy, sécurité

> **Durée** : 4 h · **Difficulté** : ⭐⭐⭐⭐ · **Prérequis** : module 19 · outil : `nginx`, `curl`, `openssl`
> nginx tourne **dans le dossier du labo** (préfixe privé, ports hauts, sans root) : rien dans `/etc/nginx`.

## Contexte

L'équipe vous demande une **passerelle web** devant deux instances d'une API interne. Elle doit servir le site statique, répartir la charge, protéger la page de connexion et la zone d'administration, et renvoyer les bons en-têtes. Le correcteur **démarre nginx avec votre configuration** et la teste avec `curl`.

## Mise en place

```bash
./lab setup 19
cd ~/labs/19 && cat ports.txt && ls -R site nginx | head -30
```

- `ports.txt` : le port d'écoute de votre nginx (`HTTP_PORT`) et ceux des deux backends (`BACKEND1`, `BACKEND2`).
- `site/` : contenu statique (`index.html`, `style.txt`, `404.html`, `admin/index.html`).
- `nginx/nginx.conf` : squelette fonctionnel à compléter (chemins temporaires déjà réglés).

Pour tester vous-même :

```bash
nginx -t -p ~/labs/19/nginx -c ~/labs/19/nginx/nginx.conf -e ~/labs/19/nginx/logs/error.log
nginx    -p ~/labs/19/nginx -c ~/labs/19/nginx/nginx.conf -e ~/labs/19/nginx/logs/error.log   # démarre
nginx    -p ~/labs/19/nginx -c ~/labs/19/nginx/nginx.conf -e ~/labs/19/nginx/logs/error.log -s reload
nginx    -p ~/labs/19/nginx -c ~/labs/19/nginx/nginx.conf -e ~/labs/19/nginx/logs/error.log -s stop
```

## Cahier des charges (fichier `nginx/nginx.conf`)

Écoutez sur `127.0.0.1:HTTP_PORT` et implémentez :

1. **Statique** : `/` sert `site/` (`root` absolu). Désactivez l'affichage de la version (`server_tokens off`).
2. **Page 404 personnalisée** : toute URL inconnue renvoie le statut **404** avec le contenu de `site/404.html`.
3. **API proxifiée** : `/api/…` est envoyé aux **deux backends** (`upstream` en round-robin) en **retirant** le préfixe `/api` (le backend reçoit `/hello` pour `/api/hello`). Transmettez `Host` (`$http_host`) et `X-Forwarded-For` (`$remote_addr`).
4. **Redirection** : `/ancien` → **301** vers `/nouveau`.
5. **Compression** : `gzip` pour `text/plain` (réponse compressée si le client envoie `Accept-Encoding: gzip`, fichiers > 256 octets).
6. **En-têtes de sécurité** sur toutes les réponses (même les erreurs) : `X-Content-Type-Options: nosniff` et `X-Frame-Options: DENY`.
7. **Limitation de débit** : `/login` (qui sert le fichier statique `site/login.txt`, contenu `login ok`) est limité à **1 requête/seconde** par IP **sans rafale** ; les requêtes en trop reçoivent **429**.
8. **Zone d'administration** : `/admin/` exige une authentification **Basic** (utilisateur `admin`, mot de passe `formation`) via un fichier `nginx/htpasswd` — sans identifiants : **401**.
9. **Journal d'accès** : format personnalisé contenant `rt=$request_time` et `up=$upstream_addr`, écrit dans `nginx/logs/access.log`.

## Validation

```bash
./lab check 19
```

<details><summary>💡 Indices</summary>

- Hachage du mot de passe : `echo "admin:$(openssl passwd -apr1 formation)" > nginx/htpasswd`
- `error_page 404 /404.html;` + `location = /404.html { internal; }`
- `proxy_pass http://pool/;` (avec le `/` final) dans `location /api/`.
- `limit_req_zone $binary_remote_addr zone=login:1m rate=1r/s;` et, dans la location, `limit_req zone=login; limit_req_status 429;`
- ⚠️ `return` s'exécute **avant** `limit_req` (phase *rewrite*) : servez plutôt un fichier avec `try_files /login.txt =404;`.
- Si vous êtes **root**, ajoutez `user root;` en tête de `nginx.conf` (sinon les workers, en `nobody`, ne peuvent pas lire `~/labs`).
- `add_header … always;` pour que les en-têtes soient présents aussi sur les erreurs.
- Les chemins `root` et `auth_basic_user_file` doivent être **absolus** ou relatifs au préfixe `nginx/` pour le fichier d'auth.
</details>

<details><summary>✅ Solution</summary>

```bash
cd ~/labs/19
. ./ports.txt
echo "admin:$(openssl passwd -apr1 formation)" > nginx/htpasswd
cat > nginx/nginx.conf <<EOF
$( [ "$(id -u)" = 0 ] && echo 'user root;' )
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
nginx -t -p $PWD/nginx -c $PWD/nginx/nginx.conf -e $PWD/nginx/logs/error.log
```
</details>

## Pour aller plus loin

- Passez en **HTTPS** avec un certificat auto-signé (`openssl req -x509 …`) et redirigez HTTP → HTTPS.
- Ajoutez `least_conn`, des poids, et un backend `backup`. Arrêtez un backend et constatez le basculement (`max_fails`, `proxy_next_upstream`).
- Mettez en place un cache (`proxy_cache`) et l'en-tête `X-Cache-Status`.
- Mesurez avec `ab -n 500 -c 20 http://127.0.0.1:PORT/` avant/après gzip et cache.

## Nettoyage

```bash
./lab reset 19     # arrête nginx et les backends
```
