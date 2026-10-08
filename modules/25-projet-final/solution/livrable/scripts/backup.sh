#!/usr/bin/env bash
# backup.sh [-n KEEP] [--dry-run] SRC DEST
# Archive SRC dans DEST/tickets-<horodatage>.tar.gz, tient à jour DEST/SHA256SUMS et applique la rétention.
# Codes : 0 ok · 1 usage · 3 source absente · 4 destination inutilisable · 5 vérification de l'archive échouée
set -euo pipefail

keep=7
dry=0
usage() { echo "Usage: ${0##*/} [-n KEEP] [--dry-run] SRC DEST" >&2; exit 1; }

args=()
while [[ $# -gt 0 ]]; do
  case $1 in
    -n) [[ ${2:-} =~ ^[0-9]+$ && ${2:-0} -ge 1 ]] || usage; keep=$2; shift 2 ;;
    --dry-run) dry=1; shift ;;
    -h|--help|-*) usage ;;
    *) args+=("$1"); shift ;;
  esac
done
[[ ${#args[@]} -eq 2 ]] || usage
src=${args[0]} dest=${args[1]}

[[ -d $src ]] || { echo "Source introuvable: $src" >&2; exit 3; }
stamp=${BACKUP_STAMP:-$(date +%Y%m%d-%H%M%S)}
archive="$dest/tickets-$stamp.tar.gz"

if (( dry )); then
  echo "DRY-RUN: créerait $archive depuis $src (rétention: $keep)"
  exit 0
fi

mkdir -p "$dest" 2>/dev/null || { echo "Destination inutilisable: $dest" >&2; exit 4; }
[[ -w $dest ]] || { echo "Destination non inscriptible: $dest" >&2; exit 4; }

tar -czf "$archive" -C "$(dirname "$src")" "$(basename "$src")"
if ! tar -tzf "$archive" >/dev/null 2>&1; then
  echo "Vérification échouée: $archive" >&2
  rm -f "$archive"
  exit 5
fi
(cd "$dest" && sha256sum "tickets-$stamp.tar.gz" >> SHA256SUMS)

# Rétention : on garde les KEEP archives les plus récentes (le format de date rend le tri par nom chronologique)
mapfile -t all < <(cd "$dest" && ls -1 tickets-*.tar.gz | sort)
if (( ${#all[@]} > keep )); then
  for old in "${all[@]:0:${#all[@]}-keep}"; do
    rm -f "$dest/$old"
    sed -i "\\|  $old\$|d" "$dest/SHA256SUMS"
  done
fi
echo "$archive"
