# Module 25 — Projet final : mettre un service en production, de bout en bout

> **Niveau** : Professionnel | **Durée** : 12 à 16 h (projet) + 30 min de soutenance | **Prérequis** : modules 01 à 24
>
> **Objectifs** — À la fin de ce projet vous aurez démontré que vous savez :
> - **concevoir et livrer** une mise en production complète et reproductible ;
> - **sécuriser, superviser, sauvegarder et documenter** un service ;
> - **automatiser** son déploiement de façon idempotente avec Ansible et Vault ;
> - **diagnostiquer** une panne et **restaurer** le service dans un délai maîtrisé ;
> - **défendre vos choix** devant un jury technique.

---

## 1. Pourquoi un projet final ?

Les 24 modules précédents vous ont donné des briques. Un administrateur professionnel est jugé sur sa capacité à les **assembler** de façon cohérente, **fiable** et **maintenable**, pas seulement à exécuter une commande isolée. Le projet reproduit une situation réelle : *« voici une application, mettez-la en production »*.

| Brique | Modules mobilisés |
|--------|-------------------|
| Service systemd durci, utilisateur dédié | 06, 14, 16 |
| Reverse proxy, en-têtes, limitation, journaux | 11, 19 |
| Scripts d'exploitation robustes (Bash) | 05, 09, 10 |
| Sauvegarde, rétention, vérification, PRA | 13, 15, 24 |
| Supervision : sonde, contrat de plugin, SLI | 18, 23 |
| Pare-feu, SSH, sysctl, moindre privilège | 12, 16, 17 |
| Déploiement idempotent, Vault, handlers | 22 |
| Documentation d'exploitation, runbooks | tous |

## 2. Méthode de travail recommandée

### 2.1 Cadrer (30 min)
Lisez le cahier des charges ([LAB.md](LAB.md)) **et** la grille ([grille-evaluation.md](grille-evaluation.md)). Listez :
- les **livrables** et leurs chemins imposés ;
- les **critères mesurables** (ports, codes retour, modes de fichiers) ;
- les **risques** (secrets, ports exposés, idempotence) ;
- votre **plan** : ordre des tâches, qui fait quoi (en binôme).

### 2.2 Découper et tester petit
Une brique = un livrable = un test isolé avant l'assemblage.

| Étape | Validation locale avant le correcteur |
|-------|----------------------------------------|
| Scripts Bash | `bash -n`, `shellcheck`, quelques exécutions manuelles avec des cas limites |
| Unité systemd | `systemd-analyze verify`, `systemd-analyze security` |
| nginx | `nginx -t` puis `curl -v`, `curl -I`, boucle de requêtes rapides pour la limite |
| Pare-feu / sshd / sysctl | `nft -c -f`, `sshd -t`, `sysctl --system` sur une VM jetable |
| Ansible | `--syntax-check`, `--check --diff`, **deux passages consécutifs** |
| Documents | relecture croisée : un collègue peut-il restaurer sans vous ? |

### 2.3 Intégrer (Ansible en dernier)
Le playbook **assemble** les livrables. S'il est difficile à écrire, c'est souvent le signe que les chemins ou les droits sont incohérents entre les briques : corrigez la cause, pas le symptôme.

### 2.4 Vérifier, puis répéter la démonstration
`./lab check 25` doit atteindre 100 %. Ensuite, **répétez** la soutenance : déploiement depuis zéro, panne simulée, restauration chronométrée. Un incident rejoué cinq fois ne surprend plus.

## 3. Bonnes pratiques du « Definition of Done »

Un service est « livré » seulement si :

- [ ] il est **déployé par du code**, de manière **reproductible** et **idempotente** ;
- [ ] il tourne avec un **compte dédié sans privilège** ;
- [ ] seuls les **ports nécessaires** sont ouverts ; l'application n'écoute que sur `127.0.0.1` derrière le proxy ;
- [ ] les **secrets** ne sont jamais en clair dans le dépôt ;
- [ ] les **journaux** sont exploitables (format, rotation) ;
- [ ] une **sonde** peut dire à la supervision « ça marche / ça ne marche pas » ;
- [ ] les **sauvegardes** sont automatiques, **vérifiées** et leur **restauration est testée et chronométrée** ;
- [ ] la **documentation** permet à un autre administrateur d'intervenir de nuit ;
- [ ] un **retour arrière** est possible (git, version précédente).

