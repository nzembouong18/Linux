# Labo 06 — Mettre en place un espace de travail partagé sécurisé

> **Durée** : 1 h 30 · **Difficulté** : ⭐⭐ · **Prérequis** : module 06 · **Droits** : `root` ou `sudo`

## Contexte

Deux développeurs (Alice et Bob) partagent un dossier de projet. Carol, auditrice, ne doit pouvoir que **lire**. Un dossier de dépôt public doit empêcher chacun de supprimer les fichiers des autres. Vous configurez le tout.

> Les comptes utilisés sont préfixés `lab_` pour ne jamais entrer en collision avec de vrais comptes. `./lab reset 06` les supprime.

## Mise en place

```bash
./lab setup 06
cd ~/labs/06 && ls -l
```

Vous disposez de `projet/` (dossier avec `plan.txt`), `depot/`, et du script `outil.sh`.

## Tâches

Toutes les commandes d'administration passent par `sudo`.

1. Créez le groupe **`lab_equipe`**.
2. Créez les utilisateurs **`lab_alice`** et **`lab_bob`** (avec répertoire personnel, shell `/bin/bash`) et ajoutez-les au groupe `lab_equipe` en tant que groupe **secondaire**. Créez **`lab_carol`** sans l'ajouter au groupe.
3. `projet/` : propriétaire `lab_alice`, groupe `lab_equipe`, droits `2770` (setgid + rwx pour u et g, rien pour les autres).
4. `projet/plan.txt` : propriétaire `lab_alice`, groupe `lab_equipe`, droits `660`.
5. Créez `projet/notes.txt` **en tant que `lab_bob`** (`sudo -u lab_bob …`) : grâce au setgid, son groupe doit être `lab_equipe`.
6. `outil.sh` : propriétaire `lab_alice`, groupe `lab_equipe`, droits `750` (exécutable par Alice et l'équipe, interdit aux autres).
7. `depot/` : droits `1777` (tout le monde écrit, mais seul le propriétaire d'un fichier peut le supprimer).
8. Donnez à **`lab_carol`** un accès **lecture seule** à `projet/` et `projet/plan.txt` avec les **ACL** (`r-x` sur le dossier, `r--` sur le fichier).
9. **Verrouillez** le compte `lab_bob` (`passwd -l` ou `usermod -L`) puis imposez à `lab_alice` une durée de vie de mot de passe maximale de **90 jours** (`chage -M 90`).
10. Écrivez dans `reponses.txt` : `UID_ALICE=<uid de lab_alice>` et `GROUPES_ALICE=<liste de ses groupes séparés par des espaces, triés>`.

## Validation

```bash
./lab check 06
```

<details><summary>💡 Indices</summary>

- `useradd -m -s /bin/bash -G lab_equipe lab_alice`
- `chown lab_alice:lab_equipe projet && chmod 2770 projet`
- `sudo -u lab_bob touch projet/notes.txt` : si l'accès est refusé, vérifiez que `lab_bob` est bien dans `lab_equipe` et que `x` est présent sur tout le chemin (`~/labs/06` doit être traversable : le script s'en charge).
- `setfacl -m u:lab_carol:rx projet && setfacl -m u:lab_carol:r projet/plan.txt`
- `id -nG lab_alice | tr ' ' '\n' | sort | tr '\n' ' '`
</details>

<details><summary>✅ Solution</summary>

```bash
cd ~/labs/06
sudo groupadd lab_equipe
sudo useradd -m -s /bin/bash -G lab_equipe lab_alice
sudo useradd -m -s /bin/bash -G lab_equipe lab_bob
sudo useradd -m -s /bin/bash lab_carol
sudo chown lab_alice:lab_equipe projet && sudo chmod 2770 projet
sudo chown lab_alice:lab_equipe projet/plan.txt && sudo chmod 660 projet/plan.txt
sudo -u lab_bob touch projet/notes.txt
sudo chown lab_alice:lab_equipe outil.sh && sudo chmod 750 outil.sh
sudo chmod 1777 depot
sudo setfacl -m u:lab_carol:rx projet
sudo setfacl -m u:lab_carol:r projet/plan.txt
sudo passwd -l lab_bob
sudo chage -M 90 lab_alice
{ echo "UID_ALICE=$(id -u lab_alice)"; echo "GROUPES_ALICE=$(id -nG lab_alice | tr ' ' '\n' | sort | tr '\n' ' ' | sed 's/ $//')"; } > reponses.txt
```
</details>

## Pour aller plus loin

- Testez : `sudo -u lab_carol cat projet/plan.txt` (OK) puis `sudo -u lab_carol sh -c 'echo x >> projet/plan.txt'` (refusé).
- Ajoutez une ACL **par défaut** sur `projet/` pour que `lab_carol` lise aussi les futurs fichiers.
- Créez `/etc/sudoers.d/lab_alice` permettant à Alice de relancer uniquement `nginx`, et validez avec `visudo -c`.

## Nettoyage

```bash
./lab reset 06     # supprime les comptes lab_* et le dossier du labo
```
