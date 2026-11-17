#!/bin/bash
# ==============================================================================
# TEST SUITE: test_bot_enable.sh
# Menjaga dua kelas bug nyata pada bot Telegram panel:
#   (A) unit hanya di-start/restart, tidak pernah di-ENABLE -> setelah reboot bot mati;
#   (B) "Stop" manual admin dibatalkan oleh restart-all / Update Script / Auto-Repair.
# Sifat: statis + behavioral dengan `systemctl` DI-STUB. Tidak menyentuh systemd asli.
# Semua berkas uji di dalam mktemp -d; kalau mktemp gagal, tes berhenti (jangan pernah
# menulis ke /etc atau /bin karena "$TMP/x" menjadi "/x" saat $TMP kosong).
# ==============================================================================
set -uo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="$REPO_DIR/menu/m-setting.sh"
REPAIR="$REPO_DIR/sbin/wibu-repair"
BACKUP="$REPO_DIR/menu/m-backup.sh"
SETUP="$REPO_DIR/setup.sh"

FAILS=0
ok()  { echo "  PASS  $1"; }
bad() { echo "  FAIL  $1"; FAILS=$((FAILS+1)); }

for f in "$TARGET" "$REPAIR" "$BACKUP" "$SETUP"; do
    [[ -f "$f" ]] || { echo "FAIL: berkas wajib tidak ada: $f"; exit 1; }
done

# ---------- harness aman ----------
TMPROOT="$(mktemp -d /tmp/wibu_bot_enable.XXXXXX)" || { echo "FAIL: mktemp gagal"; exit 1; }
[[ -n "$TMPROOT" && -d "$TMPROOT" ]] || { echo "FAIL: TMPROOT tidak sah: '$TMPROOT'"; exit 1; }
cleanup() { [[ -n "${TMPROOT:-}" && -d "${TMPROOT:-}" ]] && rm -rf "$TMPROOT"; }
trap cleanup EXIT

# Stub systemctl sebagai FUNGSI bash yang di-export, bukan lewat PATH: di VPS panel,
# `bash -c` bisa memuat BASH_ENV/.bashrc yang menimpa PATH -> stub PATH diam-diam tidak
# terpakai dan potongan kode memanggil systemctl SUNGGUHAN (pernah terukur: "Failed to
# stop uji.service"). Sentinel di bawah wajib hijau sebelum satu skenario dijalankan.
LOG=""
systemctl() { [[ -n "${LOG:-}" ]] && printf '%s\n' "systemctl $*" >> "$LOG"; return 0; }
export -f systemctl

stub_siap() { # pastikan stub benar-benar mencegat; kalau tidak, JANGAN jalankan skenario
    local d="$1"
    mkdir -p "$d/etc"
    : > "$d/sentinel"
    LOG="$d/sentinel" bash -c 'systemctl __wibu_sentinel__' >/dev/null 2>&1
    grep -q '__wibu_sentinel__' "$d/sentinel" 2>/dev/null
}

jalankan() { # $1=dir sandbox  $2=perintah bash utuh
    : > "$1/log"
    LOG="$1/log" bash -c "$2" >/dev/null 2>&1
    cat "$1/log"
}

echo "=== [1/9] Setiap start/restart bot di menu dijaga (bot_boleh_jalan / enable dulu) ==="
python3 - "$TARGET" <<'PY'
import re, sys
lines = open(sys.argv[1], encoding='utf-8').read().splitlines()
start = re.compile(r'systemctl\s+(?:start|restart)\s+[^\n]*telegram-bot')
gate  = re.compile(r'bot_boleh_jalan|bot_enable_guard|rm -f /etc/wibutunnel/bot_off')
# baris start/restart juga boleh berada satu baris setelah gerbang (pola "a && b")
masalah = []
for i, ln in enumerate(lines):
    if not start.search(ln):
        continue
    sekitar = lines[max(0, i - 2): i + 1]
    if not any(gate.search(x) for x in sekitar):
        masalah.append(f"baris {i+1}: {ln.strip()}")
if masalah:
    print("TANPA_GERBANG " + str(len(masalah)))
    for m in masalah:
        print("  " + m)
    sys.exit(1)
print("OK semua start/restart punya gerbang")
PY
[[ $? -eq 0 ]] && ok "tidak ada start/restart bot yang lolos dari gerbang" \
                || bad "ada start/restart bot tanpa gerbang (Stop manual bisa dibatalkan)"

