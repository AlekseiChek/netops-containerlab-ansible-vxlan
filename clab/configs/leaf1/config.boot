interfaces {
    bonding bond0 {
        mode 802.3ad
        lacp-rate fast
        system-mac 02:00:00:00:0a:01
        member {
            interface eth3 {
            }
        }
        evpn {
            es-id 1
            es-sys-mac 02:00:00:00:00:01
            es-df-pref 200
        }
    }
    bridge br10 {
        address 10.1.10.1/24
        mac 02:1a:10:00:00:0a
        member {
            interface bond0 {
            }
            interface vxlan10 {
            }
        }
        vrf CUST
    }
    bridge br100 {
        member {
            interface vxlan100 {
            }
        }
        vrf CUST
    }
    ethernet eth1 {
        address 10.0.1.0/31
        mtu 9500
    }
    ethernet eth2 {
        address 10.0.2.0/31
        mtu 9500
    }
    ethernet eth3 {
        mtu 9500
    }
    loopback lo {
        address 192.0.2.1/32
    }
    vxlan vxlan10 {
        mtu 1500
        parameters {
            nolearning
        }
        port 4789
        source-address 192.0.2.1
        vni 10010
    }
    vxlan vxlan100 {
        mtu 1500
        parameters {
            nolearning
        }
        port 4789
        source-address 192.0.2.1
        vni 100
    }
}
protocols {
    bgp {
        system-as 65001
        parameters {
            router-id 192.0.2.1
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
                advertise {
                    ipv4 {
                        unicast {
                        }
                    }
                }
            }
        }
        neighbor 10.0.1.1 {
            remote-as 65100
            address-family {
                ipv4-unicast {
                }
                l2vpn-evpn {
                }
            }
        }
        neighbor 10.0.2.1 {
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
vrf {
    name CUST {
        table 100
        vni 100
        protocols {
            bgp {
                system-as 65001
                parameters {
                    router-id 192.0.2.1
                }
                address-family {
                    ipv4-unicast {
                        redistribute {
                            connected {
                            }
                        }
                    }
                    l2vpn-evpn {
                        advertise {
                            ipv4 {
                                unicast {
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
system {
    host-name leaf1
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