## 4. Rédiger une documentation d'exploitation utile

- **README** : pour *comprendre en 5 minutes* (schéma, composants, où est quoi, commandes courantes).
- **RUNBOOK** : pour *agir à 3 h du matin* — un incident par fiche : **Symptômes → Diagnostic → Actions → Vérification → Escalade**. Commandes copiables, résultats attendus, pas de prose inutile.
- **PRA** : pour *survivre à un sinistre* — objectifs RPO/RTO **justifiés**, scénarios couverts, procédure pas à pas, tests périodiques, contacts, critères de retour à la normale.

Règles : un document non testé est faux ; datez-le ; indiquez qui le maintient ; liez-le depuis l'alerte (`runbook_url`).

## 5. Préparer la soutenance (30 min)

**Présentation (10 min)** — 5 diapositives maximum : contexte et besoin, architecture (schéma), 3 décisions clés et leurs alternatives, sécurité et exploitation, bilan (difficultés, ce que vous referiez).

**Démonstration (10 min)** — scénario écrit et répété :
1. dépôt vierge → `ansible-playbook` → `changed` ; second passage → `changed=0` ;
2. `systemctl kill -s KILL tickets` → redémarrage automatique constaté dans `journalctl` ;
3. sonde : `tickets-healthcheck` OK puis CRITICAL (service arrêté) ;
4. sauvegarde : lancer, corrompre une archive, montrer la détection par `sha256sum -c`, restaurer la précédente et **annoncer le temps réel** ;
5. pare-feu : prouver avec `ss`/`nc` que le port applicatif n'est pas joignable depuis l'extérieur.

**Questions (10 min)** — préparez les réponses à : *Pourquoi ce RPO/RTO ? Que se passe-t-il si nginx tombe ? Comment ajouter un 2ᵉ serveur ? Où sont les secrets et qui y a accès ? Comment faire un retour arrière ? Comment passer à HTTPS ? Qu'est-ce qui vous inquiète encore ?*

## 6. Après la formation : et ensuite ?

| Objectif | Pistes |
|----------|--------|
| **Certifications** | LPIC-1 / LPIC-2 (Linux Professional Institute), RHCSA / RHCE (Red Hat), LFCS / LFCE (Linux Foundation), CompTIA Linux+ — voir [docs/certifications.md](../../docs/certifications.md) |
| **Cloud / DevOps** | Terraform, Kubernetes (CKA/CKAD), Docker/Podman avancé, CI/CD (GitHub Actions, GitLab CI) |
| **Sécurité** | durcissement CIS, SELinux/AppArmor avancés, forensics, Blue Team (SIEM, EDR), OSCP côté offensif |
| **SRE / Observabilité** | Prometheus/Grafana/Loki, OpenTelemetry, SLO, post-mortems |
| **Noyau et systèmes** | eBPF, performance (perf, flame graphs), contribution à des projets open source |

Entretenez vos acquis : un labo personnel (VM, mini-cluster), un dépôt de notes et de scripts, la lecture des pages de manuel, la participation à des projets libres.

## 7. Résumé

- Le projet final valide la **capacité d'intégration** : tout est code, tout est testé, tout est documenté.
- **Ansible assemble** : idempotence, Vault, handlers.
- **Mesurez** (tests, codes retour, chronomètre) plutôt que d'affirmer.
- La soutenance évalue aussi la **communication** : schéma clair, choix justifiés, démonstration répétée.

➡️ **Cahier des charges** : [LAB.md](LAB.md) · **Grille** : [grille-evaluation.md](grille-evaluation.md) · **Démo de la solution de référence** : `./lab demo 25`
