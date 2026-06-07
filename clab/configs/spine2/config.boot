interfaces {
    ethernet eth1 {
        address 10.0.2.1/31
        mtu 9500
    }
    ethernet eth2 {
        address 10.0.2.3/31
        mtu 9500
    }
    ethernet eth3 {
        address 10.0.2.5/31
        mtu 9500
    }
    ethernet eth4 {
        address 10.0.2.7/31
        mtu 9500
    }
    loopback lo {
        address 192.0.2.12/32
    }
}
protocols {
    bgp {
        system-as 65200
        parameters {
            router-id 192.0.2.12
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
        neighbor 10.0.2.0 {
            remote-as 65001
            address-family {
                ipv4-unicast {
                }
                l2vpn-evpn {
                }
            }
        }
        neighbor 10.0.2.2 {
            remote-as 65002
            address-family {
                ipv4-unicast {
                }
                l2vpn-evpn {
                }
            }
        }
        neighbor 10.0.2.4 {
            remote-as 65003
            address-family {
                ipv4-unicast {
                }
                l2vpn-evpn {
                }
            }
        }
        neighbor 10.0.2.6 {
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
    host-name spine2
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
