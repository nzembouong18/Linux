# Module 22 — Automatisation et Infrastructure as Code : Ansible, cloud-init, Terraform

> **Niveau** : Professionnel | **Durée** : 7 h (3 h cours + 4 h labo) | **Prérequis** : modules 09, 12, 14, 19
>
> **Objectifs** — À la fin de ce module vous saurez :
> - expliquer l'**Infrastructure as Code** : déclaratif, idempotence, versionnement, serveurs « bétail » plutôt que « animaux de compagnie » ;
> - écrire des **playbooks Ansible** : inventaire, variables, modules, modèles Jinja2, *handlers*, **rôles**, **Vault** ;
> - garantir l'**idempotence** et vérifier (`--check`, `--diff`, relance sans changement) ;
> - initialiser des machines avec **cloud-init** ;
> - situer **Terraform/OpenTofu**, **Packer**, **Vagrant** et le flux GitOps ;
> - tester et industrialiser (lint, CI, revue de code).

---

## 1. Pourquoi automatiser ?

| Sans automatisation | Avec l'IaC |
|---------------------|-----------|
| Serveurs « flocons de neige » configurés à la main | Configuration **reproductible** à partir de code |
| « Ça marche chez moi » | Environnements identiques (dev = préprod = prod) |
| Savoir dans la tête de 2 personnes | Savoir **documenté, relu, versionné** (git) |
| Déploiement = nuit blanche | Déploiement répétable, rapide, testé |
| Dérive de configuration (*drift*) | Reconvergence : on rejoue l'état désiré |
| Reconstruction après sinistre = semaines | Reconstruction = relancer le code |

### Principes

- **Déclaratif** : on décrit l'**état voulu** (« le paquet nginx est présent, le service est actif »), pas la suite de commandes.
- **Idempotence** : appliquer N fois = même résultat que 1 fois ; la 2ᵉ exécution ne change **rien** (`changed=0`).
- **Immuable vs mutable** : remplacer un serveur par une nouvelle image plutôt que le modifier en place.
- **Tout dans git** : revue de code, historique, retour arrière, CI.
- **Pas de secrets en clair** : Vault, SOPS, gestionnaire de secrets.

### Le paysage des outils

| Besoin | Outils |
|--------|--------|
| Créer l'infrastructure (réseaux, VM, bases, DNS) | **Terraform / OpenTofu**, Pulumi, CloudFormation |
| Construire des images | **Packer**, Dockerfile, `kiwi`, Image Builder |
| Initialiser au premier démarrage | **cloud-init**, Ignition |
| Configurer l'OS et les applications | **Ansible**, Puppet, Chef, SaltStack |
| Environnements de dev jetables | Vagrant, Docker Compose |
| Orchestration de conteneurs | Kubernetes (Helm, Kustomize) |
| Livraison continue / GitOps | GitHub Actions, GitLab CI, Argo CD, Flux |

## 2. Ansible : les bases

**Ansible** configure des machines via **SSH** (ou localement), sans agent. Il lit un **inventaire**, exécute des **playbooks** (YAML) composés de **tâches** qui appellent des **modules** idempotents.

```text
 Machine de contrôle (Ansible) ──SSH──► hôtes gérés (Python requis, pas d'agent)
      inventaire + playbooks + rôles
```

```bash
sudo apt install ansible-core        # ou : pipx install ansible-core ; collections : ansible-galaxy collection install community.general
ansible --version
```

### Inventaire (`inventaire.ini`)

```ini
[web]
web1 ansible_host=10.0.1.11 web_port=8081
web2 ansible_host=10.0.1.12 web_port=8082

[db]
db1 ansible_host=10.0.2.21

[prod:children]
web
db

[all:vars]
ansible_user=deploy
ansible_python_interpreter=/usr/bin/python3
```
Variantes : YAML, inventaires dynamiques (cloud). Variables de groupe/hôte : `group_vars/web.yml`, `host_vars/web1.yml`.

```bash
ansible-inventory -i inventaire.ini --graph
ansible-inventory -i inventaire.ini --list --yaml
```

### Commandes ad hoc (une action, sans playbook)

