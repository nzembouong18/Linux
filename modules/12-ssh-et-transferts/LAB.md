# Labo 12 — Un serveur SSH de laboratoire : clés, config, rsync, tunnel, durcissement

> **Durée** : 2 h · **Difficulté** : ⭐⭐⭐ · **Prérequis** : module 12 · outils : `ssh`, `sshd`, `rsync`, `curl`

## Contexte

Le labo démarre pour vous un **serveur SSH jetable** (`sshd` privé, écoute sur `127.0.0.1`, port aléatoire, authentification **par clé uniquement**). Vous jouez le rôle du client puis de l'administrateur. Rien n'est modifié dans `/etc/ssh` ni dans votre vrai `~/.ssh`.

## Mise en place

```bash
./lab setup 12
cd ~/labs/12 && ls && cat serveur/PORT
```

Contenu : `serveur/` (le « serveur » : config, clé d'hôte, `authorized_keys` vide, dossier `depot/`), `projet/` (fichiers à synchroniser), `rapport.dat` (fichier à copier). Un petit service web écoute aussi sur un autre port local aléatoire — il servira au tunnel.

## Tâches (dans `~/labs/12`)

1. **Clé** : générez une paire **ed25519 sans passphrase** (labo uniquement !) nommée `id_lab` (`id_lab` et `id_lab.pub`).
2. **Autorisation** : ajoutez la clé publique à `serveur/authorized_keys` (droits `600`).
3. **Config client** : créez `ssh_config` définissant l'alias **`labsrv`** : `HostName 127.0.0.1`, `Port` (voir `serveur/PORT`), `User` (votre utilisateur), `IdentityFile ~/labs/12/id_lab` (chemin absolu), `IdentitiesOnly yes`, `UserKnownHostsFile` = `known_hosts` dans le labo, `StrictHostKeyChecking accept-new`. Test : `ssh -F ssh_config labsrv true`.
4. **Commande distante** : écrivez dans `distant.txt` le résultat de `uname -n` exécuté **via SSH** sur `labsrv`.
5. **scp** : copiez `rapport.dat` vers `serveur/depot/rapport.dat` **en passant par SSH** (`scp -F ssh_config …labsrv:<chemin absolu>`).
6. **rsync** : synchronisez `projet/` vers `serveur/depot/projet/` avec `-a --delete` à travers SSH (un fichier obsolète s'y trouve : il doit disparaître).
7. **Tunnel** : ouvrez un tunnel `-L 28080:127.0.0.1:<port du service web>` à travers `labsrv` (en arrière-plan : `-f -N`) puis récupérez la page via `http://127.0.0.1:28080/` dans `tunnel.txt`. *(Trouvez le port du service web avec `ss -ltnp`.)*
8. **Durcissement** : créez `sshd_config.durci` contenant (au minimum) : `PermitRootLogin no`, `PasswordAuthentication no`, `PubkeyAuthentication yes`, `MaxAuthTries 3`, `X11Forwarding no`, `AllowUsers <votre utilisateur>`.

## Validation

```bash
./lab check 12
```

<details><summary>💡 Indices</summary>

- `ssh-keygen -t ed25519 -f id_lab -N ''` · `cat id_lab.pub >> serveur/authorized_keys && chmod 600 serveur/authorized_keys`
- `ssh -F ssh_config labsrv 'uname -n'`
- `scp -F ssh_config rapport.dat labsrv:$PWD/serveur/depot/rapport.dat`
- `rsync -a --delete -e 'ssh -F ssh_config' projet/ labsrv:$PWD/serveur/depot/projet/`
- `ssh -F ssh_config -f -N -L 28080:127.0.0.1:PORTWEB labsrv` puis `curl -s http://127.0.0.1:28080/`
</details>

<details><summary>✅ Solution</summary>

```bash
cd ~/labs/12
ssh-keygen -q -t ed25519 -f id_lab -N ''
cat id_lab.pub >> serveur/authorized_keys; chmod 600 serveur/authorized_keys
cat > ssh_config <<EOF
Host labsrv
    HostName 127.0.0.1
    Port $(cat serveur/PORT)
    User $(id -un)
    IdentityFile $PWD/id_lab
    IdentitiesOnly yes
    UserKnownHostsFile $PWD/known_hosts
    StrictHostKeyChecking accept-new
EOF
ssh -F ssh_config labsrv 'uname -n' > distant.txt
scp -F ssh_config rapport.dat labsrv:$PWD/serveur/depot/rapport.dat
rsync -a --delete -e 'ssh -F ssh_config' projet/ labsrv:$PWD/serveur/depot/projet/
WEB=$(ss -ltnH | awk '{print $4}' | sed 's/.*://' | while read p; do curl -s -m1 http://127.0.0.1:$p/ | grep -q BIENVENUE && echo $p; done | head -1)
ssh -F ssh_config -f -N -L 28080:127.0.0.1:$WEB labsrv; sleep 1
curl -s http://127.0.0.1:28080/ > tunnel.txt
cat > sshd_config.durci <<EOF
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
MaxAuthTries 3
X11Forwarding no
AllowUsers $(id -un)
EOF
```
</details>

## Pour aller plus loin

- Ajoutez `ControlMaster auto`/`ControlPersist 5m` à `ssh_config` et comparez le temps de connexions successives (`time`).
- Lancez `rsync -avn …` avant et après modification d'un fichier de `projet/` : observez le calcul delta.
- Protégez la clé avec une passphrase et utilisez `ssh-agent`.

## Nettoyage

```bash
./lab reset 12     # arrête sshd, le service web et le tunnel
```
