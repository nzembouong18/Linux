# Labo 04 — Journaux et fichier de configuration

> **Durée** : 45 min · **Difficulté** : ⭐ · **Prérequis** : module 04

## Contexte

Un serveur applicatif tombe en erreur. Vous devez extraire des morceaux du journal puis corriger sa configuration avec un éditeur, comme un administrateur le ferait pendant un incident.

## Mise en place

```bash
./lab setup 04
cd ~/labs/04 && ls
```

Fichiers fournis : `server.log` (120 lignes), `config.ini`, `poeme.txt`.

## Tâches

1. `premieres.txt` : les **5 premières** lignes de `server.log`.
2. `dernieres.txt` : les **3 dernières** lignes de `server.log`.
3. `extrait.txt` : les lignes **10 à 14** (incluses) de `server.log`.
4. `stats.txt` : statistiques de `poeme.txt` au format
   ```
   LIGNES=<n>
   MOTS=<n>
   OCTETS=<n>
   ```
5. **Éditez** `config.ini` avec **nano ou vim** (pas par redirection !) pour :
   - mettre `port=8080` (au lieu de `80`) ;
   - mettre `debug=false` ;
   - **commenter** la ligne `host=0.0.0.0` (préfixe `#`) ;
   - ajouter à la fin une section `[cache]` contenant `ttl=300`.
6. Exercice libre (non vérifié) : ouvrez `poeme.txt` dans `less`, cherchez le mot « nuit », comptez les occurrences avec `n`.

## Validation

```bash
./lab check 04
```

<details><summary>💡 Indices</summary>

- `head -n 5`, `tail -n 3`, `sed -n '10,14p'`.
- `wc -l`, `wc -w`, `wc -c`.
- vim : `/port` pour trouver, `cw` pour changer le mot, `I#` pour commenter, `G` puis `o` pour ajouter en fin.
</details>

<details><summary>✅ Solution</summary>

```bash
cd ~/labs/04
head -n 5 server.log > premieres.txt
tail -n 3 server.log > dernieres.txt
sed -n '10,14p' server.log > extrait.txt
{ echo "LIGNES=$(wc -l < poeme.txt)"; echo "MOTS=$(wc -w < poeme.txt)"; echo "OCTETS=$(wc -c < poeme.txt)"; } > stats.txt
# édition (équivalent scripté de ce que vous feriez dans vim) :
sed -i -e 's/^port=.*/port=8080/' -e 's/^debug=.*/debug=false/' -e 's/^host=/#host=/' config.ini
printf '\n[cache]\nttl=300\n' >> config.ini
```
</details>

## Pour aller plus loin

- Lancez `vimtutor` et terminez les leçons 1 à 4.
- Configurez `~/.vimrc` avec `set number` et `syntax on`.
- Avec `tail -F server.log` dans un terminal, ajoutez des lignes depuis un autre (`echo test >> server.log`).

## Nettoyage

```bash
./lab reset 04
```
