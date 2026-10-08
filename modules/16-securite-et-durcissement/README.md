# Module 16 — Sécurité et durcissement d'un serveur Linux

> **Niveau** : Avancé | **Durée** : 8 h (4 h cours + 4 h labo) | **Prérequis** : modules 06, 11, 12, 14
>
> **Objectifs** — À la fin de ce module vous saurez :
> - raisonner en termes de **surface d'attaque**, de moindre privilège et de défense en profondeur ;
> - auditer un système (comptes, droits, SUID, services, ports) ;
> - configurer un **pare-feu** (`nftables`, `ufw`, `firewalld`) et `fail2ban` ;
> - durcir SSH, `sudo`, PAM, le noyau (`sysctl`) et les points de montage ;
> - comprendre et utiliser les contrôles d'accès obligatoires **SELinux** et **AppArmor** ;
> - mettre en place l'audit (`auditd`), l'intégrité (AIDE) et la mise à jour automatique ;
> - réagir à un incident de manière méthodique.

> ⚖️ **Cadre légal et éthique** : n'auditez ou ne testez que des systèmes qui vous appartiennent ou pour lesquels vous avez une **autorisation écrite**. Les labos sont des simulations locales.

---

## 1. Principes

| Principe | Mise en pratique |
|----------|------------------|
| **Moindre privilège** | comptes dédiés non-root, `sudo` ciblé, capabilities, `User=` dans les unités |
| **Défense en profondeur** | plusieurs couches : réseau, pare-feu, authentification, droits, MAC, audit, sauvegardes |
| **Réduire la surface d'attaque** | n'installer/exposer que le nécessaire ; fermer les ports ; désactiver les services inutiles |
| **Sécurisé par défaut** | refuser par défaut (`policy drop`), autoriser explicitement |
| **Séparation des tâches** | un service = un compte = un conteneur/une unité |
| **Traçabilité** | journaux centralisés, audit, temps synchronisé |
| **Patcher vite** | mises à jour de sécurité automatiques + fenêtre de maintenance |
| **Supposer la compromission** | sauvegardes immuables, segmentation, détection |

Modèle de menace : *Qui ? Quoi ? Comment ?* (attaquants externes, interne malveillant, malware, erreur humaine) → priorisez par **risque** (probabilité × impact). Références : **CIS Benchmarks**, **ANSSI** (guide de configuration GNU/Linux), STIG, OWASP, MITRE ATT&CK.

## 2. Premier audit : que tourne sur cette machine ?

```bash
# Ports et processus à l'écoute (surface réseau)
sudo ss -tulpn
# Services actifs et activés
systemctl list-units --type=service --state=running
systemctl list-unit-files --state=enabled --type=service
# Paquets installés (inutiles ?)
apt list --installed 2>/dev/null | wc -l ; dpkg -l | awk '/^ii/{print $2}' | head
# Comptes
awk -F: '$3==0 {print "UID 0:", $1}' /etc/passwd                      # un seul compte UID 0 : root
sudo awk -F: '$2=="" {print "SANS MOT DE PASSE:", $1}' /etc/shadow
awk -F: '$3<1000 && $1!="root" && $7!~/(nologin|false|sync|shutdown|halt)$/ {print "login shell système:", $1}' /etc/passwd
getent group sudo adm wheel docker                                    # qui est privilégié ? (docker ≈ root !)
sudo grep -rE 'NOPASSWD' /etc/sudoers /etc/sudoers.d/
# Fichiers dangereux
sudo find / -xdev -perm -4000 -type f 2>/dev/null                      # SUID (exécutent avec les droits du propriétaire)
sudo find / -xdev -perm -2000 -type f 2>/dev/null                      # SGID
sudo find / -xdev -type f -perm -0002 2>/dev/null                      # modifiables par tous
sudo find / -xdev -nouser -o -nogroup 2>/dev/null                      # sans propriétaire
find /home -name id_rsa -o -name id_ed25519 2>/dev/null | xargs -r ls -l   # clés privées : mode 600 ?
# Tâches planifiées
ls -l /etc/cron.* /etc/crontab ; systemctl list-timers
# Dernières connexions
last -n 10 ; sudo lastb -n 10 ; w
```

