#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/lib.sh"
LAB_ID=15
LAB_REQUIRES=(cmd:tar cmd:rsync cmd:logrotate cmd:xz cmd:bzip2 cmd:gzip)

lab_setup() {
  cd "$LAB_DIR" || return 1
  rm -rf donnees journal restauration archive.tar.gz ./*.txt app.logrotate sauvegarde-rsync.sh sauvegardes
  mkdir -p donnees/docs/rapports donnees/cache journal
  echo "Compte rendu A" > donnees/docs/a.txt
  echo "Compte rendu B" > donnees/docs/b.txt
  echo "brouillon" > donnees/docs/notes.tmp
  head -c 3000 /dev/urandom > donnees/docs/rapports/r1.pdf
  echo "id,nom" > donnees/data.csv; seq 1 200 | sed 's/.*/&,client&/' >> donnees/data.csv
  echo "token=abc" > donnees/.config
  echo "x" > donnees/tmp-1.tmp
  head -c 5000 /dev/urandom > donnees/cache/x.dat
  head -c 5000 /dev/urandom > donnees/cache/y.dat
  # journal volumineux et compressible
  local i
  for i in $(seq 1 5000); do
    printf '2024-03-12 10:%02d:%02d INFO request id=%05d user=u%d path=/api/v1/items/%d status=200\n' $((i / 3600 % 60)) $((i % 60)) "$i" $((i % 37)) $((i % 101))
  done > journal/app.log
}

sha_expected() { (cd "$LAB_DIR" && find restauration -type f -print0 | sort -z | xargs -0 sha256sum); }