```bash
ansible all -i inventaire.ini -m ping
ansible web -m ansible.builtin.command -a "uptime"
ansible web -b -m ansible.builtin.apt -a "name=nginx state=present update_cache=true"     # -b : devenir root (become)
ansible web -b -m ansible.builtin.service -a "name=nginx state=restarted"
ansible all -m ansible.builtin.setup -a "filter=ansible_distribution*"                    # facts
```

### Un playbook

```yaml
---
- name: Serveurs web
  hosts: web
  become: true
  vars:
    web_message: "Bienvenue"
  tasks:
    - name: Installer nginx
      ansible.builtin.apt:
        name: nginx
        state: present
        update_cache: true
        cache_valid_time: 3600

    - name: Déployer la configuration
      ansible.builtin.template:
        src: site.conf.j2
        dest: /etc/nginx/conf.d/site.conf
        owner: root
        group: root
        mode: "0644"
        validate: "nginx -t -c /etc/nginx/nginx.conf"      # (exemple : validation avant remplacement)
      notify: Recharger nginx

    - name: Service actif et activé au démarrage
      ansible.builtin.service:
        name: nginx
        state: started
        enabled: true

  handlers:
    - name: Recharger nginx
      ansible.builtin.service:
        name: nginx
        state: reloaded
```

```bash
ansible-playbook -i inventaire.ini site.yml --syntax-check       # syntaxe
ansible-playbook -i inventaire.ini site.yml --check --diff       # simulation avec différences (dry-run)
ansible-playbook -i inventaire.ini site.yml                      # exécution
ansible-playbook site.yml --limit web1 --tags config -e web_message="Salut" -v      # cibler / variable en ligne de commande
ansible-playbook site.yml --start-at-task "Déployer la configuration" --step
```

### Modules courants

| Domaine | Modules (`ansible.builtin.` sauf mention) |
|---------|--------------------------------------------|
| Paquets | `apt`, `dnf`, `package`, `pip` |
| Services | `service`, `systemd_service` |
| Fichiers | `file`, `copy`, `template`, `lineinfile`, `blockinfile`, `replace`, `fetch`, `unarchive`, `stat` |
| Utilisateurs | `user`, `group`, `authorized_key` (`ansible.posix`) |
| Réseau | `uri`, `get_url`, `wait_for` |
| Système | `cron`, `hostname`, `sysctl` (`ansible.posix`), `mount` (`ansible.posix`), `reboot` |
| Pare-feu | `ufw` (`community.general`), `firewalld` (`ansible.posix`) |
| Exécution | `command`, `shell` (⚠ non idempotents sauf `creates`/`changed_when`), `script` |
| Contrôle | `debug`, `assert`, `fail`, `set_fact`, `include_tasks`, `import_role` |
| Conteneurs / Cloud | `community.docker.*`, `amazon.aws.*`, `kubernetes.core.*` |

Aide : `ansible-doc ansible.builtin.lineinfile` (exemples intégrés).

### Variables, conditions, boucles

```yaml
- name: Créer des comptes
  ansible.builtin.user:
    name: "{{ item.name }}"
    groups: "{{ item.groups | default([]) }}"
    shell: /bin/bash
  loop:
    - { name: alice, groups: [sudo] }
    - { name: bob }
  when: ansible_facts['os_family'] == "Debian"

- name: Démarrer seulement si le port est libre
  ansible.builtin.command: /opt/app/start.sh
  args: { creates: /run/app.pid }                 # idempotence d'une commande
  register: resultat
  changed_when: "'started' in resultat.stdout"
  failed_when: resultat.rc not in [0, 2]
```
Précédence des variables (du moins au plus prioritaire) : valeurs par défaut du rôle → inventaire/group_vars → host_vars → play vars → `set_fact` → **`-e` en ligne de commande** (toujours gagnant).

### Modèles Jinja2 (`templates/site.conf.j2`)

```jinja
# Fichier géré par Ansible — NE PAS MODIFIER À LA MAIN
server {
    listen {{ web_port | default(80) }};
    server_name {{ inventory_hostname }};
{% for f in web_features %}
    # feature: {{ f }}
{% endfor %}
{% if web_tls | default(false) %}
    ssl_certificate /etc/ssl/{{ inventory_hostname }}.pem;
{% endif %}
}
```
Filtres utiles : `default()`, `join(',')`, `upper`, `to_json`, `to_nice_yaml`, `ipaddr` (collection `ansible.utils`), `password_hash('sha512')`.

