#!/usr/bin/env bash
# Démo formateur — module 20 (≈ 60 min). Conteneur « fait main » : root + unshare + busybox requis.
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/demo-lib.sh"
if [[ $EUID -ne 0 ]] || ! command -v busybox >/dev/null || ! command -v unshare >/dev/null; then
  demo_say "Démo nécessitant root, unshare et busybox-static. Commandes à rejouer :"
  demo_show "mkdir -p rootfs/{bin,proc,tmp}; cp /usr/bin/busybox rootfs/bin/; sudo chroot rootfs /bin/busybox --install -s /bin"
  demo_show "sudo unshare --uts --pid --ipc --mount --net --fork --mount-proc=\$PWD/rootfs/proc chroot rootfs /bin/sh"
  exit 0
fi
trap 'mountpoint -q "$DEMO_DIR/ov/merged" && umount -l "$DEMO_DIR/ov/merged"; cd /; rm -rf "$DEMO_DIR"' EXIT

demo_title "Un conteneur est un processus : les namespaces du shell courant"
demo_run "ls -l /proc/\$\$/ns | awk '{print \$9, \$10, \$11}'"
demo_run "lsns 2>/dev/null | head -6"

demo_title "Étape 1 — un système de fichiers racine minimal"
demo_run "mkdir -p rootfs/{bin,proc,sys,dev,etc,tmp,root} && cp \$(command -v busybox) rootfs/bin/"
demo_run "chroot rootfs /bin/busybox --install -s /bin && ls rootfs/bin | wc -l && ls -l rootfs/bin/sh | awk '{print \$9,\$10,\$11}'"
demo_say "Les liens sont relatifs au rootfs (créés DEPUIS le chroot) : sinon ils pointeraient vers l'hôte."

demo_title "Étape 2 — chroot seul : isolation des fichiers, mais pas du reste"
demo_run "chroot rootfs /bin/sh -c 'ls /; hostname; echo pid=\$\$'"
demo_say "On voit encore le nom d'hôte de la machine : il faut les namespaces."

demo_title "Étape 3 — unshare : UTS + PID + IPC + MNT + NET"
cat > ctr.sh <<'EOF'
#!/usr/bin/env bash
root=$(realpath "$1"); host=$2; shift 2
exec unshare --uts --pid --ipc --mount --net --fork --mount-proc="$root/proc" \
  chroot "$root" /bin/sh -c 'hostname "$1"; shift; exec "$@"' _ "$host" "$@"
EOF
chmod +x ctr.sh
demo_run "./ctr.sh rootfs mon-conteneur hostname; echo \"hôte: \$(hostname)\""
demo_run "./ctr.sh rootfs mon-conteneur sh -c 'echo \"mon PID = \$\$\"; ps'"
demo_run "./ctr.sh rootfs mon-conteneur ip -o link"
demo_say "Une seule interface (lo) : pile réseau vide, comme dans un conteneur --network none."
demo_run "./ctr.sh rootfs mon-conteneur sh -c 'echo depuis-le-conteneur > /tmp/f'; cat rootfs/tmp/f"
demo_run "./ctr.sh rootfs mon-conteneur sh -c 'exit 42'; echo \"code retour: \$?\""

demo_title "Étape 4 — overlayfs : couche inscriptible par conteneur"
demo_run "mkdir -p ov/{upper,work,merged} && mount -t overlay overlay -o lowerdir=\$PWD/rootfs,upperdir=\$PWD/ov/upper,workdir=\$PWD/ov/work ov/merged"
demo_run "echo 'écrit dans merged' > ov/merged/tmp/nouveau.txt; rm ov/merged/bin/ls"
demo_run "echo '--lower:'; ls rootfs/tmp; echo '--upper:'; ls -l ov/upper/tmp ov/upper/bin | grep -v total"
demo_say "Le fichier supprimé est masqué par un « whiteout » (c--------- 0,0) ; la couche basse reste intacte et partageable."
demo_run "umount ov/merged"

demo_title "Étape 5 — cgroups v2 : limiter"
demo_run "cat /sys/fs/cgroup/cgroup.controllers 2>/dev/null || echo '(cgroup v1 ou indisponible)'"
demo_run "stat -fc %T /sys/fs/cgroup 2>/dev/null"
demo_show "echo '+cpu +memory +pids' > /sys/fs/cgroup/cgroup.subtree_control; mkdir /sys/fs/cgroup/demo; echo 64M > /sys/fs/cgroup/demo/memory.max; echo \$\$ > /sys/fs/cgroup/demo/cgroup.procs"

demo_title "Docker/Podman automatise tout cela"
if docker info >/dev/null 2>&1; then
  demo_run "docker run --rm -m 64m --cpus 0.5 --pids-limit 50 alpine sh -c 'hostname; echo pid=\$\$; ip -o link | wc -l'"
else
  demo_say "(pas de daemon Docker ici)"
  demo_show "docker run --rm -m 64m --cpus 0.5 --pids-limit 50 alpine sh -c 'hostname; echo pid=\$\$; ip -o link'"
fi
demo_show "docker build -t monapp:1.0 . && docker run -d --name app -p 127.0.0.1:8000:8000 --read-only --cap-drop ALL monapp:1.0"
demo_end
