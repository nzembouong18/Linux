#!/usr/bin/env bash
# Démo formateur — module 22 (≈ 45 min). Ansible en local, cible = dossier temporaire.
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/demo-lib.sh"
command -v ansible-playbook >/dev/null || { demo_say "ansible absent (apt install ansible-core) — démonstration théorique."; exit 0; }
export ANSIBLE_CONFIG="$DEMO_DIR/ansible.cfg" ANSIBLE_FORCE_COLOR=0 ANSIBLE_NOCOWS=1
printf '[defaults]\ninventory = inv.ini\nhost_key_checking = False\nretry_files_enabled = False\ninterpreter_python = auto_silent\n' > ansible.cfg
cat > inv.ini <<'EOF'
[web]
web1 ansible_connection=local port=8081
web2 ansible_connection=local port=8082
EOF
ap() { ansible-playbook "$@" 2>&1 | grep -v -E '^$|^\[WARNING\]' | cut -c1-110; }

demo_title "Inventaire et commande ad hoc"
demo_run "ansible-inventory --graph 2>&1"
demo_run "ansible web -m ansible.builtin.ping 2>&1 | head -6"
demo_run "ansible web -m ansible.builtin.command -a 'echo bonjour depuis {{ inventory_hostname }}' 2>&1 | grep -v WARN | head -4"
demo_run "ansible-doc -s ansible.builtin.lineinfile 2>/dev/null | head -8"

demo_title "Un playbook idempotent avec template et handler"
demo_run "mkdir -p templates && printf 'server {\\n  listen {{ port }};\\n  name {{ inventory_hostname }};\\n{%% for f in features %%}\\n  # feature: {{ f }}\\n{%% endfor %%}\\n}\\n' > templates/site.conf.j2 && cat templates/site.conf.j2"
demo_run "cat > site.yml <<'EOF'
- hosts: web
  gather_facts: false
  vars:
    features: [gzip, cache]
    root: \"{{ playbook_dir }}/cible\"
  tasks:
    - name: Dossier
      ansible.builtin.file: { path: \"{{ root }}/{{ inventory_hostname }}\", state: directory }
    - name: Configuration
      ansible.builtin.template: { src: site.conf.j2, dest: \"{{ root }}/{{ inventory_hostname }}/site.conf\" }
      notify: recharger
  handlers:
    - name: recharger
      ansible.builtin.copy: { content: \"rechargé\\n\", dest: \"{{ root }}/{{ inventory_hostname }}/reload.flag\" }
EOF
ansible-playbook site.yml --syntax-check 2>&1 | tail -1"
demo_run "ansible-playbook site.yml --check --diff 2>&1 | grep -E 'TASK|changed|\\+|ok=' | head -14"
demo_say "--check ne modifie rien : on vérifie que cible/ n'existe pas encore."
demo_run "ls cible 2>&1 | head -1"
demo_title "1ʳᵉ exécution : changed > 0 ; 2ᵉ exécution : changed=0 (idempotence)"
demo_run "ansible-playbook site.yml 2>&1 | grep -E 'RUNNING HANDLER|PLAY RECAP|ok=' "
demo_run "ansible-playbook site.yml 2>&1 | grep -E 'RUNNING HANDLER|PLAY RECAP|ok='"
demo_run "ls cible/web1; cat cible/web1/site.conf"
demo_title "Changer une variable : seul ce qui doit changer change"
demo_run "ansible-playbook site.yml -e '{\"features\":[\"gzip\"]}' --diff 2>&1 | grep -E '^[-+] |RUNNING HANDLER|ok=' | head -10"

demo_title "Ansible Vault"
demo_run "echo formation > vp; echo 'db_password: S3cr3t' > secrets.yml; ansible-vault encrypt secrets.yml --vault-password-file vp 2>&1 | tail -1; head -2 secrets.yml | cut -c1-40"
demo_run "ansible-vault view secrets.yml --vault-password-file vp 2>&1"
demo_run "ansible-vault encrypt_string 'MonSecret!' --name db_password --vault-password-file vp 2>&1 | head -3"

demo_title "cloud-init et Terraform (aperçu)"
demo_run "printf '#cloud-config\\nhostname: web01\\npackages: [nginx]\\nruncmd:\\n  - systemctl enable --now nginx\\n' > user-data.yaml; cat user-data.yaml"
demo_run "command -v cloud-init >/dev/null && cloud-init schema --config-file user-data.yaml 2>&1 | tail -2 || echo '(cloud-init non installé : cloud-init schema --config-file user-data.yaml valide ce fichier)'"
demo_run "command -v terraform tofu 2>/dev/null | head -1 || echo '(terraform/tofu non installés : terraform init && terraform plan)'"
demo_end