### Rôles : réutilisables et structurés

```text
roles/web/
├── defaults/main.yml     valeurs par défaut (faible priorité, surchargeables)
├── vars/main.yml         variables internes (forte priorité)
├── tasks/main.yml        les tâches
├── handlers/main.yml     handlers
├── templates/*.j2        modèles
├── files/                fichiers statiques
└── meta/main.yml         dépendances
```
```yaml
- hosts: web
  roles:
    - role: web
      vars: { web_message: "Hello" }
```
`ansible-galaxy role init web` crée le squelette ; `ansible-galaxy install -r requirements.yml` récupère des rôles/collections communautaires (vérifiez leur qualité et épinglez les versions).

### Handlers

Exécutés **une seule fois, en fin de play**, et **seulement si une tâche notifiante a changé quelque chose** : idéal pour « recharger le service uniquement si la configuration a changé ». `meta: flush_handlers` les force immédiatement.

### Ansible Vault : secrets chiffrés

```bash
ansible-vault create group_vars/db/vault.yml          # édite un fichier chiffré
ansible-vault encrypt secrets.yml ; ansible-vault decrypt secrets.yml
ansible-vault view group_vars/db/vault.yml
ansible-vault rekey group_vars/db/vault.yml
ansible-vault encrypt_string 'S3cr3t!' --name 'db_password'      # chiffre une seule valeur à coller dans un YAML
ansible-playbook site.yml --ask-vault-pass                        # ou --vault-password-file .vault_pass (fichier hors git !)
```
Convention : `group_vars/db/vars.yml` (non secret, référence `db_password: "{{ vault_db_password }}"`) + `group_vars/db/vault.yml` (secrets chiffrés, préfixe `vault_`).

### Bonnes pratiques

1. **Noms de tâches explicites** et **FQCN** (`ansible.builtin.copy`).
2. Préférez les modules aux `command`/`shell` ; sinon `creates`, `changed_when`, `check_mode`.
3. **Idempotence testée** : deuxième exécution = `changed=0`.
4. `--check --diff` avant la production ; déploiements progressifs (`serial: 1`, `max_fail_percentage`).
5. Rôles petits, paramétrés par des `defaults/` documentés.
6. `ansible-lint` et `yamllint` en CI ; **Molecule** pour tester les rôles sur conteneurs.
7. Secrets dans Vault/SOPS ; pas de mots de passe dans git.
8. Inventaire par environnement (`inventaires/prod`, `inventaires/preprod`).
9. `become` seulement où nécessaire ; clés SSH + utilisateur dédié.
10. Documenter (README du rôle) et versionner (tags).

## 3. cloud-init : initialiser une VM au premier démarrage

Images cloud (Ubuntu, Debian, Rocky…) lisent un fichier **user-data** fourni par la plateforme (OpenStack, AWS, Azure, libvirt, Proxmox…).

```yaml
#cloud-config
hostname: web01
timezone: Europe/Paris
package_update: true
packages: [nginx, git, htop]
users:
  - name: deploy
    groups: [sudo]
    shell: /bin/bash
    sudo: "ALL=(ALL) NOPASSWD:ALL"
    ssh_authorized_keys:
      - ssh-ed25519 AAAA... alice@portable
write_files:
  - path: /etc/motd
    content: |
      Serveur géré par Ansible — ne pas modifier à la main
runcmd:
  - systemctl enable --now nginx
  - [ sh, -c, "echo ready > /var/lib/ready" ]
ssh_pwauth: false
```
```bash
cloud-init status --long ; sudo cloud-init analyze show ; sudo less /var/log/cloud-init-output.log
sudo cloud-init schema --config-file user-data.yaml          # valide le fichier
```
Chaîne typique : **Terraform** crée la VM avec un user-data → cloud-init crée l'utilisateur et installe Python → **Ansible** configure le reste.

## 4. Terraform / OpenTofu : l'infrastructure en code

Terraform décrit des **ressources** (VM, réseau, DNS, bases…) chez un **fournisseur** (*provider*) ; il calcule la différence entre l'état désiré (`.tf`) et l'**état connu** (`terraform.tfstate`).

