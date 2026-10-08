#!/usr/bin/env bash
# Démo formateur — module 10 (≈ 30 min)
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/demo-lib.sh"

demo_title "Jeu de données"
demo_run "printf 'id;nom;service;salaire\\n1;Alice;IT;4200\\n2;Bob;RH;3100\\n3;Carla;IT;4800\\n4;David;RH;3500\\n' > emp.csv; column -t -s';' emp.csv"

demo_title "grep : regex ERE et extraction"
demo_run "printf 'ip=10.0.0.1 ok\\nip=999.1.1.1 ko\\nip=192.168.1.20 ok\\n' > l.log"
demo_run "grep -Eo '[0-9]{1,3}(\\.[0-9]{1,3}){3}' l.log"
demo_run "grep -Eo '\\b((25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])\\.){3}(25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])\\b' l.log"
demo_say "La 2e regex rejette 999.1.1.1 : chaque octet est borné à 255."
demo_run "echo 'user=alice id=42' | grep -oP '(?<=user=)\\w+'"

demo_title "sed : substitution, suppression, blocs"
demo_run "echo 'Il fait chaud chaud' | sed 's/chaud/froid/'; echo 'Il fait chaud chaud' | sed 's/chaud/froid/g'"
demo_run "echo '12/03/2024' | sed -E 's#([0-9]{2})/([0-9]{2})/([0-9]{4})#\\3-\\2-\\1#'"
demo_run "printf '# conf\\nport=80\\n\\ndebug=1\\n' > c.conf; sed -E '/^[[:space:]]*(#|\$)/d' c.conf"
demo_run "sed -i.bak 's/^port=.*/port=8080/' c.conf && diff c.conf.bak c.conf"
demo_run "printf 'a\\nBEGIN\\nx\\ny\\nEND\\nb\\n' | sed -n '/BEGIN/,/END/p'"
demo_run "seq 1 6 | sed -n '2~2p'"

demo_title "awk : colonnes, filtres, agrégats"
demo_run "awk -F';' 'NR>1 {print \$2, \$4}' emp.csv"
demo_run "awk -F';' 'NR>1 && \$4 > 3400' emp.csv"
demo_run "awk -F';' 'NR>1 {s+=\$4} END {print \"total:\", s, \"moyenne:\", s/(NR-1)}' emp.csv"
demo_run "awk -F';' 'NR>1 {s[\$3]+=\$4; n[\$3]++} END {for (k in s) printf \"%-5s %7.2f\\n\", k, s[k]/n[k]}' emp.csv | sort"
demo_run "awk -F: '\$3>=1000 || \$3==0 {print \$1\":\"\$7}' /etc/passwd | head -3"

demo_title "jq : JSON"
demo_run "echo '{\"items\":[{\"nom\":\"vis\",\"stock\":3,\"prix\":0.1},{\"nom\":\"clou\",\"stock\":120,\"prix\":0.05}]}' > inv.json"
demo_run "jq -r '.items[] | select(.stock < 5) | .nom' inv.json"
demo_run "jq '[.items[] | .stock * .prix] | add' inv.json"
demo_run "jq -r '.items[] | [.nom, .stock] | @csv' inv.json"
demo_run "ip -j addr 2>/dev/null | jq -r '.[0].ifname' || true"
demo_end
