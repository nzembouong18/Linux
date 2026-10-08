# Labo 23 — Votre chaîne de supervision : exporter, plugin, alertes et SLO

> **Durée** : 4 h · **Difficulté** : ⭐⭐⭐⭐ · **Prérequis** : module 23 · outils : `prometheus-node-exporter` (partie A), `promtool` (facultatif), `python3`
> Tout tourne en local, sans Prometheus complet : vous maîtrisez les **briques** (exposition, plugin, règles, calcul d'SLI).

## Contexte

L'équipe passe d'une supervision artisanale à une approche moderne. Vous réalisez les quatre briques de base : exposer des métriques, écrire un plugin de contrôle de disque, définir les alertes essentielles et calculer les SLI d'un service web à partir de ses journaux.

## Mise en place

```bash
./lab setup 23
cd ~/labs/23 && cat ports.txt && ls -R donnees | head
```

## Partie A — `node_exporter` et le format d'exposition

1. Lancez `prometheus-node-exporter` **en arrière-plan**, lié à `127.0.0.1:NODE_PORT` (voir `ports.txt`), avec seulement les collecteurs `cpu`, `loadavg`, `meminfo`, `filesystem` (`--collector.disable-defaults` + `--collector.…`).
2. Enregistrez la sortie de `/metrics` dans **`metrics.txt`**.
3. Écrivez **`infos.txt`** (`CLÉ=valeur`) :
   - `MEM_TOTAL_BYTES` : valeur **entière** de `node_memory_MemTotal_bytes` (attention à la notation scientifique, ex. `1.6e+10`) ;
   - `TYPE_LOAD1` : type de la métrique `node_load1` ; `TYPE_CPU` : type de `node_cpu_seconds_total` ;
   - `NB_COEURS` : nombre de valeurs distinctes de l'étiquette `cpu` dans `node_cpu_seconds_total`.
   *(Arrêtez ensuite l'exporteur. Cette partie est ignorée si le paquet n'est pas installé.)*

## Partie B — Votre propre exporter : `exporteur.sh [DOSSIER]`

Script bash (exécutable) qui affiche sur **stdout**, **au format d'exposition Prometheus**, avec `# HELP` et `# TYPE` pour chaque métrique, les valeurs du dossier donné (défaut : `donnees`) :

| Métrique | Type | Valeur |
|----------|------|--------|
| `lab_up` | gauge | `1` |
| `lab_files` | gauge | nombre de fichiers (non récursif… les **fichiers réguliers** du dossier, y compris sous-dossiers) |
| `lab_size_bytes` | gauge | somme des tailles en octets |
| `lab_files_by_ext{ext="…"}` | gauge | nombre de fichiers par extension (dernier suffixe après le point ; `ext="none"` sans extension), une ligne par extension |

Dossier inexistant : message sur **stderr** et code retour **1**.

## Partie C — Plugin de supervision : `check_disk.sh -w SEUIL -c SEUIL [-p CHEMIN]`

Respectez le contrat Nagios :
- `-w` (warning) et `-c` (critical) : pourcentages entiers 0-100, avec `w < c` ; `-p` : chemin (défaut `/`).
- Pourcentage utilisé = `df --output=pcent CHEMIN`, **sauf** si la variable d'environnement `FAKE_PCENT` est définie (utilisée par le correcteur).
- Sortie : `DISK <ÉTAT> - <P>% used|used=<P>%;<W>;<C>;0;100` ; code `0` si `P < W`, `1` si `W ≤ P < C`, `2` si `P ≥ C`.
- Arguments manquants/invalides, `w ≥ c`, chemin absent : `DISK UNKNOWN - <raison>` et code **3**.

## Partie D — Règles d'alerte : `alertes.yml`

Fichier de règles Prometheus avec un groupe contenant :

| Alerte | Condition | `for` | `severity` |
|--------|-----------|-------|-----------|
| `HostDown` | `up == 0` | ≥ 1 min | `critical` |
| `HighCPU` | CPU utilisé > 90 %, via `rate(node_cpu_seconds_total{mode="idle"}[5m])` | ≥ 5 min | `warning` |
| `DiskAlmostFull` | système de fichiers rempli à plus de 90 % (`node_filesystem_avail_bytes` / `node_filesystem_size_bytes`) | ≥ 10 min | `warning` |
| `MemoryLow` | `node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes < 0.1` | ≥ 5 min | `warning` ou `critical` |

Chaque alerte doit avoir `annotations.summary` et `annotations.description` non vides.

## Partie E — SLI/SLO sur `access.log`

Format : `IP - - [date] "METHODE URL HTTP" STATUT OCTETS TEMPS_DE_REPONSE_EN_SECONDES`. Dans **`sli.txt`** :

| Clé | Valeur |
|-----|--------|
| `TOTAL` | nombre de requêtes |
| `NB_5XX` | requêtes en statut 5xx |
| `TAUX_ERREUR_PCT` | `NB_5XX / TOTAL × 100`, **2 décimales** |
| `DISPONIBILITE_PCT` | `100 − taux d'erreur`, 2 décimales |
| `P95_S` | 95ᵉ centile du temps de réponse (méthode du rang le plus proche : trier croissant, prendre l'élément d'indice `ceil(0,95 × N)`) |
| `BUDGET_MINUTES` | budget d'erreur en minutes pour un SLO de **99,5 %** sur **30 jours** |
| `SLO_RESPECTE` | `oui` si la disponibilité mesurée ≥ 99,5 %, sinon `non` |
| `GOLDEN_SIGNALS` | les quatre signaux dorés, séparés par des virgules (en anglais, minuscules) |

## Validation

```bash
./lab check 23
```

<details><summary>💡 Indices</summary>

- `prometheus-node-exporter --web.listen-address=127.0.0.1:PORT --collector.disable-defaults --collector.cpu --collector.loadavg --collector.meminfo --collector.filesystem &`
- Notation scientifique → entier : `awk '{printf "%.0f\n", $2}'`.
- `find "$dir" -type f -printf '%s %f\n'` ; extension : `${f##*.}` si le nom contient un `.` non initial.
- `df --output=pcent / | tail -1 | tr -dc 0-9`
- `up == 0`, `100 - (avg by (instance)(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 90`
- P95 : `awk '{print $NF}' access.log | sort -n | sed -n '950p'`
- Budget : 30 × 24 × 60 × 0,005 = 216 minutes.
</details>

<details><summary>✅ Solution</summary>

```bash
cd ~/labs/23; . ./ports.txt
# A
prometheus-node-exporter --web.listen-address=127.0.0.1:$NODE_PORT --collector.disable-defaults --collector.cpu --collector.loadavg --collector.meminfo --collector.filesystem >/dev/null 2>&1 &
EXP=$!; sleep 2
curl -s http://127.0.0.1:$NODE_PORT/metrics > metrics.txt; kill $EXP
{ echo "MEM_TOTAL_BYTES=$(awk '/^node_memory_MemTotal_bytes /{printf "%.0f", $2}' metrics.txt)"
  echo "TYPE_LOAD1=$(awk '/^# TYPE node_load1 /{print $4}' metrics.txt)"
  echo "TYPE_CPU=$(awk '/^# TYPE node_cpu_seconds_total /{print $4}' metrics.txt)"
  echo "NB_COEURS=$(grep '^node_cpu_seconds_total' metrics.txt | grep -o 'cpu="[0-9]*"' | sort -u | wc -l)"; } > infos.txt
# B
cat > exporteur.sh <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
dir=${1:-donnees}
[[ -d $dir ]] || { echo "Dossier introuvable: $dir" >&2; exit 1; }
files=$(find "$dir" -type f | wc -l)
size=$(find "$dir" -type f -printf '%s\n' | awk '{s+=$1} END{print s+0}')
echo '# HELP lab_up Indique que lexporteur fonctionne.'; echo '# TYPE lab_up gauge'; echo 'lab_up 1'
echo '# HELP lab_files Nombre de fichiers.'; echo '# TYPE lab_files gauge'; echo "lab_files $files"
echo '# HELP lab_size_bytes Taille totale en octets.'; echo '# TYPE lab_size_bytes gauge'; echo "lab_size_bytes $size"
echo '# HELP lab_files_by_ext Fichiers par extension.'; echo '# TYPE lab_files_by_ext gauge'
find "$dir" -type f -printf '%f\n' | awk '{ n=split($0,a,"."); e=(n>1 && a[1]!="")?a[n]:"none"; c[e]++ } END{for(e in c) printf "lab_files_by_ext{ext=\"%s\"} %d\n", e, c[e]}' | sort
EOS
chmod +x exporteur.sh
# C
cat > check_disk.sh <<'EOS'
#!/usr/bin/env bash
unknown() { echo "DISK UNKNOWN - $1"; exit 3; }
W="" C="" P="/"
while getopts ":w:c:p:" o; do case $o in w) W=$OPTARG;; c) C=$OPTARG;; p) P=$OPTARG;; *) unknown "option invalide";; esac; done
[[ $W =~ ^[0-9]+$ && $C =~ ^[0-9]+$ ]] || unknown "-w et -c requis (entiers)"
(( W < C && C <= 100 )) || unknown "il faut w < c <= 100"
if [[ -n ${FAKE_PCENT:-} ]]; then U=$FAKE_PCENT
else [[ -e $P ]] || unknown "chemin absent: $P"; U=$(df --output=pcent "$P" 2>/dev/null | tail -1 | tr -dc 0-9); [[ -n $U ]] || unknown "df a échoué"; fi
if (( U >= C )); then s=CRITICAL; rc=2; elif (( U >= W )); then s=WARNING; rc=1; else s=OK; rc=0; fi
echo "DISK $s - ${U}% used|used=${U}%;${W};${C};0;100"; exit $rc
EOS
chmod +x check_disk.sh
# D
cat > alertes.yml <<'EOS'
groups:
  - name: machines
    rules:
      - alert: HostDown
        expr: up == 0
        for: 2m
        labels: { severity: critical }
        annotations: { summary: "{{ $labels.instance }} injoignable", description: "La cible ne répond plus depuis 2 minutes." }
      - alert: HighCPU
        expr: 100 - (avg by (instance)(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 90
        for: 5m
        labels: { severity: warning }
        annotations: { summary: "CPU élevé sur {{ $labels.instance }}", description: "Plus de 90 % de CPU depuis 5 minutes." }
      - alert: DiskAlmostFull
        expr: (1 - node_filesystem_avail_bytes{fstype!~"tmpfs|overlay"} / node_filesystem_size_bytes) > 0.9
        for: 10m
        labels: { severity: warning }
        annotations: { summary: "Disque presque plein sur {{ $labels.instance }}", description: "Plus de 90 % utilisés depuis 10 minutes." }
      - alert: MemoryLow
        expr: node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes < 0.1
        for: 5m
        labels: { severity: critical }
        annotations: { summary: "Mémoire faible sur {{ $labels.instance }}", description: "Moins de 10 % de mémoire disponible depuis 5 minutes." }
EOS
# E
T=$(wc -l < access.log); N5=$(awk '$(NF-2) ~ /^5/' access.log | wc -l)
{ echo "TOTAL=$T"; echo "NB_5XX=$N5"
  echo "TAUX_ERREUR_PCT=$(awk -v n=$N5 -v t=$T 'BEGIN{printf "%.2f", n/t*100}')"
  echo "DISPONIBILITE_PCT=$(awk -v n=$N5 -v t=$T 'BEGIN{printf "%.2f", 100-n/t*100}')"
  echo "P95_S=$(awk '{print $NF}' access.log | sort -n | sed -n "$(awk -v t=$T 'BEGIN{x=0.95*t; print (x==int(x))?x:int(x)+1}')p")"
  echo "BUDGET_MINUTES=216"; echo "SLO_RESPECTE=$(awk -v n=$N5 -v t=$T 'BEGIN{print (100-n/t*100>=99.5)?"oui":"non"}')"
  echo "GOLDEN_SIGNALS=latency,traffic,errors,saturation"; } > sli.txt
```
</details>

## Pour aller plus loin

- Validez `alertes.yml` avec `promtool check rules alertes.yml` et écrivez un test unitaire (`promtool test rules`).
- Servez `exporteur.sh` en HTTP (via `python3 -m http.server` + CGI ou `socat`) et scrutez-le avec un vrai Prometheus.
- Branchez `check_disk.sh` dans une unité `.service` + `.timer` avec `OnFailure=`.
- Ajoutez un panneau Grafana « taux d'erreur » (`sum(rate(...{code=~"5.."}[5m])) / sum(rate(...[5m]))`).

## Nettoyage

```bash
./lab reset 23     # arrête l'exporteur éventuel
```
