interfaces {
    bridge br100 {
        member {
            interface vxlan100 {
            }
        }
        vrf CUST
    }
    ethernet eth1 {
        address 10.0.0.14/31
        mtu 9500
    }
    ethernet eth2 {
        address 10.0.0.16/31
        mtu 9500
    }
    ethernet eth3 {
        address 10.1.2.2/31
        mtu 9500
        vrf CUST
    }
    loopback lo {
        address 192.0.2.4/32
    }
    vxlan vxlan100 {
        mtu 1500
        parameters {
            nolearning
        }
        port 4789
        source-address 192.0.2.4
        vni 100
    }
}
protocols {
    isis {
        net 49.0001.1920.0000.2004.00
        level level-2
        metric-style wide
        interface eth1 {
            network point-to-point
        }
        interface eth2 {
            network point-to-point
        }
        interface lo {
            passive
        }
    }
    bgp {
        system-as 65000
        parameters {
            router-id 192.0.2.4
        }
        address-family {
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
        neighbor 192.0.2.101 {
            remote-as 65000
            update-source lo
            address-family {
                ipv4-unicast {
                    nexthop-self {
                    }
                }
                l2vpn-evpn {
                }
            }
        }
        neighbor 192.0.2.102 {
            remote-as 65000
            update-source lo
            address-family {
                ipv4-unicast {
                    nexthop-self {
                    }
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
                system-as 65000
                parameters {
                    router-id 192.0.2.4
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
                neighbor 10.1.2.3 {
                    remote-as 65002
                    address-family {
                        ipv4-unicast {
                        }
                    }
                }
            }
        }
    }
}
system {
    host-name pe4
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
