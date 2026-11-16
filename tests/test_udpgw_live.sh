#!/bin/bash
# ==========================================
# Tes LANGSUNG (live) UDP gateway badvpn-udpgw
# ==========================================
# Dijalankan DI VPS panel (butuh badvpn-udpgw aktif). Membuktikan UDP benar-benar
# mengalir lewat gateway, bukan hanya "layanan aktif".
#
# Dua detail protokol yang WAJIB benar (ini yang membuat uji pertama gagal):
#   1. Badan TCP dibingkai PacketProto: [u16 panjang little-endian][paket udpgw].
#   2. Paket udpgw: [u8 flags][u16 conid LE][alamat+port]... dengan port pada blok
#      alamat memakai urutan NETWORK (big-endian) — bukan little-endian seperti conid.
#
# Pemakaian: bash tests/test_udpgw_live.sh [port] [target-ip] [target-port]
set -uo pipefail
PORT="${1:-7300}"
DST_IP="${2:-1.1.1.1}"
DST_PORT="${3:-53}"

if ! command -v python3 >/dev/null 2>&1; then
    echo "SKIP: python3 tidak ada"; exit 0
fi
if ! ss -tln 2>/dev/null | grep -q ":${PORT} "; then
    echo "SKIP: tidak ada yang mendengarkan di 127.0.0.1:${PORT} (udpgw belum dipasang)"
    exit 0
fi

echo "=== uji UDP lewat udpgw 127.0.0.1:${PORT} -> ${DST_IP}:${DST_PORT} ==="
python3 - "$PORT" "$DST_IP" "$DST_PORT" <<'PY'
import random, socket, struct, sys
port, dst_ip, dst_port = int(sys.argv[1]), sys.argv[2], int(sys.argv[3])

def dns_query(name, qid):
    q = struct.pack("!HHHHHH", qid, 0x0100, 1, 0, 0, 0)
    for part in name.split("."):
        q += bytes([len(part)]) + part.encode()
    return q + b"\x00" + struct.pack("!HH", 1, 1)

qid = random.randint(1, 65535)
body = struct.pack("<BH", 0, 0)                                  # flags=0 (IPv4), conid LE
body += socket.inet_aton(dst_ip) + struct.pack("!H", dst_port)   # alamat+port = network order
body += dns_query("example.com", qid)
pkt = struct.pack("<H", len(body)) + body                        # bingkai PacketProto

s = socket.create_connection(("127.0.0.1", port), timeout=8)
s.settimeout(8)
s.sendall(pkt)
data = s.recv(4096)
if len(data) < 2:
    print("  GAGAL: tidak ada balasan"); sys.exit(1)
plen = struct.unpack("<H", data[:2])[0]
inner = data[2:2 + plen]
if len(inner) < 9:
    print("  GAGAL: balasan terlalu pendek"); sys.exit(1)
flags = inner[0]
off = 3 + (16 if flags & (1 << 3) else 6)
payload = inner[off:]
if len(payload) < 12:
    print("  GAGAL: tanpa muatan DNS"); sys.exit(1)
rid, fl, qd, an = struct.unpack("!HHHH", payload[:8])
if rid != qid:
    print("  GAGAL: transaction id tidak cocok"); sys.exit(1)
print("  balasan %d byte dari %s:%d, rcode=%d, jawaban=%d" % (len(payload), dst_ip, dst_port, fl & 0xF, an))
if (fl & 0xF) == 0 and an >= 1:
    print("  LULUS: UDP benar-benar mengalir lewat gateway panel"); sys.exit(0)
print("  GAGAL: jawaban DNS kosong"); sys.exit(1)
PY
rc=$?
[[ "$rc" -eq 0 ]] && echo "=== LIVE UDPGW TEST PASSED ===" || echo "=== LIVE UDPGW TEST FAILED (rc=$rc) ==="
exit "$rc"
