#!/bin/bash
# EVPN-Clos + ESI-LAG post-deploy converge + verify.
#
# Two boot-order facts on this lab:
#  1) VyOS leaves take 30-60s to apply config.boot; the host bonds (clab exec) come
#     up first, so LACP can negotiate with NO partner (Partner Mac 00:00:00:00:00:00).
#     -> we bounce the host bonds so LACP re-forms with the now-ready leaves.
#  2) If a given boot didn't converge EVPN, FIX=1 also restarts leaf FRR.
#
#   bash tools/init-evpn.sh            # bounce host bonds + verify
#   FIX=1 bash tools/init-evpn.sh      # also restart leaf FRR (deeper nudge)
# (no 'set -e': a grep with no match must not abort the script)
LAB="${LAB:-stage1}"

if [ "${FIX:-0}" = "1" ]; then
  echo "[fix] restarting FRR on leaves..."
  for l in leaf1 leaf2 leaf3 leaf4; do docker exec "clab-${LAB}-${l}" systemctl restart frr; done
  echo "[fix] waiting 30s..."; sleep 30
fi

echo "[init] bouncing host bonds so LACP re-negotiates with the leaves..."
for h in host1 host2; do
  docker exec "clab-${LAB}-${h}" sh -c 'ip link set bond0 down; sleep 1; ip link set bond0 up' 2>/dev/null
done
echo "[init] waiting 10s for LACP + EVPN..."; sleep 10

echo "=== spine EVPN peers (spine1) ==="
docker exec "clab-${LAB}-spine1" vtysh -c "show bgp l2vpn evpn summary" 2>/dev/null | grep -E "Neighbor|10\.0\." || echo "  (no EVPN peers yet)"
echo "=== L2VNI 10010 (leaf1) ==="
docker exec "clab-${LAB}-leaf1" vtysh -c "show evpn vni 10010" 2>/dev/null | grep -E "VNI:|Type:|VxLAN|#MACs" || echo "  (VNI not up yet)"
echo "=== host1 bond LACP (Partner Mac should be 02:00:00:00:0a:01, not zeros) ==="
docker exec "clab-${LAB}-host1" sh -c "cat /proc/net/bonding/bond0 2>/dev/null | grep -E 'MII Status|Partner Mac'" || echo "  (bond not formed)"
echo "=== Ethernet Segments (leaf1 / leaf3) ==="
docker exec "clab-${LAB}-leaf1" vtysh -c "show evpn es" 2>/dev/null || true
docker exec "clab-${LAB}-leaf3" vtysh -c "show evpn es" 2>/dev/null || true
echo "=== host1 -> host2 (bridged, stretched L2VNI) ==="
docker exec "clab-${LAB}-host1" ping -c3 10.10.10.22 || echo "  PING FAILED — re-run, or FIX=1 bash tools/init-evpn.sh"
