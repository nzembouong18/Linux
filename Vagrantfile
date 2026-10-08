# -*- mode: ruby -*-
# Laboratoire VM complet (modules stockage, noyau/boot, réseau avancé, systemd réels).
#   vagrant up            # VM « lab » (2 disques additionnels de 1 Go) + VM « srv1 » (cible SSH / réseau)
#   vagrant ssh lab
#   cd /vagrant && ./lab list
Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-24.04"
  config.vm.synced_folder ".", "/vagrant"

  PACKAGES = %w[
    bash-completion vim nano tree file bc tmux iproute2 iputils-ping dnsutils netcat-openbsd curl
    tcpdump nftables traceroute mtr-tiny iperf3 procps psmisc lsof htop strace sysstat stress-ng
    acl attr lvm2 parted gdisk xfsprogs mdadm cryptsetup-bin tar bzip2 xz-utils zstd zip rsync git jq
    shellcheck python3-yaml python3-jmespath nginx apache2-utils haproxy keepalived busybox-static
    prometheus prometheus-node-exporter ansible-core yamllint openssh-server
  ].join(" ")

  config.vm.define "lab", primary: true do |lab|
    lab.vm.hostname = "lab"
    lab.vm.network "private_network", ip: "192.168.56.10"
    lab.vm.provider "virtualbox" do |vb|
      vb.name = "linux-lab"
      vb.memory = 4096
      vb.cpus = 2
    end
    lab.vm.provider "libvirt" do |lv|
      lv.memory = 4096
      lv.cpus = 2
      lv.storage :file, size: "1G"
      lv.storage :file, size: "1G"
    end
    # Disques additionnels (modules 13 : partitionnement, LVM, RAID)
    lab.vm.disk :disk, size: "1GB", name: "extra1"
    lab.vm.disk :disk, size: "1GB", name: "extra2"
    lab.vm.provision "shell", inline: <<-SHELL
      set -e
      export DEBIAN_FRONTEND=noninteractive
      apt-get update
      apt-get install -y --no-install-recommends #{PACKAGES}
      systemctl disable --now nginx haproxy keepalived prometheus prometheus-node-exporter 2>/dev/null || true
      id student >/dev/null 2>&1 || useradd -m -s /bin/bash -G sudo student
      echo 'student ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/student
      echo 'student:formation' | chpasswd
      ln -sfn /vagrant /home/student/formation
      echo 'cd /vagrant 2>/dev/null; export LAB_ROOT=$HOME/labs' >> /home/student/.bashrc
    SHELL
  end

  config.vm.define "srv1" do |srv|
    srv.vm.hostname = "srv1"
    srv.vm.network "private_network", ip: "192.168.56.11"
    srv.vm.provider "virtualbox" do |vb|
      vb.name = "linux-srv1"
      vb.memory = 1024
      vb.cpus = 1
    end
    srv.vm.provision "shell", inline: <<-SHELL
      export DEBIAN_FRONTEND=noninteractive
      apt-get update && apt-get install -y --no-install-recommends openssh-server python3 nginx rsync
      systemctl enable --now ssh nginx
      echo "srv1 : serveur cible des exercices SSH, rsync et réseau" > /var/www/html/index.html
    SHELL
  end
end
