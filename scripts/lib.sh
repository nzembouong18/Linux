#!/usr/bin/env bash
# =============================================================================
# lib.sh — bibliothèque commune des labos (setup / check / solve / reset)
# Chaque modules/NN-xxx/lab.sh source ce fichier puis définit :
#   lab_setup, lab_check, lab_solve   (et optionnellement LAB_REQUIRES=(...))
# =============================================================================

LAB_ROOT="${LAB_ROOT:-$HOME/labs}"
PASS=0; FAIL=0; SKIPPED=0

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  C_RED=$'\e[31m'; C_GRN=$'\e[32m'; C_YLW=$'\e[33m'; C_BLU=$'\e[34m'; C_BLD=$'\e[1m'; C_OFF=$'\e[0m'
else
  C_RED=''; C_GRN=''; C_YLW=''; C_BLU=''; C_BLD=''; C_OFF=''
fi

info()  { printf '%s[i]%s %s\n' "$C_BLU" "$C_OFF" "$*"; }
warn()  { printf '%s[!]%s %s\n' "$C_YLW" "$C_OFF" "$*" >&2; }
die()   { printf '%s[x]%s %s\n' "$C_RED" "$C_OFF" "$*" >&2; exit 1; }
ok()    { printf '  %s✔%s %s\n' "$C_GRN" "$C_OFF" "$*"; PASS=$((PASS + 1)); }
ko()    { printf '  %s✘%s %s\n' "$C_RED" "$C_OFF" "$*"; FAIL=$((FAIL + 1)); }
# skip "description" : vérification impossible dans cet environnement (ni réussite ni échec)
skip()  { printf '  %s⊘%s %s %s(ignoré : non supporté ici)%s\n' "$C_YLW" "$C_OFF" "$*" "$C_YLW" "$C_OFF"; SKIPPED=$((SKIPPED + 1)); }

# assert "description" commande [args...]  → ✔ si la commande retourne 0
assert() {
  local desc=$1; shift
  if "$@" >/dev/null 2>&1; then ok "$desc"; else ko "$desc"; fi
}

# assert_eq "description" attendu obtenu
assert_eq() {
  if [[ "$2" == "$3" ]]; then ok "$1"; else ko "$1 (attendu: '$2', obtenu: '$3')"; fi
}

# assert_grep "description" regex fichier
assert_grep() {
  if [[ -f "$3" ]] && grep -Eq -- "$2" "$3"; then ok "$1"; else ko "$1"; fi
}

# assert_mode "description" mode_octal chemin  (ex: 640)
assert_mode() {
  local got; got=$(stat -c '%a' -- "$3" 2>/dev/null || echo "absent")
  assert_eq "$1" "$2" "$got"
}

# Exécute en root (direct si déjà root, sinon via sudo)
as_root() {
  if [[ $EUID -eq 0 ]]; then "$@"; else sudo "$@"; fi
}

# requires root|systemd|docker|net ... — sort avec le code 77 (« skipped ») si absent
requires() {
  local r
  for r in "$@"; do
    case $r in
      root)    [[ $EUID -eq 0 ]] || sudo -n true 2>/dev/null || { warn "Ce labo nécessite root/sudo"; exit 77; } ;;
      systemd) [[ -d /run/systemd/system ]] || { warn "Ce labo nécessite systemd (PID 1) — utilisez la VM Vagrant ou le conteneur 'lab'"; exit 77; } ;;
      loop)    as_root losetup -f >/dev/null 2>&1 || { warn "Ce labo nécessite les périphériques loop (conteneur --privileged ou VM)"; exit 77; } ;;
      netns)   as_root ip netns add __lab_probe >/dev/null 2>&1 && as_root ip netns del __lab_probe >/dev/null 2>&1 || { warn "Ce labo nécessite les network namespaces (root + CAP_NET_ADMIN : conteneur --privileged ou VM)"; exit 77; } ;;
      cmd:*)   command -v "${r#cmd:}" >/dev/null 2>&1 || { warn "Commande requise absente : ${r#cmd:}"; exit 77; } ;;
      *)       warn "requires: inconnu '$r'" ;;
    esac
  done
}

summary() {
  local total=$((PASS + FAIL))
  echo
  if [[ $FAIL -eq 0 ]]; then
    printf '%sRésultat : %d/%d — labo réussi 🎉%s' "$C_GRN$C_BLD" "$PASS" "$total" "$C_OFF"
    [[ $SKIPPED -eq 0 ]] || printf ' %s(%d vérification(s) ignorée(s) : prérequis noyau absents)%s' "$C_YLW" "$SKIPPED" "$C_OFF"
    echo
    return 0
  fi
  printf '%sRésultat : %d/%d — %d point(s) à corriger.%s\n' "$C_RED$C_BLD" "$PASS" "$total" "$FAIL" "$C_OFF"
  return 1
}

# Point d'entrée commun : lab_main <action>
lab_main() {
  local action=${1:-help}
  [[ -n "${LAB_ID:-}" ]] || die "LAB_ID non défini"
  LAB_DIR="$LAB_ROOT/$LAB_ID"
  case $action in
    setup)
      [[ -z "${LAB_REQUIRES[*]:-}" ]] || requires "${LAB_REQUIRES[@]}"
      mkdir -p "$LAB_DIR"
      info "Préparation du labo $LAB_ID dans $LAB_DIR"
      lab_setup
      info "Prêt. Lisez l'énoncé : modules/$(basename "$(dirname "${BASH_SOURCE[1]}")")/LAB.md"
      ;;
    check)
      [[ -z "${LAB_REQUIRES[*]:-}" ]] || requires "${LAB_REQUIRES[@]}"
      [[ -d "$LAB_DIR" ]] || die "Labo non initialisé : lancez d'abord './lab setup $LAB_ID'"
      printf '%sVérification du labo %s%s\n' "$C_BLD" "$LAB_ID" "$C_OFF"
      lab_check
      summary
      ;;
    solve)
      [[ -z "${LAB_REQUIRES[*]:-}" ]] || requires "${LAB_REQUIRES[@]}"
      [[ -d "$LAB_DIR" ]] || die "Labo non initialisé : lancez d'abord './lab setup $LAB_ID'"
      info "Application de la solution de référence (à utiliser pour comparer, pas pour tricher 😉)"
      lab_solve
      ;;
    reset)
      if declare -F lab_cleanup >/dev/null; then lab_cleanup || true; fi
      rm -rf "$LAB_DIR"
      info "Labo $LAB_ID réinitialisé."
      ;;
    *) echo "Usage: $0 {setup|check|solve|reset}"; exit 2 ;;
  esac
}
