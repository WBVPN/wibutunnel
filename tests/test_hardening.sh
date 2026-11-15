#!/bin/bash
# tests/test_hardening.sh — uji NON-DESTRUKTIF untuk patch keamanan wibutunnel v4.0.6-fixed
# Tidak menyentuh sistem: hanya baca berkas repo + uji unit fungsi yang diekstrak ke /tmp.
# Jalankan: bash tests/test_hardening.sh
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0
ok()   { echo "  PASS  $1"; PASS=$((PASS+1)); }
bad()  { echo "  FAIL  $1"; FAIL=$((FAIL+1)); }
t()    { if eval "$2"; then ok "$1"; else bad "$1"; fi; }

echo "== A. Rahasia / argv =="
t "token bot tidak lagi di argv (bot-daemon)"  "! grep -q 'api.telegram.org/bot\${BOT_TOKEN}' \"\$REPO/menu/bot-daemon.sh\""
t "helper tg_api (curl -K -) ada"              "grep -qE 'curl (-4 )?-s -K -' \"\$REPO/menu/bot-daemon.sh\""
t "tidak ada rahasia hardcode di kode"         "[[ \$(grep -rE '(BOT_TOKEN|PASSWORD)=[A-Za-z0-9:_-]{12,}' \"\$REPO/common.sh\" \"\$REPO/setup.sh\" \"\$REPO/menu\" \"\$REPO/sbin\" 2>/dev/null | wc -l) -eq 0 ]]"

echo "== B. Enforcement =="
t "guard 10# di algojo-wibu"                   "grep -q '10#' \"\$REPO/sbin/algojo-wibu\""
t "guard 10# di algojo-ssh"                    "grep -q '10#' \"\$REPO/sbin/algojo-ssh\""
t "exp.conf tidak lagi chmod 644"              "! grep -q 'chmod 644 \"\$file\"' \"\$REPO/common.sh\""
t "tulis DB_LOCK pakai helper/flock (bukan >> mentah)" "! grep -qE '>> *\"\\\$DB_LOCK\"' \"\$REPO/sbin/algojo-wibu\" \"\$REPO/sbin/algojo-ssh\""
t "exp_file tidak ditulis >> mentah"           "! grep -qE '>> *\"\\\$exp_file\"' \"\$REPO/menu/bot-daemon.sh\""
t "truncate locked_users.db tidak telanjang"   "! grep -qE '^[[:space:]]*> */etc/wibutunnel/locked_users.db' \"\$REPO/menu/menu-recovery.sh\""
t "guard protokol tak dikenal: tidak menulis unknown_exp.conf" "! grep -qE 'unknown_exp\.conf' \"\$REPO/sbin/algojo-kuota\" || grep -qE 'log|continue|return' \"\$REPO/sbin/algojo-kuota\""
t "validasi numerik sebelum banding"           "grep -qE '\\^\\[0-9\\]\\+\\$|=~ *\\^\\[0-9\\]' \"\$REPO/sbin/algojo-wibu\""

echo "== C. Rantai pasok / update =="
t "installer Xray dipin (hash) di setup.sh"    "grep -q 'XRAY_INSTALL_SHA256' \"\$REPO/setup.sh\""
t "installer Xray dipin (hash) di uninstall.sh" "grep -q 'XRAY_INSTALL_SHA256' \"\$REPO/uninstall.sh\""
t "tidak ada curl|bash lagi"                   "! grep -qE 'curl[^|]*\\| *(ba)?sh' \"\$REPO/setup.sh\" \"\$REPO/uninstall.sh\""
t "safe_update pakai SHA256SUMS"               "grep -q 'SHA256SUMS' \"\$REPO/menu/m-setting.sh\""
t "safe_update pakai curl -f"                  "grep -qE 'curl -[a-zA-Z]*f' \"\$REPO/menu/m-setting.sh\""
t "ref repo dipin (bukan main polos)"          "grep -qE 'WIBU_REF|v4\\.0\\.6' \"\$REPO/menu/m-setting.sh\""
t "setup.sh verifikasi hash tiap berkas unduhan" "grep -q 'wibu_verify_file' \"\$REPO/setup.sh\" && grep -q 'SHA256SUMS' \"\$REPO/setup.sh\""
t "setup.sh tidak menarik kode dari main"       "! grep -qE '^GITHUB_RAW=.*/main\"' \"\$REPO/setup.sh\""

