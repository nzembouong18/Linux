# Module 12 — SSH, clés, tunnels et transferts de fichiers

> **Niveau** : Intermédiaire | **Durée** : 4 h (2 h cours + 2 h labo) | **Prérequis** : modules 06, 11
>
> **Objectifs** — À la fin de ce module vous saurez :
> - vous connecter à un serveur distant avec SSH et vérifier son identité (empreinte d'hôte) ;
> - créer et utiliser des **paires de clés** ; utiliser `ssh-agent` ;
> - simplifier le quotidien avec `~/.ssh/config`, `ProxyJump`, le multiplexage ;
> - transférer des fichiers (`scp`, `sftp`, `rsync`) ;
> - ouvrir des **tunnels** (`-L`, `-R`, `-D`) ;
> - **durcir** `sshd` et dépanner les connexions.

---

## 1. SSH en bref

**SSH** (*Secure Shell*, TCP/22) fournit un canal **chiffré et authentifié** pour : shell distant, exécution de commandes, transferts de fichiers, tunnels réseau. Il a remplacé `telnet`, `rsh`, `ftp`.

```text
 client (ssh)  ───────────── réseau non sûr ─────────────►  serveur (sshd)
   1. négociation des algorithmes, échange de clés (Diffie-Hellman) → clé de session
   2. le client vérifie la clé d'hôte du serveur (known_hosts)
   3. le client s'authentifie : clé publique (recommandé) / mot de passe / certificat
   4. canal chiffré : shell, commande, sftp, tunnels
```

```bash
ssh alice@srv.example.org                 # connexion
ssh -p 2222 alice@srv.example.org         # autre port
ssh alice@srv 'uptime; df -h /'           # exécute une commande puis se déconnecte
ssh -t alice@srv 'sudo systemctl status nginx'     # -t : terminal (commande interactive)
ssh -i ~/.ssh/id_ed25519 alice@srv        # clé précise
ssh -v alice@srv                          # débogage (-vv, -vvv)
```

## 2. Identité du serveur : `known_hosts`

À la première connexion :

```text
The authenticity of host 'srv (203.0.113.10)' can't be established.
ED25519 key fingerprint is SHA256:abc123…
Are you sure you want to continue connecting (yes/no/[fingerprint])?
```

Comparez l'empreinte avec celle fournie **hors bande** (console du fournisseur, collègue). Acceptée, la clé est mémorisée dans `~/.ssh/known_hosts`. Si elle change plus tard :

```text
WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!
```

**Ne contournez pas à la légère** : réinstallation du serveur *ou* attaque d'homme du milieu. Après vérification : `ssh-keygen -R srv`.

```bash
ssh-keyscan -t ed25519 srv                 # récupérer la clé publique d'un hôte
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub     # empreinte côté serveur
```

## 3. Authentification par clés

Une paire **clé privée** (reste secrète sur votre poste, `600`) / **clé publique** (copiée sur les serveurs). Le serveur prouve que vous détenez la clé privée sans jamais la recevoir.

```bash
ssh-keygen -t ed25519 -C "alice@portable" -f ~/.ssh/id_ed25519      # crée la paire — mettez une PASSPHRASE
ssh-copy-id -i ~/.ssh/id_ed25519.pub alice@srv      # installe la clé publique dans ~alice/.ssh/authorized_keys
```
Équivalent manuel :
```bash
cat ~/.ssh/id_ed25519.pub | ssh alice@srv 'umask 077; mkdir -p ~/.ssh; cat >> ~/.ssh/authorized_keys'
```

| Algorithme | Conseil |
|-----------|---------|
| **ed25519** | **recommandé** (court, rapide, sûr) |
| rsa (≥ 3072 bits) | compatibilité avec anciens systèmes : `-t rsa -b 4096` |
| ecdsa | acceptable ; dsa : **obsolète** |

**Droits obligatoires** (sinon `sshd` ignore la clé — `StrictModes`) :

```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys ~/.ssh/id_ed25519 ~/.ssh/config
chmod 644 ~/.ssh/id_ed25519.pub ~/.ssh/known_hosts
# le home ne doit pas être modifiable par le groupe/les autres
```

### `ssh-agent` : saisir la passphrase une seule fois

```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519           # demande la passphrase
ssh-add -l                          # clés chargées
ssh-add -t 4h ~/.ssh/id_ed25519     # durée limitée
```
Sur poste de travail, l'agent est souvent déjà géré (GNOME Keyring, macOS Keychain). Évitez `ssh -A` (agent forwarding) vers des machines non fiables : préférez `ProxyJump`.

## 4. Le fichier `~/.ssh/config`

```text
Host *
    ServerAliveInterval 30
    ServerAliveCountMax 3
    AddKeysToAgent yes
    IdentitiesOnly yes

Host bastion
    HostName bastion.example.org
    User alice
    IdentityFile ~/.ssh/id_ed25519

Host web01 web02
    HostName %h.interne.example.org
    User deploy
    ProxyJump bastion                # passe par le bastion (ssh -J)
    Port 2222

Host prod-*
    User admin
    StrictHostKeyChecking yes
```

Désormais : `ssh web01` suffit. Les motifs `Host` sont évalués **dans l'ordre** ; la première valeur obtenue pour un paramètre l'emporte (mettez les cas spécifiques avant `Host *`).

### Multiplexage de connexions (connexions instantanées)

```text
Host *
    ControlMaster auto
    ControlPath ~/.ssh/cm-%r@%h:%p
    ControlPersist 10m
```

## 5. Transfert de fichiers

### `scp` (simple)

```bash
scp fichier.txt alice@srv:/tmp/                # local → distant
scp alice@srv:/var/log/syslog ./               # distant → local
scp -r dossier/ alice@srv:/srv/data/           # récursif
scp -P 2222 -i cle f alice@srv:~/              # attention : -P majuscule pour le port
```

### `sftp` (interactif)

```bash
sftp alice@srv
sftp> ls / cd / get / put / mget / mput / exit
```

### `rsync` — l'outil de référence pour copier et synchroniser

`rsync` ne transfère que les **différences** (algorithme delta), reprend après interruption et préserve droits/dates.

```bash
rsync -avz --progress source/ alice@srv:/dest/        # -a archive · -v verbeux · -z compression
rsync -avn source/ dest/                              # -n : simulation (dry-run) — TOUJOURS avant --delete
rsync -a --delete source/ alice@srv:/dest/            # miroir exact : supprime à la destination ce qui n'est plus à la source
rsync -a --exclude='*.tmp' --exclude='.git/' src/ dest/
rsync -a --partial --append-verify gros.iso srv:/data/   # reprise des gros fichiers
rsync -e 'ssh -p 2222 -i ~/.ssh/cle' -a src/ srv:/dest/
rsync -a --link-dest=/backup/hier /data/ /backup/aujourdhui/    # sauvegardes incrémentales par liens durs
rsync -a --info=progress2 --human-readable src/ dest/
```

> ⚠️ **Le slash final compte** : `rsync -a src/ dest/` copie le **contenu** de `src` dans `dest` ; `rsync -a src dest/` crée `dest/src`.

### Autres

`sshfs alice@srv:/data /mnt/data` (monter un dossier distant en FUSE) ; `tar czf - dossier | ssh srv 'tar xzf - -C /dest'` (flux compressé).

## 6. Tunnels SSH (redirection de ports)

```text
-L  local  : j'ouvre un port LOCAL qui atteint une destination vue DEPUIS le serveur
-R  remote : j'ouvre un port sur le SERVEUR qui revient vers ma machine
-D  dynamic: proxy SOCKS local
```

```bash
# Accéder à une base PostgreSQL (non exposée) qui n'est joignable que depuis le serveur
ssh -N -L 5433:127.0.0.1:5432 alice@srv          # puis: psql -h 127.0.0.1 -p 5433
ssh -N -L 8080:intranet.interne:80 alice@bastion # 8080 local → intranet via le bastion

# Exposer temporairement un service local sur le serveur distant
ssh -N -R 9000:127.0.0.1:3000 alice@srv          # srv:9000 → mon poste:3000

# Proxy SOCKS : naviguer « depuis » le serveur
ssh -N -D 1080 alice@srv                          # puis proxy SOCKS5 localhost:1080

ssh -f -N -L …                                    # -f : passe en arrière-plan ; -N : pas de commande
ssh -J bastion alice@interne                      # saut à travers un bastion (ProxyJump)
```

```text
 Poste ──(tunnel chiffré)──► Bastion ───► Base de données :5432
 localhost:5433 ═══════════════╝
```

## 7. Durcir le serveur (`/etc/ssh/sshd_config`)

```text
Port 22                          # changer le port réduit le bruit, ne remplace PAS la sécurité
PermitRootLogin no               # ou prohibit-password
PasswordAuthentication no        # clés uniquement (après avoir vérifié que la vôtre fonctionne !)
KbdInteractiveAuthentication no
PubkeyAuthentication yes
AuthenticationMethods publickey
MaxAuthTries 3
LoginGraceTime 30
AllowUsers alice bob@10.0.0.0/8  # liste blanche (ou AllowGroups ssh-users)
X11Forwarding no
AllowAgentForwarding no
ClientAliveInterval 300
ClientAliveCountMax 2
LogLevel VERBOSE
```

Procédure **sûre** :

```bash
sudo sshd -t                       # test de syntaxe : ne rechargez JAMAIS sans ce test
sudo systemctl reload ssh          # (ssh sous Debian/Ubuntu, sshd sous RHEL)
# GARDEZ votre session actuelle ouverte et testez une NOUVELLE connexion avant de la fermer
```

Configurations complémentaires : `/etc/ssh/sshd_config.d/*.conf` (prioritaire, préférez-le), `fail2ban` (bannit les IP qui échouent), MFA (`libpam-google-authenticator`), certificats SSH signés par une CA, bastion + journalisation, pare-feu limitant le port 22 (module 16). Réglage SELinux d'un port non standard : `semanage port -a -t ssh_port_t -p tcp 2222`.

## 8. Dépannage

```bash
ssh -vvv alice@srv                         # côté client : quelles clés, quelle méthode, quelle erreur
sudo journalctl -u ssh -f                  # côté serveur (RHEL: -u sshd) ; ou /var/log/auth.log
sudo sshd -T | grep -Ei 'passwordauth|permitroot|allowusers'     # configuration réellement appliquée
```

| Symptôme | Causes fréquentes |
|----------|-------------------|
| `Connection refused` | sshd arrêté, mauvais port, pare-feu local |
| `Connection timed out` | pare-feu/routage/IP erronée |
| `Permission denied (publickey)` | clé non autorisée, **droits** de `~/.ssh` ou `authorized_keys`, mauvais utilisateur, `AllowUsers` |
| Demande de mot de passe malgré la clé | droits incorrects, clé non copiée, agent sans la bonne clé (`-i`, `IdentitiesOnly`) |
| `Too many authentication failures` | trop de clés dans l'agent → `IdentitiesOnly yes` |
| Lenteur à la connexion | `UseDNS`, résolution inverse, GSSAPI (`GSSAPIAuthentication no`) |
| Déconnexions sur inactivité | `ServerAliveInterval` côté client |

## 9. Résumé

- SSH = chiffrement + authentification ; vérifiez l'empreinte d'hôte (`known_hosts`).
- **Clés ed25519 + passphrase + agent** ; droits : `~/.ssh` 700, clé privée 600.
- `~/.ssh/config` : alias, `ProxyJump`, multiplexage.
- `scp`/`sftp` pour le simple, **`rsync -a`** pour synchroniser (attention au `/` final, `-n` avant `--delete`).
- Tunnels : `-L` (accéder à), `-R` (exposer), `-D` (SOCKS).
- Durcissement : pas de root, pas de mot de passe, `AllowUsers`, `sshd -t` avant rechargement.

## 10. Quiz

1. Où se trouve la clé privée et quels droits doit-elle avoir ?
2. Pourquoi ne pas ignorer l'avertissement « REMOTE HOST IDENTIFICATION HAS CHANGED » ?
3. Quelle différence entre `rsync -a src dest/` et `rsync -a src/ dest/` ?
4. Quelle commande crée un tunnel pour atteindre le port 5432 d'un serveur depuis `localhost:5433` ?
5. Pourquoi tester avec `sshd -t` et garder une session ouverte avant de recharger ?
6. Que fait `ssh -J bastion web01` ?
7. La connexion par clé échoue (`Permission denied (publickey)`) : donnez 3 pistes.
8. Pourquoi `PasswordAuthentication no` améliore-t-il la sécurité ?

<details><summary>Réponses</summary>

1. `~/.ssh/id_ed25519`, droits `600` (le dossier `~/.ssh` en `700`).
2. La clé a changé : réinstallation légitime ou attaque de type homme du milieu. Vérifier avant `ssh-keygen -R`.
3. Sans `/` : crée `dest/src/…` ; avec `/` : copie le **contenu** de `src` dans `dest`.
4. `ssh -N -L 5433:127.0.0.1:5432 user@serveur`
5. Une faute dans la config peut empêcher `sshd` de redémarrer, vous verrouillant dehors ; une session ouverte permet de corriger.
6. Se connecte à `web01` en passant par la machine `bastion`.
7. Droits de `~/.ssh`/`authorized_keys`, clé publique absente/mauvais utilisateur, `AllowUsers`, mauvaise clé proposée, `journalctl -u ssh` pour le motif exact.
8. Supprime les attaques par force brute/devinette de mots de passe ; seule la possession de la clé privée permet l'accès.
</details>

➡️ **Labo** : [LAB.md](LAB.md) · **Démo** : `./lab demo 12` · **Suivant** : [13 — Stockage et systèmes de fichiers](../13-stockage-et-systemes-de-fichiers/README.md)
