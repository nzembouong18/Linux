#!/usr/bin/env bash
# Démo formateur — module 08 (≈ 20 min). Lecture seule : n'installe rien sur la machine.
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/demo-lib.sh"

demo_title "Qui a installé ce fichier ? Que contient ce paquet ?"
if command -v dpkg >/dev/null; then
  demo_run "dpkg -S /bin/ls"
  demo_run "dpkg -L coreutils | head -5"
  demo_run "dpkg -s bash | grep -E '^(Package|Status|Version|Depends)'"
  demo_run "dpkg-query -W -f='\${Package}\\t\${Version}\\n' bash coreutils"
  demo_run "dpkg -l | awk 'NR>5 {print \$1}' | sort | uniq -c"
  demo_title "Dépôts configurés"
  demo_run "ls /etc/apt/sources.list.d/ 2>/dev/null; cat /etc/apt/sources.list.d/ubuntu.sources 2>/dev/null | head -8"
  demo_run "apt-cache policy bash 2>/dev/null | head -5"
  demo_title "Simulation : que ferait l'installation de 'tree' ?"
  demo_run "apt-get -s install tree 2>/dev/null | grep -E '^(Inst|Remv|[0-9]+ upgraded)' | head -3"
else
  demo_say "Système non Debian : montrer rpm -qf /bin/ls ; dnf info bash ; dnf provides '*/ssh'."
fi

demo_title "Construire un .deb en 1 minute"
demo_run "mkdir -p pkg/DEBIAN pkg/usr/local/bin"
demo_run "printf 'Package: hello-demo\\nVersion: 0.1\\nArchitecture: all\\nMaintainer: Demo <d@example.org>\\nDescription: demo\\n' > pkg/DEBIAN/control"
demo_run "printf '#!/bin/sh\\necho hello depuis un paquet\\n' > pkg/usr/local/bin/hello-demo && chmod 755 pkg/usr/local/bin/hello-demo"
if command -v dpkg-deb >/dev/null; then
  demo_run "dpkg-deb --build --root-owner-group pkg hello-demo_0.1_all.deb"
  demo_run "dpkg-deb -I hello-demo_0.1_all.deb | head -8"
  demo_run "dpkg-deb -c hello-demo_0.1_all.deb"
  demo_show "sudo apt install ./hello-demo_0.1_all.deb"
  demo_show "sudo apt remove hello-demo && sudo apt purge hello-demo"
fi
demo_title "Équivalences Red Hat (à commenter)"
demo_show "dnf provides '*/ssh'   |  rpm -qf /usr/bin/ssh  |  dnf history  |  dnf versionlock add nginx"
demo_end
