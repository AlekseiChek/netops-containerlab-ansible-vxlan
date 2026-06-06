#!/bin/bash
# Post-deploy EVPN convergence helper (safety net).
#
# With the bridge-backed L3VNI SVI baked into config.boot, the L3VNI should
# come up at boot on its own. If bgpd loses the zebra L3VNI race on a given
# boot (no Type-5 routes, "show bgp l2vpn evpn vni" empty), this script does a
# clean FRR restart on the PEs, which re-syncs bgpd with zebra (the SVI and
# router-MAC already exist, so the L3VNI registers correctly).
#
# USAGE (only if EVPN has not converged after deploy):
#   bash tools/init-evpn.sh

set -e
LAB="${LAB:-stage1}"

echo "[evpn-init] Restarting FRR on all PEs to re-sync L3VNI with zebra..."
for n in pe1 pe2 pe3 pe4; do
  ctr="clab-${LAB}-${n}"
  echo "  -> $ctr"
  docker exec "$ctr" systemctl restart frr
done

echo "[evpn-init] Waiting 30s for EVPN to converge..."
sleep 30

echo "[evpn-init] === L3VNI state (pe1) ==="
docker exec "clab-${LAB}-pe1" vtysh -c "show evpn vni 100"
echo "[evpn-init] === EVPN summary (rr1) ==="
docker exec "clab-${LAB}-rr1" vtysh -c "show bgp l2vpn evpn summary" | grep -E "Neighbor|192\.0\."
echo "[evpn-init] === CE1 -> CE2 ==="
docker exec "clab-${LAB}-ce1" ping -c2 -I 198.51.100.1 203.0.113.1 || echo "PING FAILED — inspect output above"
