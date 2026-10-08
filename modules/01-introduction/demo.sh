#!/usr/bin/env bash
# Démo formateur — module 01 (≈ 10 min)
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/demo-lib.sh"

demo_title "Qui suis-je, où suis-je, sur quoi ?"
demo_say "Les 4 commandes de survie pour se repérer sur un serveur inconnu."
demo_run "whoami && hostname"
demo_run "uname -srm"
demo_run "grep -E '^(PRETTY_NAME|VERSION_ID)=' /etc/os-release"

demo_title "Matériel et ressources"
demo_say "CPU, mémoire, disque : le tableau de bord minimal."
demo_run "nproc"
demo_run "free -h | head -2"
demo_run "df -h / | tail -1"
demo_run "cat /proc/loadavg"

demo_title "Tout est fichier : /proc expose le noyau"
demo_say "Aucune commande magique : uname et free lisent simplement /proc."
demo_run "head -3 /proc/meminfo"
demo_run "cat /proc/version | cut -c1-80"

demo_title "S'aider soi-même"
demo_run "whatis ls grep tar 2>/dev/null | head -3"
demo_run "ls --help | head -5"
demo_run "type cd; type ls"
demo_say "Code retour : 0 = succès, autre chose = erreur."
demo_run "ls /dossier/inexistant"
demo_run "echo \"Code retour : \$?\""
demo_end