echo "=== [2/9] restart-all & Update Script TIDAK menyalakan bot yang di-Stop ==="
python3 - "$TARGET" <<'PY'
import sys
lines = open(sys.argv[1], encoding='utf-8').read().splitlines()
masalah = []
for i, ln in enumerate(lines):
    if 'systemctl restart' not in ln:
        continue
    # restart massal = satu baris yang menyalakan beberapa layanan inti sekaligus
    if sum(x in ln for x in ('xray', 'dropbear', 'haproxy')) >= 2 and 'telegram-bot' in ln:
        masalah.append(f"baris {i+1}: {ln.strip()}")
if masalah:
    for m in masalah: print("BOT_DI_RESTART_MASSAL " + m)
    sys.exit(1)
PY
[[ $? -eq 0 ]] && ok "telegram-bot tidak pernah ikut restart massal (urutan nama tidak dipatok)" \
                || bad "telegram-bot masih ikut restart massal tanpa syarat"
n_gate=$(grep -c 'bot_boleh_jalan && systemctl restart telegram-bot' "$TARGET")
[[ "$n_gate" -ge 2 ]] && ok "gerbang dipakai di restart-all dan Update Script ($n_gate tempat)" \
                      || bad "gerbang bot_boleh_jalan tidak dipakai di kedua jalur ($n_gate)"

echo "=== [3/9] Penanda bot_off ditulis oleh Stop dan dihapus oleh Start/simpan token ==="
python3 - "$TARGET" <<'PY'
import sys
lines = open(sys.argv[1], encoding='utf-8').read().splitlines()
def idx(pat, after=0):
    for i in range(after, len(lines)):
        if pat in lines[i]:
            return i
    return -1
i_stop  = idx('systemctl stop telegram-bot')
i_touch = idx('touch /etc/wibutunnel/bot_off')
ok = True
if i_touch < 0:
    print("TIDAK_ADA_TANDA"); ok = False
elif i_stop >= 0 and i_touch > i_stop:
    print("TANDA_SETELAH_STOP"); ok = False          # penanda harus dipasang SEBELUM stop
elif idx('rm -f /etc/wibutunnel/bot_off') < 0:
    print("TIDAK_ADA_HAPUS_TANDA"); ok = False
sys.exit(0 if ok else 1)
PY
[[ $? -eq 0 ]] && ok "Stop menulis penanda sebelum unit dimatikan; Start/simpan token menghapusnya" \
                || bad "produsen penanda bot_off tidak lengkap (Stop bisa tidak menghasilkan penanda)"

echo "=== [4/9] Guard: perilaku (systemctl di-stub) ==="
D1="$TMPROOT/guard"
stub_siap "$D1" || { bad "stub systemctl tidak mencegat (BASH_ENV?) — skenario DIBATALKAN agar tidak menyentuh layanan nyata"; }
awk '/^bot_conf_lengkap\(\)/,/^}/' "$TARGET" | sed "s#/etc/wibutunnel#$D1/etc#g" > "$D1/guard.sh"
awk '/^bot_enable_guard\(\)/,/^}/' "$TARGET" | sed "s#/etc/wibutunnel#$D1/etc#g" >> "$D1/guard.sh"
printf 'BOT_TOKEN="123:abc"\nCHAT_ID="42"\n' > "$D1/etc/bot.conf"

out=$(jalankan "$D1" "source '$D1/guard.sh'; bot_enable_guard")
grep -q 'systemctl enable telegram-bot' <<<"$out" \
  && ok "kontrol positif: token+chat id lengkap -> guard meng-enable" \
  || bad "guard tidak jalan sama sekali (kontrol positif gagal: fungsi hilang/stub tidak terpakai)"

touch "$D1/etc/bot_off"
out=$(jalankan "$D1" "source '$D1/guard.sh'; bot_enable_guard")
[[ -z "$out" ]] && ok "penanda Stop dihormati -> guard tidak menyentuh systemctl" \
                || bad "guard meng-enable walau admin sudah Stop ($out)"
rm -f "$D1/etc/bot_off"

printf 'BOT_TOKEN="123:abc"\n' > "$D1/etc/bot.conf"   # token ada, chat id TIDAK
out=$(jalankan "$D1" "source '$D1/guard.sh'; bot_enable_guard")
[[ -z "$out" ]] && ok "konfigurasi tidak lengkap (tanpa CHAT_ID) -> tidak di-enable" \
                || bad "guard meng-enable dengan konfigurasi tidak lengkap ($out)"

