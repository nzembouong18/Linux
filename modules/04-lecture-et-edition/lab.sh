#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/lib.sh"
LAB_ID=04

lab_setup() {
  cd "$LAB_DIR" || return 1
  local i lvl
  : > server.log
  for i in $(seq 1 120); do
    case $((i % 7)) in 0) lvl=ERROR ;; 3|5) lvl=WARN ;; *) lvl=INFO ;; esac
    printf '2024-03-01 10:%02d:%02d %-5s request id=%03d handled\n' $((i / 60)) $((i % 60)) "$lvl" "$i" >> server.log
  done
  cat > config.ini <<'EOF'
[server]
host=0.0.0.0
port=80
debug=true

[database]
user=app
password=changeme
EOF
  cat > poeme.txt <<'EOF'
La nuit tombe sur la ville endormie,
Les lampadaires murmurent à la pluie.
Dans le silence, une nuit de plus,
Le monde respire, doux et menu.
EOF
}

lab_check() {
  cd "$LAB_DIR" || return 1
  assert "premieres.txt = head -5" cmp -s premieres.txt <(head -n 5 server.log)
  assert "dernieres.txt = tail -3" cmp -s dernieres.txt <(tail -n 3 server.log)
  assert "extrait.txt = lignes 10-14" cmp -s extrait.txt <(sed -n '10,14p' server.log)
  assert_eq "stats LIGNES" "$(wc -l < poeme.txt)" "$(grep -E '^LIGNES=' stats.txt 2>/dev/null | cut -d= -f2)"
  assert_eq "stats MOTS" "$(wc -w < poeme.txt)" "$(grep -E '^MOTS=' stats.txt 2>/dev/null | cut -d= -f2)"
  assert_eq "stats OCTETS" "$(wc -c < poeme.txt)" "$(grep -E '^OCTETS=' stats.txt 2>/dev/null | cut -d= -f2)"
  assert_grep "port=8080" '^port=8080$' config.ini
  assert_grep "debug=false" '^debug=false$' config.ini
  assert_grep "host commenté" '^#host=0\.0\.0\.0' config.ini
  assert "aucune ligne host= active" test -z "$(grep -E '^host=' config.ini)"
  assert "section [cache] avec ttl=300 en fin" bash -c "tail -n 3 config.ini | grep -q '^\[cache\]' && tail -n 2 config.ini | grep -q '^ttl=300$'"
  assert "section [database] préservée" grep -q '^password=changeme' config.ini
}

lab_solve() {
  cd "$LAB_DIR" || return 1
  head -n 5 server.log > premieres.txt
  tail -n 3 server.log > dernieres.txt
  sed -n '10,14p' server.log > extrait.txt
  { echo "LIGNES=$(wc -l < poeme.txt)"; echo "MOTS=$(wc -w < poeme.txt)"; echo "OCTETS=$(wc -c < poeme.txt)"; } > stats.txt
  sed -i -e 's/^port=.*/port=8080/' -e 's/^debug=.*/debug=false/' -e 's/^host=/#host=/' config.ini
  printf '\n[cache]\nttl=300\n' >> config.ini
}

lab_main "$@"
