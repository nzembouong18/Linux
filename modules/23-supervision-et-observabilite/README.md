# Module 23 — Supervision et observabilité : métriques, logs, alertes, SLO

> **Niveau** : Professionnel | **Durée** : 7 h (3 h cours + 4 h labo) | **Prérequis** : modules 11, 14, 15, 18, 19
>
> **Objectifs** — À la fin de ce module vous saurez :
> - distinguer **supervision** (« est-ce que ça marche ? ») et **observabilité** (« pourquoi ça ne marche pas ? ») ;
> - choisir et interpréter les bons indicateurs : *Golden Signals*, **RED**, **USE**, **SLI/SLO/SLA** ;
> - déployer la chaîne **Prometheus** : exporters, format d'exposition, PromQL, règles d'alerte, Alertmanager, Grafana ;
> - écrire un **plugin de supervision** (contrat Nagios : codes 0-3 + *perfdata*) ;
> - centraliser les logs (journald → Loki/ELK) et lancer des sondes (blackbox) ;
> - construire des **alertes utiles** (peu de bruit, actionnables, avec runbook) et dimensionner les capacités.

---

## 1. Supervision, monitoring, observabilité

| Notion | Question | Exemples |
|--------|----------|----------|
| **Supervision (monitoring)** | « Le système va-t-il bien ? Une alerte ? » (inconnues **connues**) | CPU > 90 %, disque plein, service arrêté |
| **Observabilité** | « Pourquoi ce comportement ? » (inconnues **inconnues**) | corréler métriques, logs, traces pour comprendre une panne inédite |

