# Labo 22 — Un projet Ansible complet : inventaire, rôle, handlers, Vault et idempotence

> **Durée** : 4 h · **Difficulté** : ⭐⭐⭐⭐ · **Prérequis** : module 22 · outils : `ansible-core`, `ansible-vault`
> Les « serveurs » sont des hôtes **locaux** (`ansible_connection=local`) et la configuration est déployée dans le dossier `cible/` du labo : rien n'est installé ni modifié sur votre système.

## Contexte

Vous automatisez le déploiement de deux sites web et d'une base de données, sur une maquette où chaque hôte est un dossier. Le correcteur **rejoue vos playbooks** plusieurs fois : il vérifie le résultat, l'**idempotence** et le bon fonctionnement des **handlers**.

## Mise en place

```bash
./lab setup 22
cd ~/labs/22 && ls -a && cat ansible.cfg
```
Fournis : `ansible.cfg` (inventaire, `roles_path = roles`, mot de passe Vault `.vault_pass`), `.vault_pass`. Variable globale à utiliser : `target_root` = dossier `cible/` du labo (à définir dans `group_vars/all.yml` : `target_root: "{{ playbook_dir }}/cible"`).

## Cahier des charges

1. **`inventaire.ini`** : groupe `web` = `web1` (`web_port=8081`) et `web2` (`web_port=8082`) ; groupe `db` = `db1` ; groupe `prod` contenant `web` et `db` (*children*). Tous avec `ansible_connection=local`.
2. **Rôle `web`** (`roles/web/`) :
   - `defaults/main.yml` : `web_port: 80`, `web_message: "Bienvenue"`, `web_features: [gzip, cache]` ;
   - création des dossiers `{{ target_root }}/{{ inventory_hostname }}/conf`, `…/www`, `…/logs` ;
   - modèle `site.conf.j2` → `conf/site.conf` contenant : `listen <port>;`, `server_name <hôte>;` et **une ligne `# feature: <nom>` par élément** de `web_features` (boucle Jinja2) ;
   - modèle `index.html.j2` → `www/index.html` : `<h1>{{ web_message }}</h1>` puis une ligne `Serveur <hôte> port <port>` ;
   - la modification de `site.conf` **notifie** le handler `recharger` qui écrit le fichier `{{ target_root }}/{{ inventory_hostname }}/reload.flag` (contenu libre). Le changement de `index.html` ne notifie rien.
3. **Vault** : `group_vars/db/vault.yml` **chiffré** (avec `.vault_pass`) contenant `vault_db_password: "S3cr3t!"`, et `group_vars/db/vars.yml` (clair) : `db_password: "{{ vault_db_password }}"`.
4. **`site.yml`** : play 1 sur `web` avec le rôle `web` ; play 2 sur `db` créant `{{ target_root }}/db1/conf/db.conf` (**mode `0600`**) contenant `password = <db_password>` et `listen = 127.0.0.1`.
5. **Idempotence** : après une première exécution, une seconde ne doit rien changer (`changed=0` pour tous les hôtes).

## Validation

```bash
./lab check 22
```

Pour tester vous-même :
```bash
ansible-playbook site.yml --syntax-check
ansible-playbook site.yml --check --diff
ansible-playbook site.yml            # puis relancez : changed=0 ?
ansible-playbook site.yml -e web_message="Salut"
```

<details><summary>💡 Indices</summary>

- `ansible-vault encrypt group_vars/db/vault.yml` (après avoir créé le fichier en clair) — le `vault_password_file` est déjà dans `ansible.cfg`.
- `ansible.builtin.file` avec `loop: [conf, www, logs]` et `state: directory`.
- `ansible.builtin.template` + `notify: recharger` ; handler : `ansible.builtin.copy: { content: "rechargé\n", dest: … }`.
- Boucle Jinja2 : `{% for f in web_features %}    # feature: {{ f }}{% endfor %}`.
- `no_log: true` sur les tâches manipulant des secrets (bonne pratique).
</details>

<details><summary>✅ Solution</summary>

```bash
cd ~/labs/22
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
echo 'vault_db_password: "S3cr3t!"' > group_vars/db/vault.yml && ansible-vault encrypt group_vars/db/vault.yml
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
```
</details>

## Pour aller plus loin

- Ajoutez un rôle `common` (`lineinfile`, `blockinfile`) et un 3ᵉ play ; utilisez des **tags** (`--tags config`).
- Passez `yamllint` et `ansible-lint` sur le projet ; corrigez les avertissements.
- Utilisez `serial: 1` et `max_fail_percentage` sur le play `web`.
- Reproduisez la logique sur de vraies machines (VM Vagrant du dépôt) avec `apt`, `service`, `ufw`.

## Nettoyage

```bash
./lab reset 22
```
