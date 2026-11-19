#!/bin/bash
# [FIX] Probe dukungan target CLASSIFY: sebagian kernel VPS tanpa modul ini, dan sebelumnya
# 4 aturan gagal setiap menit (journal spam + QoS tidak jalan diam-diam).
#
# [FIX] JANGAN `iptables -t mangle -F`: skrip ini dijalankan berkala, jadi flush akan menghapus
# aturan mangle MILIK VPS (QoS lain, firewall, fail2ban) tiap putaran. Yang dihapus hanya 4 aturan
# CLASSIFY milik panel ini — dan penghapusan itu juga yang membuat penambahan di bawah idempoten.
WIBU_MANGLE_RULES=(
    "-p icmp -j CLASSIFY --set-class 1:1"
    "-p tcp --tcp-flags ACK ACK -j CLASSIFY --set-class 1:1"
    "-p tcp -m length --length 0:128 -j CLASSIFY --set-class 1:1"
    "-p udp -m length --length 0:128 -j CLASSIFY --set-class 1:1"
)

wibu_mangle_del() {
    local spec
    for spec in "${WIBU_MANGLE_RULES[@]}"; do
        while iptables -t mangle -C PREROUTING $spec 2>/dev/null; do
            iptables -t mangle -D PREROUTING $spec 2>/dev/null || break
        done
    done
}

if iptables -t mangle -A PREROUTING -p icmp -j CLASSIFY --set-class 1:1 2>/dev/null; then
    wibu_mangle_del                                       # termasuk aturan probe di atas
    for spec in "${WIBU_MANGLE_RULES[@]}"; do
        iptables -t mangle -A PREROUTING $spec 2>/dev/null
    done
else
    echo "[network-tune] Target CLASSIFY tidak didukung kernel ini - aturan QoS dilewati (bukan error)."
fi
for IFACE in $(ip -o -4 addr show | awk '{print $2}' | grep -v lo); do
    tc qdisc del dev $IFACE root 2>/dev/null
    tc qdisc add dev $IFACE root handle 1: htb default 10 2>/dev/null || { echo "[network-tune] $IFACE: HTB tidak didukung, QoS dilewati"; continue; }
    tc class add dev $IFACE parent 1: classid 1:1 htb rate 1000mbit ceil 1000mbit
    tc qdisc add dev $IFACE parent 1:1 fq_codel quantum 300 ecn
done
