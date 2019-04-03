terraform {
  required_version = ">= 0.12"
}

provider "packet" {
  version = "~> 2.2"
}

resource "packet_project" "test" {
  name = "Terraform Acc Test vSphere"
}

data "local_file" "esxi_thumbprint" {
  filename   = "${path.module}/${local.esxi_ssl_cert_thumbprint_path}"
  depends_on = [packet_device.esxi]
}

resource "random_string" "password" {
  length           = 16
  special          = true
  min_lower        = 1
  min_numeric      = 1
  min_upper        = 1
  min_special      = 1
  override_special = "@_"
}

locals {
  helper_plan = "m1.xlarge.x86"
  vcenter_ipv4 = cidrhost(
    format(
      "%s/%s",
      packet_device.esxi.network[0].gateway,
      packet_device.esxi.public_ipv4_subnet_size,
    ),
    3,
  )
}

resource "local_file" "vcsa" {
  content  = jsonencode(local.vcsa_template)
  filename = "${path.module}/template.json"
}

resource "tls_private_key" "test" {
  algorithm = "RSA"
}

resource "packet_project_ssh_key" "test" {
  name       = "tf-acc-test"
  public_key = tls_private_key.test.public_key_openssh
  project_id = packet_project.test.id
}

data "packet_operating_system" "helper" {
  name   = "Ubuntu"
  distro = "ubuntu"

  # 18.04 has a broken ifupdown version which makes it difficult to setup VLANs
  # See https://bugs.launchpad.net/ubuntu/+source/ifupdown/+bug/1806153
  # 19.04 seems to have a later (fixed) version,
  # but the next LTS is 20.04 (not released yet; planned for Apr 2020)
  version          = "16.04"
  provisionable_on = local.helper_plan
}

resource "packet_device" "helper" {
  hostname            = "tf-acc-vmware-helper"
  plan                = local.helper_plan
  facilities          = [var.facility]
  operating_system    = data.packet_operating_system.helper.id
  billing_cycle       = "hourly"
  project_id          = packet_project.test.id
  project_ssh_key_ids = [packet_project_ssh_key.test.id]
  network_type        = "hybrid"

  connection {
    type        = "ssh"
    host        = self.access_public_ipv4
    user        = "root"
    private_key = tls_private_key.test.private_key_pem
    agent       = false
  }

  provisioner "remote-exec" {
    inline = [templatefile("${path.module}/scripts/setup-vlan.sh", {
      vlans        = local.vlans,
      vlan_ids     = packet_vlan.default.*.vxlan
      nic_mac_addr = [for port in self.ports : port if port.name == "eth1"][0].mac,
    })]
  }

  provisioner "remote-exec" {
    inline = [templatefile("${path.module}/scripts/configure-nat.sh", {
      natted_vlans = [for vlan in local.vlans : vlan if vlan.nat == true]
    })]
  }

  provisioner "remote-exec" {
    inline = [templatefile("${path.module}/scripts/iptables.sh", {
      block_dns_vlans = [for vlan in local.vlans : vlan if vlan.dns == false]
    })]
  }

  provisioner "remote-exec" {
    inline = [templatefile("${path.module}/scripts/install-and-configure-dnsmasq.sh", {
      listen_addresses = local.vlans.*.addr
      dns_servers      = var.dns_servers
      vlans            = local.vlans
      domain_name      = local.vcsa_domain_name
    })]
  }

  provisioner "file" {
    source      = local_file.vcsa.filename
    destination = "/tmp/vcsa-template.json"
  }

  provisioner "remote-exec" {
    inline = [templatefile("${path.module}/scripts/install-vcsa.sh", {
      ovftool_url   = var.ovftool_url
      vcsa_iso_url  = var.vcsa_iso_url
      vcsa_tpl_path = "/tmp/vcsa-template.json"
    })]
  }

  provisioner "remote-exec" {
    inline = [templatefile("${path.module}/scripts/install-govc.sh", {
      govc_url = local.govc_url
    })]
  }

  provisioner "remote-exec" {
    inline = [
      <<SCRIPT
set -e
echo "Attempting to login via govc..."
export GOVC_USERNAME="${local.vcenter_username}"
export GOVC_PASSWORD="${random_string.password.result}"
export GOVC_URL=${local.vcenter_ipv4}
export GOVC_INSECURE=1
./govc about

echo "Creating datacenter..."
./govc datacenter.create ${local.datacenter_name}

echo "Adding ESXi as host to the datacenter..."
./govc host.add -hostname ${packet_device.esxi.access_public_ipv4} -username ${local.esxi_username} -password '${packet_device.esxi.root_password}' -thumbprint ${local.esxi_cert_thumbprint}
SCRIPT
      ,
    ]
  }
}

data "packet_operating_system" "esxi" {
  name = "VMware ESXi"
  distro = "vmware"
  version = var.esxi_version
  provisionable_on = var.plan
}

resource "packet_device" "esxi" {
  hostname = "tf-acc-vmware-esxi"
  plan = var.plan
  facilities = [var.facility]
  operating_system = data.packet_operating_system.esxi.id
  billing_cycle = "hourly"
  project_id = packet_project.test.id
  project_ssh_key_ids = [packet_project_ssh_key.test.id]
  network_type = "hybrid"

  connection {
    type = "ssh"
    host = self.access_public_ipv4
    user = "root"
    private_key = tls_private_key.test.private_key_pem
    agent = false
    timeout = "10m"
  }

  provisioner "remote-exec" {
    inline = [
      "openssl x509 -in /etc/vmware/ssl/rui.crt -fingerprint -sha1 -noout | awk -F= '{print $2}' > /tmp/ssl-rui-thumbprint.txt",
    ]
  }
  provisioner "local-exec" {
    # There isn't better way to download a file yet
    # See https://github.com/hashicorp/terraform/issues/3379
    environment = {
      SSH_PRIV_KEY = tls_private_key.test.private_key_pem
      FROM = "root@${self.access_public_ipv4}:/tmp/ssl-rui-thumbprint.txt"
      TO = local.esxi_ssl_cert_thumbprint_path
    }
    command = "${path.module}/scripts/scp.sh"
  }
  provisioner "local-exec" {
    when = destroy
    command = "rm -f ${local.esxi_ssl_cert_thumbprint_path}"
  }

  provisioner "remote-exec" {
    inline = [templatefile("${path.module}/scripts/configure-esx-network.sh", {
      vlans = local.vlans,
      vlan_ids = packet_vlan.default.*.vxlan
      nic_mac_addr = [for port in self.ports : port if port.name == "eth1"][0].mac,
    })]
  }
}

