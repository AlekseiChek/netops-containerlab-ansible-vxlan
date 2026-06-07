interfaces {
    ethernet eth1 {
        address 10.0.1.1/31
        mtu 9500
    }
    ethernet eth2 {
        address 10.0.1.3/31
        mtu 9500
    }
    ethernet eth3 {
        address 10.0.1.5/31
        mtu 9500
    }
    ethernet eth4 {
        address 10.0.1.7/31
        mtu 9500
    }
    loopback lo {
        address 192.0.2.11/32
    }
}
protocols {
    bgp {
        system-as 65100
        parameters {
            router-id 192.0.2.11
        }
        address-family {
            ipv4-unicast {
                redistribute {
                    connected {
                    }
                }
                maximum-paths {
                    ebgp 4
                }
            }
        }
        neighbor 10.0.1.0 {
            remote-as 65001
            address-family {
                ipv4-unicast {
                }
                l2vpn-evpn {
                }
            }
        }
        neighbor 10.0.1.2 {
            remote-as 65002
            address-family {
                ipv4-unicast {
                }
                l2vpn-evpn {
                }
            }
        }
        neighbor 10.0.1.4 {
            remote-as 65003
            address-family {
                ipv4-unicast {
                }
                l2vpn-evpn {
                }
            }
        }
        neighbor 10.0.1.6 {
            remote-as 65004
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
    host-name spine1
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
