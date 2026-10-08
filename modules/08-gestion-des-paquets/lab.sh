#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/lib.sh"
LAB_ID=08
LAB_REQUIRES=(root cmd:dpkg-deb cmd:apt-mark)

lab_cleanup() {
  apt-mark showhold 2>/dev/null | grep -qx monpaquet && as_root apt-mark unhold monpaquet >/dev/null 2>&1
  dpkg -s monpaquet >/dev/null 2>&1 && as_root dpkg -P monpaquet >/dev/null 2>&1
  return 0
}

lab_setup() {
  cd "$LAB_DIR" || return 1
  lab_cleanup
  rm -rf monpaquet ./*.deb info.txt fichiers.txt proprietaire.txt systeme.txt
  mkdir -p monpaquet/DEBIAN monpaquet/usr/local/bin
  cat > monpaquet/DEBIAN/control <<'EOF'
Package: monpaquet
Version: 1.0
Section: utils
Priority: optional
Architecture: all
Maintainer: Formation Linux <formation@example.org>
Description: Outil de demonstration du labo 08
 Affiche un message de bienvenue.
EOF
  cat > monpaquet/usr/local/bin/bonjour <<'EOF'
#!/bin/sh
echo "Bonjour depuis monpaquet"
EOF
  chmod 755 monpaquet/usr/local/bin/bonjour
}

lab_check() {
  cd "$LAB_DIR" || return 1
  assert "monpaquet_1.0_all.deb construit" test -f monpaquet_1.0_all.deb
  assert "monpaquet_1.1_all.deb construit" test -f monpaquet_1.1_all.deb
  assert "le .deb 1.0 est valide" dpkg-deb -I monpaquet_1.0_all.deb
  assert "fichiers du .deb appartiennent à root" bash -c "dpkg-deb -c monpaquet_1.1_all.deb | grep 'bonjour' | grep -q 'root/root'"
  assert_grep "info.txt : Package" '^Package: monpaquet$' info.txt
  assert_grep "info.txt : Version" '^Version: 1\.0$' info.txt
  assert_eq "paquet installé en version 1.1" "1.1" "$(dpkg-query -W -f='${Version}' monpaquet 2>/dev/null)"
  assert "paquet dans l'état installé (ii)" bash -c "dpkg -s monpaquet | grep -q '^Status: .* installed'"
  assert "bonjour fonctionne et affiche la version 1.1" bash -c "bonjour | grep -q 'version 1.1'"
  assert_grep "fichiers.txt liste /usr/local/bin/bonjour" '^/usr/local/bin/bonjour$' fichiers.txt
  assert_eq "proprietaire.txt" "monpaquet" "$(tr -d ' \n' < proprietaire.txt 2>/dev/null)"
  assert "paquet verrouillé (hold)" bash -c "apt-mark showhold | grep -qx monpaquet"
  assert_eq "BASH_PKG" "$(dpkg-query -W -f='${Version}' bash)" "$(grep '^BASH_PKG=' systeme.txt 2>/dev/null | cut -d= -f2-)"
}

lab_solve() {
  cd "$LAB_DIR" || return 1
  dpkg-deb --build --root-owner-group monpaquet monpaquet_1.0_all.deb >/dev/null
  dpkg-deb -I monpaquet_1.0_all.deb | grep -E '^ *(Package|Version):' | sed 's/^ *//' > info.txt
  as_root dpkg -i monpaquet_1.0_all.deb >/dev/null
  dpkg -L monpaquet > fichiers.txt
  dpkg -S /usr/local/bin/bonjour | cut -d: -f1 > proprietaire.txt
  sed -i 's/^Version: .*/Version: 1.1/' monpaquet/DEBIAN/control
  echo 'echo "version 1.1"' >> monpaquet/usr/local/bin/bonjour
  dpkg-deb --build --root-owner-group monpaquet monpaquet_1.1_all.deb >/dev/null
  as_root dpkg -i monpaquet_1.1_all.deb >/dev/null
  as_root apt-mark hold monpaquet >/dev/null
  echo "BASH_PKG=$(dpkg-query -W -f='${Version}' bash)" > systeme.txt
}

lab_main "$@"
