# Plan de reprise d'activité — application Tickets

## Objectifs

| Indicateur | Valeur | Signification |
|------------|--------|---------------|
| **RPO** | 24 heures | perte de données maximale tolérée (une sauvegarde quotidienne) |
| **RTO** | 4 heures | durée maximale d'indisponibilité tolérée |
| Rétention | 7 sauvegardes quotidiennes en local, 30 jours hors site | règle 3-2-1 : 3 copies, 2 supports, 1 hors site |

## Scénarios couverts

1. Perte du serveur (matériel, hébergeur) ;
2. Suppression ou corruption des données applicatives ;
3. Compromission (rançongiciel) : restauration depuis une sauvegarde **antérieure à la compromission**, sur une machine reconstruite.

## Procédure de reprise (serveur perdu)

1. **Déclarer l'incident** et ouvrir la cellule de crise (responsable exploitation, développeur référent).
2. **Provisionner** un serveur Ubuntu 24.04 identique (image ou cloud-init).
3. **Redéployer la configuration** : `ansible-playbook -i inventaire.ini site.yml` (le mot de passe Vault est conservé dans le coffre de l'équipe).
4. **Restaurer les données** :
   - récupérer la dernière sauvegarde **valide** : `sha256sum -c SHA256SUMS` et `tar -tzf archive` ; en cas d'échec, passer à la précédente ;
   - extraire dans un dossier temporaire puis synchroniser : `tar -xzf tickets-AAAAMMJJ-HHMMSS.tar.gz -C /tmp/restore && rsync -a /tmp/restore/tickets/ /var/lib/tickets/`.
5. **Démarrer** : `systemctl start tickets nginx` ; vérifier `tickets-healthcheck`.
6. **Basculer le DNS** (TTL 300 s) vers la nouvelle adresse si elle a changé.
7. **Communiquer** : état toutes les 30 minutes aux métiers ; message de fin d'incident.
8. **Retour d'expérience** sous 5 jours ouvrés (chronologie, cause racine, actions correctives).

## Tests de restauration

- **Mensuel** : restauration automatisée de la dernière sauvegarde dans un dossier isolé, comparaison des empreintes, temps mesuré (cible : < 30 minutes).
- **Semestriel** : exercice complet de reprise sur un serveur neuf (chronométré, comparé au RTO de 4 heures).
- Les résultats sont consignés ; tout écart au RPO/RTO déclenche une action corrective.

## Contacts

| Rôle | Contact |
|------|---------|
| Astreinte exploitation | astreinte-infra@example.org — 06 00 00 00 01 |
| Responsable applicatif | tickets-dev@example.org |
| Hébergeur | support@hebergeur.example |
