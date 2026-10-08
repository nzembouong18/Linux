#!/usr/bin/env bash
# =============================================================================
# demo-lib.sh — mini moteur de démonstration « live » pour le formateur
#   demo_title "Titre"        bandeau de section
#   demo_say   "Texte"        commentaire du formateur
#   demo_run   "commande"     affiche la commande (effet « frappe »), l'exécute
#   demo_show  "commande"     affiche seulement (commande dangereuse/non rejouable)
# Variables : DEMO_FAST=1 (aucune pause, pour la CI) · DEMO_SPEED=0.03 (délai/car.)
# Enregistrement : asciinema rec -c "./lab demo 05" demo05.cast
# =============================================================================

DEMO_FAST="${DEMO_FAST:-0}"
DEMO_SPEED="${DEMO_SPEED:-0.025}"
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  D_CYN=$'\e[36m'; D_GRN=$'\e[32m'; D_YLW=$'\e[33m'; D_BLD=$'\e[1m'; D_OFF=$'\e[0m'
else
  D_CYN=''; D_GRN=''; D_YLW=''; D_BLD=''; D_OFF=''
fi

DEMO_DIR="$(mktemp -d "${TMPDIR:-/tmp}/demo.XXXXXX")"
trap 'cd /; rm -rf "$DEMO_DIR"' EXIT
cd "$DEMO_DIR" || exit 1

_pause() { [[ "$DEMO_FAST" == 1 ]] || { [[ -t 0 ]] && read -r -p "${D_YLW}⏎ Entrée…${D_OFF}" _ </dev/tty || sleep 1; }; }

_type() {
  local s=$1 i
  if [[ "$DEMO_FAST" == 1 ]]; then printf '%s' "$s"; return; fi
  for ((i = 0; i < ${#s}; i++)); do printf '%s' "${s:i:1}"; sleep "$DEMO_SPEED"; done
}

demo_title() { printf '\n%s━━━ %s ━━━%s\n' "$D_BLD$D_CYN" "$*" "$D_OFF"; }
demo_say()   { printf '%s# %s%s\n' "$D_GRN" "$*" "$D_OFF"; [[ "$DEMO_FAST" == 1 ]] || sleep 0.6; }
demo_show()  { printf '%s$ %s' "$D_BLD" "$D_OFF"; _type "$1"; printf '   %s(non exécuté dans la démo)%s\n' "$D_YLW" "$D_OFF"; }
demo_run() {
  printf '%s$ %s' "$D_BLD" "$D_OFF"; _type "$1"; echo
  _pause
  # (exit N) restaure $? de la commande précédente pour que « echo $? » reste fidèle
  eval "(exit ${DEMO_RC:-0}); $1"
  DEMO_RC=$?
  [[ $DEMO_RC -eq 0 ]] || printf '%s(code retour %d)%s\n' "$D_YLW" "$DEMO_RC" "$D_OFF"
  return 0
}
demo_end() { printf '\n%s✔ Fin de la démo.%s\n' "$D_GRN$D_BLD" "$D_OFF"; }
