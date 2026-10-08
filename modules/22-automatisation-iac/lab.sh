#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/lib.sh"
LAB_ID=22
LAB_REQUIRES=(cmd:ansible-playbook cmd:ansible-vault cmd:ansible-inventory cmd:python3)

lab_setup() {
  cd "$LAB_DIR" || return 1
  rm -rf cible roles group_vars inventaire.ini site.yml
  echo "formation-lab" > .vault_pass; chmod 600 .vault_pass
  cat > ansible.cfg <<'EOF'
[defaults]
inventory = inventaire.ini
roles_path = roles
host_key_checking = False
retry_files_enabled = False
interpreter_python = auto_silent
vault_password_file = .vault_pass
nocows = 1
EOF
}

# Exécute ansible-playbook dans le labo, renvoie sortie dans $PB_OUT et code dans $PB_RC
pb() { PB_OUT=$(cd "$LAB_DIR" && ANSIBLE_CONFIG="$LAB_DIR/ansible.cfg" ANSIBLE_FORCE_COLOR=0 ansible-playbook "$@" 2>&1); PB_RC=$?; }
recap_sum() { # recap_sum <champ> → somme sur tous les hôtes du récapitulatif
  awk -v f="$1" '/ : ok=/ { for (i=1;i<=NF;i++) if ($i ~ "^"f"=") { split($i,a,"="); s+=a[2] } } END{print s+0}' <<<"$PB_OUT"
}

