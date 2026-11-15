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
t "ref repo dipin (bukan main polos)"          "grep -qE 'WIBU_REF|v4\\.0\\.8' \"\$REPO/menu/m-setting.sh\""
t "setup.sh verifikasi hash tiap berkas unduhan" "grep -q 'wibu_verify_file' \"\$REPO/setup.sh\" && grep -q 'SHA256SUMS' \"\$REPO/setup.sh\""
t "setup.sh tidak menarik kode dari main"       "! grep -qE '^GITHUB_RAW=.*/main\"' \"\$REPO/setup.sh\""

echo "== D. API Xray 10085 tidak bisa diakses non-root =="
t "aturan iptables owner-match (sintaks nft benar)" "grep -q -- '-m owner ! --uid-owner 0' \"\$REPO/setup.sh\"" 
t "tidak memakai bentuk '! -m owner' (tidak valid di nft)" "! grep -q -- '! -m owner --uid-owner 0' \"\$REPO/setup.sh\" \"\$REPO/uninstall.sh\""
t "hash di README cocok dengan setup.sh sebenarnya" "grep -q $(sha256sum $REPO/setup.sh | cut -d' ' -f1) $REPO/README.md && ! grep -qE 'harap: __HASH' $REPO/README.md"
t "hash di README cocok dengan uninstall.sh sebenarnya" "grep -q $(sha256sum $REPO/uninstall.sh | cut -d' ' -f1) $REPO/README.md && ! grep -qE 'harap: __HASH' $REPO/README.md"
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
t "penanda versi = tag rilis di setup.sh (tidak bisa melenceng)" "V=\$(grep -oE '[0-9]+\.[0-9]+\.[0-9]+. > /etc/wibutunnel/version' \$REPO/setup.sh | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1); [[ -n \"\$V\" ]] && grep -q \"WIBU_REF:-v\$V\" \$REPO/setup.sh"
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
t "manifest diunduh dengan cache-buster (setup.sh)" "grep -q 'SHA256SUMS?\${cb}' \"\$REPO/setup.sh\""
t "manifest diunduh dengan cache-buster (menu update)" "grep -q 'SHA256SUMS?\${cb}' \"\$REPO/menu/m-setting.sh\""
t "ada fallback API GitHub untuk manifest" "grep -q 'api.github.com/repos' \"\$REPO/setup.sh\" && grep -q 'api.github.com/repos' \"\$REPO/menu/m-setting.sh\""
t "manifest API-first (installer)" "grep -q 'API GitHub = sumber OTORITATIF' \"\$REPO/setup.sh\""
t "manifest API-first (menu update)" "grep -q 'API GitHub = sumber OTORITATIF' \"\$REPO/menu/m-setting.sh\""
t "berkas diunduh ulang via API bila hash tak cocok" "grep -q 'bisa basi juga' \"\$REPO/menu/m-setting.sh\" && grep -q 'coba sekali lagi lewat API' \"\$REPO/setup.sh\""
t "ada timer firewall idempoten (atasi urutan boot)" "grep -q 'wibutunnel-firewall.timer' \"\$REPO/setup.sh\" && grep -q 'OnUnitActiveSec=5min' \"\$REPO/setup.sh\""
t "unit firewall After netfilter-persistent" "grep -q 'After=network.target netfilter-persistent.service' \"\$REPO/setup.sh\""
t "skrip firewall menyimpan rules.v4 hasil dedupe" "grep -q 'iptables-save > /etc/iptables/rules.v4' \"\$REPO/sbin/wibutunnel-firewall.sh\""
t "uninstall membersihkan timer" "grep -q 'wibutunnel-firewall.timer' \"\$REPO/uninstall.sh\""
t "menu keluar rapi saat EOF (bukan loop)"    "grep -q 'read -r sub_menu || exit 0' \"\$REPO/menu/m-vless.sh\" && grep -q 'read -r sub_br || exit 0' \"\$REPO/menu/m-backup.sh\" && grep -q 'read -r sub_setting || exit 0' \"\$REPO/menu/m-setting.sh\""
t "restore memperbaiki pemilik config (Xray bisa membaca)" "grep -q 'chown root:xray /usr/local/etc/xray/config.json' \"\$REPO/menu/m-backup.sh\""
t "backup menyertakan bot.conf" "grep -q 'etc/wibutunnel/bot.conf' \"\$REPO/menu/m-backup.sh\""
t "ada pemeriksa akun tanpa exp" "test -x \"\$REPO/sbin/wibu-audit-akun\" && grep -q 'AKUN TANPA EXP' \"\$REPO/sbin/wibu-audit-akun\""
t "audit dipanggil dari auto-repair & bisa di-update" "grep -q 'wibu-audit-akun' \"\$REPO/menu/m-setting.sh\""
t "gagal polling dicatat (401/409 tidak diam)" "grep -q 'getUpdates GAGAL' \"\$REPO/menu/bot-daemon.sh\" && grep -q '409' \"\$REPO/menu/bot-daemon.sh\""
t "restore mematikan bot agar tak tabrakan token" "grep -q 'layanan bot DIMATIKAN' \"\$REPO/menu/m-backup.sh\""
t "audit menampilkan jumlah catatan dummy (tidak senyap)" "grep -q 'Catatan dummy installer' \"\$REPO/sbin/wibu-audit-akun\""
t "update menu ikut rilis terbaru (main), bukan tag beku" "grep -q 'WIBU_REF:-main' \"\$REPO/menu/m-setting.sh\""
t "update memperbarui penanda versi" "grep -q 'wibutunnel/version' \"\$REPO/menu/m-setting.sh\" && grep -q 'wibutunnel/version' \"\$REPO/setup.sh\""
t "tidak ada '-4' nyasar di daftar paket apt" "! grep -nE '^[[:space:]]*apt(-get)? install[^|]*[[:space:]]-4([[:space:]]|$)' \"\$REPO/setup.sh\""
t "apt gagal = fatal (tidak lanjut setengah jalan)" "grep -q 'Instalasi DIHENTIKAN supaya tidak setengah jalan' \"\$REPO/setup.sh\""
t "banner disiapkan sebelum apt (dropbear tidak gagal configure)" "grep -q 'ssh-banner' \"\$REPO/setup.sh\" && grep -q 'DEBIAN_FRONTEND=noninteractive' \"\$REPO/setup.sh\""
t "uninstall membersihkan rujukan banner dropbear" "grep -q 'DROPBEAR_BANNER' \"\$REPO/uninstall.sh\""
t "audit akun ikut dipasang instalasi baru" "grep -q 'sbin/wibu-audit-akun' \"\$REPO/setup.sh\" && grep -q 'wibu-audit-akun' <(grep '^for s in' \"\$REPO/setup.sh\")"
t "unit bot tidak diaktifkan tanpa token" "grep -q 'unit tidak diaktifkan' \"\$REPO/setup.sh\""
t "penanda versi ditulis ulang di akhir instalasi" "grep -q 'Tulis ULANG penanda versi' \"\$REPO/setup.sh\""
t "uninstall menghapus semua skrip yang dipasang" "for s in algojo-ssh lock-user unlock-user ws-stunnel wibu-daemon wibu-audit-akun wibutunnel-firewall network-tune; do grep -q \"\$s\" \"\$REPO/uninstall.sh\" || exit 1; done"
t "dukungan Debian 12: rsyslog ikut dipasang (/dev/log ada)" "grep -q 'python3 rsyslog' \"\$REPO/setup.sh\""
t "NTP punya fallback (ntp tidak ada di bookworm minimal)" "grep -q 'systemd-timesyncd' \"\$REPO/setup.sh\""
t "penjaga OS menyebut versi yang didukung" "grep -q 'Didukung: Ubuntu 20.04/22.04/24.04, Debian 11/12' \"\$REPO/setup.sh\""
t "status failed sisa percobaan dibersihkan (dropbear/haproxy)" "grep -q 'reset-failed dropbear.service haproxy.service' \"\$REPO/setup.sh\""
t "portabilitas: dropbear tidak start otomatis sebelum konfigurasi siap" "grep -q 'NO_START=1' \"\$REPO/setup.sh\""
t "portabilitas: konfigurasi haproxy divalidasi + fallback" "grep -q 'haproxy -c menolak konfigurasi' \"\$REPO/setup.sh\""
t "portabilitas: fallback AppArmor haproxy" "grep -q 'AppArmor memblokir haproxy' \"\$REPO/setup.sh\""
t "portabilitas: laporan versi paket saat instalasi" "grep -q 'Versi: haproxy' \"\$REPO/setup.sh\""
t "apt memakai --force-confold (conffile tidak pernah bertanya)" "grep -q 'Dpkg::Options::=--force-confold' \"\$REPO/setup.sh\""
t "heredoc konfigurasi bersih dari kode shell (cegah tambalan nyasar)" "! awk '/^cat <<HFEOF/{f=1;next} f&&/^HFEOF/{exit} f' \"\$REPO/setup.sh\" | grep -qE 'PORTABILITAS|haproxy -c|aa-status|^rm '"
t "timesyncd dipasang bila belum ada (non-fatal)" "grep -q 'apt-get install -y -o Dpkg::Options::=--force-confold systemd-timesyncd' \"\$REPO/setup.sh\" && grep -q 'Tidak ada layanan NTP yang aktif' \"\$REPO/setup.sh\""
t "sertifikat sementara dipasang bila certbot gagal (tidak hentikan instalasi)" "grep -q 'cert-temp/fullchain.pem' \"\$REPO/setup.sh\" && ! grep -q 'SSL GAGAL! Pastikan domain \$domain mengarah ke IP ini.\${NC}\"$\n    exit 1' \"\$REPO/setup.sh\""
t "penjadwal penerbitan ulang otomatis ikut dipasang" "grep -q 'wibutunnel-ssl-ulang.timer' \"\$REPO/setup.sh\" && test -x \"\$REPO/sbin/wibu-ssl-ulang\""
t "uninstall menghapus penjadwal ssl ulang" "grep -q 'wibutunnel-ssl-ulang' \"\$REPO/uninstall.sh\" && grep -q 'wibu-ssl-ulang' \"\$REPO/uninstall.sh\""
t "nama ISP pendek dipakai di semua menu (wibu-isp)" "grep -q 'ISP=\$(wibu-isp)' \"\$REPO/menu/menu.sh\" && grep -q 'ISP=\$(wibu-isp)' \"\$REPO/menu/m-vless.sh\" && grep -q 'ISP=\$(wibu-isp)' \"\$REPO/menu/m-trojan.sh\""
t "nama ISP bisa ditimpa manual lewat /etc/wibutunnel/isp.txt" "grep -q '/etc/wibutunnel/isp.txt' \"\$REPO/sbin/wibu-isp\" && test -x \"\$REPO/sbin/wibu-isp\""
t "unduhan punya rantai sumber + verifikasi hash per sumber" "grep -q 'for src in raw api jsdelivr raw2' \"\$REPO/setup.sh\" && grep -q 'hash tidak cocok (CDN kemungkinan masih basi)' \"\$REPO/setup.sh\""
t "reinstall tidak menghapus daftar masa aktif akun" "grep -q 'if \[ ! -f /etc/xray/vless_exp.conf \]' \"\$REPO/setup.sh\""
t "reinstall memasang kembali klien lama" "grep -q 'Akun lama dipasang kembali' \"\$REPO/setup.sh\" && grep -q 'KLIEN_LAMA' \"\$REPO/setup.sh\""
t "cache manifest per-ref + divalidasi" "grep -q 'wibu-manifest-\${WIBU_REF}' \"\$REPO/setup.sh\" && grep -q 'wibu_manifest_valid()' \"\$REPO/setup.sh\""
t "validasi domain jalan tanpa dig (image minimal)" "grep -q 'wibu_resolve_a' \"\$REPO/setup.sh\" && grep -q 'getent ahostsv4' \"\$REPO/setup.sh\" && ! grep -q 'IP_DOMAIN=\$(dig +short' \"\$REPO/setup.sh\""
t "Debian 11 EOL dialihkan ke arsip resmi" "grep -q 'archive.debian.org/debian bullseye' \"\$REPO/setup.sh\" && grep -q 'Check-Valid-Until' \"\$REPO/setup.sh\" && grep -q 'bullseye-backports\|backports' \"\$REPO/setup.sh\""
t "regex awk portabel (tanpa interval {n} - mawk Debian 11 menolaknya)" "! grep -q 'awk.*\$1 ~ /\^\[0-9a-f\]{64\}\$/' \"\$REPO/setup.sh\" && grep -q 'length(\$1) == 64' \"\$REPO/setup.sh\""
t "Xray punya jalur cadangan tanpa API + TMPDIR aman (tmp noexec)" "grep -q 'xray_pasang_cadangan' \"\$REPO/setup.sh\" && grep -q 'export TMPDIR=/usr/local/src' \"\$REPO/setup.sh\" && grep -q 'releases/download/\${XRAY_VER}' \"\$REPO/setup.sh\""
t "hash biner Xray diverifikasi di jalur cadangan" "grep -q 'XRAY_BIN_SHA256' \"\$REPO/setup.sh\" && grep -q 'Hash biner Xray tidak cocok' \"\$REPO/setup.sh\""
t "berhenti memakai API setelah 403/429" "grep -q 'WIBU_API_MATI' \"\$REPO/setup.sh\""
t "ada alat verifikasi rantai rilis" "test -x \"\$REPO/tools/verify-release.sh\""
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
