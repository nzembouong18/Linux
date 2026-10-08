# Module 20 — Conteneurs : namespaces, cgroups, overlayfs, Docker et Podman

> **Niveau** : Avancé | **Durée** : 8 h (3 h cours + 5 h labo) | **Prérequis** : modules 07, 13, 14, 16, 17
>
> **Objectifs** — À la fin de ce module vous saurez :
> - expliquer ce qu'est **vraiment** un conteneur (processus isolé par le noyau) ;
> - construire un mini-conteneur « à la main » (`unshare`, `chroot`, **namespaces**, **cgroups**, **overlayfs**) ;
> - utiliser Docker/Podman : images, conteneurs, volumes, réseaux, **Compose** ;
> - écrire un **Dockerfile** efficace et sûr ;
> - appliquer les bonnes pratiques de sécurité (non-root, capacités, `read-only`, rootless) ;
> - diagnostiquer un conteneur et situer Kubernetes.

---

## 1. Conteneur ≠ machine virtuelle

```text
   Machines virtuelles                          Conteneurs
 ┌───────┐ ┌───────┐ ┌───────┐            ┌───────┐ ┌───────┐ ┌───────┐
 │ App A │ │ App B │ │ App C │            │ App A │ │ App B │ │ App C │
 │ libs  │ │ libs  │ │ libs  │            │ libs  │ │ libs  │ │ libs  │
 │ OS    │ │ OS    │ │ OS    │            └───┬───┘ └───┬───┘ └───┬───┘
 └───┬───┘ └───┬───┘ └───┬───┘               moteur de conteneurs (runc)
   hyperviseur (KVM, VMware)                 ──────────────────────────
 ───────────────────────────────                 UN SEUL noyau Linux partagé
        matériel                                       matériel
```

| | VM | Conteneur |
|---|----|-----------|
| Isolation | forte (noyau dédié) | par le noyau partagé (moins étanche) |
| Démarrage | minutes | millisecondes |
| Taille | Go | Mo |
| Densité | dizaines | centaines |
| Cas d'usage | OS différents, forte isolation | microservices, CI, déploiement reproductible |

> Un conteneur **n'est pas un objet du noyau** : c'est un **processus Linux ordinaire** auquel on a appliqué des **namespaces** (ce qu'il voit), des **cgroups** (ce qu'il consomme), un système de fichiers racine séparé, des capacités réduites et un filtre **seccomp**.

## 2. Les briques du noyau

### Namespaces (isolation de la vue)

| Namespace | Isole | Option `unshare` |
|-----------|-------|------------------|
| **PID** | numéros de processus (le 1er processus voit le PID 1) | `--pid` |
| **NET** | interfaces, routes, ports, pare-feu | `--net` |
| **MNT** | points de montage | `--mount` |
| **UTS** | nom d'hôte | `--uts` |
| **IPC** | files de messages, mémoire partagée | `--ipc` |
| **USER** | UID/GID (root dans le conteneur = utilisateur ordinaire dehors) | `--user --map-root-user` |
| **CGROUP** | vue de la hiérarchie cgroup | `--cgroup` |

```bash
ls -l /proc/$$/ns                         # les namespaces d'un processus
sudo lsns                                 # liste des namespaces du système
sudo unshare --uts --pid --mount --ipc --net --fork --mount-proc bash
  # dans ce shell :  hostname isole ; echo $$ → 1 ; ps → seulement ce shell
sudo nsenter -t PID --net ip addr         # entrer dans le namespace réseau d'un conteneur existant
```

### cgroups v2 (limitation et comptabilité des ressources)

```bash
cat /sys/fs/cgroup/cgroup.controllers            # contrôleurs disponibles : cpu memory io pids…
sudo mkdir /sys/fs/cgroup/demo
echo "+cpu +memory +pids" | sudo tee /sys/fs/cgroup/cgroup.subtree_control
echo 64M | sudo tee /sys/fs/cgroup/demo/memory.max             # plafond mémoire → OOM dans ce groupe seulement
echo "50000 100000" | sudo tee /sys/fs/cgroup/demo/cpu.max      # 50 ms par période de 100 ms = 50 % d'un cœur
echo 16 | sudo tee /sys/fs/cgroup/demo/pids.max                 # anti fork-bomb
echo $$ | sudo tee /sys/fs/cgroup/demo/cgroup.procs             # y placer le shell courant
cat /sys/fs/cgroup/demo/memory.current /sys/fs/cgroup/demo/memory.events
systemd-cgtop                                                   # consommation par cgroup
```
systemd et Docker créent et gèrent ces cgroups pour vous (`MemoryMax=`, `docker run -m 256m --cpus 0.5 --pids-limit 100`).

