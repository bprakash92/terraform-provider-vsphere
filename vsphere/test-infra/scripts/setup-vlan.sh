#!/bin/bash
set -e

echo "Installing VLAN support ..."
apt-get update
apt-get -y install vlan
modprobe 8021q
echo "8021q" >> /etc/modules

echo "Finding interface with MAC ${nic_mac_addr} ..."
PORT_OCTETS=$(echo "${nic_mac_addr}" | awk -F: '{print $4$5$6}')
# Suppress failures like "Operation not supported" on virtual devices
# This could be improved to only search in physical devices,
# then there's no such hack needed
set +e
MATCHED_PATH=$(grep -l $PORT_OCTETS /sys/class/net/*/phys_port_id 2>/dev/null)
set -e
NIC_NAME=$(echo $MATCHED_PATH | awk -F/ '{print $5}')
echo "Found interface $${NIC_NAME}."

echo "Removing $${NIC_NAME} from bond ..."
apt-get -y install augeas-tools
IFACE_PATH=$(augtool match /files/etc/network/interfaces/iface $${NIC_NAME})
augtool rm $${IFACE_PATH}/bond-master
augtool rm $${IFACE_PATH}/pre-up

ifdown $${NIC_NAME}

echo "Setting up ${length(vlans)} VLANs on $${NIC_NAME} ..."
cat <<EOT >> /etc/network/interfaces
%{ for idx, vlan in vlans ~}
auto $${NIC_NAME}.${vlan_ids[idx]}
iface $${NIC_NAME}.${vlan_ids[idx]} inet static
    address ${vlan.addr}
    netmask ${vlan.netmask}
    vlan-raw-device $${NIC_NAME}
%{ endfor }
EOT

echo "Bringing $${NIC_NAME} back up ..."
ifup $${NIC_NAME}

echo "VLAN setup done."
