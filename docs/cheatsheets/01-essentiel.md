# Aide-mémoire 1 — L'essentiel en ligne de commande (modules 01-06)

## Aide et repérage
```bash
man cmd · cmd --help · apropos mot · whatis cmd · type cmd · which cmd
whoami · id · hostname · uname -a · cat /etc/os-release · uptime · date
echo $?                          # code retour (0 = succès)
```

## Navigation
```bash
pwd · cd /chemin · cd .. · cd - · cd            # courant, parent, précédent, HOME
ls -lah · ls -ld dossier · ls -R · tree -L 2
file fichier · stat fichier
```
| Dossier | Contenu |
|---------|---------|
| `/etc` | configuration du système |
| `/var/log` | journaux |
| `/home`, `/root` | répertoires personnels |
| `/proc`, `/sys` | noyau et matériel (virtuels) |
| `/dev` | périphériques |
| `/tmp` | fichiers temporaires |
| `/usr`, `/opt`, `/srv` | programmes, logiciels tiers, données de services |

Joker : `*` `?` `[a-z]` `{a,b}` — guillemets : `"…"` (variables), `'…'` (littéral).

## Lire / éditer
```bash
cat f · less f · head -n 5 f · tail -n 20 f · tail -F f · wc -l f · nl f
sed -n '10,20p' f · grep -n motif f
nano f · vim f      # vim : i insérer · Esc · :w · :q · :wq · :q! · dd · yy · p · u · /motif · :%s/a/b/g
```

## Redirections et filtres
```bash
cmd > f  cmd >> f  cmd < f  cmd 2> err  cmd > f 2>&1  cmd &> f  cmd > /dev/null 2>&1
cmd1 | cmd2        cmd | tee f        $(cmd)     <(cmd)
grep -inrE 'motif' .   (-i casse · -n lignes · -r récursif · -E regex · -v inverse · -c compte · -o seul)
sort -n -r -u -k2 -t:    uniq -c    cut -d: -f1,3    tr 'a-z' 'A-Z'    paste    column -t
sort | uniq -c | sort -rn | head            # classement par fréquence
```

## Utilisateurs et permissions
```bash
sudo useradd -m -s /bin/bash alice · sudo passwd alice · sudo usermod -aG groupe alice · sudo userdel -r alice
sudo groupadd g · getent passwd alice · id alice · groups
chmod 640 f · chmod u+x f · chmod -R g+rX d · chown alice:dev f · chgrp dev f · umask 027
chmod 2775 dossier (setgid) · chmod 1777 /tmp (sticky) · chmod u+s prog (setuid ⚠)
setfacl -m u:carol:r f · getfacl f · chattr +i f
```
| Octal | Symbole | Usage |
|------:|---------|-------|
| 600 | `rw-------` | clé privée, secret |
| 640 | `rw-r-----` | fichier partagé avec un groupe |
| 644 | `rw-r--r--` | fichier ordinaire |
| 700 | `rwx------` | dossier privé |
| 750 | `rwxr-x---` | programme ou dossier de groupe |
| 755 | `rwxr-xr-x` | programme ou dossier public |
