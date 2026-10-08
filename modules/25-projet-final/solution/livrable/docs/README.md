# Application Tickets — dossier d'exploitation

Application web de gestion de tickets (API JSON + page d'accueil), exploitée sur un serveur Linux Ubuntu 24.04 LTS.

## Architecture

```text
 Internet ──► [ nftables : 22 (admins), 80, 443 ]
                 │
              nginx :80/:443  (reverse proxy, gzip, en-têtes de sécurité, limite 5 req/s sur /api/)
                 │  127.0.0.1:8000  (le port applicatif n'est JAMAIS exposé)
              tickets.service  (utilisateur « tickets », unité systemd durcie, redémarrage automatique)
                 │
        /var/lib/tickets  ──► sauvegarde quotidienne (tickets-backup) ──► copie hors site
```

| Composant | Rôle | Emplacement |
|-----------|------|-------------|
| `tickets.service` | exécute `/opt/tickets/app.py` | `/etc/systemd/system/` |
| nginx | reverse proxy, TLS | `/etc/nginx/conf.d/tickets.conf` |
| `tickets-backup` | sauvegarde + rotation + empreintes | `/usr/local/bin/` |
| `tickets-healthcheck` | sonde de supervision (codes 0-3, perfdata) | `/usr/local/bin/` |
| pare-feu, sshd, sysctl | durcissement | `/etc/nftables.conf`, `/etc/ssh/sshd_config.d/`, `/etc/sysctl.d/` |

## Installation

Tout le déploiement est décrit dans le code (Ansible) : aucune étape manuelle sur le serveur.

```bash
cd ansible
ansible-playbook -i inventaire.ini site.yml --check --diff     # simulation
ansible-playbook -i inventaire.ini site.yml                    # application
ansible-playbook -i inventaire.ini site.yml                    # 2ᵉ passage : changed=0 (idempotence)
```
Les secrets (`SECRET_KEY`) sont chiffrés avec Ansible Vault (`group_vars/all/vault.yml`) ; le mot de passe Vault n'est jamais versionné.

## Exploitation courante

| Action | Commande |
|--------|----------|
| État du service | `systemctl status tickets` |
| Journaux | `journalctl -u tickets -f` · `/var/log/nginx/tickets-access.log` |
| Santé | `tickets-healthcheck -u http://127.0.0.1/health` |
| Sauvegarde manuelle | `tickets-backup /var/lib/tickets /var/backups/tickets` |
| Mise à jour de la config | modifier le dépôt → relancer le playbook (jamais d'édition manuelle) |

## Supervision

La sonde `tickets-healthcheck` est appelée toutes les minutes par la supervision (OK/WARNING > 500 ms/CRITICAL > 1 s). Les alertes `HostDown`, `DiskAlmostFull` et le taux d'erreurs 5xx > 2 % sont actionnables via le [runbook](RUNBOOK.md). Le plan de reprise est dans [PRA.md](PRA.md).
