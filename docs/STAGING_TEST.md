# Uji di VPS staging (WAJIB sebelum produksi)

## 0. Aman dulu (jangan langsung di VPS pelanggan)
```bash
# snapshot/backup dulu — ini panel yang mengubah sshd, xray, iptables, cron
tar czf /root/wibutunnel-before-$(date +%F-%H%M).tgz /etc/wibutunnel /etc/xray /usr/local/etc/xray         /usr/local/bin /usr/local/sbin /etc/systemd/system/wibutunnel* 2>/dev/null
crontab -l > /root/crontab-before.txt 2>/dev/null
```
VPS uji ideal: **VPS kosong** (Ubuntu 20.04/22.04), bukan VPS yang sudah melayani pelanggan.

## 1. Uji statis (tidak mengubah sistem, boleh di mana saja)
```bash
git clone <repo> wibutunnel && cd wibutunnel
bash tests/test_hardening.sh          # target: 120 PASS / 0 FAIL
bash tests/test_license_enforcement.sh # target: 15 PASS / 0 FAIL
bash -n setup.sh && for f in sbin/* menu/*.sh; do bash -n "$f" || echo "GAGAL $f"; done
sha256sum -c SHA256SUMS 2>&1 | grep -v ': OK' | head        # harus kosong
```

## 2. JANGAN jalankan di produksi (destruktif — menulis /etc + restart layanan)
`tests/test_auto_repair.sh` (menghapus host key dropbear + jalankan `wibu-repair`), lalu
`test_xray_api_sync`, `test_bot_lock_unlock`, `test_ssh_integration`, `test_expiry_and_xp`,
`test_algojo_ssh`, `test_deep_audit_fixes`. Jalankan **hanya di VPS staging**.

## 3. Pasang di staging
```bash
bash setup.sh            # perhatikan: verifikasi hash installer Xray harus lulus
systemctl list-units --type=service | grep -E 'xray|dropbear|haproxy|ws-stunnel|algojo|wibu|telegram'
```

## 4. Verifikasi patch keamanan (yang paling penting)
```bash
# 1) API Xray tidak bisa diakses non-root  -> harus "DIHARAPKAN DITOLAK"
iptables -S OUTPUT | grep 10085
su - <user_pelanggan> -c 'command -v xray >/dev/null && xray api statsquery --server=127.0.0.1:10085; echo exit=$?'
#    (atau dari klien: ssh -N -L 10085:127.0.0.1:10085 user@host  lalu curl 127.0.0.1:10085 -> harus gagal)

# 2) token tidak lagi terlihat di ps saat bot mengirim pesan
systemctl restart telegram-bot; ps aux | grep -c 'api.telegram.org/bot'      # harus 0

# 3) izin berkas
stat -c '%a %n' /etc/xray/*_exp.conf /var/log/xray /var/log/xray/access.log  # exp.conf 600, dir 750, log 640

# 4) update menolak berkas tanpa hash benar
WIBU_REF=v4.0.6-fixed /usr/local/bin/m-setting   # menu 10 -> Update; log harus menyebut verifikasi SHA256
#    uji negatif: rusak satu baris SHA256SUMS di klon lokal -> update harus DITOLAK

# 5) enforcement
useradd -m -s /bin/bash tes1 && echo 'tes1:x' | chpasswd
#    buka 2 sesi SSH melebihi limit -> harus terkunci; cek: cat /etc/wibutunnel/locked_users.db
#    pastikan pesan unlock tidak kosong: grep tes1 /etc/wibutunnel/locked_users.db

# 6) reboot: aturan firewall + 8 layanan kembali hidup
reboot; sleep 60; iptables -S OUTPUT | grep 10085
```

## 5. Rollback
```bash
cp -a /usr/local/share/wibutunnel/backup/<nama>.<ts> /usr/local/bin/<nama>   # cadangan otomatis dari safe_update
# atau pulihkan penuh dari tar.gz langkah 0
```
