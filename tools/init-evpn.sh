#!/bin/bash
# Post-deploy EVPN init — run ONCE after containerlab deploy.
#
# WHY: FRR bgpd has a startup race with zebra for L3VNI registration.
# bgpd queries zebra for VNIs before zebra has processed the VRF-VNI
# binding, so bgpd misses VNI 100. Toggling advertise-all-vni forces
# bgpd to re-query zebra and pick it up.
#
# USAGE:
#   cd clab && sudo containerlab deploy -t stage1.clab.yml
#   # wait ~60s for VyOS to boot, then:
#   bash tools/init-evpn.sh

set -e
LAB="${LAB:-stage1}"

echo "[evpn-init] Fixing L3VNI ZAPI registration on all PEs..."
for n in pe1 pe2 pe3 pe4; do
  ctr="clab-${LAB}-${n}"
  echo "  -> $ctr: toggling advertise-all-vni..."
  docker exec "$ctr" vtysh \
    -c "conf t" \
    -c "router bgp 65000" \
    -c " address-family l2vpn evpn" \
    -c "  no advertise-all-vni" \
    -c " exit-address-family" \
    -c "end" 2>/dev/null
  sleep 1
  docker exec "$ctr" vtysh \
    -c "conf t" \
    -c "router bgp 65000" \
    -c " address-family l2vpn evpn" \
    -c "  advertise-all-vni" \
    -c " exit-address-family" \
    -c "end" 2>/dev/null
  echo "     done"
done

echo "[evpn-init] Waiting 15s for EVPN to converge..."
sleep 15

echo "[evpn-init] Verification:"
echo "--- bgp l2vpn evpn summary (rr1) ---"
docker exec "clab-${LAB}-rr1" vtysh -c "show bgp l2vpn evpn summary" 2>/dev/null | grep -E "Neighbor|192\.0\."
echo "--- evpn vni (pe1) ---"
docker exec "clab-${LAB}-pe1" vtysh -c "show evpn vni" 2>/dev/null
echo "--- CE1 -> CE2 ping ---"
docker exec "clab-${LAB}-ce1" ping -c2 -I 198.51.100.1 203.0.113.1 2>/dev/null || echo "PING FAILED — check BGP above"
