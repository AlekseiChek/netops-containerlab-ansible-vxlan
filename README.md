# netops-containerlab-ansible-vxlan

**Redundant SP fabric with EVPN-VXLAN L3VPN — no kernel modules, no MPLS, deployable anywhere Docker runs.**

A self-contained **network operations lab** you can run on a laptop, NAS or EVE-NG host.
It builds a realistic **3-stage Clos data-center fabric**: **eBGP underlay + eBGP EVPN overlay** (no IGP, no route reflectors), **EVPN-VXLAN** putting both customer sites in one shared L3VNI, and an **Ansible pipeline** that reboots the fabric with **proven zero packet loss** — drain → reboot → verify → restore, one device at a time.

> **vs. the MPLS variant:** VXLAN is plain UDP/4789 over the eBGP IP underlay. No `mpls_router` kernel module, no `net.mpls.platform_labels` sysctl — it just works wherever Docker runs.

---

## ⚡ Quick start (4 steps)

> Prereqs: **Docker**, **containerlab**, and **Ansible** installed (see [§1 Install the tools](#1-install-the-tools-one-time) if you do not have them). **No kernel modules required.**

```bash
# 1) get the lab
git clone https://github.com/AlekseiChek/netops-containerlab-ansible-vxlan
cd netops-containerlab-ansible-vxlan

# 2) build the topology (8 nodes: 2 spines, 4 leaves, 2 customers, ~1–2 min)
cd clab && sudo containerlab deploy -t stage1.clab.yml && cd ..

# 3) EVPN init — REQUIRED once (spine retain-RT + L3VNI sync; see note below)
bash tools/init-evpn.sh

# 4) prove a zero-loss rolling reboot of the fabric
cd ansible && ansible-galaxy collection install -r requirements.yml && ansible-playbook playbooks/safe-reboot.yml
```

Watch it live — open a second terminal while step 4 runs:
```bash
docker exec clab-stage1-ce1 ping -I 198.51.100.1 203.0.113.1
```
The playbook drains → reboots → restores each router one at a time and **asserts 0% packet loss** at the end.
Tear it all down: `sudo containerlab destroy -t clab/stage1.clab.yml --cleanup`

> **Required once after deploy — `bash tools/init-evpn.sh`:** the **spines** need `retain route-target all` to relay EVPN with no local VRF (VyOS can't express it in `config.boot`, so it's applied to the spines via FRR), and it re-syncs the leaf L3VNIs. Without it the spines drop EVPN routes and CE↔CE won't work.

---

## Network scheme

![Clos topology](docs/topology-clos.png)

<sub>Source: [`docs/topology-clos.svg`](docs/topology-clos.svg).</sub>

- **3-stage Clos** — 2 spines (`p1`,`p2`), 4 leaves (`pe1`–`pe4`). No route reflectors, no IGP.
- **Spines** `p1` (AS `65100`) / `p2` (AS `65200`) — pure eBGP relay; no VTEP, no VRF. Spines don't interconnect.
- **Leaves** `pe1`–`pe4` (AS `65001`–`65004`) — **VTEPs**, each dual-uplinked to both spines.
- **Underlay:** **eBGP** on `/31` fabric links, loopbacks via `redistribute connected`, `maximum-paths ebgp`.
- **Overlay:** **eBGP `l2vpn-evpn`** on the *same* sessions — spines relay EVPN (`retain route-target all`). No RR.
- **ECMP:** leaves run `bestpath as-path multipath-relax` (paths via spine1/spine2 have different AS-paths).
- **Service:** `ce1` + `ce2` share **VRF `CUST`** (L3VNI 100, bridge-backed SVI); customer prefixes ride **EVPN Type-5**.

| Node | Role | NOS | ASN | Loopback / VTEP |
|------|------|-----|-----|-----------------|
| p1 | Spine | VyOS | 65100 | 192.0.2.11 |
| p2 | Spine | VyOS | 65200 | 192.0.2.12 |
| pe1 | Leaf / VTEP | VyOS | 65001 | 192.0.2.1 |
| pe2 | Leaf / VTEP | VyOS | 65002 | 192.0.2.2 |
| pe3 | Leaf / VTEP | VyOS | 65003 | 192.0.2.3 |
| pe4 | Leaf / VTEP | VyOS | 65004 | 192.0.2.4 |
| ce1 | Customer → pe1/pe2 | FRR | 65010 | 198.51.100.1 |
| ce2 | Customer → pe3/pe4 | FRR | 65020 | 203.0.113.1 |

Fabric: `10.0.1.x` = via-spine1, `10.0.2.x` = via-spine2.

---

## Feature set (and how to verify it)

| Feature | Where | Verify command |
|---------|-------|----------------|
| **eBGP underlay** (no IGP) | all | `docker exec clab-stage1-pe1 vtysh -c "show bgp summary"` |
| **ECMP** across both spines | leaves | `docker exec clab-stage1-pe1 vtysh -c "show ip route 192.0.2.3/32"` (2 next-hops) |
| **eBGP EVPN overlay** | all | `docker exec clab-stage1-pe1 vtysh -c "show bgp l2vpn evpn summary"` |
| **EVPN Type-5** routes | leaves | `docker exec clab-stage1-pe1 vtysh -c "show bgp l2vpn evpn route type prefix"` |
| **VRF CUST** (L3VNI 100) | leaves | `docker exec clab-stage1-pe1 vtysh -c "show evpn vni 100"` (State: Up) |
| **VXLAN** tunnel | leaves | `docker exec clab-stage1-pe1 ip -d link show vxlan100` |
| **spine EVPN relay** | spines | `docker exec clab-stage1-p1 vtysh -c "show bgp l2vpn evpn summary"` |

**Proof the two customers share one VRF** — CE1 should learn CE2's prefix over the EVPN-VXLAN and ping end-to-end:
```bash
docker exec clab-stage1-ce1 vtysh -c "show ip route 203.0.113.0/24"   # learned via EVPN
docker exec clab-stage1-ce1 ping -c2 -I 198.51.100.1 203.0.113.1      # CE1 -> CE2 across VXLAN
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
for n in p1 p2 pe1 pe2 pe3 pe4; do docker exec clab-stage1-$n vtysh -c "clear bgp *"; done
```

**Check end-to-end:**
```bash
docker exec clab-stage1-ce1 ping -c2 -I 198.51.100.1 203.0.113.1
```

**Stop / delete:**
```bash
sudo containerlab destroy -t stage1.clab.yml --cleanup
```

---

## 3. Connect to a node manually

**VyOS core nodes — via SSH** (user `vyos`, password `vyos`):
```bash
ssh vyos@clab-stage1-pe1
# useful commands:
show bgp l2vpn evpn summary        # EVPN peers + prefix count
show bgp l2vpn evpn route type prefix   # Type-5 EVPN routes
show ip route vrf CUST             # VRF routing table
show interfaces vxlan              # VTEP state
show bgp summary                   # eBGP underlay peers
```

**Any node — via docker exec:**
```bash
docker exec -it clab-stage1-pe1 vtysh
docker exec clab-stage1-p1 vtysh -c "show bgp l2vpn evpn summary"
docker exec clab-stage1-ce1 vtysh -c "show ip route"
```

> Tip: `docker ps` lists all container names (`clab-stage1-<node>`).

---

## 4. The Ansible automation

```bash
cd ../ansible
ansible-galaxy collection install -r requirements.yml
```

| Playbook | What it does | Changes network? |
|----------|-------------|-----------------|
| `facts.yml` | Connectivity check — SSH + BGP summary on every core node | No |
| `site.yml` | Safe config change — drain → precheck → deploy → postcheck → undrain | Yes |
| `safe-reboot.yml` | **Zero-loss rolling reboot** — proven by non-stop CE1↔CE2 ping | Reboots only |
| `compliance-check.yml` | Audit — eBGP (no IGP) / l2vpn-evpn everywhere; VXLAN + VRF CUST + multipath-relax on leaves | No |

```bash
ansible-playbook playbooks/facts.yml                       # connectivity check first
ansible-playbook playbooks/safe-reboot.yml                 # whole core, one at a time
ansible-playbook playbooks/safe-reboot.yml -e target=site_b
ansible-playbook playbooks/compliance-check.yml            # audit
```

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