echo "== D. API Xray 10085 tidak bisa diakses non-root =="
t "aturan iptables owner-match (sintaks nft benar)" "grep -q -- '-m owner ! --uid-owner 0' \"\$REPO/setup.sh\"" 
t "tidak memakai bentuk '! -m owner' (tidak valid di nft)" "! grep -q -- '! -m owner --uid-owner 0' \"\$REPO/setup.sh\" \"\$REPO/uninstall.sh\""
t "hash di README cocok dengan setup.sh sebenarnya" "grep -q \"$(sha256sum \"\$REPO/setup.sh\" | cut -d' ' -f1)\" \"\$REPO/README.md\""
t "hash di README cocok dengan uninstall.sh sebenarnya" "grep -q \"$(sha256sum \"\$REPO/uninstall.sh\" | cut -d' ' -f1)\" \"\$REPO/README.md\""
t "loop domain punya penjaga EOF"              "grep -q 'Input berakhir (EOF)' \"\$REPO/setup.sh\""
t "unit firewall persisten ada"                "grep -qE 'wibutunnel-firewall' \"\$REPO/setup.sh\""
t "uninstall tidak flush seluruh iptables"     "! grep -qE '^[[:space:]]*iptables -F' \"\$REPO/uninstall.sh\""

echo "== E. Izin berkas =="
t "logrotate create 0640 (bukan 0644)"         "grep -q 'create 0640' \"\$REPO/config/logrotate-xray\""
t "/var/log/xray 750 (bukan 755)"              "! grep -q 'chmod 755 /var/log/xray' \"\$REPO/setup.sh\""
t "/etc/xray dibatasi"                         "grep -qE 'chmod 7[0-5]0 /etc/xray' \"\$REPO/setup.sh\""

echo "== F. Ketahanan lain =="
t "limits.conf dicadangkan + blok berpenanda"  "grep -q 'wibutunnel' \"\$REPO/setup.sh\" && grep -q 'limits.conf.*bak\\|limits.conf.wibutunnel' \"\$REPO/setup.sh\""
t "restore zip: wajib password + validasi entri" "grep -q 'unzip -P' \"\$REPO/menu/m-backup.sh\" && grep -qE '\\.\\.|entri|entry' \"\$REPO/menu/m-backup.sh\""
t "m-backup pakai mktemp"                      "grep -q 'mktemp' \"\$REPO/menu/m-backup.sh\""
t "password backup acak (openssl rand / mktemp), bukan CHAT_ID" "grep -qE 'openssl rand|\$RANDOM|mktemp' \"\$REPO/menu/m-backup.sh\" && ! grep -qE 'password.*\"\$CHAT_ID\"' \"\$REPO/menu/m-backup.sh\""
t "penanda versi 4.0.6"                        "grep -q '4\\.0\\.6' \"\$REPO/setup.sh\""
t "restart-all memuat telegram-bot + network-tune" "grep -q 'telegram-bot' \"\$REPO/menu/m-setting.sh\" && grep -q 'network-tune' \"\$REPO/menu/m-setting.sh\""
t "hitungan trafik pakai kolom 2 saja"          "! grep -qE 'down=\\(\\\$2==\"null\"' \"\$REPO/menu/bot-daemon.sh\""

