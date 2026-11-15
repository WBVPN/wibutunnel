#!/bin/bash
# [FIX] Probe dukungan target CLASSIFY: sebagian kernel VPS tanpa modul ini, dan sebelumnya
# 4 aturan gagal setiap menit (journal spam + QoS tidak jalan diam-diam).
iptables -t mangle -F 2>/dev/null && iptables -t mangle -X 2>/dev/null
if iptables -t mangle -A PREROUTING -p icmp -j CLASSIFY --set-class 1:1 2>/dev/null; then
    iptables -t mangle -D PREROUTING -p icmp -j CLASSIFY --set-class 1:1 2>/dev/null
    iptables -t mangle -A PREROUTING -p tcp --tcp-flags ACK ACK -j CLASSIFY --set-class 1:1
    iptables -t mangle -A PREROUTING -p tcp -m length --length 0:128 -j CLASSIFY --set-class 1:1
    iptables -t mangle -A PREROUTING -p udp -m length --length 0:128 -j CLASSIFY --set-class 1:1
    iptables -t mangle -A PREROUTING -p icmp -j CLASSIFY --set-class 1:1
else
    echo "[network-tune] Target CLASSIFY tidak didukung kernel ini - aturan QoS dilewati (bukan error)."
fi
for IFACE in $(ip -o -4 addr show | awk '{print $2}' | grep -v lo); do
    tc qdisc del dev $IFACE root 2>/dev/null
    tc qdisc add dev $IFACE root handle 1: htb default 10 2>/dev/null || { echo "[network-tune] $IFACE: HTB tidak didukung, QoS dilewati"; continue; }
    tc class add dev $IFACE parent 1: classid 1:1 htb rate 1000mbit ceil 1000mbit
    tc qdisc add dev $IFACE parent 1:1 fq_codel quantum 300 ecn
done
