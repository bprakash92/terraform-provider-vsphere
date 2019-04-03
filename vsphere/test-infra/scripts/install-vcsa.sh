#!/bin/bash
set -e

# Install ovftool
echo "Downloading ovftool ..."
curl -f -L '${ovftool_url}' -o ./vmware-ovftool.bundle
chmod a+x ./vmware-ovftool.bundle
echo "Installing ovftool ..."
TERM=dumb sudo ./vmware-ovftool.bundle --eulas-agreed

# Install vCenter Server Appliance
MOUNT_LOCATION=/mnt/vcenter
echo "Downloading vCenter Server Appliance ..."
curl -f -L '${vcsa_iso_url}' -o ./vmware-vcenter.iso
sudo mkdir $MOUNT_LOCATION
echo "Mounting downloaded VCSA ISO to $MOUNT_LOCATION ..."
sudo mount -o loop ./vmware-vcenter.iso $MOUNT_LOCATION
echo "Installing VCSA ..."
sudo $${MOUNT_LOCATION}/vcsa-cli-installer/lin64/vcsa-deploy install --accept-eula ${vcsa_tpl_path}
echo "VCSA installed."
sudo umount $MOUNT_LOCATION
echo "$MOUNT_LOCATION unmounted."
