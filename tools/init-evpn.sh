#!/bin/bash
# EVPN-Clos + ESI-LAG verification (post-deploy).
#
# In FRR 10.6.1 the eBGP spines relay EVPN by default (no "retain route-target
# all" needed), and the bridge-backed L3VNI SVI comes up at boot. Normally NO
# post-deploy action is required; this just verifies the fabric.
# Nudge if a boot didn't converge:  FIX=1 bash tools/init-evpn.sh
set -e
LAB="${LAB:-stage1}"

if [ "${FIX:-0}" = "1" ]; then
  echo "[fix] restarting FRR on leaves..."
  for l in leaf1 leaf2 leaf3 leaf4; do docker exec "clab-${LAB}-${l}" systemctl restart frr; done
  echo "[fix] waiting 30s..."; sleep 30
fi

echo "=== spine EVPN peers (spine1) ==="
docker exec "clab-${LAB}-spine1" vtysh -c "show bgp l2vpn evpn summary" | grep -E "Neighbor|10\.0\." | head
echo "=== L3VNI 100 (leaf1) ==="
docker exec "clab-${LAB}-leaf1" vtysh -c "show evpn vni 100" | grep -E "VNI:|State:|L2 VNIs:|Router MAC:"
echo "=== Ethernet Segments (leaf1 site-A / leaf3 site-B) ==="
docker exec "clab-${LAB}-leaf1" vtysh -c "show evpn es"
docker exec "clab-${LAB}-leaf3" vtysh -c "show evpn es"
echo "=== host1 -> host2 across the fabric (Type-5 routed) ==="
docker exec "clab-${LAB}-host1" ping -c2 10.2.20.10 || echo "PING FAILED — inspect above"
