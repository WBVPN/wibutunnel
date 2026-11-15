#!/bin/bash
# Wibu Tunneling - paksa akses root-only ke port API Xray (mitigasi utama).
# Tambahkan port API baru ke API_PORTS bila skema berubah.
API_PORTS="10085"
rc=0
for p in $API_PORTS; do
    # [FIX] Buang SEMUA salinan lama dulu. `iptables -C` tidak mengenali aturan hasil
    # restore /etc/iptables/rules.v4 (spesifikasi target REJECT dinormalisasi berbeda),
    # sehingga tiap boot menambah satu salinan lagi. Dedupe lewat spesifikasi persis
    # dari `iptables -S` -> pasti terhapus, lalu pasang tepat satu aturan.
    while :; do
        spec=$(iptables -S OUTPUT 2>/dev/null | awk -v p="$p" 'index($0,"-j REJECT") && index($0,"--dport "p){sub(/^-A OUTPUT /,"");print;exit}')
        [ -z "$spec" ] && break
        # shellcheck disable=SC2086
        iptables -D OUTPUT $spec 2>/dev/null || break
    done
    iptables -I OUTPUT 1 -m owner ! --uid-owner 0 -p tcp -d 127.0.0.1 --dport "$p" -j REJECT || rc=1
done
exit $rc
