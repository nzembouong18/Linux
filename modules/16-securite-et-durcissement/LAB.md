# Labo 16 — Audit et durcissement d'un serveur (simulé)

> **Durée** : 4 h · **Difficulté** : ⭐⭐⭐⭐ · **Prérequis** : module 16 · `nft` (pour la validation du pare-feu)
> Le « serveur » est une **arborescence de fichiers** (`srv/`) fabriquée par le labo : aucun réglage réel de votre machine n'est modifié.

## Contexte

Vous venez d'hériter du serveur web d'une PME. Avant toute mise en production, le RSSI exige un **audit** puis un **plan de durcissement appliqué**. L'image du serveur est dans `~/labs/16/srv/` (comme si c'était `/`).

## Mise en place

```bash
./lab setup 16
cd ~/labs/16 && tree -a -p srv 2>/dev/null || find srv | head -40
```

## Partie A — Audit : `audit.txt`

Écrivez dans `audit.txt` (format `CLÉ=valeur`) le résultat de votre audit **de l'état initial** (avant correction !). Les listes sont séparées par des virgules, sans espace ; les chemins sont **relatifs à `srv/`**.

| Clé | Contenu |
|-----|---------|
| `UID0` | comptes ayant l'UID 0 (`etc/passwd`) |
| `SANS_MDP` | comptes sans mot de passe (`etc/shadow`, champ vide) |
| `SHELL_SERVICE` | comptes **système** (UID < 1000, hors root) ayant un shell de connexion réel (ni `nologin`, ni `false`, ni `/bin/sync`, `/sbin/shutdown`, `/sbin/halt`) |
| `SUID` | fichiers avec le bit **setuid** |
| `WORLD_WRITABLE` | fichiers/dossiers modifiables par **tous**, hors liens symboliques et hors dossiers à *sticky bit* |
| `SSH_PROBLEMES` | nombre de directives dangereuses dans `etc/ssh/sshd_config` : `PermitRootLogin yes`, `PasswordAuthentication yes`, `PermitEmptyPasswords yes`, `X11Forwarding yes`, `MaxAuthTries` > 4 |
| `NOPASSWD` | sujet (utilisateur ou `%groupe`) disposant de `NOPASSWD` dans `etc/sudoers.d/` |
| `CLE_EXPOSEE` | clé SSH privée lisible par d'autres que son propriétaire |

## Partie B — Correction (appliquée dans `srv/`)

1. La clé privée exposée passe en **600**.
2. Retirez le **setuid** du fichier **non légitime** `usr/local/bin/outil` (conservez celui de `usr/bin/legit-passwd`).
3. Plus **aucun** fichier/dossier world-writable (hors dossiers sticky comme `tmp/`) : dossier `uploads` → `755`, `config.php` → `640`, tâche cron → `644`.
4. `etc/ssh/sshd_config` : `PermitRootLogin no` (ou `prohibit-password`), `PasswordAuthentication no`, `PermitEmptyPasswords no`, `X11Forwarding no`, `MaxAuthTries` ≤ 4 (les autres lignes restent).
5. Comptes : supprimez le compte pirate `toor` (`etc/passwd` **et** `etc/shadow`) ; **verrouillez** `bob` (le champ mot de passe ne doit plus être vide : préfixe `!`) ; le shell de `svc` devient `/usr/sbin/nologin`.
6. `etc/sudoers.d/dev` : plus de `NOPASSWD: ALL`. Autorisez à la place le groupe `%dev` à exécuter **uniquement** `/usr/bin/systemctl restart nginx` (avec mot de passe).
7. `etc/fstab` : la ligne `/tmp` reçoit les options `noexec,nosuid,nodev`.

## Partie C — Pare-feu et noyau

8. Écrivez **`pare-feu.nft`** (règles `nftables`, table `inet`) : chaîne `input` avec `policy drop` ; accepter `ct state established,related` ; l'interface `lo` ; SSH (tcp/22) ; HTTP et HTTPS (tcp/80 et 443) ; limiter le ping (`icmp echo-request`) à un débit raisonnable. Le fichier doit passer `sudo nft -c -f pare-feu.nft`.
9. Écrivez **`99-durcissement.conf`** (format `sysctl`) contenant au moins : `net.ipv4.tcp_syncookies = 1`, `net.ipv4.conf.all.rp_filter = 1`, `net.ipv4.conf.all.accept_redirects = 0`, `net.ipv4.conf.all.send_redirects = 0`, `kernel.randomize_va_space = 2`, `kernel.kptr_restrict` ≥ 1, `kernel.yama.ptrace_scope` ≥ 1, `fs.protected_symlinks = 1`, `fs.protected_hardlinks = 1`.

