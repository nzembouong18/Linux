# Environnement de laboratoire pour la formation Linux
# Ubuntu 24.04 LTS + systemd (PID 1) + tous les outils utilisés par les 25 modules.
#   docker compose up -d --build
#   docker compose exec -u student lab bash
FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ENV container=docker \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# policy-rc.d : les paquets ne démarrent pas leurs services pendant la construction
RUN printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d && chmod +x /usr/sbin/policy-rc.d

RUN apt-get update && apt-get install -y --no-install-recommends \
      systemd systemd-sysv dbus sudo locales ca-certificates tzdata \
      bash-completion vim nano less man-db manpages tree file bc bsdextrautils tmux gawk sed \
      iproute2 iputils-ping dnsutils netcat-openbsd curl wget openssh-client openssh-server \
      tcpdump nftables traceroute mtr-tiny iperf3 net-tools \
      procps psmisc lsof htop strace sysstat stress-ng cron logrotate rsyslog acl attr \
      lvm2 parted gdisk xfsprogs e2fsprogs dosfstools mdadm cryptsetup-bin kmod udev \
      tar gzip bzip2 xz-utils zstd zip unzip rsync git jq gnupg openssl shellcheck \
      python3 python3-yaml python3-jmespath \
      nginx-light apache2-utils haproxy keepalived busybox-static \
      prometheus prometheus-node-exporter \
      ansible-core yamllint \
    && rm -rf /var/lib/apt/lists/* \
    && rm -f /usr/sbin/policy-rc.d

# Les services « lourds » sont démarrés par les labos eux-mêmes (ports aléatoires) : on les désactive
RUN systemctl mask nginx.service haproxy.service keepalived.service prometheus.service \
      prometheus-node-exporter.service ssh.service ssh.socket \
    && systemctl mask getty.target console-getty.service systemd-udevd.service systemd-udevd-kernel.socket \
      systemd-udevd-control.socket systemd-modules-load.service sys-kernel-debug.mount sys-kernel-tracing.mount \
      dev-hugepages.mount systemd-remount-fs.service

# Utilisateur de formation (sudo sans mot de passe : environnement jetable !)
RUN useradd -m -s /bin/bash -G sudo student \
    && echo 'student ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/student && chmod 440 /etc/sudoers.d/student \
    && echo 'student:formation' | chpasswd

# Copie du dépôt (remplacée par un montage dans docker-compose.yml pour pouvoir éditer)
COPY --chown=student:student . /opt/linux-training
RUN ln -s /opt/linux-training /home/student/formation \
    && printf '\n# Formation Linux\ncd /opt/linux-training 2>/dev/null\nexport LAB_ROOT=$HOME/labs\nalias lab=/opt/linux-training/lab\n' >> /home/student/.bashrc

STOPSIGNAL SIGRTMIN+3
VOLUME ["/sys/fs/cgroup"]
CMD ["/sbin/init"]
