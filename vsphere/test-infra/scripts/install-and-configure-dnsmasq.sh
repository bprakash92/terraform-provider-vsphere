#!/bin/bash
set -e

echo "Installing dnsmasq ..."
apt-get -y install dnsmasq

echo "Configuring dnsmasq ..."
cat <<EOT > /etc/dnsmasq.d/default.conf
listen-address=${join(",", listen_addresses)}

no-resolv
dnssec
%{ for server in dns_servers ~}
server=${server}#53
%{ endfor ~}

%{ for vlan in vlans ~}
dhcp-range=set:${vlan.name},${vlan.dhcp_range.from},${vlan.dhcp_range.to},${vlan.dhcp_range.netmask},${vlan.dhcp_range.lease_time}
dhcp-option=tag:${vlan.name},option:router,${vlan.addr}
domain=${vlan.name}.${domain_name},${vlan.network_addr}
%{ if vlan.dns ~}
dhcp-option=tag:${vlan.name},option:dns-server,${vlan.addr}
%{ endif ~}
%{ endfor }

log-dhcp
log-queries
EOT

echo "Starting dnsmasq ..."
systemctl start dnsmasq
systemctl restart dnsmasq

echo "dnsmasq configured & started."
