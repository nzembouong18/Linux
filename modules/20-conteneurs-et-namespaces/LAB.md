# Labo 20 — Fabriquer un mini-conteneur, puis écrire un Dockerfile et un Compose sûrs

> **Durée** : 5 h · **Difficulté** : ⭐⭐⭐⭐ · **Prérequis** : module 20 · **Droits** : `root`/`sudo` · outils : `unshare`, `chroot`, `busybox-static`, `mount` (overlay)
> Pas besoin de Docker : on reconstruit **à la main** ce que Docker automatise.

## Contexte

Avant de faire confiance à Docker, votre équipe veut comprendre ce qu'il fait réellement. Vous construisez un mini-moteur (`ctr.sh`), ajoutez une couche inscriptible avec **overlayfs**, limitez les ressources avec les **cgroups v2**, puis rédigez un **Dockerfile** et un **compose.yaml** conformes aux bonnes pratiques pour l'application fournie.

## Mise en place

```bash
./lab setup 20
cd ~/labs/20 && ls -R app && which busybox
```
*(`busybox` : `sudo apt install busybox-static`.)*

## Partie A — Le système de fichiers racine

1. Créez `rootfs/` avec les dossiers `bin proc sys dev etc tmp root`. Copiez-y le binaire **statique** `busybox` dans `rootfs/bin/`, puis installez les applets **de l'intérieur** (`chroot rootfs /bin/busybox --install -s /bin`) afin que les liens soient valides dans le rootfs. Vérifiez : `sudo chroot rootfs /bin/sh -c 'echo ok'`.

## Partie B — Le moteur : `ctr.sh`

2. Écrivez **`ctr.sh ROOTFS HOSTNAME CMD [ARGS...]`** (exécutable, bash) qui lance `CMD` dans un conteneur :
   - namespaces **UTS, PID, IPC, mount et réseau** isolés (`unshare … --fork --mount-proc=…`) ;
   - racine = `ROOTFS` (`chroot`) ;
   - nom d'hôte du conteneur = `HOSTNAME` ;
   - le **code retour** de `CMD` est propagé ;
   - sans arguments suffisants : message d'usage sur **stderr** et code **1**.
   Le correcteur le teste : `hostname`, PID 1, listing de `/`, interfaces réseau, `ps`, écriture dans `/tmp`, code retour.

## Partie C — overlayfs

3. Montez un **overlayfs** sur `overlay/merged` avec `lowerdir=rootfs`, `upperdir=overlay/upper`, `workdir=overlay/work`. Dans `merged` : créez `tmp/nouveau.txt` (contenu `couche haute`) et **supprimez** `bin/ls`. Le montage doit rester actif. Constatez : `rootfs` n'a pas changé ; `upper` contient le nouveau fichier et un *whiteout* pour `bin/ls`.

## Partie D — cgroups v2 (évaluée si le noyau/l'hôte le permet)

4. Écrivez **`limites.sh CMD...`** : crée le cgroup `lab20` sous la racine cgroup (variable `CGROOT`, défaut `/sys/fs/cgroup`), y règle **`memory.max` = 64 Mo**, **`pids.max` = 16**, **`cpu.max` = 50 %** d'un cœur (`50000 100000`), y place le processus courant puis fait `exec "$@"`. *(Prérequis : activer les contrôleurs dans `cgroup.subtree_control`.)*

## Partie E — Dockerfile et Compose (dans `app/`, application fournie)

L'application (`app/app.py`, `app/requirements.txt`) écoute sur le port **8000** et expose `/health`.

5. **`app/Dockerfile`** : base **épinglée** et légère (ex. `python:3.12-slim`, jamais `latest`) ; `WORKDIR` ; `COPY requirements.txt` **avant** `COPY . .` (cache de couches) ; `pip install --no-cache-dir` ; pas de `ADD` ; création d'un **utilisateur non-root** puis `USER` ; `EXPOSE 8000` ; `HEALTHCHECK` ; `CMD` en **forme exec** (JSON) ; aucun secret en `ENV`.
6. **`app/.dockerignore`** : au moins `.git` et `.env`.
7. **`app/compose.yaml`** : services `web` (build local) et `db` (`postgres:16-alpine`) ; `web` publie **`127.0.0.1:8000:8000`**, `restart: unless-stopped`, `read_only: true`, `cap_drop: [ALL]`, `security_opt: ["no-new-privileges:true"]`, limite mémoire (`mem_limit`) ; `db` avec **volume nommé** pour ses données, `healthcheck`, et `web` en `depends_on` de `db` avec `condition: service_healthy` ; le mot de passe vient d'une variable (`${DB_PASSWORD}`), jamais en clair.

