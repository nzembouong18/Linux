#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/lib.sh"
LAB_ID=10
LAB_REQUIRES=(cmd:jq cmd:awk)

lab_setup() {
  cd "$LAB_DIR" || return 1
  cat > employes.csv <<'EOF'
id;nom;service;salaire;ville
1;Alice;IT;4200;Paris
2;Bob;RH;3100;Lyon
3;Carla;IT;4800;Paris
4;David;Compta;3500;Lille
5;Emma;IT;3900;Nantes
6;Farid;RH;3300;Paris
7;Gina;Compta;3700;Lyon
8;Hugo;Ventes;3000;Lille
9;Ines;Ventes;3200;Paris
10;Jules;IT;5100;Lyon
11;Karim;Ventes;2900;Nantes
12;Lea;Compta;3600;Paris
EOF
  cat > config.conf <<'EOF'
# Configuration SSH d'exemple
Port 22

# Authentification
PermitRootLogin yes
PasswordAuthentication yes   # à désactiver en production
   # commentaire indenté

UsePAM yes
X11Forwarding no
EOF
  cat > dates.txt <<'EOF'
Réunion le 12/03/2024 à 10h
Facture du 01/12/2023 payée
Pas de date ici
Du 05/01/2024 au 07/01/2024 inclus
EOF
  cat > app.log <<'EOF'
2024-03-12 10:00:01 login ok user=alice ip=192.168.1.10
2024-03-12 10:00:05 login failed user=root ip=203.0.113.7
2024-03-12 10:00:09 login failed user=root ip=203.0.113.7
2024-03-12 10:01:00 login ok user=bob ip=10.0.0.5
2024-03-12 10:02:13 login failed user=admin ip=999.12.3.4
2024-03-12 10:03:44 login ok user=carla ip=172.16.254.1 via proxy 255.255.255.0
2024-03-12 10:04:02 login failed user=test ip=256.1.1.1
2024-03-12 10:05:00 login ok user=alice ip=192.168.1.10
EOF
  cat > emails.txt <<'EOF'
alice@example.org
bob.martin@societe.fr
pas-un-email
carla@@example.org
david@exemple
emma+tag@sub.domain.com
@sans-nom.fr
felix@domaine.c
EOF
  cat > inventaire.json <<'EOF'
{"items":[{"nom":"clou","stock":120,"prix":0.05},{"nom":"vis","stock":3,"prix":0.1},{"nom":"marteau","stock":4,"prix":12.5},{"nom":"scie","stock":0,"prix":18},{"nom":"colle","stock":45,"prix":3.2}]}
EOF
}

lab_check() {
  cd "$LAB_DIR" || return 1
  local nrm='s/^ *//; s/ *$//'
  assert_eq "A1 total_it" "$(awk -F';' '$3=="IT" {s+=$4} END{print s}' employes.csv)" "$(tr -d ' \n' < total_it.txt 2>/dev/null)"
  assert "A2 moyennes par service" cmp -s <(sed "$nrm" moyennes.txt 2>/dev/null | sort) <(awk -F';' 'NR>1 {s[$3]+=$4; n[$3]++} END {for (k in s) printf "%s %.2f\n", k, s[k]/n[k]}' employes.csv | sort)
  assert_eq "A3 ville_top" "Paris" "$(tr -d ' \n' < ville_top.txt 2>/dev/null)"
  assert "B4 config_propre.conf" cmp -s config_propre.conf <(sed -E '/^[[:space:]]*(#|$)/d' config.conf)
  assert "B5 config_modifiee.conf" cmp -s config_modifiee.conf <(sed -e 's/^Port 22$/Port 2222/' -e 's/^PermitRootLogin yes/PermitRootLogin no/' -e 's/^PasswordAuthentication yes/PasswordAuthentication no/' config.conf)
  assert "B6 dates_iso.txt" cmp -s dates_iso.txt <(sed -E 's#([0-9]{2})/([0-9]{2})/([0-9]{4})#\3-\2-\1#g' dates.txt)
  assert "C7 ips_uniques.txt (IPv4 valides, triées, uniques)" cmp -s <(sort ips_uniques.txt 2>/dev/null) <(printf '10.0.0.5\n172.16.254.1\n192.168.1.10\n203.0.113.7\n255.255.255.0\n' | sort)
  assert "C8 emails_valides.txt" cmp -s <(sort emails_valides.txt 2>/dev/null) <(printf 'alice@example.org\nbob.martin@societe.fr\nemma+tag@sub.domain.com\n' | sort)
  assert "D9 rupture.txt" cmp -s <(sort rupture.txt 2>/dev/null) <(printf 'marteau\nscie\nvis\n')
  assert_eq "D10 valeur_stock" "$(jq '[.items[] | .stock * .prix] | add' inventaire.json)" "$(jq -n "$(tr -d ' \n' < valeur_stock.txt 2>/dev/null || echo null)" 2>/dev/null)"
  assert "sources non modifiées" bash -c "grep -q '^Port 22$' config.conf && grep -q '12/03/2024' dates.txt"
}

lab_solve() {
  cd "$LAB_DIR" || return 1
  awk -F';' '$3=="IT" {s+=$4} END{print s}' employes.csv > total_it.txt
  awk -F';' 'NR>1 {s[$3]+=$4; n[$3]++} END {for (k in s) printf "%s %.2f\n", k, s[k]/n[k]}' employes.csv > moyennes.txt
  awk -F';' 'NR>1 {c[$5]++} END {for (v in c) print c[v], v}' employes.csv | sort -rn | head -1 | cut -d' ' -f2 > ville_top.txt
  sed -E '/^[[:space:]]*(#|$)/d' config.conf > config_propre.conf
  sed -e 's/^Port 22$/Port 2222/' -e 's/^PermitRootLogin yes/PermitRootLogin no/' -e 's/^PasswordAuthentication yes/PasswordAuthentication no/' config.conf > config_modifiee.conf
  sed -E 's#([0-9]{2})/([0-9]{2})/([0-9]{4})#\3-\2-\1#g' dates.txt > dates_iso.txt
  grep -Eo '\b((25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])\b' app.log | sort -u > ips_uniques.txt
  grep -E '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' emails.txt > emails_valides.txt
  jq -r '.items[] | select(.stock < 5) | .nom' inventaire.json > rupture.txt
  jq '[.items[] | .stock * .prix] | add' inventaire.json > valeur_stock.txt
}

lab_main "$@"
