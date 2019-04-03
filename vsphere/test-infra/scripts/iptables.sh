#!/bin/bash
set -e

%{ for vlan in block_dns_vlans ~}
iptables -A INPUT -s ${vlan.network_addr} -p tcp --dport 53 -j REJECT
iptables -A INPUT -s ${vlan.network_addr} -p udp --dport 53 -j REJECT
%{ endfor }
