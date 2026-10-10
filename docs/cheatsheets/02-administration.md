# Aide-mémoire 2 — Administration (modules 07-15)

## Processus
```bash
ps aux · ps -ef --forest · pgrep -a nom · top · htop · pstree -p
kill PID (TERM) · kill -9 PID · kill -HUP PID · pkill -f motif · killall nom
commande & · jobs · fg %1 · bg %1 · nohup commande & · tmux new -s x (Ctrl+b d · tmux attach -t x)
nice -n 10 commande · renice -n 5 -p PID · ls -l /proc/PID/fd · lsof -p PID
```
Signaux : `1 HUP` recharger · `2 INT` Ctrl+C · `9 KILL` brutal · `15 TERM` arrêt propre · `19 STOP` · `18 CONT`.

## Paquets
| | Debian/Ubuntu | RHEL/Rocky |
|---|---|---|
| index | `apt update` | — |
| installer | `apt install p` | `dnf install p` |
| mettre à jour | `apt upgrade` / `full-upgrade` | `dnf upgrade` |
| supprimer | `apt remove` / `purge` / `autoremove` | `dnf remove` / `autoremove` |
| chercher / infos | `apt search` / `apt show` / `apt policy` | `dnf search` / `info` |
| qui a ce fichier | `dpkg -S /chemin` | `rpm -qf /chemin` |
| fichiers du paquet | `dpkg -L p` | `rpm -ql p` |
| verrouiller | `apt-mark hold p` | `dnf versionlock add p` |

## Bash (scripting)
```bash
#!/usr/bin/env bash
set -Eeuo pipefail ; trap 'rm -rf "$tmp"' EXIT ; tmp=$(mktemp -d)
"$@" "$1" "${2:-défaut}" "${#tab[@]}" "${var%.txt}" "${var##*/}" $((a+b))
[[ -f $f && -r $f ]] ; [[ $s =~ ^[0-9]+$ ]] ; (( n > 3 ))
for f in *.log; do …; done ; while read -r l; do …; done < f ; case $x in a|b) … ;; *) … ;; esac
fn() { local x=$1; echo "$x"; } ; getopts ":vn:" o
bash -n s.sh · bash -x s.sh · shellcheck s.sh
```

## Texte
```bash
sed -E 's/(a)(b)/\2\1/g' f · sed -i.bak 's/x/y/' f · sed -n '5,9p' f · sed '/^#/d' f
awk -F: '$3>=1000{print $1}' /etc/passwd · awk '{s+=$3} END{print s}' f · awk '{c[$1]++} END{for(k in c)print c[k],k}' f
jq -r '.items[] | select(.n<5) | .name' f.json
```

## Réseau
```bash
ip -br addr · ip route · ip neigh · ip route get 8.8.8.8 · ss -tulpn · ss -s
ping -c3 h · mtr -rwc10 h · traceroute h · dig +short h · getent hosts h · nc -zv h 22
curl -I url · curl -s -o /dev/null -w '%{http_code} %{time_total}\n' url · curl -fsSL -o f url
sudo ip addr add 10.0.0.5/24 dev eth0 · sudo ip link set eth0 up · sudo ip route add default via 10.0.0.1
sudo tcpdump -ni eth0 'port 53' -c 10 -w c.pcap · nmcli · sudo netplan try
```
CIDR : `/24`=254 hôtes · `/25`=126 · `/26`=62 · `/27`=30 · `/28`=14 · `/30`=2. Privées : `10/8` `172.16/12` `192.168/16`.

## SSH et transferts
```bash
ssh-keygen -t ed25519 -C "moi@pc" · ssh-copy-id user@h · ssh -p 2222 user@h 'commande' · ssh -J bastion user@h
scp f user@h:/tmp/ · rsync -avz --progress src/ user@h:/dest/ · rsync -avn --delete src/ dest/   # -n = simulation
ssh -N -L 5433:127.0.0.1:5432 user@h · ssh -N -R 9000:127.0.0.1:3000 user@h · ssh -N -D 1080 user@h
chmod 700 ~/.ssh · chmod 600 ~/.ssh/authorized_keys ~/.ssh/id_ed25519 · sudo sshd -t
```

## Stockage
```bash
lsblk -f · blkid · findmnt · df -hT · sudo parted /dev/sdb --script mklabel gpt mkpart d ext4 1MiB 100%
sudo mkfs.ext4 -L DATA /dev/sdb1 · sudo mount /dev/sdb1 /data · sudo umount /data · sudo mount -a
# /etc/fstab : UUID=… /data ext4 defaults,noatime,nofail 0 2
sudo pvcreate /dev/sdb1 · sudo vgcreate vg /dev/sdb1 · sudo lvcreate -L 10G -n lv vg · sudo lvextend -r -L +5G /dev/vg/lv
sudo fsck -f /dev/sdb1 (démonté) · sudo e2fsck -fn img · sudo mdadm --detail /dev/md0 · cat /proc/mdstat
```

## systemd, journaux, cron
```bash
systemctl status|start|stop|restart|reload|enable --now|disable|mask s · systemctl --failed · systemctl list-timers
sudo systemctl daemon-reload · sudo systemctl edit s · systemctl cat s · systemd-analyze verify f · systemd-analyze blame
journalctl -u s -f · journalctl -b -p err · journalctl --since "1 hour ago" · journalctl -k · journalctl --vacuum-size=500M
crontab -e : m h dom mon dow commande   (*/15 * * * *   30 2 * * *   0 8 * * 1-5)   · systemd-analyze calendar 'Mon..Fri 08:00'
```

## Archives et sauvegardes
```bash
tar -czf a.tgz -C /srv dossier · tar -tzf a.tgz · tar -xzf a.tgz -C /dest · tar --exclude='*.tmp' …
gzip -k f · xz -T0 -9 -k f · zstd -19 f · sha256sum f · sha256sum -c SHA256SUMS
rsync -a --delete --link-dest=/b/hier /data/ /b/aujourdhui/ · logrotate -d /etc/logrotate.d/x
```