Outils d'audit automatisés : **Lynis** (`sudo lynis audit system`), **OpenSCAP** (`oscap`), `debsecan`, `lynis`, `chkrootkit`/`rkhunter` (indicatifs), `nmap` (depuis l'extérieur : `nmap -sV -p- hôte` sur *vos* machines uniquement).

## 3. Pare-feu

Le pare-feu filtre le trafic dans le noyau (Netfilter). Deux interfaces modernes et un moteur :

```text
 ufw (Ubuntu, simple)  ─┐
 firewalld (RHEL)       ├─►  nftables (moteur, successeur d'iptables)  ─►  Netfilter (noyau)
 règles nft directes   ─┘
```

### Politique recommandée

**Entrée : refuser par défaut**, autoriser : connexions établies, loopback, SSH (limité), services publics. **Sortie** : autoriser (ou filtrer finement sur des serveurs sensibles).

### `ufw` (Ubuntu)

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp comment 'SSH'        # ou : sudo ufw limit 22/tcp (anti brute-force)
sudo ufw allow from 10.0.0.0/8 to any port 5432 proto tcp
sudo ufw allow 80,443/tcp
sudo ufw enable                            # ⚠ autorisez SSH AVANT d'activer
sudo ufw status verbose numbered
sudo ufw delete 3
```

### `firewalld` (RHEL/Rocky/Alma)

```bash
sudo firewall-cmd --state
sudo firewall-cmd --get-active-zones
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --permanent --add-port=8080/tcp
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="10.0.0.0/8" port port="5432" protocol="tcp" accept'
sudo firewall-cmd --reload && sudo firewall-cmd --list-all
```

### `nftables` en direct

```nft
#!/usr/sbin/nft -f
flush ruleset

table inet filtre {
    set admins { type ipv4_addr; elements = { 10.0.0.0/8 } flags interval; }

    chain entree {
        type filter hook input priority 0; policy drop;

        ct state invalid drop
        ct state established,related accept
        iif "lo" accept

        ip protocol icmp icmp type echo-request limit rate 5/second accept
        ip6 nexthdr icmpv6 accept

        tcp dport 22 ip saddr @admins ct state new limit rate 10/minute accept
        tcp dport { 80, 443 } accept

        log prefix "nft-drop: " limit rate 5/minute counter drop
    }
    chain transfert { type filter hook forward priority 0; policy drop; }
    chain sortie    { type filter hook output  priority 0; policy accept; }
}
```
```bash
sudo nft -c -f /etc/nftables.conf        # -c : vérifie la syntaxe SANS appliquer (toujours avant)
sudo nft -f /etc/nftables.conf           # applique
sudo nft list ruleset                    # affiche l'état
sudo systemctl enable --now nftables     # charge /etc/nftables.conf au démarrage
```
Gardez toujours une session ouverte (ou `at now + 5 minutes <<< 'nft flush ruleset'` comme filet de sécurité) quand vous modifiez le pare-feu d'une machine distante.

**Docker et pare-feu** : Docker insère ses propres règles (publier `-p 8080:80` contourne `ufw`). Utilisez la chaîne `DOCKER-USER` ou liez les ports à `127.0.0.1`.

### `fail2ban` — bannissement automatique

```ini
# /etc/fail2ban/jail.local
[DEFAULT]
bantime  = 1h
findtime = 10m
maxretry = 5
ignoreip = 127.0.0.1/8 10.0.0.0/8