lab_check() {
  cd "$LAB_DIR" || return 1
  local A=archive.tar.gz
  # ---- A
  assert "A1 archive.tar.gz valide" tar -tzf $A
  assert "A1 chemins relatifs sous donnees/ uniquement" bash -c "! tar -tzf $A | grep -qv '^donnees/'"
  assert "A1 inclut docs/a.txt, data.csv et le fichier caché .config" bash -c "tar -tzf $A | grep -qx 'donnees/docs/a.txt' && tar -tzf $A | grep -qx 'donnees/data.csv' && tar -tzf $A | grep -qx 'donnees/.config'"
  assert "A1 aucun .tmp" bash -c "! tar -tzf $A | grep -q '\.tmp$'"
  assert "A1 dossier cache exclu" bash -c "! tar -tzf $A | grep -q 'cache'"
  local s; s() { grep -E "^$1=" stats.txt 2>/dev/null | cut -d= -f2; }
  assert_eq "A2 NB_FICHIERS" "$(tar -tzf $A 2>/dev/null | grep -vc '/$')" "$(s NB_FICHIERS)"
  assert_eq "A2 TAILLE_ARCHIVE" "$(stat -c %s $A 2>/dev/null)" "$(s TAILLE_ARCHIVE)"
  assert "A3 restauration identique à donnees (hors exclusions)" diff -r -x '*.tmp' -x cache donnees restauration/donnees
  assert "A3 donnees/ intact (cache et .tmp toujours présents)" bash -c "test -f donnees/notes.tmp -o -f donnees/docs/notes.tmp && test -d donnees/cache"
  assert "A4 sha256sum.txt = empreintes des fichiers restaurés" cmp -s <(sort sha256sum.txt 2>/dev/null) <(sha_expected | sort)

  # ---- B
  assert "B5 app.log.gz décompresse en l'original" bash -c "gzip -dc journal/app.log.gz | cmp -s - journal/app.log"
  assert "B5 app.log.bz2 décompresse en l'original" bash -c "bzip2 -dc journal/app.log.bz2 | cmp -s - journal/app.log"
  assert "B5 app.log.xz décompresse en l'original" bash -c "xz -dc journal/app.log.xz | cmp -s - journal/app.log"
  assert "B5 l'original est conservé" test -s journal/app.log
  local c; c() { grep -E "^$1=" compare.txt 2>/dev/null | cut -d= -f2; }
  local best; best=$(ls -S journal/app.log.gz journal/app.log.bz2 journal/app.log.xz 2>/dev/null | tail -1); best=${best##*.}
  assert_eq "B6 ORIGINAL_OCTETS" "$(stat -c %s journal/app.log)" "$(c ORIGINAL_OCTETS)"
  assert_eq "B6 MEILLEUR" "$best" "$(c MEILLEUR)"

  # ---- C
  local conf=app.logrotate me grp; me=$(id -un); grp=$(id -gn)
  assert "C7 cible le journal (chemin absolu)" grep -qF "$LAB_DIR/journal/app.log" $conf
  for d in daily 'rotate 7' compress delaycompress missingok notifempty; do
    assert "C7 directive « $d »" grep -Eq "^[[:space:]]*${d}[[:space:]]*$" $conf
  done
  assert "C7 create 0640 $me $grp" grep -Eq "^[[:space:]]*create[[:space:]]+0?640[[:space:]]+${me}[[:space:]]+${grp}" $conf
  local dbg; dbg=$(logrotate -d -s "$LAB_DIR/.state-check" $conf 2>&1); rm -f "$LAB_DIR/.state-check"
  dbg_ok() { grep -F "rotating pattern: $LAB_DIR/journal/app.log" <<<"$dbg" | grep -Eq 'after 1 days \(7 rotations\)'; }
  assert "C7 logrotate -d : configuration acceptée et motif reconnu (1 jour, 7 rotations)" dbg_ok
  # rotation réelle sur une COPIE (non destructif)
  local t; t=$(mktemp -d); cp journal/app.log "$t/app.log"
  sed "s#$LAB_DIR/journal/app.log#$t/app.log#" $conf > "$t/conf"; chmod 644 "$t/conf"
  logrotate -f -s "$t/state" "$t/conf" >/dev/null 2>&1
  assert "C7 rotation forcée : app.log.1 créé, nouveau app.log vide en 640" bash -c "test -s '$t/app.log.1' && test ! -s '$t/app.log' && [[ \$(stat -c %a '$t/app.log') == 640 ]]"
  rm -rf "$t"

  # ---- D
  local sc=./sauvegarde-rsync.sh
  assert "D8 script exécutable avec shebang" bash -c "test -x $sc && head -1 $sc | grep -q '^#!.*bash'"
  local f="$LAB_DIR/.fixture"; rm -rf "$f"; mkdir -p "$f/src/dir"
  echo "inchange" > "$f/src/a.txt"; echo "version1" > "$f/src/b.txt"; echo "supprime" > "$f/src/c.txt"; echo "sous" > "$f/src/dir/d.txt"
  $sc "$f/src" "$f/dest" snap1 >/dev/null 2>&1; local rc1=$?
  echo "version 2 modifiee" > "$f/src/b.txt"; rm "$f/src/c.txt"; echo "nouveau" > "$f/src/e.txt"
  local out; out=$($sc "$f/src" "$f/dest" snap2 2>/dev/null); local rc2=$?
  assert_eq "D8 deux exécutions réussies (rc 0)" "0:0" "$rc1:$rc2"
  assert_eq "D8 affiche le chemin de la sauvegarde" "$f/dest/snap2" "$out"
  assert "D8 snap1 conserve l'ancien état (c.txt, b.txt v1)" bash -c "test -f '$f/dest/snap1/c.txt' && grep -q version1 '$f/dest/snap1/b.txt'"
  assert "D8 snap2 reflète la source (c.txt absent, e.txt présent, b.txt v2)" bash -c "test ! -e '$f/dest/snap2/c.txt' && test -f '$f/dest/snap2/e.txt' && grep -q 'version 2' '$f/dest/snap2/b.txt'"
  assert "D8 fichier inchangé = lien dur entre snap1 et snap2" bash -c "[[ \$(stat -c %i '$f/dest/snap1/a.txt') == \$(stat -c %i '$f/dest/snap2/a.txt') ]]"
  assert "D8 sous-dossier inchangé aussi (lien dur)" bash -c "[[ \$(stat -c %i '$f/dest/snap1/dir/d.txt') == \$(stat -c %i '$f/dest/snap2/dir/d.txt') ]]"
  assert "D8 fichier modifié = nouvel inode" bash -c "[[ \$(stat -c %i '$f/dest/snap1/b.txt') != \$(stat -c %i '$f/dest/snap2/b.txt') ]]"
  assert_eq "D8 latest → snap2" "snap2" "$(readlink "$f/dest/latest")"
  $sc "$f/src" "$f/dest" snap2 >/dev/null 2>&1; assert_eq "D8 NOM existant → rc 4" "4" "$?"
  $sc /dossier/absent "$f/dest" snap9 >/dev/null 2>&1; assert_eq "D8 source absente → rc 3" "3" "$?"
  $sc >/dev/null 2>&1; assert_eq "D8 sans argument → rc 1" "1" "$?"
  rm -rf "$f"

  # ---- E
  local r; r() { grep -E "^$1=" reponses.txt 2>/dev/null | cut -d= -f2 | tr -d ' '; }
  assert_eq "E9 COPIES" 3 "$(r COPIES)"
  assert_eq "E9 SUPPORTS" 2 "$(r SUPPORTS)"
  assert_eq "E9 HORS_SITE" 1 "$(r HORS_SITE)"
  assert_eq "E9 PERTE_MAX" RPO "$(r PERTE_MAX | tr a-z A-Z)"
  assert_eq "E9 DUREE_REPRISE" RTO "$(r DUREE_REPRISE | tr a-z A-Z)"
}

lab_solve() {
  cd "$LAB_DIR" || return 1
  tar -czf archive.tar.gz --exclude='*.tmp' --exclude='cache' donnees
  { echo "NB_FICHIERS=$(tar -tzf archive.tar.gz | grep -vc '/$')"; echo "TAILLE_ARCHIVE=$(stat -c %s archive.tar.gz)"; } > stats.txt
  mkdir -p restauration && tar -xzf archive.tar.gz -C restauration
  find restauration -type f -print0 | sort -z | xargs -0 sha256sum > sha256sum.txt
  gzip -k -9 journal/app.log; bzip2 -k -9 journal/app.log; xz -k -9 journal/app.log
  local best; best=$(ls -S journal/app.log.gz journal/app.log.bz2 journal/app.log.xz | tail -1)
  { echo "ORIGINAL_OCTETS=$(stat -c %s journal/app.log)"; echo "MEILLEUR=${best##*.}"; } > compare.txt
  cat > app.logrotate <<EOF
$PWD/journal/app.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0640 $(id -un) $(id -gn)
}
EOF
  cat > sauvegarde-rsync.sh <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
[[ $# -eq 3 ]] || { echo "Usage: $0 SRC DESTDIR NOM" >&2; exit 1; }
src=$1 dest=$2 name=$3
[[ -d $src ]] || { echo "Source absente: $src" >&2; exit 3; }
[[ ! -e $dest/$name ]] || { echo "Existe déjà: $dest/$name" >&2; exit 4; }
mkdir -p "$dest"
link=()
[[ -e $dest/latest ]] && link=(--link-dest="$(readlink -f "$dest/latest")")
rsync -a --delete "${link[@]}" "$src"/ "$dest/$name"/
ln -sfn "$name" "$dest/latest"
echo "$dest/$name"
EOS
  chmod +x sauvegarde-rsync.sh
  printf 'COPIES=3\nSUPPORTS=2\nHORS_SITE=1\nPERTE_MAX=RPO\nDUREE_REPRISE=RTO\n' > reponses.txt
}

lab_main "$@"
