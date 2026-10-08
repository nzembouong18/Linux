#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/lib.sh"
LAB_ID=06
LAB_REQUIRES=(root cmd:setfacl)

lab_setup() {
  cd "$LAB_DIR" || return 1
  mkdir -p projet depot
  echo "Plan du projet" > projet/plan.txt
  printf '#!/bin/sh\necho "outil exécuté par $(id -un)"\n' > outil.sh
  # les comptes lab_* doivent pouvoir traverser le chemin du labo
  local p="$LAB_DIR"
  while [[ "$p" != "/" ]]; do as_root chmod o+x "$p" 2>/dev/null || true; p=$(dirname "$p"); done
}

lab_cleanup() {
  local u
  for u in lab_alice lab_bob lab_carol; do id "$u" &>/dev/null && as_root userdel -rf "$u" 2>/dev/null; done
  getent group lab_equipe >/dev/null && as_root groupdel lab_equipe 2>/dev/null
  return 0
}

lab_check() {
  cd "$LAB_DIR" || return 1
  assert "groupe lab_equipe existe" getent group lab_equipe
  for u in lab_alice lab_bob; do
    assert "$u existe, shell bash, HOME créé" bash -c "[[ \$(getent passwd $u | cut -d: -f7) == /bin/bash ]] && [[ -d \$(getent passwd $u | cut -d: -f6) ]]"
    assert "$u membre (secondaire) de lab_equipe" bash -c "id -nG $u | tr ' ' '\n' | grep -qx lab_equipe"
  done
  assert "lab_carol existe" id lab_carol
  assert "lab_carol N'est PAS dans lab_equipe" bash -c "! id -nG lab_carol | tr ' ' '\n' | grep -qx lab_equipe"
  assert_eq "projet/ propriétaire:groupe" "lab_alice:lab_equipe" "$(stat -c %U:%G projet 2>/dev/null)"
  assert_mode "projet/ en 2770 (setgid)" 2770 projet
  assert_eq "plan.txt propriétaire:groupe" "lab_alice:lab_equipe" "$(as_root stat -c %U:%G projet/plan.txt 2>/dev/null)"
  assert_eq "plan.txt en 660" 660 "$(as_root stat -c %a projet/plan.txt 2>/dev/null || echo absent)"
  assert_eq "notes.txt créé par lab_bob" "lab_bob" "$(as_root stat -c %U projet/notes.txt 2>/dev/null)"
  assert_eq "notes.txt hérite du groupe lab_equipe" "lab_equipe" "$(as_root stat -c %G projet/notes.txt 2>/dev/null)"
  assert_eq "outil.sh propriétaire:groupe" "lab_alice:lab_equipe" "$(stat -c %U:%G outil.sh 2>/dev/null)"
  assert_mode "outil.sh en 750" 750 outil.sh
  assert_mode "depot/ en 1777 (sticky)" 1777 depot
  assert "ACL : carol lit plan.txt" as_root runuser -u lab_carol -- cat projet/plan.txt
  assert "ACL : carol liste projet/" as_root runuser -u lab_carol -- ls projet
  carol_ne_peut_pas_ecrire() { ! as_root runuser -u lab_carol -- sh -c 'echo x >> projet/plan.txt' 2>/dev/null; }
  bob_verrouille() { as_root passwd -S lab_bob | awk '{print $2}' | grep -qx L; }
  alice_90j() { as_root env LC_ALL=C chage -l lab_alice | grep -i 'maximum' | grep -q 90; }
  assert "ACL : carol ne peut PAS écrire dans plan.txt" carol_ne_peut_pas_ecrire
  acl_carol() { as_root getfacl -p projet/plan.txt 2>/dev/null | grep -q '^user:lab_carol:r--'; }
  assert "ACL explicite pour lab_carol sur plan.txt" acl_carol
  assert "lab_bob verrouillé" bob_verrouille
  assert "lab_alice : expiration max 90 jours" alice_90j
  local r="reponses.txt"; get() { grep -E "^$1=" "$r" 2>/dev/null | head -1 | cut -d= -f2-; }
  assert_eq "UID_ALICE" "$(id -u lab_alice 2>/dev/null)" "$(get UID_ALICE)"
  assert_eq "GROUPES_ALICE" "$(id -nG lab_alice 2>/dev/null | tr ' ' '\n' | sort | tr '\n' ' ' | sed 's/ $//')" "$(get GROUPES_ALICE)"
}

lab_solve() {
  cd "$LAB_DIR" || return 1
  as_root groupadd lab_equipe
  as_root useradd -m -s /bin/bash -G lab_equipe lab_alice
  as_root useradd -m -s /bin/bash -G lab_equipe lab_bob
  as_root useradd -m -s /bin/bash lab_carol
  as_root chown lab_alice:lab_equipe projet; as_root chmod 2770 projet
  as_root chown lab_alice:lab_equipe projet/plan.txt; as_root chmod 660 projet/plan.txt
  as_root runuser -u lab_bob -- touch projet/notes.txt
  as_root chown lab_alice:lab_equipe outil.sh; as_root chmod 750 outil.sh
  as_root chmod 1777 depot
  as_root setfacl -m u:lab_carol:rx projet
  as_root setfacl -m u:lab_carol:r projet/plan.txt
  as_root passwd -l lab_bob >/dev/null
  as_root chage -M 90 lab_alice
  { echo "UID_ALICE=$(id -u lab_alice)"; echo "GROUPES_ALICE=$(id -nG lab_alice | tr ' ' '\n' | sort | tr '\n' ' ' | sed 's/ $//')"; } > reponses.txt
}

lab_main "$@"
