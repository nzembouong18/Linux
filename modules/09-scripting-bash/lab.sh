#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/lib.sh"
LAB_ID=09

lab_setup() {
  cd "$LAB_DIR" || return 1
  cp "$(dirname "${BASH_SOURCE[0]}")/LAB.md" CAHIER_DES_CHARGES.md
}

# Exécute un script et capture stdout / stderr / code retour
run_script() { # run_script <script> [args...] → variables OUT ERR RC
  local s=$1; shift
  OUT=$(timeout 10 "./$s" "$@" 2>"$LAB_DIR/.err"); RC=$?
  ERR=$(cat "$LAB_DIR/.err")
}

lab_check() {
  cd "$LAB_DIR" || return 1
  local s
  for s in salut parite somme compte-ext sauvegarde; do
    assert "$s.sh : exécutable, shebang, syntaxe valide" bash -c "test -x $s.sh && head -1 $s.sh | grep -q '^#!.*bash' && bash -n $s.sh"
  done

  run_script salut.sh Alice;               assert_eq "salut : Alice"        "Bonjour Alice !" "$OUT"
  run_script salut.sh "Alice Dupont";      assert_eq "salut : nom composé"  "Bonjour Alice Dupont !" "$OUT"
  run_script salut.sh;                     assert_eq "salut : sans arg → rc 1" "1" "$RC"
  assert "salut : usage sur stderr, rien sur stdout" test -n "$ERR" -a -z "$OUT"

  run_script parite.sh 7;   assert_eq "parite 7" "7 est impair" "$OUT"
  run_script parite.sh 10;  assert_eq "parite 10" "10 est pair" "$OUT"
  run_script parite.sh 0;   assert_eq "parite 0" "0 est pair" "$OUT"
  run_script parite.sh -4;  assert_eq "parite -4" "-4 est pair" "$OUT"
  run_script parite.sh -3;  assert_eq "parite -3" "-3 est impair" "$OUT"
  run_script parite.sh abc; assert_eq "parite abc → rc 2" "2" "$RC"
  run_script parite.sh 3.5; assert_eq "parite 3.5 → rc 2" "2" "$RC"
  assert "parite : erreur sur stderr" test -n "$ERR"

  run_script somme.sh 1 2 3;  assert_eq "somme 1 2 3" "6" "$OUT"
  run_script somme.sh;        assert_eq "somme sans arg" "0" "$OUT"
  run_script somme.sh -5 10;  assert_eq "somme -5 10" "5" "$OUT"

  local f="$LAB_DIR/jeu-essai"
  rm -rf "$f"; mkdir -p "$f/sousdossier"; touch "$f"/{a.txt,b.txt,c.log,Makefile,README} "$f/sousdossier/x.txt" "$f/archive.tar.gz"
  run_script compte-ext.sh "$f"
  local want got
  want=$(printf '(aucune): 2\nlog: 1\ngz: 1\ntxt: 2\n' | sort)
  got=$(echo "$OUT" | sed 's/ *$//' | sort)
  assert_eq "compte-ext : comptage correct" "$want" "$got"
  run_script compte-ext.sh /dossier/inexistant; assert_eq "compte-ext : dossier absent → rc 3" "3" "$RC"

  local src="$LAB_DIR/jeu-src" dst="$LAB_DIR/jeu-dst"
  rm -rf "$src" "$dst"; mkdir -p "$src"; echo data > "$src/fichier un.txt"
  run_script sauvegarde.sh "$src" "$dst"
  local arch; arch="$dst/backup-$(date +%Y%m%d).tar.gz"
  assert_eq "sauvegarde : stdout = chemin de l'archive" "$arch" "$OUT"
  assert "sauvegarde : archive contient le fichier (nom avec espace)" bash -c "tar -tzf '$arch' | grep -q 'fichier un.txt'"
  run_script sauvegarde.sh;                       assert_eq "sauvegarde : sans arg → rc 1" "1" "$RC"
  run_script sauvegarde.sh /dossier/absent "$LAB_DIR/jeu-dst2"; assert_eq "sauvegarde : source absente → rc 3" "3" "$RC"
  assert "sauvegarde : aucune archive créée si source absente" bash -c "! ls '$LAB_DIR/jeu-dst2'/backup-*.tar.gz 2>/dev/null"
  assert_grep "sauvegarde : contient set -e" 'set +-[A-Za-z]*e' sauvegarde.sh
  rm -rf "$f" "$src" "$dst" "$LAB_DIR/jeu-dst2" "$LAB_DIR/.err"
}

lab_solve() {
  cd "$LAB_DIR" || return 1
  cat > salut.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ $# -ge 1 ]] || { echo "Usage: salut.sh NOM" >&2; exit 1; }
echo "Bonjour $* !"
EOF
  cat > parite.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
n=${1:-}
if [[ ! $n =~ ^-?[0-9]+$ ]]; then echo "Erreur: '$n' n'est pas un entier" >&2; exit 2; fi
if (( n % 2 == 0 )); then echo "$n est pair"; else echo "$n est impair"; fi
EOF
  cat > somme.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
total=0
for n in "$@"; do total=$((total + n)); done
echo "$total"
EOF
  cat > compte-ext.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
dir=${1:?Usage: compte-ext.sh DOSSIER}
[[ -d $dir ]] || { echo "Dossier introuvable: $dir" >&2; exit 3; }
declare -A n=()
shopt -s dotglob nullglob
for f in "$dir"/*; do
  [[ -f $f ]] || continue
  name=${f##*/}
  if [[ $name == *.* && $name != .* ]]; then ext=${name##*.}; elif [[ $name == .*.* ]]; then ext=${name##*.}; else ext="(aucune)"; fi
  n[$ext]=$(( ${n[$ext]:-0} + 1 ))
done
for ext in "${!n[@]}"; do echo "$ext: ${n[$ext]}"; done
EOF
  cat > sauvegarde.sh <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
[[ $# -eq 2 ]] || { echo "Usage: sauvegarde.sh SOURCE DESTINATION" >&2; exit 1; }
src=$1 dest=$2
[[ -d $src ]] || { echo "Source introuvable: $src" >&2; exit 3; }
mkdir -p "$dest"
archive="$dest/backup-$(date +%Y%m%d).tar.gz"
tar -czf "$archive" -C "$(dirname "$src")" "$(basename "$src")"
echo "$archive"
EOF
  chmod +x salut.sh parite.sh somme.sh compte-ext.sh sauvegarde.sh
}

lab_main "$@"