### Système de fichiers en couches : overlayfs

```text
   merged  (vue du conteneur)   ◄── ce que voit le processus
      ▲
   upper   (couche inscriptible, propre au conteneur)  ← les écritures ; suppressions = « whiteouts »
      ▲
   lower   (couches de l'image, en lecture seule, partagées entre conteneurs)
```
```bash
sudo mount -t overlay overlay -o lowerdir=base,upperdir=up,workdir=work merged
```
C'est pourquoi des centaines de conteneurs basés sur la même image ne coûtent presque rien en disque, et pourquoi les données à conserver vont dans des **volumes**.

### Sécurité du noyau
- **Capabilities** : root découpé en privilèges (`CAP_NET_BIND_SERVICE`, `CAP_SYS_ADMIN`…). Docker en retire la plupart par défaut.
- **seccomp** : filtre des appels système autorisés (profil par défaut qui en bloque ~50).
- **AppArmor/SELinux** : confinement (module 16).
- **user namespaces / rootless** : le « root » du conteneur n'est pas root sur l'hôte.

## 3. Construire un conteneur à la main

```bash
# 1. Un système de fichiers racine minimal (busybox statique)
mkdir -p rootfs/{bin,proc,sys,dev,etc,tmp,root}
cp /usr/bin/busybox rootfs/bin/                      # paquet busybox-static
sudo chroot rootfs /bin/busybox --install -s /bin    # applets : liens RELATIFS au rootfs (pas depuis l'hôte !)

# 2. L'isoler
sudo unshare --uts --pid --ipc --mount --net --fork --mount-proc="$PWD/rootfs/proc" \
     chroot rootfs /bin/sh -c 'hostname mon-conteneur; exec sh'
# dedans :  hostname → mon-conteneur · echo $$ → 1 · ps → 2 lignes · ip link → seulement lo · ls / → rootfs seul

# 3. Réseau : relier à l'hôte avec une paire veth (module 17) — ip link set vethX netns <pid>
```
Docker/Podman automatisent exactement ceci (`runc` / `crun`), plus les images en couches, le réseau, les volumes et le cycle de vie.

## 4. Docker (et Podman) : l'essentiel

**Architecture** : CLI `docker` → daemon `dockerd` → `containerd` → `runc` (création du conteneur). **Podman** : sans daemon, **rootless** par défaut, CLI compatible (`alias docker=podman`), intégration systemd (Quadlet).

```text
 Dockerfile ──docker build──► Image (couches, immuable) ──docker run──► Conteneur (processus + couche inscriptible)
                                   │ docker push/pull
                              Registre (Docker Hub, GHCR, Harbor…)
```

```bash
# Installer (Ubuntu) :  sudo apt install docker.io    ou  docker-ce depuis le dépôt officiel Docker
sudo systemctl enable --now docker
docker run --rm hello-world
docker run -d --name web -p 8080:80 nginx:1.27-alpine        # -d détaché · -p HÔTE:CONTENEUR
docker ps ; docker ps -a                                     # actifs / tous
docker logs -f --tail 50 web
docker exec -it web sh                                       # shell dans le conteneur
docker inspect web | jq '.[0].NetworkSettings.IPAddress'
docker stats --no-stream ; docker top web
docker stop web && docker rm web                             # ou docker rm -f web
docker images ; docker pull alpine:3.20 ; docker rmi alpine:3.20
docker system df ; docker system prune -f                    # nettoyage (attention !)
```

### Données : volumes et bind mounts

```bash
docker volume create donnees
docker run -d --name db -v donnees:/var/lib/postgresql/data -e POSTGRES_PASSWORD=secret postgres:16
docker run --rm -v "$PWD":/app:ro -w /app python:3.12-slim python script.py       # bind mount en lecture seule
docker run --rm --tmpfs /tmp:rw,noexec,nosuid alpine sh -c 'df /tmp'
```
Règle : **le conteneur est jetable, les données sont dans des volumes** (ou en base externe).

### Réseau

| Mode | Description |
|------|-------------|
| `bridge` (défaut) | réseau privé `docker0`, NAT vers l'extérieur, `-p` pour publier |
| réseau utilisateur | `docker network create app` : **résolution DNS par nom de conteneur** |
| `host` | partage la pile réseau de l'hôte (pas d'isolation) |
| `none` | aucun réseau |
| `macvlan` | IP sur le LAN physique |

```bash
docker network create app
docker run -d --network app --name api monapi
docker run --rm --network app curlimages/curl http://api:8080/health
```
Attention : publier `-p 5432:5432` expose le port sur **toutes** les interfaces et **contourne ufw** ; utilisez `-p 127.0.0.1:5432:5432`.