## Validation

```bash
./lab check 20
```

<details><summary>💡 Indices</summary>

- `sudo unshare --uts --pid --ipc --mount --net --fork --mount-proc="$ROOT/proc" chroot "$ROOT" /bin/sh -c 'hostname "$1"; shift; exec "$@"' _ "$HOST" "$@"`
- Chemin absolu du rootfs : `ROOT=$(realpath "$1")`.
- `sudo mount -t overlay overlay -o lowerdir=$PWD/rootfs,upperdir=$PWD/overlay/upper,workdir=$PWD/overlay/work $PWD/overlay/merged`
- cgroup : `echo "+cpu +memory +pids" > $CG/cgroup.subtree_control; mkdir $CG/lab20; echo 64M > $CG/lab20/memory.max; echo $$ > $CG/lab20/cgroup.procs`
- Un utilisateur non-root dans une image slim : `RUN useradd --system --no-create-home appuser` puis `USER appuser`.
</details>

<details><summary>✅ Solution</summary>

```bash
cd ~/labs/20
mkdir -p rootfs/{bin,proc,sys,dev,etc,tmp,root}
cp "$(command -v busybox)" rootfs/bin/ && sudo chroot rootfs /bin/busybox --install -s /bin

cat > ctr.sh <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
[[ $# -ge 3 ]] || { echo "Usage: $0 ROOTFS HOSTNAME CMD [ARGS...]" >&2; exit 1; }
root=$(realpath "$1"); host=$2; shift 2
exec unshare --uts --pid --ipc --mount --net --fork --mount-proc="$root/proc" \
  chroot "$root" /bin/sh -c 'hostname "$1"; shift; exec "$@"' _ "$host" "$@"
EOS
chmod +x ctr.sh

mkdir -p overlay/{upper,work,merged}
sudo mount -t overlay overlay -o lowerdir=$PWD/rootfs,upperdir=$PWD/overlay/upper,workdir=$PWD/overlay/work $PWD/overlay/merged
echo "couche haute" | sudo tee overlay/merged/tmp/nouveau.txt
sudo rm overlay/merged/bin/ls

cat > limites.sh <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
CG=${CGROOT:-/sys/fs/cgroup}
[[ $# -ge 1 ]] || { echo "Usage: $0 CMD..." >&2; exit 1; }
echo "+cpu +memory +pids" > "$CG/cgroup.subtree_control" 2>/dev/null || true
mkdir -p "$CG/lab20"
echo 64M > "$CG/lab20/memory.max"
echo 16 > "$CG/lab20/pids.max"
echo "50000 100000" > "$CG/lab20/cpu.max"
echo $$ > "$CG/lab20/cgroup.procs"
exec "$@"
EOS
chmod +x limites.sh

cat > app/Dockerfile <<'EOS'
FROM python:3.12-slim
ENV PYTHONUNBUFFERED=1
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
RUN useradd --system --no-create-home appuser && chown -R appuser /app
USER appuser
EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=3s CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health')"
CMD ["python", "app.py"]
EOS
printf '.git\n.env\n__pycache__/\n' > app/.dockerignore
cat > app/compose.yaml <<'EOS'
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
    cap_drop: [ALL]
    security_opt: ["no-new-privileges:true"]
    mem_limit: 256m
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
EOS
```
</details>

## Pour aller plus loin

- Reliez le conteneur au réseau : créez une paire veth, déplacez une extrémité dans le namespace réseau du conteneur (`ip link set vethX netns PID`), adressez-la et pingez l'hôte.
- Ajoutez un **user namespace** (`--user --map-root-user`) pour un conteneur sans root.
- Si Docker/Podman est disponible : construisez l'image, lancez la pile Compose, comparez `docker inspect` avec ce que vous avez fabriqué.
- Passez le Dockerfile à `hadolint`, l'image à `trivy`.

## Nettoyage

```bash
./lab reset 20     # démonte l'overlay, retire le cgroup de test
```