**Les trois piliers** : **métriques** (séries numériques agrégées, peu coûteuses), **logs** (événements détaillés), **traces** (parcours d'une requête à travers les services — OpenTelemetry, Jaeger, Tempo).

### Quoi mesurer ?

- **Les 4 signaux dorés (SRE)** : **latence** (temps de réponse, séparer succès/erreurs), **trafic** (requêtes/s), **erreurs** (taux), **saturation** (à quel point la ressource est pleine).
- **RED** (services) : *Rate*, *Errors*, *Duration*.
- **USE** (ressources) : *Utilization*, *Saturation*, *Errors* (module 18).
- **Alerter sur les symptômes** (impact utilisateur : erreurs, latence), **diagnostiquer avec les causes** (CPU, disque, GC…).

### SLI, SLO, SLA, budget d'erreur

| Terme | Définition | Exemple |
|-------|------------|---------|
| **SLI** (indicateur) | une mesure du niveau de service | % de requêtes réussies, p95 de latence |
| **SLO** (objectif) | cible interne sur un SLI | 99,5 % de requêtes < 500 ms sur 30 jours |
| **SLA** (accord) | engagement contractuel (pénalités) | 99,9 % de disponibilité |
| **Budget d'erreur** | 100 % − SLO = ce qu'on a le droit de « consommer » | 0,5 % de 30 j = **216 min** d'indisponibilité |

Si le budget est épuisé : on gèle les nouveautés et on traite la fiabilité. Disponibilité → temps d'arrêt annuel : 99 % = 3,65 j · 99,9 % = 8,76 h · 99,99 % = 52,6 min · 99,999 % = 5,3 min.

## 2. Panorama des outils

| Outil | Modèle | Points forts |
|-------|--------|--------------|
| **Nagios / Icinga / Naemon / Checkmk** | contrôles actifs périodiques (plugins) | simples, états OK/WARN/CRIT, historique des pannes |
| **Zabbix** | agent + serveur + base | tout-en-un : découverte, modèles, cartes |
| **Prometheus + Grafana** | collecte « pull » de métriques, TSDB, PromQL | standard cloud-native, conteneurs, Kubernetes |
| **Netdata, Glances, btop** | temps réel local | diagnostic instantané |
| **Loki / ELK-OpenSearch / Graylog** | logs centralisés | recherche, alertes sur logs |
| **Uptime Kuma, Blackbox exporter, healthchecks.io** | sondes externes / « dead man's switch » | disponibilité vue de l'extérieur, tâches planifiées |
| **Tempo / Jaeger / OpenTelemetry** | traces distribuées | latence entre services |

## 3. Contrat d'un plugin de supervision (Nagios/Icinga/Centreon)

Un plugin est un **programme** qui renvoie : un **code de sortie**, une **ligne de texte**, et éventuellement des **données de performance**.

| Code | État | Signification |
|-----:|------|---------------|
| 0 | **OK** | tout va bien |
| 1 | **WARNING** | seuil d'avertissement dépassé |
| 2 | **CRITICAL** | seuil critique dépassé |
| 3 | **UNKNOWN** | impossible de déterminer (arguments invalides, outil absent…) |

```text
DISK WARNING - 85% used|used=85%;80;90;0;100
└──────┬──────────────┘ └──────────┬──────────┘
   texte lisible            perfdata : étiquette=valeur[unité];warn;crit;min;max
```
```bash
#!/usr/bin/env bash
# check_load.sh : charge moyenne 1 min  -w 2 -c 4
while getopts "w:c:" o; do case $o in w) W=$OPTARG;; c) C=$OPTARG;; *) echo "UNKNOWN - usage"; exit 3;; esac; done
l=$(cut -d' ' -f1 /proc/loadavg)
if   awk "BEGIN{exit !($l >= $C)}"; then s=CRITICAL; rc=2
elif awk "BEGIN{exit !($l >= $W)}"; then s=WARNING;  rc=1
else s=OK; rc=0; fi
echo "LOAD $s - load1=$l|load1=$l;$W;$C;0"; exit $rc
```
Collections de plugins : `monitoring-plugins` (`/usr/lib/nagios/plugins/check_disk`, `check_http`, `check_ssh`, `check_load`, `check_procs`…). Exemple : `/usr/lib/nagios/plugins/check_http -H example.org -S -C 14` (alerte si le certificat expire dans < 14 jours).

## 4. Prometheus : l'essentiel

```text
 cibles (exporters)  ◄── scrape HTTP /metrics (toutes les 15 s) ── Prometheus (TSDB, règles) ──► Alertmanager ─► mail/Slack/PagerDuty
 node_exporter :9100                                                    │ PromQL
 appli instrumentée :8000                                               ▼
 blackbox_exporter :9115                                              Grafana (tableaux de bord)
```

### Format d'exposition (texte)

```text
# HELP node_load1 1m load average.
# TYPE node_load1 gauge
node_load1 0.57
# HELP http_requests_total Nombre total de requêtes.
# TYPE http_requests_total counter
http_requests_total{method="GET",code="200"} 1027
http_requests_total{method="POST",code="500"} 3
```
Types : **counter** (ne fait qu'augmenter : requêtes, erreurs, octets — on utilise `rate()`), **gauge** (monte/descend : température, mémoire), **histogram** (distribution : `_bucket`, `_sum`, `_count` → quantiles), **summary**. Nommage : `nom_en_snake_case_unité` (`_seconds`, `_bytes`, `_total`). Étiquettes (*labels*) = dimensions ; **évitez les étiquettes à cardinalité illimitée** (ID utilisateur, URL brute).

### Exporters

```bash
sudo apt install prometheus-node-exporter                    # métriques machine, port 9100
curl -s localhost:9100/metrics | grep -E '^node_(load1|memory_MemAvailable_bytes|filesystem_avail_bytes)'
prometheus-node-exporter --web.listen-address=127.0.0.1:9100 --collector.disable-defaults --collector.cpu --collector.meminfo
```
Autres : `blackbox_exporter` (sondes HTTP/TCP/ICMP/DNS/TLS), `postgres_exporter`, `mysqld_exporter`, `nginx-prometheus-exporter`, `cAdvisor` (conteneurs), `process-exporter`, `smartctl_exporter`. Pour vos propres scripts (cron) : fichier `.prom` lu par le *textfile collector*, ou Pushgateway (batchs courts).

### Configuration `prometheus.yml`

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s
rule_files:
  - /etc/prometheus/alertes.yml
alerting:
  alertmanagers:
    - static_configs: [{ targets: ["localhost:9093"] }]
scrape_configs:
  - job_name: prometheus
    static_configs: [{ targets: ["localhost:9090"] }]
  - job_name: noeuds
    static_configs:
      - targets: ["web1:9100", "web2:9100", "db1:9100"]
        labels: { env: prod }
```
Découverte dynamique : `file_sd_configs`, DNS, Consul, Kubernetes, EC2. Validation : `promtool check config prometheus.yml`.

### PromQL : exemples à connaître

```promql
up                                                        # 1 si la cible répond, 0 sinon
up == 0                                                   # cibles en panne
node_load1 / count without(cpu, mode)(node_cpu_seconds_total{mode="idle"})     # charge par cœur
100 - (avg by (instance)(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)   # % CPU utilisé
(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100        # % mémoire utilisée
(1 - node_filesystem_avail_bytes{fstype!~"tmpfs|overlay"} / node_filesystem_size_bytes) * 100   # % disque
rate(node_network_receive_bytes_total{device="eth0"}[5m]) * 8                  # débit entrant (bits/s)
sum by (code)(rate(http_requests_total[5m]))                                  # req/s par code
sum(rate(http_requests_total{code=~"5.."}[5m])) / sum(rate(http_requests_total[5m]))   # taux d'erreurs
histogram_quantile(0.95, sum by (le)(rate(http_request_duration_seconds_bucket[5m])))   # p95 de latence
predict_linear(node_filesystem_avail_bytes[6h], 4*3600) < 0                  # disque plein dans < 4 h ?
increase(node_boottime_seconds[1d]) ; changes(node_boot_time_seconds[1d])     # redémarrages
```
`rate()` s'applique aux **counters**, avec une fenêtre ≥ 4× l'intervalle de scrape. `by`/`without` regroupent ; `on()`/`ignoring()` jointures.

### Règles d'alerte `alertes.yml`

```yaml
groups:
  - name: machines
    rules:
      - alert: HostDown
        expr: up == 0
        for: 2m                              # doit rester vrai 2 min (évite les faux positifs)
        labels: { severity: critical }
        annotations:
          summary: "{{ $labels.instance }} injoignable"
          description: "La cible {{ $labels.job }}/{{ $labels.instance }} ne répond plus depuis 2 minutes."
          runbook_url: https://wiki.example.org/runbooks/host-down
      - alert: DiskAlmostFull
        expr: (1 - node_filesystem_avail_bytes{fstype!~"tmpfs|overlay"} / node_filesystem_size_bytes) > 0.9
        for: 10m
        labels: { severity: warning }
        annotations:
          summary: "Disque presque plein sur {{ $labels.instance }} ({{ $labels.mountpoint }})"
          description: "Occupation supérieure à 90 % depuis 10 minutes."
```
```bash
promtool check rules alertes.yml
promtool test rules tests.yml                          # tests unitaires de règles
```

### Alertmanager

Regroupe, déduplique, route, silencie et inhibe les alertes.

```yaml
route:
  receiver: equipe-infra
  group_by: [alertname, instance]
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  routes:
    - matchers: [severity="critical"]
      receiver: astreinte
receivers:
  - name: equipe-infra
    email_configs: [{ to: infra@example.org }]
  - name: astreinte
    webhook_configs: [{ url: "http://pagerduty-bridge:8080/alert" }]
inhibit_rules:
  - source_matchers: [alertname="HostDown"]
    target_matchers: [severity="warning"]
    equal: [instance]                                  # si la machine est down, inutile d'alerter sur son disque
```

### Grafana
Sources de données (Prometheus, Loki), tableaux de bord *provisionnés* en YAML/JSON, variables (`$instance`), panneaux. Un bon dashboard : **vue d'ensemble en haut** (golden signals), détails en dessous, un objectif par tableau.

## 5. Logs centralisés

- **Collecte** : `journald`/`rsyslog` → agent (Promtail/Alloy, Filebeat, Fluent Bit, Vector) → **Loki** (index par étiquettes, économique) ou **Elasticsearch/OpenSearch** (plein texte).
- **LogQL** (Loki) : `{job="nginx"} |= "error" | json | status >= 500` ; `sum(rate({job="nginx"} |~ " 5.. " [5m]))`.
- **Structurer** : journaux JSON (`{"level":"error","msg":"…","trace_id":"…"}`), niveaux cohérents, identifiants de corrélation (*trace_id*).
- **Alertes sur logs** : règles Loki/ElastAlert/Graylog ; ne pas dupliquer ce qu'une métrique mesure mieux.
- **Rétention et coûts** : 7–30 jours en chaud, archivage, masquage des données personnelles.

## 6. Sondes et disponibilité vue de l'extérieur

```yaml
# blackbox.yml
modules:
  http_2xx: { prober: http, timeout: 5s, http: { valid_status_codes: [200], fail_if_not_ssl: true } }
```
```yaml
# prometheus.yml (extrait)
  - job_name: sondes
    metrics_path: /probe
    params: { module: [http_2xx] }
    static_configs: [{ targets: ["https://example.org"] }]
    relabel_configs:
      - { source_labels: [__address__], target_label: __param_target }
      - { source_labels: [__param_target], target_label: instance }
      - { target_label: __address__, replacement: localhost:9115 }
```
Alertes : `probe_success == 0`, `probe_ssl_earliest_cert_expiry - time() < 14*86400` (certificat), `probe_duration_seconds > 2`. Sauvegardes : **dead man's switch** (alerter quand le *ping* de fin de sauvegarde n'arrive **pas**).

## 7. Concevoir de bonnes alertes

1. **Actionnables** : chaque alerte appelle une action humaine précise ; sinon c'est un graphique, pas une alerte.
2. **Symptômes > causes** : « taux d'erreur 5xx > 2 % » plutôt que « CPU 85 % ».
3. **`for:`** pour filtrer le bruit ; **sévérités** : *critical* (réveille quelqu'un), *warning* (ticket, jours ouvrés).
4. **Runbook** lié (que vérifier ? comment réparer ? qui prévenir ?).
5. **Éviter la fatigue d'alertes** : revue mensuelle, suppression des alertes ignorées, regroupement/inhibition.
6. **Tester** : `promtool test rules`, exercices de panne (*game days*).
7. **Astreinte** : rotation, escalade, post-mortems sans recherche de coupable.

## 8. Capacité et tendances

```promql
predict_linear(node_filesystem_avail_bytes{mountpoint="/"}[7d], 30*86400) < 0       # plein dans 30 jours ?
avg_over_time(node_load1[7d]) ; max_over_time(node_memory_Active_bytes[30d])
```
Planifier : croissance mensuelle, pics saisonniers, marge de sécurité (≥ 30 %), tests de charge (module 19).

## 9. Résumé

- Supervision = alerter sur l'impact ; observabilité = comprendre grâce à métriques + logs + traces.
- Golden signals / RED / USE ; SLI → SLO → budget d'erreur.
- Plugin Nagios : codes **0/1/2/3** + texte + *perfdata* `label=valeur;warn;crit;min;max`.
- Prometheus : pull, exporters, format texte, `rate()` sur les counters, règles avec `for`, Alertmanager (groupement, inhibition), Grafana.
- Logs structurés centralisés (Loki/ELK) ; sondes externes ; dead man's switch.
- Alertes actionnables, peu nombreuses, avec runbook ; surveiller les tendances.

## 10. Quiz

1. Que signifient les codes de sortie 0, 1, 2, 3 d'un plugin Nagios ?
2. Différence entre un *counter* et un *gauge* ? Quelle fonction PromQL pour un counter ?
3. Un SLO de 99,9 % sur 30 jours : quel budget d'erreur en minutes ?
4. Pourquoi mettre `for: 5m` dans une alerte ?
5. Écrivez la requête PromQL du pourcentage de mémoire utilisée.
6. Quel est l'intérêt de l'inhibition dans Alertmanager ?
7. Pourquoi une étiquette `user_id` est-elle dangereuse dans une métrique ?
8. Comment détecter qu'une sauvegarde nocturne n'a pas eu lieu ?

<details><summary>Réponses</summary>

1. 0 OK, 1 WARNING, 2 CRITICAL, 3 UNKNOWN.
2. Counter : valeur cumulative croissante (→ `rate()`/`increase()`) ; gauge : valeur instantanée qui monte/descend.
3. 0,1 % de 43 200 min = 43,2 min.
4. L'état doit persister 5 min avant de notifier : évite les pics transitoires et le bruit.
5. `(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100`
6. Supprimer les alertes dérivées quand une cause plus grave est déjà signalée (machine down ⇒ pas d'alertes disque).
7. Cardinalité explosive (une série par utilisateur) : mémoire et performance de Prometheus dégradées.
8. *Dead man's switch* : la sauvegarde envoie un ping à la fin ; l'absence de ping déclenche l'alerte (healthchecks.io, métrique `time() - last_success > 90000`).
</details>

➡️ **Labo** : [LAB.md](LAB.md) · **Démo** : `./lab demo 23` · **Suivant** : [24 — Haute disponibilité, sauvegarde et PRA](../24-haute-disponibilite-et-pra/README.md)
