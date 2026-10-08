# Contribuer à la formation

Merci de votre intérêt ! Cette formation est vivante : corrections, nouveaux exercices et améliorations sont bienvenus.

## Principes

1. **Tout labo doit être vérifiable automatiquement** : `lab.sh` fournit `lab_setup`, `lab_check`, `lab_solve` (et `lab_cleanup` si nécessaire). La CI exécute `scripts/validate.sh` :
   `setup` → `check` (**doit échouer**) → `solve` → `check` (**doit réussir**) → démo → `reset`.
2. **Pédagogie d'abord** : une notion = une explication courte + un exemple + un exercice. Les solutions sont en `<details>`.
3. **Sécurité des labos** : jamais de modification du système hôte hors `~/labs` (sauf comptes `lab_*`, namespaces `lab*`, etc. nettoyés par `lab_cleanup`). Pas de réseau externe requis pour réussir un labo.
4. **Français** pour le contenu, anglais accepté pour les noms de commandes et de fichiers de configuration.

## Ajouter un module

```text
modules/NN-nom-du-module/
├── README.md     cours : en-tête « > **Niveau** : … | **Durée** : … », objectifs, contenu, résumé, quiz (réponses repliées)
├── LAB.md        énoncé du labo : contexte, mise en place, tâches, indices (<details>), solution (<details>), nettoyage
├── lab.sh        source scripts/lib.sh ; LAB_ID=NN ; lab_setup / lab_check / lab_solve ; lab_main "$@"
└── demo.sh       source scripts/demo-lib.sh ; demo_title / demo_say / demo_run / demo_show
```

Le modèle le plus simple à copier : `modules/01-introduction/`.

### Règles pour `lab.sh`
- `assert`, `assert_eq`, `assert_grep`, `assert_mode`, `skip` (prérequis noyau absent) ; `LAB_REQUIRES=(root systemd netns loop cmd:xxx)`.
- Les vérifications comparent à une **référence calculée** (ou constante) ; elles ne doivent pas dépendre de la machine (sauf à les recalculer).
- Attention aux pièges classiques : `pgrep -f` / `pkill -f` sans motif **ancré** (ils peuvent tuer votre propre shell), processus d'arrière-plan qui gardent ouvert le tube d'un `$(…)` (rediriger stdin/stdout/stderr), variables non protégées.
- `lab_solve` applique la **solution de référence** ; elle sert à tester le correcteur.

### Règles pour `demo.sh`
- Utiliser `demo_run` pour ce qui est exécutable sans danger, `demo_show` pour ce qui ne l'est pas.
- Ne rien modifier hors du répertoire temporaire `$DEMO_DIR` (nettoyé automatiquement).

## Avant de soumettre

```bash
make lint            # shellcheck
make links           # liens Markdown relatifs
make validate-05     # votre module (ou : make validate pour tout)
```

## Style
- Markdown : titres hiérarchiques, tableaux pour les comparaisons, blocs de code annotés.
- Shell : `#!/usr/bin/env bash`, guillemets autour des variables, `shellcheck` propre.
- Commits : message court à l'impératif (« Ajoute le labo cron »), détail dans le corps si utile.