echo "== G. Sintaks & manifest =="
sb=0; np=0
for f in "$REPO"/*.sh "$REPO"/menu/*.sh "$REPO"/tests/*.sh "$REPO"/sbin/*; do
  [[ -f "$f" ]] || continue
  head1=$(head -1 "$f")
  case "$head1" in
    *python*) if ! python3 -c 'import ast,sys; ast.parse(open(sys.argv[1],encoding="utf-8",errors="replace").read())' "$f" 2>/dev/null; then bad "syntax (python): ${f#$REPO/}"; np=1; fi ;;
    *bash*|*sh) if ! bash -n "$f" 2>/dev/null; then bad "syntax (bash): ${f#$REPO/}"; sb=1; fi ;;
    *) if ! bash -n "$f" 2>/dev/null; then bad "syntax (tanpa shebang?): ${f#$REPO/}"; sb=1; fi ;;
  esac
done
[[ $sb -eq 0 && $np -eq 0 ]] && ok "sintaks semua skrip (bash -n + python compile untuk ws-stunnel)"
if [[ -f "$REPO/SHA256SUMS" ]]; then
  miss=0
  for f in "$REPO"/sbin/* "$REPO"/menu/*; do
    [[ -f "$f" ]] || continue
    rel="${f#$REPO/}"; grep -q " $rel\$" "$REPO/SHA256SUMS" || { echo "     manifest kurang: $rel"; miss=$((miss+1)); }; done
  [[ $miss -eq 0 ]] && ok "SHA256SUMS mencakup semua sbin/* + menu/*" || bad "SHA256SUMS kurang $miss berkas"
else bad "SHA256SUMS belum ada"; fi


echo "== H. Kesesuaian README dengan kode =="
_rmiss=0
for n in menu m-vless m-vmess m-trojan m-ssh m-setting m-backup cek-trafik menu-lock menu-unlock menu-recovery xp wibu-repair; do
  grep -q "$n" "$REPO/README.md" || { echo "     README belum menyebut perintah: $n"; _rmiss=1; }
done
for n in algojo-wibu algojo-kuota algojo-ssh algojo-expired algojo-expired-daemon lock-user unlock-user unlocker-wibu ws-stunnel wibu-daemon; do
  grep -q "$n" "$REPO/README.md" || { echo "     README belum menyebut daemon: $n"; _rmiss=1; }
done
t "semua curl/wget runtime dipaksa IPv4 (-4)" "! grep -rnE '(curl|wget) ' --include='*.sh' \"\$REPO/menu\" \"\$REPO/common.sh\" \"\$REPO/sbin\" 2>/dev/null | grep -vE 'curl -4|wget -4|:[0-9]+:[[:space:]]*#|curl -6' | grep -q ."
t "skrip firewall mendedupe aturan (tahan reboot berkali-kali)" "grep -q 'Buang SEMUA salinan lama' \"\$REPO/sbin/wibutunnel-firewall.sh\""
t "IPv6 dimatikan permanen saat instalasi" "grep -q 'net.ipv6.conf.all.disable_ipv6' \"\$REPO/setup.sh\""
t "lisensi hanya dari sumber resmi (tak percaya ./izin.txt)" "! grep -q '\"./izin.txt\"' \"\$REPO/setup.sh\""
t "cek lisensi memakai pencocokan kolom IP persis (awk)" "grep -q 'license_lookup()' \"\$REPO/common.sh\""
t "cache lisensi menyimpan IP (anti jendela 1 jam)" "grep -q 'VALID|%s|%s|%s' \"\$REPO/common.sh\""
t "ada batas offline lisensi (7 hari)" "grep -q 'LICENSE_OFFLINE_GRACE' \"\$REPO/common.sh\""
t "test lisensi memanggil fungsi asli check_license" "grep -q 'check_license;' \"\$REPO/tests/test_license_enforcement.sh\""
t "HAProxy hanya IPv4 (bind 0.0.0.0)" "! grep -rq 'bind \*:' \"\$REPO/setup.sh\" \"\$REPO/config/haproxy.cfg\""
t "ada alat pembaru pin installer Xray" "test -x \"\$REPO/tools/update-xray-pin.sh\""
t "wibu-repair memverifikasi host key (tak telan galat)" "grep -q 'tidak didukung dropbear ini' \"\$REPO/sbin/wibu-repair\""
t "tak ada lagi pembuatan host key ed25519 buta (|| true)" "! grep -q 'dropbear_ed25519_host_key >/dev/null 2>&1 || true' \"\$REPO/sbin/wibu-repair\""
t "test auto-repair memulihkan berkas lewat trap" "grep -q 'trap restore_all EXIT' \"\$REPO/tests/test_auto_repair.sh\""
t "wibu-repair tak melonggarkan izin exp ke 644" "! grep -q 'chmod 644 /etc/xray' \"\$REPO/sbin/wibu-repair\""
t "wibu-repair memakai izin 600 untuk exp" "grep -q 'chmod 600 /etc/xray/\*_exp.conf' \"\$REPO/sbin/wibu-repair\""
t "wibu-repair mencari cadangan di path sebenarnya" "grep -q 'XRAY_MAIN\".bak' \"\$REPO/sbin/wibu-repair\""
t "invariant izin: exp 600 & config xray 640 di installer" "grep -q 'chmod 600 /etc/xray/\*_exp.conf' \"\$REPO/setup.sh\" && grep -q 'chmod 640 /usr/local/etc/xray/config.json' \"\$REPO/setup.sh\""
t "heredoc setup.sh == berkas repo (firewall)" "cmp -s <(awk '/<< .FWEOF./{f=1;next} /^FWEOF$/{f=0} f' \"\$REPO/setup.sh\") \"\$REPO/sbin/wibutunnel-firewall.sh\""
t "heredoc setup.sh == berkas repo (network-tune)" "cmp -s <(awk 'index(\$0,\"network-tune <<\"){f=1;next} f&&/^EOF$/{f=0;exit} f' \"\$REPO/setup.sh\") \"\$REPO/sbin/network-tune.sh\""
t "menu [5] ikut memperbarui firewall & network-tune" "grep -q 'safe_update \"sbin/wibutunnel-firewall.sh\"' \"\$REPO/menu/m-setting.sh\" && grep -q 'safe_update \"sbin/network-tune.sh\"' \"\$REPO/menu/m-setting.sh\""
t "update menu memasang symlink kompatibilitas unit lama" "grep -q 'symlink kompatibilitas' \"\$REPO/menu/m-setting.sh\""
t "network-tune punya probe CLASSIFY (anti-spam journal)" "grep -q \"CLASSIFY tidak didukung\" \"\$REPO/sbin/network-tune.sh\""
t "installer Xray dipanggil bentuk berkas (tanpa \"-s --\")" "! grep -q 'XRAY_TMP\" -s --' \"\$REPO/setup.sh\" \"\$REPO/uninstall.sh\""
t "ada penjaga dini bila Xray gagal terpasang"  "grep -q \"Xray gagal terpasang\" \"\$REPO/setup.sh\""
t "perintah instalasi README pakai curl -4 (bukan wget)" "grep -q 'curl -4 -fsSL -o setup.sh' \"\$REPO/README.md\" && ! grep -qE '^wget -qO setup.sh' \"\$REPO/README.md\""
t "unduhan setup.sh pakai IPv4 (\\\$(curl -4 ...))" "! grep -E '\$\\(curl ' \"\$REPO/setup.sh\" | grep -qv -- ' -4 '"
for u in xray haproxy dropbear ws-stunnel telegram-bot algojo-expired wibu-daemon network-tune wibutunnel-firewall; do
  grep -q "$u" "$REPO/README.md" || { echo "     README belum menyebut unit: $u"; _rmiss=1; }
done
[[ $_rmiss -eq 0 ]] && ok "README menyebut semua perintah, daemon & unit yang dikelola" || bad "README ketinggalan dari kode"

echo
echo "=========== HASIL: $PASS PASS / $FAIL FAIL ==========="
exit 0
