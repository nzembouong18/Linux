#!/usr/bin/env bash
# check-links.sh — vérifie que les liens relatifs [texte](chemin) des fichiers Markdown pointent vers des fichiers existants.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bad=0; total=0
while IFS= read -r md; do
  dir=$(dirname "$md")
  # extrait la cible de chaque lien [..](cible) en ignorant les blocs de code
  while IFS= read -r target; do
    case "$target" in http://*|https://*|mailto:*|\#*|'') continue ;; esac
    path="${target%%#*}"; path="${path%% *}"
    [[ -z "$path" ]] && continue
    total=$((total + 1))
    if [[ ! -e "$dir/$path" ]]; then echo "LIEN CASSÉ : ${md#"$ROOT"/} → $target"; bad=$((bad + 1)); fi
  done < <(awk '/^```/{c=!c; next} !c' "$md" | grep -oE '\]\([^)]+\)' | sed -E 's/^\]\((.*)\)$/\1/')
done < <(find "$ROOT" -name '*.md' -not -path '*/node_modules/*' -not -path '*/.git/*')
echo "Liens relatifs vérifiés : $total — cassés : $bad"
[[ $bad -eq 0 ]]