```hcl
terraform {
  required_providers {
    local = { source = "hashicorp/local", version = "~> 2.5" }
  }
}

variable "nom" {
  type    = string
  default = "demo"
}

resource "local_file" "salut" {
  filename = "${path.module}/salut-${var.nom}.txt"
  content  = "Bonjour ${var.nom}\n"
}

output "chemin" {
  value = local_file.salut.filename
}
```
```bash
terraform init                  # télécharge les providers
terraform fmt && terraform validate
terraform plan                  # montre ce qui sera créé/modifié/détruit — LIRE avant d'appliquer
terraform apply                 # applique (confirmation) ;  terraform destroy
terraform state list ; terraform output
```
Bonnes pratiques : état distant **verrouillé** (S3 + DynamoDB, GitLab, Terraform Cloud), **modules**, workspaces/dossiers par environnement, secrets hors du code, revue du `plan` en CI. Terraform = *provisionnement* ; Ansible = *configuration* (les deux se complètent). Une formation Terraform dédiée peut compléter ce parcours.

## 5. Packer, Vagrant, GitOps

- **Packer** : construit des images (AMI, qcow2, VMDK) à partir d'une description HCL et d'un provisioner (Ansible) → serveurs immuables.
- **Vagrant** : VMs de développement reproductibles (`Vagrantfile`, `vagrant up`), utilisé dans ce dépôt pour les labos.
- **GitOps** : le dépôt git est la source de vérité ; un opérateur (Argo CD/Flux) ou la CI applique les changements après revue (pull request, `plan`/`--check` automatique, approbation, déploiement).

```text
 Développeur ─ commit/PR ─► Dépôt git ─► CI : lint · tests · plan/--check ─► revue ─► merge ─► déploiement automatique
```

## 6. Résumé

- IaC = déclaratif + idempotent + versionné + testé ; supprime la dérive et les « snowflakes ».
- Ansible : inventaire → playbook → rôles ; modules idempotents, templates Jinja2, **handlers**, **Vault**.
- Contrôles : `--syntax-check`, `--check --diff`, deuxième exécution `changed=0`, `ansible-lint`.
- cloud-init (premier démarrage), Terraform (création de l'infrastructure), Packer (images), GitOps (livraison).

## 7. Quiz

1. Qu'est-ce que l'idempotence et comment la vérifier avec Ansible ?
2. Quand un handler s'exécute-t-il ? Combien de fois ?
3. Quelle différence entre `defaults/main.yml` et `vars/main.yml` dans un rôle ?
4. Pourquoi préférer `ansible.builtin.copy` à `shell: cp` ?
5. Comment passer un mot de passe de base de données sans le stocker en clair dans git ?
6. Que montre `--check --diff` ?
7. Quelle est la différence de rôle entre Terraform et Ansible ?
8. Quel est l'intérêt de `cloud-init` avec une image cloud ?

<details><summary>Réponses</summary>

1. Appliquer plusieurs fois = même état final, sans changement supplémentaire ; vérifier que la 2ᵉ exécution affiche `changed=0` partout.
2. À la fin du play, seulement si une tâche qui le `notify` a produit un changement ; une seule fois même si notifié plusieurs fois.
3. `defaults` : faible priorité, destinées à être surchargées ; `vars` : forte priorité, valeurs internes difficilement surchargeables.
4. Modules : idempotents, gèrent droits/propriétaire/sauvegarde/mode check ; `shell` s'exécute à chaque fois sans connaissance de l'état.
5. Ansible Vault (`ansible-vault encrypt_string` ou fichier chiffré) avec mot de passe hors dépôt, ou SOPS/gestionnaire de secrets.
6. Une simulation : ce qui **changerait** et le diff des fichiers, sans rien modifier.
7. Terraform crée/gère les ressources d'infrastructure (état, plan) ; Ansible configure le système et les applications sur ces ressources.
8. Personnaliser au premier boot (utilisateur, clés SSH, paquets, fichiers) sans image sur mesure ni intervention manuelle.
</details>

➡️ **Labo** : [LAB.md](LAB.md) · **Démo** : `./lab demo 22` · **Suivant** : [23 — Supervision et observabilité](../23-supervision-et-observabilite/README.md)
