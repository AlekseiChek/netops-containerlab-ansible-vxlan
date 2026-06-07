# netops-containerlab-ansible-vxlan

**3-stage EVPN-VXLAN data-center Clos with ESI-LAG multihoming — no kernel modules, no MPLS, runs anywhere Docker runs.**

A self-contained **network operations lab** you can run on a laptop, NAS or EVE-NG host.
It builds a realistic **DC fabric**: 2 spines + 4 leaves, **eBGP underlay + eBGP EVPN overlay** (no IGP, no route reflectors), **anycast gateway**, **ESI-LAG** dual-homed servers on a **stretched L2VNI** (bridged EVPN Type-2) — plus an **Ansible pipeline** that reboots the fabric with **proven zero packet loss** (drain → reboot → verify → restore, one device at a time).

> **vs. the MPLS variant:** VXLAN is plain UDP/4789 over the eBGP IP underlay. No `mpls_router` kernel module, no `net.mpls.platform_labels` sysctl — it just works wherever Docker runs.

---

## ⚡ Quick start (4 steps)

> Prereqs: **Docker**, **containerlab**, and **Ansible** installed (see [§1 Install the tools](#1-install-the-tools-one-time) if you do not have them). **No kernel modules required.**

```bash
# 1) get the lab
git clone https://github.com/AlekseiChek/netops-containerlab-ansible-vxlan
cd netops-containerlab-ansible-vxlan

# 2) build the topology (8 nodes: 2 spines, 4 leaves, 2 hosts, ~1-2 min)
cd clab && sudo containerlab deploy -t stage1.clab.yml && cd ..

# 3) verify EVPN converged (optional; FIX=1 to nudge if not)
bash tools/init-evpn.sh

# 4) prove a zero-loss rolling reboot of the fabric
cd ansible && ansible-galaxy collection install -r requirements.yml && ansible-playbook playbooks/safe-reboot.yml
```

Watch it live — open a second terminal while step 4 runs:
```bash
docker exec clab-stage1-host1 ping 10.10.10.22
```
The playbook drains → reboots → restores each router one at a time and **asserts 0% packet loss** at the end.
Tear it all down: `sudo containerlab destroy -t clab/stage1.clab.yml --cleanup`

> **`tools/init-evpn.sh` = verification.** In FRR 10.6 the eBGP spines relay EVPN natively and the L2VNI comes up at boot, so no post-deploy fix is normally needed. The script prints the spine EVPN peers, the Ethernet Segments (ESI-LAG/DF) and the host1↔host2 ping. If a boot did not converge, run `FIX=1 bash tools/init-evpn.sh` to restart leaf FRR.

---

## Network scheme

![Clos topology](docs/topology-clos.png)

<sub>Source: [`docs/topology-clos.svg`](docs/topology-clos.svg).</sub>

- **3-stage Clos** — 2 spines (`spine1`,`spine2`), 4 leaves (`leaf1`–`leaf4`). No route reflectors, no IGP.
- **Spines** (AS `65100` / `65200`) — eBGP EVPN relay; no VTEP, no VRF. Spines don't interconnect.
- **Leaves** (AS `65001`–`65004`) — **VTEPs** with an **anycast gateway**, each dual-uplinked to both spines.
- **Underlay:** **eBGP** on `/31` fabric links, loopbacks via `redistribute connected`, `maximum-paths ebgp`.
- **Overlay:** **eBGP `l2vpn-evpn`** on the *same* sessions (spines relay natively in FRR 10.6 — no `retain route-target`).
- **ECMP:** leaves run `bestpath as-path multipath-relax` (paths via spine1/spine2 have different AS-paths).
- **Access:** **ESI-LAG** — each server bonds (LACP/802.3ad) to its two leaves as one **Ethernet Segment** (ES1 = leaf1+leaf2, ES2 = leaf3+leaf4); DF election, no MLAG / peer-link.
- **Service:** one **stretched L2VNI 10010** (`10.10.10.0/24`) + anycast gw `10.10.10.1` on every leaf; **host1↔host2 is bridged EVPN Type-2** across the fabric.

| Node | Role | NOS | ASN | Loopback / VTEP |
|------|------|-----|-----|-----------------|
| spine1 | Spine | VyOS | 65100 | 192.0.2.11 |
| spine2 | Spine | VyOS | 65200 | 192.0.2.12 |
| leaf1 | Leaf / VTEP (ES1) | VyOS | 65001 | 192.0.2.1 |
| leaf2 | Leaf / VTEP (ES1) | VyOS | 65002 | 192.0.2.2 |
| leaf3 | Leaf / VTEP (ES2) | VyOS | 65003 | 192.0.2.3 |
| leaf4 | Leaf / VTEP (ES2) | VyOS | 65004 | 192.0.2.4 |
| host1 | Server, ESI-LAG → leaf1/leaf2 | Linux bond | — | 10.10.10.11/24 |
| host2 | Server, ESI-LAG → leaf3/leaf4 | Linux bond | — | 10.10.10.22/24 |

Fabric: `10.0.1.x` = via-spine1, `10.0.2.x` = via-spine2. One stretched **L2VNI 10010** = `10.10.10.0/24`, anycast gateway `10.10.10.1`.

---

## Feature set (and how to verify it)

| Feature | Where | Verify command |
|---------|-------|----------------|
| **eBGP underlay** (no IGP) | all | `docker exec clab-stage1-leaf1 vtysh -c "show bgp summary"` |
| **ECMP** across both spines | leaves | `docker exec clab-stage1-leaf1 vtysh -c "show ip route 192.0.2.3/32"` (2 next-hops) |
| **eBGP EVPN overlay** | all | `docker exec clab-stage1-spine1 vtysh -c "show bgp l2vpn evpn summary"` |
| **ESI-LAG** Ethernet Segment | leaves | `docker exec clab-stage1-leaf1 vtysh -c "show evpn es"` (Local+Remote, DF) |
| **LACP bond** on the server | hosts | `docker exec clab-stage1-host1 cat /proc/net/bonding/bond0` (MII up, 2 slaves) |
| **L2VNI 10010** stretched | leaves | `docker exec clab-stage1-leaf1 vtysh -c "show evpn vni 10010"` |
| **EVPN Type-2** (host MAC/IP) | leaves | `docker exec clab-stage1-leaf1 vtysh -c "show evpn mac vni 10010"` |
| **end-to-end** | hosts | `docker exec clab-stage1-host1 ping -c2 10.10.10.22` |

**Proof end-to-end** — host1 reaches host2 across the fabric, bridged over the stretched L2VNI (EVPN Type-2, dual-homed via ESI-LAG at both ends):
```bash
docker exec clab-stage1-host1 ping -c2 10.10.10.22            # host1 -> host2 (same subnet, bridged)
```

> **Why VXLAN and not MPLS?** VyOS/FRR implement EVPN over VXLAN only (no MPLS data plane for EVPN).
> VXLAN is plain UDP — no kernel modules, no sysctl tuning, works on any standard host.
> For the MPLS L3VPN variant (SR-MPLS + TI-LFA) see [`netops-containerlab-ansible-mpls`](https://github.com/AlekseiChek/netops-containerlab-ansible-mpls).

---

## 1. Install the tools (one-time)

```bash
# Docker — must be installed and running
docker --version

# containerlab — builds the topology
bash -c "$(curl -sL https://get.containerlab.dev)"
clab version

# Ansible — automates changes
python3 -m pip install --upgrade ansible paramiko
ansible --version

# pull the router images (first time only)
docker pull ghcr.io/sysoleg/vyos-container:latest    # core (VyOS)
docker pull frrouting/frr:latest                     # customers (FRR)
```

---

## 2. Start the lab

```bash
cd clab
sudo containerlab deploy -t stage1.clab.yml
sudo containerlab inspect -t stage1.clab.yml
```

VyOS takes ~30–60 s to boot. If BGP/EVPN looks stuck right after deploy, reset once:
```bash
for n in spine1 spine2 leaf1 leaf2 leaf3 leaf4; do docker exec clab-stage1-$n vtysh -c "clear bgp *"; done
```

**Check end-to-end:**
```bash
docker exec clab-stage1-host1 ping -c2 10.10.10.22
```

**Stop / delete:**
```bash
sudo containerlab destroy -t stage1.clab.yml --cleanup
```

---

## 3. Connect to a node manually

**VyOS core nodes — via SSH** (user `vyos`, password `vyos`):
```bash
ssh vyos@clab-stage1-leaf1
# useful commands:
show bgp l2vpn evpn summary        # EVPN peers + prefix count
show bgp l2vpn evpn                 # EVPN routes (Type-2 MAC/IP, Type-3 IMET)
show evpn mac vni 10010            # learned host MACs
show interfaces vxlan              # VTEP state
show bgp summary                   # eBGP underlay peers
```

**Any node — via docker exec:**
```bash
docker exec -it clab-stage1-leaf1 vtysh
docker exec clab-stage1-spine1 vtysh -c "show bgp l2vpn evpn summary"
docker exec clab-stage1-host1 ip route
```

> Tip: `docker ps` lists all container names (`clab-stage1-<node>`).

---

## 4. The Ansible automation

```bash
cd ../ansible
ansible-galaxy collection install -r requirements.yml
```

Real-world DC operations set — read-only checks (no drain) and change ops (with drain):

| Playbook | Drain? | What it does |
|----------|--------|--------------|
| `facts.yml` | no | Reachability + version + BGP/EVPN status on every fabric node |
| `fabric-validate.yml` | no | **Read-only health gate** — underlay+overlay sessions, VNIs, ES/DF, duplicate-MAC across the whole fabric. Run in CI / scheduled / as the pre-change baseline |
| `compliance-check.yml` | no | Config-intent audit — eBGP (no IGP) / l2vpn-evpn everywhere; VXLAN + ESI-LAG + multipath-relax on leaves |
| `site.yml` | **yes** | Safe rolling config change — per node: drain → precheck → deploy → **EVPN health gate** → undrain |
| `safe-reboot.yml` | **yes** | **Zero-loss rolling reboot** — non-stop host1↔host2 probe asserts 0% loss |
| `drain.yml` / `undrain.yml` | drain-only | Operator maintenance mode — drain a node, do manual work, undrain |

The pre/postchecks are **EVPN-aware**: they gate on underlay *and* overlay BGP fully established, VNIs up, no duplicate-MAC, and endpoint MAC counts not regressing.

```bash
ansible-playbook playbooks/facts.yml                       # quick status
ansible-playbook playbooks/fabric-validate.yml             # full read-only health gate (CI)
ansible-playbook playbooks/compliance-check.yml            # config audit
ansible-playbook playbooks/safe-reboot.yml                 # rolling reboot, zero loss
ansible-playbook playbooks/safe-reboot.yml -e target=site_a
ansible-playbook playbooks/drain.yml   -e target=leaf3     # maintenance mode on
ansible-playbook playbooks/undrain.yml -e target=leaf3     # back in service
```

**Drain = BGP graceful-shutdown (RFC 8326).** One role-agnostic lever: the node re-advertises *all* routes (underlay loopbacks/transit **and** overlay EVPN Type-1/2/3) with the GRACEFUL_SHUTDOWN community + lowest local-pref, so peers immediately prefer the other spine / the ES-peer leaf. Make-before-break, fully reversible.

---

## Repo layout

```
netops-containerlab-ansible-vxlan/
├── clab/
│   ├── stage1.clab.yml             # topology: 10 nodes + 17 links
│   ├── daemons / vtysh.conf        # FRR helpers (CE nodes)
│   └── configs/<node>/
│       ├── <core>/config.boot      # VyOS set-style (pe*/p*/rr*)
│       └── <ce>/frr.conf           # FRR (ce1/ce2)
├── ansible/
│   ├── ansible.cfg
│   ├── requirements.yml
│   ├── inventory/hosts.yml
│   ├── roles/{drain,precheck,deploy,postcheck,compliance}/
│   └── playbooks/{facts,site,safe-reboot,compliance-check}.yml
└── docs/topology.{svg,drawio}
```

---

## Production mapping

| Lab | Production |
|-----|-----------|
| VyOS / FRR containers | Juniper MX / Nokia SR Linux / Arista |
| EVPN-VXLAN L3VPN | Standard DC/SP overlay, same RFC 8365 |
| `serial: 1` Ansible | canary → wave → fleet rollout |
| postcheck asserts | golden-signal health gate |

---

## License

MIT — see `LICENSE`.



