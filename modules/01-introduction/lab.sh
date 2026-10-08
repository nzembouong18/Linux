#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/lib.sh"
LAB_ID=01

lab_setup() {
  cat > "$LAB_DIR/CONSIGNES.txt" <<'TXT'
Créez rapport.txt (8 lignes CLÉ=valeur) et aide.txt.
Voir modules/01-introduction/LAB.md
TXT
}

lab_check() {
  local r="$LAB_DIR/rapport.txt"
  get() { grep -E "^$1=" "$r" 2>/dev/null | head -1 | cut -d= -f2-; }
  assert "rapport.txt existe" test -f "$r"
  assert_eq "HOSTNAME correct" "$(hostname)" "$(get HOSTNAME)"
  assert_eq "USER correct" "$(whoami)" "$(get USER)"
  assert_eq "KERNEL correct" "$(uname -r)" "$(get KERNEL)"
  assert_eq "ARCH correct" "$(uname -m)" "$(get ARCH)"
  assert_eq "DISTRO correct" "$(. /etc/os-release; echo "$PRETTY_NAME")" "$(get DISTRO)"
  assert_eq "CPUS correct" "$(nproc)" "$(get CPUS)"
  assert_eq "HOME_DIR correct" "$HOME" "$(get HOME_DIR)"
  local real got; real=$(free -m | awk '/^Mem:/{print $2}'); got=$(get MEM_MB)
  if [[ "$got" =~ ^[0-9]+$ ]] && (( got * 100 >= real * 95 && got * 100 <= real * 105 )); then
    ok "MEM_MB cohérent (±5 %)"; else ko "MEM_MB incohérent (réel ≈ ${real})"; fi
  assert_grep "aide.txt mentionne tar" '(^|[^a-z])tar([^a-z]|$)' "$LAB_DIR/aide.txt"
}

lab_solve() {
  cd "$LAB_DIR" || return 1
  {
    echo "HOSTNAME=$(hostname)"; echo "USER=$(whoami)"; echo "KERNEL=$(uname -r)"
    echo "ARCH=$(uname -m)"; echo "DISTRO=$(. /etc/os-release; echo "$PRETTY_NAME")"
    echo "CPUS=$(nproc)"; echo "MEM_MB=$(free -m | awk '/^Mem:/{print $2}')"; echo "HOME_DIR=$HOME"
  } > rapport.txt
  echo "tar - an archiving utility" > aide.txt
}

lab_main "$@"
