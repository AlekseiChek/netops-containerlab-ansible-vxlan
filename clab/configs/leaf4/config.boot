interfaces {
    bonding bond0 {
        mode 802.3ad
        lacp-rate fast
        system-mac 02:00:00:00:0b:02
        member {
            interface eth3 {
            }
        }
        evpn {
            es-id 2
            es-sys-mac 02:00:00:00:00:02
            es-df-pref 100
        }
    }
    bridge br10 {
        address 10.10.10.1/24
        mac 02:10:10:00:00:01
        member {
            interface bond0 {
            }
            interface vxlan10 {
            }
        }
    }
    ethernet eth1 {
        address 10.0.1.6/31
        mtu 9500
        evpn {
            uplink
        }
    }
    ethernet eth2 {
        address 10.0.2.6/31
        mtu 9500
        evpn {
            uplink
        }
    }
    ethernet eth3 {
        mtu 9500
    }
    loopback lo {
        address 192.0.2.4/32
    }
    vxlan vxlan10 {
        mtu 1500
        parameters {
            nolearning
        }
        port 4789
        source-address 192.0.2.4
        vni 10010
    }
}
protocols {
    bgp {
        system-as 65004
        parameters {
            router-id 192.0.2.4
            bestpath {
                as-path {
                    multipath-relax
                }
            }
        }
        address-family {
            ipv4-unicast {
                redistribute {
                    connected {
                    }
                }
                maximum-paths {
                    ebgp 2
                }
            }
            l2vpn-evpn {
                advertise-all-vni
            }
        }
        neighbor 10.0.1.7 {
            remote-as 65100
            address-family {
                ipv4-unicast {
                }
                l2vpn-evpn {
                }
            }
        }
        neighbor 10.0.2.7 {
            remote-as 65200
            address-family {
                ipv4-unicast {
                }
                l2vpn-evpn {
                }
            }
        }
    }
}
system {
    host-name leaf4
    login {
        user vyos {
            authentication {
                plaintext-password vyos
            }
        }
    }
}
service {
    ssh {
    }
}
