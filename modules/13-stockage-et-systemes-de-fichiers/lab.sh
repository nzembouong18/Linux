#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/lib.sh"
LAB_ID=13
LAB_REQUIRES=(root loop cmd:mkfs.ext4 cmd:dumpe2fs cmd:blkid cmd:findmnt cmd:losetup cmd:pvcreate)

# device-mapper réellement utilisable (pas seulement le périphérique de contrôle) ?
dm_ok() { dmsetup targets 2>/dev/null | grep -qw linear; }

lab_cleanup() {
  local m img dev
  LAB_DIR="${LAB_DIR:-$LAB_ROOT/$LAB_ID}"
  [[ -d "$LAB_DIR" ]] || return 0
  for m in lvm sauvegarde donnees; do
    mountpoint -q "$LAB_DIR/mnt/$m" 2>/dev/null && as_root umount -l "$LAB_DIR/mnt/$m" 2>/dev/null
  done
  if vgs labvg >/dev/null 2>&1; then
    as_root vgchange -an labvg >/dev/null 2>&1
    as_root vgremove -ff -y labvg >/dev/null 2>&1
  fi
  for img in "$LAB_DIR"/*.img; do
    [[ -f "$img" ]] || continue
    for dev in $(losetup -j "$img" -O NAME -n 2>/dev/null); do
      as_root pvremove -ff -y "$dev" >/dev/null 2>&1
      as_root losetup -d "$dev" 2>/dev/null
    done
  done
  return 0
}

lab_setup() {
  cd "$LAB_DIR" || return 1
  lab_cleanup
  rm -rf ./*.img ./*.txt fstab.lab mnt
  mkdir -p mnt/donnees mnt/sauvegarde mnt/lvm
}

# helpers de contrôle -----------------------------------------------------
fs_field() { dumpe2fs -h "$1" 2>/dev/null | awk -F: -v k="$2" '$1==k {gsub(/^ +| +$/,"",$2); print $2}'; }
loop_backing() { losetup -nO BACK-FILE "$1" 2>/dev/null; }
mounted_image() { # mounted_image <mountpoint> → fichier image qui le sous-tend
  local src; src=$(findmnt -no SOURCE "$1" 2>/dev/null) || return 1
  [[ -n "$src" ]] && loop_backing "$src"
}
ro_peek() { # ro_peek <image> <fichier> → affiche le contenu en montant l'image en lecture seule
  local t; t=$(mktemp -d)
  as_root mount -o loop,ro "$1" "$t" 2>/dev/null && { cat "$t/$2" 2>/dev/null; as_root umount "$t"; }
  rmdir "$t" 2>/dev/null
}

lab_check() {
  cd "$LAB_DIR" || return 1
  local L="$LAB_DIR" get; get() { grep -E "^$1=" "$L/infos.txt" 2>/dev/null | head -1 | cut -d= -f2-; }

  # --- Partie A
  assert_eq "A1 disque1.img = 64 MiB" 67108864 "$(stat -c %s disque1.img 2>/dev/null)"
  assert_eq "A1 disque1 : ext4, label DONNEES" "ext4:DONNEES" "$(blkid -p -s TYPE -o value disque1.img 2>/dev/null):$(blkid -p -s LABEL -o value disque1.img 2>/dev/null)"
  assert_eq "A2 disque2.img = 32 MiB" 33554432 "$(stat -c %s disque2.img 2>/dev/null)"
  assert_eq "A2 disque2 : ext4, label SAUVEGARDE" "ext4:SAUVEGARDE" "$(blkid -p -s TYPE -o value disque2.img 2>/dev/null):$(blkid -p -s LABEL -o value disque2.img 2>/dev/null)"
  local res tot pct; res=$(fs_field disque2.img "Reserved block count"); tot=$(fs_field disque2.img "Block count")
  pct=$(( ${tot:-0} > 0 ? res * 1000 / tot : 0 ))
  if (( pct >= 9 && pct <= 11 )); then ok "A2 blocs réservés ≈ 1 %"; else ko "A2 blocs réservés ≈ 1 % (obtenu ${pct}‰)"; fi
  assert_eq "A3 UUID_DONNEES"    "$(blkid -p -s UUID -o value disque1.img 2>/dev/null)" "$(get UUID_DONNEES)"
  assert_eq "A3 UUID_SAUVEGARDE" "$(blkid -p -s UUID -o value disque2.img 2>/dev/null)" "$(get UUID_SAUVEGARDE)"
  assert_eq "A3 TAILLE_BLOC"     "$(fs_field disque1.img 'Block size')" "$(get TAILLE_BLOC)"

  # --- Partie B
  assert "B4 mnt/donnees est monté" mountpoint -q "$L/mnt/donnees"
  assert_eq "B4 mnt/donnees ← disque1.img" "$L/disque1.img" "$(mounted_image "$L/mnt/donnees")"
  assert_eq "B5 hello.txt dans disque1.img" "bonjour stockage" "$(cat "$L/mnt/donnees/hello.txt" 2>/dev/null)"
  assert_eq "B5 hello.txt copié dans disque2.img" "bonjour stockage" "$(ro_peek "$L/disque2.img" hello.txt)"
  assert_grep "B6 mount.txt : noexec" 'noexec' mount.txt
  assert_grep "B6 mount.txt : nosuid" 'nosuid' mount.txt
  assert_grep "B6 mount.txt : nodev"  'nodev'  mount.txt
  local u1 u2; u1=$(get UUID_DONNEES); u2=$(get UUID_SAUVEGARDE)
  assert "B7 fstab.lab : ligne des données (UUID, chemin absolu, ext4, loop)" \
    awk -v u="UUID=$u1" -v p="$L/mnt/donnees" '$1==u && $2==p && $3=="ext4" && $4 ~ /loop/ && $5=="0" && $6=="2" && NF==6 {f=1} END{exit !f}' fstab.lab
  assert "B7 fstab.lab : ligne de la sauvegarde (noexec,nosuid,nodev,nofail)" \
    awk -v u="UUID=$u2" -v p="$L/mnt/sauvegarde" '$1==u && $2==p && $3=="ext4" && $4 ~ /noexec/ && $4 ~ /nosuid/ && $4 ~ /nodev/ && $4 ~ /nofail/ && NF==6 {f=1} END{exit !f}' fstab.lab
  assert "B8 mnt/sauvegarde démonté" bash -c "! mountpoint -q '$L/mnt/sauvegarde'"
  assert_grep "B8 fsck.txt : résultat e2fsck" '[0-9]+/[0-9]+ files' fsck.txt

  # --- Partie C
  assert "C9 groupe de volumes labvg existe" as_root vgs labvg
  assert_eq "C9 labvg contient 2 PV" 2 "$(as_root vgs --noheadings -o pv_count labvg 2>/dev/null | tr -d ' ')"
  local vg; vg=$(as_root vgs --noheadings --units m --nosuffix -o vg_size labvg 2>/dev/null | awk '{printf "%d", $1}')
  if (( ${vg:-0} >= 100 && ${vg:-0} <= 128 )); then ok "C9 taille du VG plausible (${vg} MiB)"; else ko "C9 taille du VG plausible (obtenu '${vg}' MiB)"; fi
  assert_eq "C11 VG_TAILLE_MIB" "$vg" "$(grep -E '^VG_TAILLE_MIB=' lvm.txt 2>/dev/null | cut -d= -f2)"
  if dm_ok; then
    local lv; lv=$(as_root lvs --noheadings --units m --nosuffix -o lv_size labvg/labdata 2>/dev/null | awk '{printf "%d", $1}')
    if (( ${lv:-0} >= 80 )); then ok "C10 LV labdata agrandi (${lv} MiB ≥ 80)"; else ko "C10 LV labdata agrandi à 80 MiB (obtenu '${lv}')"; fi
    assert "C10 labdata monté sur mnt/lvm" mountpoint -q "$L/mnt/lvm"
    local fsz; fsz=$(df -BM --output=size "$L/mnt/lvm" 2>/dev/null | tail -1 | tr -dc 0-9)
    if (( ${fsz:-0} >= 70 )); then ok "C10 le système de fichiers a suivi (-r) : ${fsz} Mo"; else ko "C10 le système de fichiers n'a pas suivi (-r)"; fi
  else
    skip "C10 volume logique (device-mapper indisponible)"
  fi
}

lab_solve() {
  cd "$LAB_DIR" || return 1
  truncate -s 64M disque1.img; mkfs.ext4 -q -L DONNEES disque1.img
  truncate -s 32M disque2.img; mkfs.ext4 -q -m 1 -L SAUVEGARDE disque2.img
  {
    echo "UUID_DONNEES=$(blkid -p -s UUID -o value disque1.img)"
    echo "UUID_SAUVEGARDE=$(blkid -p -s UUID -o value disque2.img)"
    echo "TAILLE_BLOC=$(dumpe2fs -h disque1.img 2>/dev/null | awk -F: '/^Block size/{gsub(/ /,"",$2); print $2}')"
  } > infos.txt
  as_root mount -o loop,noexec,nosuid,nodev disque1.img mnt/donnees
  as_root mount -o loop,noexec,nosuid,nodev disque2.img mnt/sauvegarde
  echo "bonjour stockage" | as_root tee mnt/donnees/hello.txt >/dev/null
  as_root cp mnt/donnees/hello.txt mnt/sauvegarde/
  findmnt -no OPTIONS mnt/sauvegarde > mount.txt
  # shellcheck disable=SC1091
  . ./infos.txt
  cat > fstab.lab <<EOF
UUID=$UUID_DONNEES $PWD/mnt/donnees ext4 loop,defaults 0 2
UUID=$UUID_SAUVEGARDE $PWD/mnt/sauvegarde ext4 loop,noexec,nosuid,nodev,nofail 0 2
EOF
  as_root umount mnt/sauvegarde
  e2fsck -fn disque2.img > fsck.txt 2>&1 || true
  truncate -s 64M pv1.img pv2.img
  local l1 l2; l1=$(as_root losetup -f --show pv1.img); l2=$(as_root losetup -f --show pv2.img)
  as_root pvcreate -q -y "$l1" "$l2" >/dev/null && as_root vgcreate -q labvg "$l1" "$l2" >/dev/null
  if dm_ok; then
    as_root lvcreate -q -y -L 60M -n labdata labvg >/dev/null
    as_root mkfs.ext4 -q /dev/labvg/labdata
    as_root mount /dev/labvg/labdata mnt/lvm
    echo ok | as_root tee mnt/lvm/test.txt >/dev/null
    as_root lvextend -q -r -L +20M /dev/labvg/labdata >/dev/null
  else
    warn "device-mapper indisponible : étape LV ignorée (VG créé seulement)"
  fi
  echo "VG_TAILLE_MIB=$(as_root vgs --noheadings --units m --nosuffix -o vg_size labvg | awk '{printf "%d", $1}')" > lvm.txt
}

lab_main "$@"