## Validation

```bash
./lab check 16
```

<details><summary>💡 Indices</summary>

- `awk -F: '$3==0{print $1}' srv/etc/passwd` · `awk -F: '$2==""{print $1}' srv/etc/shadow`
- `find srv -perm -4000 -type f` · `find srv -perm -0002 ! -type l ! -perm -1000`
- `ls -l srv/home/*/.ssh/` · `grep -r NOPASSWD srv/etc/sudoers.d`
- `sed -i` pour les modifications de fichiers de configuration ; `chmod u-s fichier`.
- Syntaxe nft : voir le cours §3. `ct state established,related accept`, `iif "lo" accept`, `tcp dport { 80, 443 } accept`.
</details>

<details><summary>✅ Solution</summary>

```bash
cd ~/labs/16
# --- A (audit de l'état initial)
cat > audit.txt <<'EOF'
UID0=root,toor
SANS_MDP=bob
SHELL_SERVICE=svc
SUID=usr/bin/legit-passwd,usr/local/bin/outil
WORLD_WRITABLE=etc/cron.d/backup,var/www/config.php,var/www/uploads
SSH_PROBLEMES=5
NOPASSWD=%dev
CLE_EXPOSEE=home/alice/.ssh/id_rsa
EOF
# --- B (corrections)
chmod 600 srv/home/alice/.ssh/id_rsa
chmod u-s srv/usr/local/bin/outil
chmod 755 srv/var/www/uploads; chmod 640 srv/var/www/config.php; chmod 644 srv/etc/cron.d/backup
sed -i -e 's/^PermitRootLogin .*/PermitRootLogin no/' -e 's/^PasswordAuthentication .*/PasswordAuthentication no/' \
       -e 's/^PermitEmptyPasswords .*/PermitEmptyPasswords no/' -e 's/^X11Forwarding .*/X11Forwarding no/' \
       -e 's/^MaxAuthTries .*/MaxAuthTries 3/' srv/etc/ssh/sshd_config
sed -i '/^toor:/d' srv/etc/passwd srv/etc/shadow
sed -i 's/^bob::/bob:!:/' srv/etc/shadow
sed -i 's#^\(svc:.*:\)/bin/bash$#\1/usr/sbin/nologin#' srv/etc/passwd
echo '%dev ALL=(root) /usr/bin/systemctl restart nginx' > srv/etc/sudoers.d/dev
sed -i 's#^\(tmpfs[[:space:]]\+/tmp[[:space:]]\+tmpfs[[:space:]]\+\)defaults#\1defaults,noexec,nosuid,nodev#' srv/etc/fstab
# --- C
cat > pare-feu.nft <<'EOF'
flush ruleset
table inet filtre {
    chain input {
        type filter hook input priority 0; policy drop;
        ct state invalid drop
        ct state established,related accept
        iif "lo" accept
        icmp type echo-request limit rate 5/second accept
        tcp dport 22 accept
        tcp dport { 80, 443 } accept
    }
    chain forward { type filter hook forward priority 0; policy drop; }
    chain output  { type filter hook output  priority 0; policy accept; }
}
EOF
sudo nft -c -f pare-feu.nft
cat > 99-durcissement.conf <<'EOF'
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
kernel.randomize_va_space = 2
kernel.kptr_restrict = 2
kernel.yama.ptrace_scope = 1
fs.protected_symlinks = 1
fs.protected_hardlinks = 1
EOF
```
</details>

## Pour aller plus loin

- Faites tourner `lynis audit system` sur votre propre machine de test et classez 5 recommandations par risque.
- Écrivez une règle `auditd` qui surveille `srv/etc/sudoers.d`.
- Ajoutez au pare-feu un `set` d'adresses d'administration pour SSH et limitez le débit des nouvelles connexions.
- Rédigez en 10 lignes la procédure d'incident si `toor` avait été utilisé.

## Nettoyage

```bash
./lab reset 16
```
