# Évaluation et certification interne

## Principes

L'évaluation mesure des **compétences observables** : « je sais faire » plutôt que « je sais réciter ». Elle combine un contrôle continu automatique, des quiz, un examen écrit (QCM) et un projet final soutenu devant un jury.

## Barème global (100 points)

| Composante | Points | Modalité |
|------------|:------:|----------|
| **Labos** (contrôle continu) | 30 | `./lab check NN` : 100 % = pleine note du module ; pondération par niveau (voir ci-dessous) |
| **Quiz de modules** | 10 | questions de fin de cours (auto-évaluation, relevé du formateur) |
| **QCM final** | 20 | [qcm-final.md](qcm-final.md), 60 questions tirées au sort (40 min) |
| **Projet final** | 40 | [grille](../modules/25-projet-final/grille-evaluation.md) : automatique + qualité + documentation + soutenance |

Seuil de réussite : **70/100**, avec **≥ 50 %** à chaque composante et **aucun critère éliminatoire** du projet.

### Pondération des labos (30 pts)

| Niveau | Modules | Poids |
|--------|---------|:-----:|
| Débutant | 01-06 | 6 pts |
| Intermédiaire | 07-15 | 12 pts |
| Avancé | 16-21 | 8 pts |
| Professionnel | 22-24 | 4 pts |

Le score d'un niveau est la moyenne des pourcentages de réussite de ses labos (un labo « ignoré » faute de prérequis n'est pas compté).

## Badges de progression

| Badge | Condition |
|-------|-----------|
| 🌱 **Fondations** | labos 01-06 à 100 %, QCM niveau 1 ≥ 70 % |
| 🔧 **Administrateur** | labos 07-15 ≥ 90 %, QCM niveau 2 ≥ 70 % |
| 🛡️ **Expert** | labos 16-21 ≥ 85 %, QCM niveau 3 ≥ 70 % |
| 🚀 **Professionnel** | labos 22-24 ≥ 85 %, projet final ≥ 70/100 |

## Générer un relevé de notes

```bash
# Dans l'environnement de labo, pour chaque module : mémorise le score affiché par ./lab check
for m in $(seq -w 1 25); do
  printf '%s : ' "$m"
  NO_COLOR=1 ./lab check "$m" 2>&1 | tail -1
done | tee releve.txt
```
(La dernière ligne de `check` est `Résultat : P/T — …` ; un module non initialisé affiche l’erreur « Labo non initialisé ».)

## Rôle de l'auto-évaluation

Avant chaque évaluation, les stagiaires répondent aux questions « Je sais… » de la fiche de synthèse :

- [ ] expliquer le rôle d'une commande sans la copier ;
- [ ] prévoir la sortie d'un pipeline ;
- [ ] lire une erreur et proposer une hypothèse ;
- [ ] retrouver une option dans `man` ;
- [ ] refaire le labo sans regarder la solution.

## QCM : mode d'emploi

Le [QCM final](qcm-final.md) contient 60 questions (15 par niveau) avec réponses et explications. Pour une session :
1. Tirer 30 questions au hasard (`shuf -n 30`) ou choisir par niveau ;
2. Chronométrer (1 minute par question) ;
3. Corriger collectivement les erreurs fréquentes.

```bash
grep -E '^\*\*Q[0-9]+' docs/qcm-final.md | shuf -n 30
```

## Soutenance du projet

30 minutes : 10 min de présentation, 10 min de démonstration (déploiement depuis zéro, panne simulée, restauration chronométrée), 10 min de questions. Grille détaillée dans [`modules/25-projet-final/grille-evaluation.md`](../modules/25-projet-final/grille-evaluation.md).