lab_check() {
  cd "$LAB_DIR" || return 1
  local T="$LAB_DIR/cible"
  # ---- 1. inventaire
  local inv; inv=$(cd "$LAB_DIR" && ANSIBLE_CONFIG="$LAB_DIR/ansible.cfg" ansible-inventory --list 2>/dev/null)
  inv_ok() { python3 -c "
import json,sys
d=json.loads(sys.stdin.read())
h=d['_meta']['hostvars']
c={'web':set(d.get('web',{}).get('hosts',[])),'db':set(d.get('db',{}).get('hosts',[]))}
ok={'web':c['web']=={'web1','web2'},'db':c['db']=={'db1'},
 'prod':set(d.get('prod',{}).get('children',[]))>={'web','db'},
 'ports':str(h.get('web1',{}).get('web_port'))=='8081' and str(h.get('web2',{}).get('web_port'))=='8082',
 'local':all(h.get(x,{}).get('ansible_connection')=='local' for x in ('web1','web2','db1'))}
sys.exit(0 if ok['$1'] else 1)" <<<"$inv" 2>/dev/null; }
  assert "1 groupe web = web1, web2" inv_ok web
  assert "1 groupe db = db1" inv_ok db
  assert "1 groupe prod contient web et db (children)" inv_ok prod
  assert "1 web_port 8081/8082 par hôte" inv_ok ports
  assert "1 ansible_connection=local partout" inv_ok local
  # ---- 3. vault
  assert "3 vault.yml chiffré (en-tête \$ANSIBLE_VAULT)" bash -c "head -1 group_vars/db/vault.yml | grep -q '^\$ANSIBLE_VAULT;'"
  assert "3 vault.yml se déchiffre avec .vault_pass et contient vault_db_password" bash -c "ansible-vault view group_vars/db/vault.yml --vault-password-file .vault_pass 2>&1 | grep -q vault_db_password"
  assert "3 vars.yml (clair) : db_password référence vault_db_password" grep -Eq 'db_password:.*vault_db_password' group_vars/db/vars.yml
  # ---- syntaxe
  pb site.yml --syntax-check
  assert_eq "4 site.yml : --syntax-check" 0 "$PB_RC"
  assert "2 rôle web : defaults, tasks, templates, handlers" bash -c "cd roles/web && test -s defaults/main.yml && test -s tasks/main.yml && test -s handlers/main.yml && test -s templates/site.conf.j2 && test -s templates/index.html.j2"
  # ---- exécution 1 (depuis zéro)
  rm -rf "$T"
  pb site.yml
  assert_eq "4 première exécution : code retour 0" 0 "$PB_RC"
  assert_eq "4 première exécution : failed=0" 0 "$(recap_sum failed)"
  assert "4 première exécution : des changements (changed>0)" bash -c "[[ $(recap_sum changed) -gt 0 ]]"
  for h in web1 web2; do
    local port; [[ $h == web1 ]] && port=8081 || port=8082
    assert_grep "2 $h : site.conf listen $port;" "^[[:space:]]*listen $port;" "$T/$h/conf/site.conf"
    assert_grep "2 $h : site.conf server_name $h;" "^[[:space:]]*server_name $h;" "$T/$h/conf/site.conf"
    assert_grep "2 $h : features gzip et cache (boucle)" '# feature: gzip' "$T/$h/conf/site.conf"
    assert_grep "2 $h : feature cache" '# feature: cache' "$T/$h/conf/site.conf"
    assert_grep "2 $h : index.html <h1>Bienvenue</h1>" '<h1>Bienvenue</h1>' "$T/$h/www/index.html"
    assert_grep "2 $h : index.html « Serveur $h port $port »" "Serveur $h port $port" "$T/$h/www/index.html"
    assert "2 $h : dossier logs créé" test -d "$T/$h/logs"
    assert "2 $h : reload.flag écrit par le handler (config modifiée)" test -f "$T/$h/reload.flag"
  done
  assert_grep "4 db1 : db.conf contient le mot de passe déchiffré" '^password = S3cr3t!$' "$T/db1/conf/db.conf"
  assert_grep "4 db1 : db.conf listen = 127.0.0.1" '^listen = 127\.0\.0\.1$' "$T/db1/conf/db.conf"
  assert_mode "4 db1 : db.conf en 0600" 600 "$T/db1/conf/db.conf"
  # ---- exécution 2 : idempotence
  rm -f "$T"/web1/reload.flag "$T"/web2/reload.flag
  pb site.yml
  assert_eq "5 idempotence : 2ᵉ exécution changed=0" 0 "$(recap_sum changed)"
  assert "5 handler non déclenché sans changement de config (pas de reload.flag)" bash -c "test ! -e '$T/web1/reload.flag' && test ! -e '$T/web2/reload.flag'"
  # ---- exécution 3 : changement de variable sur l'index
  pb site.yml -e web_message=Salut
  assert_grep "5 -e web_message=Salut : index mis à jour" '<h1>Salut</h1>' "$T/web1/www/index.html"
  assert "5 index modifié ⇒ pas de reload (le handler n'est notifié que par la config)" test ! -e "$T/web1/reload.flag"
  # ---- exécution 4 : changement de config ⇒ handler
  pb site.yml -e '{"web_features":["gzip"]}'
  assert_eq "5 changement de features : exécution OK" 0 "$PB_RC"
  assert "5 site.conf mis à jour (plus de feature cache)" bash -c "! grep -q 'feature: cache' '$T/web1/conf/site.conf' && grep -q 'feature: gzip' '$T/web1/conf/site.conf'"
  assert "5 config modifiée ⇒ handler exécuté (reload.flag réapparaît)" test -f "$T/web1/reload.flag"
  # ---- retour à l'état nominal
  pb site.yml >/dev/null
}

lab_solve() {
  cd "$LAB_DIR" || return 1
  cat > inventaire.ini <<'EOF'
[web]
web1 ansible_connection=local web_port=8081
web2 ansible_connection=local web_port=8082

[db]
db1 ansible_connection=local

[prod:children]
web
db
EOF
  mkdir -p group_vars/db roles/web/{defaults,tasks,templates,handlers}
  echo 'target_root: "{{ playbook_dir }}/cible"' > group_vars/all.yml
  cat > roles/web/defaults/main.yml <<'EOF'
web_port: 80
web_message: "Bienvenue"
web_features: [gzip, cache]
EOF
  cat > roles/web/tasks/main.yml <<'EOF'
- name: Créer l'arborescence de l'hôte
  ansible.builtin.file:
    path: "{{ target_root }}/{{ inventory_hostname }}/{{ item }}"
    state: directory
    mode: "0755"
  loop: [conf, www, logs]

- name: Configuration du site
  ansible.builtin.template:
    src: site.conf.j2
    dest: "{{ target_root }}/{{ inventory_hostname }}/conf/site.conf"
    mode: "0644"
  notify: recharger

- name: Page d'accueil
  ansible.builtin.template:
    src: index.html.j2
    dest: "{{ target_root }}/{{ inventory_hostname }}/www/index.html"
    mode: "0644"
EOF
  cat > roles/web/handlers/main.yml <<'EOF'
- name: recharger
  ansible.builtin.copy:
    content: "rechargé\n"
    dest: "{{ target_root }}/{{ inventory_hostname }}/reload.flag"
    mode: "0644"
EOF
  cat > roles/web/templates/site.conf.j2 <<'EOF'
server {
    listen {{ web_port }};
    server_name {{ inventory_hostname }};
{% for f in web_features %}
    # feature: {{ f }}
{% endfor %}
}
EOF
  cat > roles/web/templates/index.html.j2 <<'EOF'
<h1>{{ web_message }}</h1>
Serveur {{ inventory_hostname }} port {{ web_port }}
EOF
  echo 'vault_db_password: "S3cr3t!"' > group_vars/db/vault.yml
  ANSIBLE_CONFIG="$LAB_DIR/ansible.cfg" ansible-vault encrypt group_vars/db/vault.yml >/dev/null 2>&1
  echo 'db_password: "{{ vault_db_password }}"' > group_vars/db/vars.yml
  cat > site.yml <<'EOF'
- name: Sites web
  hosts: web
  gather_facts: false
  roles:
    - web

- name: Base de données
  hosts: db
  gather_facts: false
  tasks:
    - name: Dossier de configuration
      ansible.builtin.file:
        path: "{{ target_root }}/{{ inventory_hostname }}/conf"
        state: directory
        mode: "0755"
    - name: Fichier db.conf
      ansible.builtin.copy:
        content: |
          password = {{ db_password }}
          listen = 127.0.0.1
        dest: "{{ target_root }}/{{ inventory_hostname }}/conf/db.conf"
        mode: "0600"
      no_log: true
EOF
}

lab_main "$@"