[sshd]
enabled = true
```
```bash
sudo systemctl enable --now fail2ban
sudo fail2ban-client status sshd
sudo fail2ban-client set sshd unbanip 203.0.113.7
```

## 4. Authentification : SSH, sudo, PAM

### SSH (rappel module 12)
Pas de root, pas de mot de passe, clés ed25519, `AllowUsers`, `MaxAuthTries 3`, MFA pour les bastions, `sshd -t` avant rechargement.

### `sudo`

```text
# /etc/sudoers.d/webops   (créé avec visudo -f)
Defaults use_pty, logfile="/var/log/sudo.log", timestamp_timeout=5
%webops ALL=(root) /usr/bin/systemctl restart nginx, /usr/bin/systemctl reload nginx
```
Évitez `NOPASSWD: ALL`, les wildcards dans les commandes autorisées, et les commandes permettant une évasion (`vi`, `less`, `find`, `awk`, `tar`… utilisez `sudoedit`).

### PAM (*Pluggable Authentication Modules*)

Fichiers : `/etc/pam.d/*`. Piles : `auth`, `account`, `password`, `session`.

```text
# /etc/security/pwquality.conf — politique de mots de passe
minlen = 14
minclass = 3
maxrepeat = 3
dictcheck = 1

# verrouillage après échecs (pam_faillock) : /etc/security/faillock.conf
deny = 5
unlock_time = 900
fail_interval = 900
```
```bash
faillock --user alice            # voir les échecs ; --reset pour débloquer
sudo chage -M 90 -m 1 -W 14 alice
sudo passwd -l compte            # verrouiller ; usermod -s /usr/sbin/nologin pour les comptes de service
```
`/etc/security/limits.conf` / `limits.d/` : limites par utilisateur (`nproc`, `nofile`, `core`).

## 5. Durcissement du noyau et du système

### `sysctl`

```ini
# /etc/sysctl.d/99-durcissement.conf     puis: sudo sysctl --system
net.ipv4.tcp_syncookies = 1                    # protège des SYN flood
net.ipv4.conf.all.rp_filter = 1                # anti-usurpation d'adresse source
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.conf.all.log_martians = 1
net.ipv4.ip_forward = 0                        # 1 seulement pour un routeur/hôte Docker
kernel.randomize_va_space = 2                  # ASLR complet
kernel.kptr_restrict = 2                       # masque les adresses noyau
kernel.dmesg_restrict = 1
kernel.yama.ptrace_scope = 1                   # limite ptrace (debug entre processus)
kernel.unprivileged_bpf_disabled = 1
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
fs.suid_dumpable = 0
```

### Montage et système de fichiers

`/tmp`, `/var/tmp`, `/dev/shm` en `noexec,nosuid,nodev` ; `/home` en `nosuid,nodev` ; partitions séparées pour `/var`, `/var/log`, `/home` (évite qu'un remplissage fasse tomber le système).

### Services et paquets
Supprimer ce qui est inutile (`telnet`, `rsh`, `ftp`, `avahi`, `cups` sur un serveur) ; `systemctl mask` ; unités durcies (`systemd-analyze security`) ; mises à jour automatiques de sécurité (`unattended-upgrades`, `dnf-automatic`) ; limiter `cron`/`at` (`/etc/cron.allow`).

### Chiffrement et secrets
Disques : LUKS ; transport : TLS (≥ 1.2) avec Let's Encrypt (`certbot`) ; secrets hors dépôts git (fichiers en 600, `systemd-creds`, Vault, SOPS) ; bannière légale `/etc/issue.net` ; **UEFI Secure Boot** + mot de passe GRUB sur machines physiques.

## 6. Contrôle d'accès obligatoire (MAC)

Les droits Unix sont **discrétionnaires** : le propriétaire décide. Un MAC impose une politique **globale** que même root ne peut contourner : un service piraté reste confiné.

### SELinux (RHEL, Fedora, Rocky, Alma)

```bash
getenforce ; sestatus                    # Enforcing / Permissive / Disabled
sudo setenforce 0                        # permissif (temporaire) — pour diagnostiquer, JAMAIS « disabled » par réflexe
ls -Z /var/www/html ; ps -eZ | grep nginx    # contexte user:rôle:type:niveau
```
Principe : un processus de type `httpd_t` ne peut accéder qu'aux fichiers de types autorisés (`httpd_sys_content_t`…).

Cas fréquent : « Permission denied » alors que les droits Unix sont bons → SELinux.

```bash
sudo ausearch -m AVC -ts recent                 # refus récents
sudo sealert -a /var/log/audit/audit.log        # explication (setroubleshoot)
sudo restorecon -Rv /var/www/html               # remet les types par défaut
sudo semanage fcontext -a -t httpd_sys_content_t "/srv/site(/.*)?" && sudo restorecon -Rv /srv/site   # type permanent
getsebool -a | grep httpd ; sudo setsebool -P httpd_can_network_connect on     # interrupteurs (booleans)
sudo semanage port -a -t http_port_t -p tcp 8081     # autoriser un port non standard
sudo audit2allow -M mamodule < /var/log/audit/audit.log   # module personnalisé (en dernier recours)
```

### AppArmor (Ubuntu, Debian, SUSE)

Profils par programme (chemins), plus simples.
```bash
sudo aa-status                           # profils chargés, modes enforce/complain
sudo aa-complain /usr/sbin/nginx         # journalise sans bloquer
sudo aa-enforce  /etc/apparmor.d/usr.sbin.nginx
sudo aa-logprof                          # assistant de mise à jour du profil depuis les journaux
journalctl -k | grep -i 'apparmor="DENIED"'
```

## 7. Audit et intégrité

### `auditd`

```bash
sudo apt install auditd
sudo auditctl -w /etc/passwd -p wa -k identite        # surveille écritures/attributs
sudo auditctl -w /etc/sudoers.d/ -p wa -k sudo
sudo auditctl -a always,exit -F arch=b64 -S execve -F euid=0 -k root-exec
sudo ausearch -k identite -i                          # lire (-i : interpréter)
sudo aureport -au --failed                            # échecs d'authentification
# règles persistantes : /etc/audit/rules.d/*.rules puis sudo augenrules --load
```

### Intégrité des fichiers : AIDE / Tripwire

```bash
sudo apt install aide && sudo aideinit             # base de référence
sudo aide --check                                  # détecte les fichiers modifiés
debsums -c                                         # compare aux sommes des paquets
```

### Journaux et alertes
Centraliser (rsyslog/Loki/ELK), alerter sur : `sudo` inattendu, échecs SSH massifs, nouveaux comptes, modification de `/etc`, nouveaux ports en écoute, arrêt de `auditd`.

## 8. Réponse à incident (méthode)

1. **Détecter et qualifier** (alerte, comportement anormal : charge CPU, connexions sortantes, processus inconnus).
2. **Contenir** : isoler du réseau (règle de pare-feu / débrancher / VLAN de quarantaine) **sans éteindre** si possible (la RAM contient des preuves).
3. **Préserver les preuves** : ordre de volatilité — mémoire, connexions, processus, puis disque ; copie bit à bit (`dd`, `ddrescue`), sommes de hachage, chaîne de traçabilité.
4. **Analyser** : `ps auxf`, `ss -tupan`, `lsof -nP`, `last`, `find / -mtime -2`, `crontab -l` de tous les comptes, `~/.ssh/authorized_keys`, unités systemd nouvelles, `/etc/ld.so.preload`, modules noyau (`lsmod`).
5. **Éradiquer** et **restaurer** : **réinstaller** depuis une base saine plutôt que « nettoyer » ; changer **tous** les secrets ; corriger la faille.
6. **Retour d'expérience** : chronologie, cause racine, actions correctives.

```bash
ps -eo pid,ppid,user,lstart,cmd --sort=lstart | tail -20          # processus récents
sudo ss -tupan | grep ESTAB ; sudo lsof -nP -i | grep -v LISTEN
sudo find / -xdev -type f -mtime -2 -not -path '/proc/*' 2>/dev/null | head
cat /etc/ld.so.preload 2>/dev/null ; lsmod | head
for u in $(cut -d: -f1 /etc/passwd); do sudo crontab -l -u "$u" 2>/dev/null | sed "s/^/$u: /"; done
```

## 9. Checklist de durcissement (serveur)

- [ ] Système à jour + mises à jour de sécurité automatiques
- [ ] Comptes : pas de compte partagé, pas de mot de passe vide, un seul UID 0, comptes de service en `nologin`
- [ ] SSH : clés seules, pas de root, `AllowUsers`, fail2ban
- [ ] `sudo` précis, journalisé
- [ ] Pare-feu : `deny` par défaut, ports minimaux
- [ ] Services inutiles supprimés, ports vérifiés (`ss -tulpn`)
- [ ] `sysctl` durci, `/tmp` `noexec,nosuid,nodev`
- [ ] SELinux enforcing ou AppArmor enforce
- [ ] Audit (`auditd`), intégrité (AIDE), journaux centralisés
- [ ] Sauvegardes testées, hors ligne/immuables
- [ ] Chiffrement : disques (LUKS), transport (TLS)
- [ ] Scan régulier (Lynis/OpenSCAP) et revue

## 10. Résumé

- Réduire la surface d'attaque ; moindre privilège ; défense en profondeur ; refuser par défaut.
- Audit rapide : `ss -tulpn`, UID 0, mots de passe vides, SUID/world-writable, `NOPASSWD`, clés privées exposées.
- Pare-feu `nftables`/`ufw`/`firewalld` + `fail2ban` ; `nft -c` avant d'appliquer.
- PAM (pwquality/faillock), `sudo` ciblé, `sysctl` durci, montages `noexec,nosuid,nodev`.
- SELinux/AppArmor : ne pas désactiver, diagnostiquer (`ausearch`, `sealert`, `aa-logprof`).
- `auditd`, AIDE, centralisation, procédure d'incident : contenir → préserver → analyser → réinstaller.

## 11. Quiz

1. Pourquoi `docker` dans un groupe équivaut-il presque à donner root ?
2. Que signifie « policy drop » pour la chaîne `input` ? Que doit-on autoriser explicitement ?
3. Comment trouver les binaires SUID du système ? Pourquoi est-ce sensible ?
4. SELinux bloque votre application. Qu'est-ce qui est faux de faire, et que faire à la place ?
5. Quelle commande vérifie un fichier nftables sans l'appliquer ?
6. Citez 4 paramètres `sysctl` de durcissement.
7. Après la découverte d'une compromission, pourquoi est-il préférable de réinstaller ?
8. Que surveille `auditctl -w /etc/passwd -p wa -k identite` ?

<details><summary>Réponses</summary>

1. Un membre du groupe `docker` peut lancer un conteneur montant `/` et agir en root sur l'hôte.
2. Tout trafic entrant non explicitement autorisé est rejeté ; autoriser : `established,related`, `lo`, SSH, services publics, ICMP utile.
3. `find / -xdev -perm -4000 -type f` ; ces programmes s'exécutent avec les droits de leur propriétaire (souvent root) : une faille = élévation de privilèges.
4. Passer SELinux en `disabled`. Il faut lire les refus (`ausearch -m AVC`), corriger contextes (`restorecon`, `semanage fcontext`), booleans, ports.
5. `nft -c -f fichier`.
6. Ex. : `net.ipv4.tcp_syncookies=1`, `net.ipv4.conf.all.rp_filter=1`, `kernel.randomize_va_space=2`, `kernel.kptr_restrict=2`, `fs.protected_symlinks=1`, `kernel.yama.ptrace_scope=1`.
7. On ne peut pas garantir avoir trouvé toutes les portes dérobées ; une base saine + rotation des secrets est la seule certitude.
8. Les écritures (w) et changements d'attributs (a) sur `/etc/passwd`, étiquetés `identite` pour la recherche.
</details>

➡️ **Labo** : [LAB.md](LAB.md) · **Démo** : `./lab demo 16` · **Suivant** : [17 — Réseau avancé](../17-reseau-avance/README.md)