### Limiter les ressources

```bash
docker run -d --memory 256m --memory-swap 256m --cpus 0.5 --pids-limit 100 --name limite nginx
docker update --cpus 1 limite
```

## 5. Écrire un bon Dockerfile

```dockerfile
# syntax=docker/dockerfile:1
FROM python:3.12-slim AS base                    # tag précis (jamais :latest), image légère
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /app

# Les dépendances d'abord → le cache de couches est réutilisé tant que requirements.txt ne change pas
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .
RUN useradd --system --no-create-home appuser && chown -R appuser /app
USER appuser                                     # ne pas tourner en root

EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=3s CMD python -c "import urllib.request,sys; urllib.request.urlopen('http://127.0.0.1:8000/health')" || exit 1
CMD ["gunicorn", "-b", "0.0.0.0:8000", "app:app"]   # forme exec (JSON), pas de shell intermédiaire
```

**Build en plusieurs étapes** (*multi-stage*) : compilez dans une image lourde, copiez seulement le binaire dans une image minimale.

```dockerfile
FROM golang:1.23 AS build
WORKDIR /src
COPY . .
RUN CGO_ENABLED=0 go build -o /out/app ./cmd/app

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/app /app
ENTRYPOINT ["/app"]
```

**Bonnes pratiques**

1. Image de base **officielle, minimale, épinglée** (`alpine`, `-slim`, `distroless`), mise à jour régulièrement.
2. **Un processus par conteneur**, lancé en **exec form** ; gérer SIGTERM (arrêt propre ; `docker stop` attend 10 s puis SIGKILL).
3. **Couches** : regrouper les `RUN`, nettoyer dans la même couche (`apt-get update && apt-get install -y --no-install-recommends … && rm -rf /var/lib/apt/lists/*`), mettre ce qui change rarement en premier.
4. `COPY` plutôt que `ADD` ; `.dockerignore` (`.git`, `node_modules`, secrets).
5. **Jamais de secrets** dans l'image (ni `ENV`, ni `COPY`) : variables à l'exécution, `docker secret`, `--secret` de BuildKit.
6. `USER` non-root, `HEALTHCHECK`, `WORKDIR`, `LABEL`.
7. Journaliser sur stdout/stderr (collecté par `docker logs`).
8. Analyser : `hadolint Dockerfile`, `trivy image monimage` (vulnérabilités), `dive monimage` (couches).

## 6. Docker Compose : une application multi-conteneurs

`compose.yaml` :

```yaml
services:
  web:
    build: .
    ports:
      - "127.0.0.1:8000:8000"
    environment:
      DATABASE_URL: postgresql://app:${DB_PASSWORD}@db:5432/app
    depends_on:
      db:
        condition: service_healthy
    restart: unless-stopped
    read_only: true
    tmpfs: [/tmp]
    cap_drop: [ALL]
    security_opt: ["no-new-privileges:true"]
    mem_limit: 512m
  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: app
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_DB: app
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U app"]
      interval: 5s
      retries: 10
volumes:
  pgdata:
```
```bash
docker compose up -d --build           # crée réseau, volumes, conteneurs
docker compose ps ; docker compose logs -f web
docker compose exec db psql -U app
docker compose config                  # valide et affiche la config finale
docker compose down                    # arrête et supprime (ajouter -v pour les volumes)
```
Le fichier `.env` fournit les variables (`DB_PASSWORD=…`) : ne le versionnez pas.

## 7. Sécuriser les conteneurs

