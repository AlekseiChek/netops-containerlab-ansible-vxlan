#!/bin/bash
# EVPN-Clos + ESI-LAG verification (post-deploy).
#
# In FRR 10.6.1 the eBGP spines relay EVPN by default (no "retain route-target
# all" needed — eBGP transit re-advertises regardless of RT import), and the
# bridge-backed L3VNI SVI comes up at boot. So normally NO post-deploy action is
# required; this script just verifies the fabric.
#
# If EVPN has not converged on some boot, nudge it:  FIX=1 bash tools/init-evpn.sh
set -e
LAB="${LAB:-stage1}"

if [ "${FIX:-0}" = "1" ]; then
  echo "[fix] restarting FRR on leaves to re-sync L3VNI/ES..."
  for l in pe1 pe2 pe3 pe4; do docker exec "clab-${LAB}-${l}" systemctl restart frr; done
  echo "[fix] waiting 30s..."; sleep 30
fi

echo "=== spine EVPN peers (p1) ==="
docker exec "clab-${LAB}-p1" vtysh -c "show bgp l2vpn evpn summary" | grep -E "Neighbor|10\.0\." | head
echo "=== L3VNI 100 (pe1) ==="
docker exec "clab-${LAB}-pe1" vtysh -c "show evpn vni 100" | grep -E "VNI:|State:|L2 VNIs:|Router MAC:"
echo "=== Ethernet Segments (pe1) ==="
docker exec "clab-${LAB}-pe1" vtysh -c "show evpn es"
echo "=== ce1 host -> anycast gateway 10.1.10.1 ==="
docker exec "clab-${LAB}-ce1" ping -c2 10.1.10.1 || echo "PING FAILED — inspect above"
