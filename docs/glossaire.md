# Glossaire

| Terme | Définition |
|-------|------------|
| **ACL** | *Access Control List* : droits fins par utilisateur/groupe en plus du modèle ugo (`setfacl`). |
| **AppArmor** | Contrôle d'accès obligatoire par profils de chemins (Ubuntu, SUSE). |
| **apt / dpkg** | Gestionnaire de paquets haut niveau / bas niveau de la famille Debian. |
| **ASLR** | Randomisation de l'espace d'adressage (`kernel.randomize_va_space`). |
| **Bash** | *Bourne Again Shell* : interpréteur de commandes standard de Linux. |
| **Bastion** | Machine d'entrée unique, durcie et journalisée, pour accéder à un réseau interne (SSH `ProxyJump`). |
| **Bridge** | Commutateur logiciel de couche 2. |
| **Budget d'erreur** | 100 % − SLO : indisponibilité tolérée sur une période. |
| **cgroup** | *Control group* : limitation et comptabilité des ressources (CPU, mémoire, E/S, PIDs). |
| **chroot** | Change la racine apparente d'un processus. |
| **CIDR** | Notation `a.b.c.d/n` du préfixe réseau. |
| **cloud-init** | Initialisation d'une VM cloud au premier démarrage. |
| **Conteneur** | Processus isolé par namespaces, limité par cgroups, avec sa propre racine de fichiers. |
| **conntrack** | Suivi des connexions du noyau (NAT, pare-feu à états). |
| **cron** | Planificateur de tâches périodiques. |
| **Daemon / démon** | Processus de service en arrière-plan. |
| **DKMS** | Recompilation automatique des modules noyau hors arbre. |
| **DNAT / SNAT** | Réécriture de l'adresse destination / source (NAT). |
| **Drop-in** | Fichier de surcharge d'une unité systemd (`.d/*.conf`). |
| **ESP** | *EFI System Partition* : partition FAT32 de démarrage UEFI. |
| **ext4 / XFS / Btrfs** | Systèmes de fichiers Linux courants. |
| **Fencing / STONITH** | Isolement forcé d'un nœud défaillant pour éviter le split-brain. |
| **FHS** | *Filesystem Hierarchy Standard* : organisation standard de l'arborescence. |
| **fstab** | Table des montages permanents (`/etc/fstab`). |
| **GPT / MBR** | Tables de partitions moderne / historique. |
| **GRUB** | Chargeur de démarrage le plus répandu. |
| **Handler** | Tâche Ansible déclenchée seulement si une tâche notifiante a changé quelque chose. |
| **Idempotence** | Appliquer N fois = même état que 1 fois. |
| **Inode** | Structure contenant les métadonnées d'un fichier (sans son nom). |
| **initramfs** | Mini-système en RAM chargé avant la racine réelle. |
| **journald / journalctl** | Service de journalisation de systemd / son outil de lecture. |
| **Kernel panic** | Erreur fatale du noyau. |
| **keepalived** | VRRP : adresse IP virtuelle flottante entre serveurs. |
| **LTS** | *Long Term Support* : version à support prolongé. |
| **LUKS** | Chiffrement de volumes bloc (`cryptsetup`). |
| **LVM** | *Logical Volume Manager* : PV → VG → LV, redimensionnement à chaud. |
| **MAC (contrôle obligatoire)** | Politique d'accès imposée même à root (SELinux, AppArmor). |
| **Masquerade** | SNAT dynamique pour un accès Internet partagé. |
| **MTU** | Taille maximale d'un paquet sur un lien (1500 par défaut). |
| **Namespace** | Isolation de la vue d'un processus (PID, réseau, montages, UTS, IPC, utilisateurs). |
| **netplan** | Configuration réseau YAML d'Ubuntu. |
| **nftables** | Pare-feu Netfilter moderne (remplace iptables). |
| **OOM killer** | Mécanisme du noyau qui tue un processus quand la mémoire est épuisée. |
| **overlayfs** | Système de fichiers en couches (lower/upper). |
| **PAM** | *Pluggable Authentication Modules*. |
| **PATH** | Liste des dossiers où le shell cherche les commandes. |
| **PCA / PRA** | Plan de continuité / de reprise d'activité. |
| **PID** | Identifiant de processus ; le PID 1 est systemd. |
| **Pipe** | `\|` : relie la sortie d'une commande à l'entrée de la suivante. |
| **PromQL** | Langage de requête de Prometheus. |
| **Quorum** | Majorité de votes nécessaire à un cluster pour agir (⌊n/2⌋+1). |
| **RAID** | Redondance/agrégation de disques (0, 1, 5, 6, 10). |
| **Reverse proxy** | Serveur intermédiaire exposé qui relaie vers des serveurs internes. |
| **RPO / RTO** | Perte de données / durée d'interruption maximales tolérées. |
| **rsync** | Synchronisation incrémentale de fichiers. |
| **Runbook** | Procédure d'exploitation pas à pas pour un incident. |
| **seccomp** | Filtre des appels système autorisés. |
| **SELinux** | Contrôle d'accès obligatoire par étiquettes (RHEL/Fedora). |
| **Shell** | Programme qui interprète les commandes (bash, zsh…). |
| **SLI / SLO / SLA** | Indicateur / objectif / accord de niveau de service. |
| **Split-brain** | Deux moitiés d'un cluster se croient actives simultanément. |
| **SPOF** | Point unique de défaillance. |
| **ss** | Outil d'inspection des sockets (remplace netstat). |
| **stderr / stdout / stdin** | Flux standards 2 / 1 / 0. |
| **sudo** | Exécution de commandes avec les droits d'un autre utilisateur, avec traçabilité. |
| **Sticky bit** | Bit `t` : seul le propriétaire peut supprimer ses fichiers dans le dossier. |
| **Swap** | Espace disque servant d'extension de mémoire. |
| **sysctl** | Réglage des paramètres du noyau à chaud (`/proc/sys`). |
| **systemd** | Gestionnaire de système et de services (PID 1). |
| **tmux** | Multiplexeur de terminaux (sessions persistantes). |
| **Timer systemd** | Unité de déclenchement planifié (alternative à cron). |
| **udev** | Gestion dynamique des périphériques et de `/dev`. |
| **umask** | Masque des droits par défaut des nouveaux fichiers. |
| **Unit (unité)** | Objet géré par systemd (service, timer, mount, target…). |
| **VRRP** | Protocole de redondance d'une adresse IP de passerelle. |
| **veth** | Paire d'interfaces virtuelles reliées comme un câble. |
| **Vault** | Chiffrement de secrets (Ansible Vault, HashiCorp Vault). |
| **WireGuard** | VPN moderne dans le noyau. |
| **Zombie** | Processus terminé dont le parent n'a pas encore lu le code retour. |
