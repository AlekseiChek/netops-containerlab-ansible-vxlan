#!/bin/bash
# EVPN-Clos + ESI-LAG verification (post-deploy).
#
# In FRR 10.6 the eBGP spines relay EVPN by default and the bridge-backed L3VNI
# SVI comes up at boot, so normally NO post-deploy fix is needed; this verifies.
# Nudge if a boot didn't converge:  FIX=1 bash tools/init-evpn.sh
# (no 'set -e' on purpose: a grep with no match must not abort the script)
LAB="${LAB:-stage1}"

if [ "${FIX:-0}" = "1" ]; then
  echo "[fix] restarting FRR on leaves..."
  for l in leaf1 leaf2 leaf3 leaf4; do docker exec "clab-${LAB}-${l}" systemctl restart frr; done
  echo "[fix] waiting 30s..."; sleep 30
fi

echo "=== spine EVPN peers (spine1) ==="
docker exec "clab-${LAB}-spine1" vtysh -c "show bgp l2vpn evpn summary" 2>/dev/null | grep -E "Neighbor|10\.0\." || echo "  (no EVPN peers yet)"
echo "=== L2VNI 10010 (leaf1) ==="
docker exec "clab-${LAB}-leaf1" vtysh -c "show evpn vni 10010" 2>/dev/null | grep -E "VNI:|Type:|VxLAN|#MACs" || echo "  (L3VNI not up yet)"
echo "=== Ethernet Segment site-A (leaf1) ==="
docker exec "clab-${LAB}-leaf1" vtysh -c "show evpn es" 2>/dev/null || true
echo "=== Ethernet Segment site-B (leaf3) ==="
docker exec "clab-${LAB}-leaf3" vtysh -c "show evpn es" 2>/dev/null || true
echo "=== host1 bond LACP ==="
docker exec "clab-${LAB}-host1" sh -c "cat /proc/net/bonding/bond0 2>/dev/null | grep -E 'MII Status|Partner Mac|Slave Interface'" || echo "  (bond not formed)"
echo "=== host1 -> host2 (bridged, stretched L2VNI) ==="
docker exec "clab-${LAB}-host1" ping -c2 10.10.10.22 || echo "  PING FAILED — inspect above"

