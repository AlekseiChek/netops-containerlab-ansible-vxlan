#!/bin/bash
# Post-deploy EVPN init for the eBGP Clos + ESI-LAG. Run once after deploy.
#
# 1) SPINES (p1,p2) relay EVPN with no local VRF -> they need "retain route-target
#    all" so they keep/re-advertise EVPN routes whose RT they do not import.
#    VyOS cannot express this in config.boot, so it is applied via FRR here.
# 2) LEAVES (pe1-4): a clean frr restart re-syncs the L3VNI/Ethernet-Segment
#    state with zebra if bgpd lost the boot race.
#
#   bash tools/init-evpn.sh

set -e
LAB="${LAB:-stage1}"

echo "[init] spines: retain route-target all (EVPN relay)"
for s in p1 p2; do
  asn=$([ "$s" = "p1" ] && echo 65100 || echo 65200)
  docker exec "clab-${LAB}-${s}" vtysh \
    -c "conf t" \
    -c "router bgp ${asn}" \
    -c " address-family l2vpn evpn" \
    -c "  retain route-target all" \
    -c " exit-address-family" \
    -c "end" 2>/dev/null && echo "  ${s} ok" || echo "  ${s}: command rejected (check FRR syntax)"
done

echo "[init] leaves: re-sync L3VNI / Ethernet-Segment"
for l in pe1 pe2 pe3 pe4; do
  docker exec "clab-${LAB}-${l}" systemctl restart frr
done

echo "[init] waiting 30s for EVPN to converge..."
sleep 30

echo "=== spine EVPN peers (p1) ==="
docker exec "clab-${LAB}-p1" vtysh -c "show bgp l2vpn evpn summary" | grep -E "Neighbor|10\.0\." | head
echo "=== L3VNI 100 (pe1) ==="
docker exec "clab-${LAB}-pe1" vtysh -c "show evpn vni 100" | grep -E "VNI:|State:|L2 VNIs:|Router MAC:"
echo "=== Ethernet Segment / ESI-LAG (pe1) ==="
docker exec "clab-${LAB}-pe1" vtysh -c "show evpn es" || true
echo "=== ce1 host -> anycast gateway 10.1.10.1 ==="
docker exec "clab-${LAB}-ce1" ping -c2 10.1.10.1 || echo "PING FAILED — check ESI/anycast above"
