#!/usr/bin/env bash
# =============================================================================
# validate.sh — teste TOUS les labos et démos (utilisé par la CI)
#   Pour chaque module :
#     1. setup
#     2. check  → doit ÉCHOUER (sinon le labo est trivial)
#     3. solve  → check doit RÉUSSIR
#     4. demo (DEMO_FAST=1) → doit se terminer sans erreur
#     5. reset
#   Code 77 = labo ignoré (prérequis absent : systemd, loop, root…)
# Usage : scripts/validate.sh [NN ...]
# =============================================================================
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export NO_COLOR=1 DEMO_FAST=1
export LAB_ROOT="${LAB_ROOT:-$(mktemp -d /tmp/labs-validate.XXXXXX)}"

mods=("$@")
if [[ ${#mods[@]} -eq 0 ]]; then
  while IFS= read -r d; do mods+=("$(basename "$d" | cut -d- -f1)"); done < <(find "$ROOT/modules" -mindepth 1 -maxdepth 1 -type d | sort)
fi

ok=0; ko=0; skip=0
run() { # run <module> <étape> <attendu: ok|ko> cmd...
  local m=$1 step=$2 want=$3; shift 3
  local out rc; out=$("$@" 2>&1); rc=$?
  if [[ $rc -eq 77 ]]; then echo "SKIP  $m $step (prérequis absent)"; return 77; fi
  if { [[ $want == ok && $rc -eq 0 ]] || [[ $want == ko && $rc -ne 0 ]]; }; then return 0; fi
  echo "FAIL  $m $step (rc=$rc, attendu=$want)"; echo "$out" | tail -15 | sed 's/^/        /'; return 1
}

for m in "${mods[@]}"; do
  dir=$(find "$ROOT/modules" -maxdepth 1 -type d -name "${m}-*" | head -1)
  [[ -n "$dir" ]] || { echo "FAIL  $m introuvable"; ko=$((ko + 1)); continue; }
  failed=0; skipped=0
  if [[ -f "$dir/lab.sh" ]]; then
    run "$m" setup ok bash "$dir/lab.sh" setup; r=$?
    if [[ $r -eq 77 ]]; then skipped=1; elif [[ $r -ne 0 ]]; then failed=1; fi
    if [[ $failed -eq 0 && $skipped -eq 0 ]]; then
      run "$m" "check-avant-solution" ko bash "$dir/lab.sh" check || failed=1
      run "$m" solve ok bash "$dir/lab.sh" solve || failed=1
      run "$m" "check-apres-solution" ok bash "$dir/lab.sh" check || failed=1
      bash "$dir/lab.sh" reset >/dev/null 2>&1
    fi
  fi
  if [[ -f "$dir/demo.sh" ]]; then run "$m" demo ok bash "$dir/demo.sh"; r=$?; [[ $r -eq 0 || $r -eq 77 ]] || failed=1; fi
  for f in README.md LAB.md; do [[ -f "$dir/$f" ]] || { echo "FAIL  $m fichier manquant: $f"; failed=1; }; done
  if [[ $failed -eq 1 ]]; then ko=$((ko + 1)); elif [[ $skipped -eq 1 ]]; then skip=$((skip + 1)); echo "SKIP  $m"; else ok=$((ok + 1)); echo "OK    $m"; fi
done

rm -rf "$LAB_ROOT" 2>/dev/null
echo "----"; echo "Modules : $ok OK · $ko en échec · $skip ignorés"
[[ $ko -eq 0 ]]