echo "=== [5/9] wibu-repair: perilaku (systemctl di-stub) ==="
D2="$TMPROOT/repair"
stub_siap "$D2" || { bad "stub systemctl tidak mencegat di sandbox repair — skenario DIBATALKAN"; }
awk '/^if \[\[ -f \/etc\/wibutunnel\/bot_off \]\]/{f=1} f{print} f&&/^fi$/{exit}' "$REPAIR" \
  | sed "s#/etc/wibutunnel#$D2/etc#g" > "$D2/blok.sh"
[[ -s "$D2/blok.sh" ]] || bad "blok bot wibu-repair tidak bisa diekstrak"

printf 'BOT_TOKEN="1:a"\nCHAT_ID="9"\n' > "$D2/etc/bot.conf"
touch "$D2/etc/bot_off"
out=$(jalankan "$D2" "source '$D2/blok.sh'")
if grep -q 'systemctl enable telegram-bot' <<<"$out" || grep -q 'systemctl restart telegram-bot' <<<"$out"; then
    bad "repair menghidupkan bot yang sengaja di-Stop ($out)"
elif grep -q 'systemctl disable telegram-bot' <<<"$out"; then
    ok "repair menghormati Stop: stop + disable, tanpa enable/restart"
else
    bad "repair tidak men-disable unit saat penanda Stop ada ($out)"
fi

rm -f "$D2/etc/bot_off"
out=$(jalankan "$D2" "source '$D2/blok.sh'")
grep -q 'systemctl enable telegram-bot' <<<"$out" && grep -q 'systemctl restart telegram-bot' <<<"$out" \
  && ok "konfigurasi lengkap tanpa penanda -> repair enable + restart" \
  || bad "repair tidak meng-enable bot yang seharusnya hidup ($out)"

printf 'BOT_TOKEN="1:a"\n' > "$D2/etc/bot.conf"
out=$(jalankan "$D2" "source '$D2/blok.sh'")
grep -q 'systemctl disable telegram-bot' <<<"$out" \
  && ok "konfigurasi tidak lengkap -> repair disable (tidak ada 'failed' tiap boot)" \
  || bad "repair membiarkan unit enabled tanpa CHAT_ID ($out)"

printf "BOT_TOKEN='1:a'\nCHAT_ID='9'\n" > "$D2/etc/bot.conf"   # kutip tunggal
# Yang diuji bukan "harus ditolak", melainkan KESEPAKATAN: keputusan repair harus sama
# dengan keputusan predikat menu atas berkas yang sama. Format apa pun boleh, asal satu suara.
awk '/^bot_conf_lengkap\(\)/,/^}/' "$TARGET" | sed "s#/etc/wibutunnel#$D2/etc#g" > "$D2/predikat.sh"
if bash -c "source '$D2/predikat.sh'; bot_conf_lengkap" >/dev/null 2>&1; then
    harap='enable'; lawan='disable'
else
    harap='disable'; lawan='enable'
fi
out=$(jalankan "$D2" "source '$D2/blok.sh'")
if [[ "$harap" == "enable" ]]; then
    grep -q 'systemctl enable telegram-bot' <<<"$out" \
      && ok "menu dan repair sepakat: berkas berkutip tunggal dinilai LENGKAP oleh keduanya" \
      || bad "predikat menu bilang lengkap tapi repair tidak meng-enable ($out)"
else
    grep -q 'systemctl disable telegram-bot' <<<"$out" && ! grep -q 'systemctl enable telegram-bot' <<<"$out" \
      && ok "menu dan repair sepakat: berkas berkutip tunggal dinilai BELUM LENGKAP oleh keduanya" \
      || bad "predikat menu bilang belum lengkap tapi repair menghidupkan bot ($out)"
fi

echo "=== [6/9] Restore backup menulis penanda Stop ==="
if awk '/bot.conf ikut dipulihkan/,/^    fi$/' "$BACKUP" | grep -q 'touch /etc/wibutunnel/bot_off'; then
    ok "restore menandai bot berhenti (tidak dihidupkan lagi oleh repair/update berikutnya)"
else
    bad "restore mematikan bot tanpa penanda -> repair/update berikutnya menghidupkannya (409)"
fi