| Risque | Mesure |
|--------|--------|
| Processus root dans le conteneur | `USER` non-root ; **rootless Podman/Docker** |
| `--privileged`, `-v /:/host`, socket Docker monté | **à proscrire** (équivaut à root sur l'hôte) |
| Capacités excessives | `--cap-drop ALL --cap-add NET_BIND_SERVICE` |
| Système de fichiers modifiable | `--read-only` + `--tmpfs /tmp` |
| Élévation de privilèges | `--security-opt no-new-privileges` |
| Images vulnérables / non fiables | images officielles, `trivy`, signatures (cosign), registre privé |
| Secrets dans l'image | variables d'exécution, gestionnaire de secrets |
| Ports exposés | `-p 127.0.0.1:…`, réseau interne |
| Ressources | limites mémoire/CPU/PIDs |
| Groupe `docker` | équivaut à root : n'y mettre que des administrateurs |

## 8. Dépannage

```bash
docker ps -a                              # le conteneur est-il Exited ? code de sortie ?
docker logs --tail 100 NOM                # la plupart des réponses sont là
docker inspect NOM --format '{{.State.ExitCode}} {{.State.OOMKilled}} {{.State.Error}}'
docker run --rm -it --entrypoint sh IMAGE # explorer l'image
docker events                             # flux d'événements
sudo journalctl -u docker -n 100          # le daemon
docker compose config && docker compose logs
nsenter -t $(docker inspect -f '{{.State.Pid}}' NOM) -n ss -ltnp        # réseau vu DEPUIS le conteneur
```
| Symptôme | Cause fréquente |
|----------|-----------------|
| `Exited (137)` | tué par SIGKILL : OOM (`OOMKilled=true`) ou `docker stop` trop long |
| `Exited (1)` au démarrage | erreur applicative : voir `docker logs` |
| Port inaccessible | l'appli écoute sur `127.0.0.1` dans le conteneur (il faut `0.0.0.0`) ; `-p` oublié ; pare-feu |
| Données perdues | pas de volume |
| Disque saturé | `docker system df`, logs non limités (`--log-opt max-size=10m`) |
| Résolution DNS entre conteneurs impossible | réseau `bridge` par défaut (créez un réseau utilisateur) |

## 9. Et ensuite : orchestration

Un seul hôte → Compose / systemd+Podman (Quadlet). Plusieurs hôtes, haute disponibilité, déploiements progressifs → **Kubernetes** : *Pod* (1+ conteneurs), *Deployment* (réplicas, mises à jour), *Service* (adresse stable + répartition), *Ingress* (HTTP entrant), *ConfigMap/Secret*, *PersistentVolume*. Chaque nœud utilise exactement les mécanismes de ce module (namespaces, cgroups, overlayfs). Alternatives légères : K3s, Nomad. Systèmes de conteneurs « système » : LXC/LXD (Incus), `systemd-nspawn`.

## 10. Résumé

- Conteneur = **processus** + **namespaces** (vue) + **cgroups** (ressources) + **overlayfs** (fichiers) + capacités/seccomp.
- `unshare` + `chroot` + busybox = un conteneur en 3 commandes ; Docker/Podman automatisent et standardisent.
- Images immuables en couches ; données dans des **volumes** ; réseau utilisateur pour le DNS interne.
- Dockerfile : base épinglée, couches ordonnées, `USER` non-root, `HEALTHCHECK`, `CMD` exec form, pas de secrets.
- Sécurité : rootless, `cap-drop`, `read-only`, pas de `--privileged`, ports en `127.0.0.1`, scan des images.
- Diagnostic : `ps -a`, `logs`, `inspect` (ExitCode, OOMKilled), `exec`, `nsenter`.

## 11. Quiz

1. Qu'est-ce qui rend un processus « conteneurisé » du point de vue du noyau ?
2. Quel namespace donne l'impression qu'un processus est le PID 1 ? Lequel isole le nom d'hôte ?
3. Comment limiter un conteneur à 256 Mo de RAM et 0,5 CPU ?
4. Pourquoi `-p 5432:5432` est-il risqué sur un serveur public ?
5. Que contient la couche *upper* d'un overlayfs ? Que devient un fichier supprimé de la couche *lower* ?
6. Citez 4 bonnes pratiques de Dockerfile.
7. Pourquoi mettre `COPY requirements.txt` avant `COPY . .` ?
8. Un conteneur sort avec le code 137 : que vérifiez-vous ?

<details><summary>Réponses</summary>

1. Il est lancé dans des namespaces dédiés, limité par des cgroups, avec une racine de fichiers distincte et des privilèges réduits (capabilities, seccomp).
2. PID namespace ; UTS namespace.
3. `docker run -m 256m --cpus 0.5 …` (cgroups `memory.max`, `cpu.max`).
4. Le port est publié sur toutes les interfaces et Docker contourne ufw ; préférer `127.0.0.1:5432:5432` ou un réseau interne.
5. Les écritures du conteneur ; la suppression est représentée par un *whiteout* (fichier spécial) : le fichier de la couche basse reste intact mais invisible.
6. Ex. : tag épinglé, `USER` non-root, `.dockerignore`, `COPY`, `HEALTHCHECK`, exec form, nettoyage dans la même couche, pas de secret, multi-stage.
7. Pour réutiliser le cache de la couche des dépendances tant qu'elles ne changent pas.
8. SIGKILL (128+9) : OOM (`docker inspect … OOMKilled`) ou arrêt forcé ; limites mémoire, fuite mémoire.
</details>

➡️ **Labo** : [LAB.md](LAB.md) · **Démo** : `./lab demo 20` · **Suivant** : [21 — Noyau, démarrage et récupération](../21-noyau-et-demarrage/README.md)
