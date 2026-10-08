# Labo 05 — Analyse d'un journal d'accès web

> **Durée** : 1 h 30 · **Difficulté** : ⭐⭐ · **Prérequis** : module 05

## Contexte

Le site web de l'entreprise subit des lenteurs. On vous remet `access.log` (200 requêtes, format *Common Log* : `IP - - [date] "METHODE URL HTTP" statut taille`). Répondez aux questions uniquement avec des **pipelines** (pas de tableur !).

## Mise en place

```bash
./lab setup 05
cd ~/labs/05 && head -3 access.log
```

## Partie A — Redirections

1. Exécutez `ls /etc /dossier-inexistant` de façon à obtenir :
   - `sortie.txt` : uniquement la sortie normale ;
   - `erreurs.txt` : uniquement le message d'erreur ;
   - `tout.txt` : les deux flux ensemble.
2. Créez avec un *here-document* le fichier `bienvenue.txt` contenant exactement les 2 lignes :
   ```
   Bonjour utilisateur
   Fin du message
   ```
   (le mot `utilisateur` doit être le résultat de `whoami`, développé par le shell : le fichier contient donc votre nom d'utilisateur à la place).

## Partie B — Analyse

3. `erreurs_404.txt` : toutes les lignes dont le statut est **404**.
4. `nb_404.txt` : un seul nombre — combien de requêtes 404.
5. `top_ips.txt` : les **3 IP** les plus fréquentes, format `compte IP` (sortie de `uniq -c`), du plus fréquent au moins fréquent.
6. `urls.txt` : la liste **triée et sans doublon** des URL demandées (une par ligne).
7. `statuts.txt` : le nombre de requêtes par code de statut (sortie de `sort | uniq -c`, triée par code croissant).
8. `octets.txt` : le total des octets envoyés (dernier champ), un nombre seul. *(indice : `awk` ou `paste -sd+ | bc`)*

## Validation

```bash
./lab check 05
```

<details><summary>💡 Indices</summary>

- Partie A : `> sortie.txt 2> erreurs.txt` et `> tout.txt 2>&1`.
- Here-doc : `cat > bienvenue.txt << EOF` avec `$(whoami)` dans le corps.
- 404 : `awk '$9 == 404'` (ou `grep ' 404 '`).
- URL = champ 7, statut = champ 9, octets = champ 10 (délimiteur espace).
</details>

<details><summary>✅ Solution</summary>

```bash
cd ~/labs/05
ls /etc /dossier-inexistant > sortie.txt 2> erreurs.txt
ls /etc /dossier-inexistant > tout.txt 2>&1
cat > bienvenue.txt << EOF
Bonjour $(whoami)
Fin du message
EOF
awk '$9 == 404' access.log > erreurs_404.txt
awk '$9 == 404' access.log | wc -l > nb_404.txt
awk '{print $1}' access.log | sort | uniq -c | sort -rn | head -3 > top_ips.txt
awk '{print $7}' access.log | sort -u > urls.txt
awk '{print $9}' access.log | sort | uniq -c > statuts.txt
awk '{s+=$10} END{print s}' access.log > octets.txt
```
</details>

## Pour aller plus loin

- Quelle est l'heure (champ `[01/Mar/2024:10:..`) la plus chargée ? (`cut -c` ou `awk -F'[:[]'`).
- Affichez le top 3 des URL les plus demandées avec le nombre de visites.
- Écrivez un script `rapport.sh` qui regroupe toutes ces analyses.

## Nettoyage

```bash
./lab reset 05
```