echo "=== [7/9] Predikat konfigurasi seragam di installer ==="
python3 - "$SETUP" <<'PY'
import sys
s = open(sys.argv[1], encoding='utf-8').read()
ok = ('CHAT_ID=' in s) and ('BOT_TOKEN' in s)
# blok enable bot harus menuntut keduanya
for i, ln in enumerate(s.splitlines()):
    if 'grep -qE' in ln and 'BOT_TOKEN' in ln:
        window = "\n".join(s.splitlines()[i:i+3])
        if 'CHAT_ID' not in window:
            print("SETUP_TANPA_CHATID"); sys.exit(1)
        break
if 'rm -f /etc/wibutunnel/bot_off' in s:
    print("SETUP_MENGHAPUS_PENANDA"); sys.exit(1)   # re-run setup tidak boleh membatalkan Stop

lines = s.splitlines()
i_marker = next((i for i, ln in enumerate(lines) if 'bot_off' in ln), -1)
i_enable = next((i for i, ln in enumerate(lines) if 'systemctl enable telegram-bot.service' in ln), -1)
if i_marker < 0:
    print("SETUP_TANPA_CABANG_PENANDA"); sys.exit(1)   # installer bisa membatalkan Stop
if i_enable >= 0 and i_marker > i_enable:
    print("SETUP_CABANG_PENANDA_SETELAH_ENABLE"); sys.exit(1)
sys.exit(0 if ok else 1)
PY
[[ $? -eq 0 ]] && ok "installer menuntut token + chat id dan tidak menghapus penanda Stop" \
                || bad "predikat installer beda dari guard/repair, atau menghapus penanda Stop"

echo "=== [8/9] Status boot tetap menunjukkan fakta is-enabled walau penanda ada ==="
if grep -q 'unit: ${text_en}' "$TARGET"; then
    ok "menu menampilkan status unit sebenarnya, bukan hanya 'dimatikan manual'"
else
    bad "penanda menyembunyikan is-enabled (unit bisa hidup saat boot tanpa terlihat)"
fi


echo "=== [9/9] Penulis bot.conf dan pembacanya harus sepakat ==="
D3="$TMPROOT/writer"; mkdir -p "$D3/etc"
WK=$(grep -n "printf 'BOT_TOKEN=" "$SETUP" | head -1 | cut -d: -f1)
if [[ -z "$WK" ]]; then
    bad "tidak menemukan baris penulis bot.conf di setup.sh (format penulis berubah?)"
else
    sed -n "${WK}p" "$SETUP" | sed "s#/etc/wibutunnel#$D3/etc#g" > "$D3/writer.sh"
    awk '/^bot_conf_lengkap\(\)/,/^}/' "$TARGET" | sed "s#/etc/wibutunnel#$D3/etc#g" > "$D3/predikat.sh"

    # (a) berkas hasil tulisan INSTALLER harus dianggap lengkap oleh predikat menu
    : > "$D3/etc/bot.conf"
    bash -c "_bt='111:AAA'; _bc='42'; source '$D3/writer.sh'" >/dev/null 2>&1
    isi=$(tr '\n' ' ' < "$D3/etc/bot.conf")
    if bash -c "source '$D3/predikat.sh'; bot_conf_lengkap" >/dev/null 2>&1; then
        ok "tulisan installer diterima predikat menu (isi: $isi)"
    else
        bad "installer menulis format yang DITOLAK predikatnya sendiri (isi: $isi) — bot tidak akan pernah enabled"
    fi

    # (b) berkas lama tanpa tanda kutip (warisan setup.sh <= v4.1.28) tetap terbaca
    printf 'BOT_TOKEN=111:AAA\nCHAT_ID=42\n' > "$D3/etc/bot.conf"
    if bash -c "source '$D3/predikat.sh'; bot_conf_lengkap" >/dev/null 2>&1; then
        ok "berkas lama tanpa kutip tetap dianggap lengkap (tidak memutus VPS yang sudah jalan)"
    else
        bad "berkas tanpa kutip (format lama) ditolak -> upgrade mematikan bot yang tadinya jalan"
    fi

    # (c) kontrol negatif: berkas kosong harus ditolak
    : > "$D3/etc/bot.conf"
    if bash -c "source '$D3/predikat.sh'; bot_conf_lengkap" >/dev/null 2>&1; then
        bad "berkas KOSONG dianggap lengkap (predikat terlalu longgar)"
    else
        ok "kontrol negatif: berkas kosong ditolak"
    fi
fi

echo
if [[ $FAILS -eq 0 ]]; then
    echo "=== ALL BOT-ENABLE TESTS PASSED ==="
    exit 0
else
    echo "=== $FAILS TES GAGAL ==="
    exit 1
fi
