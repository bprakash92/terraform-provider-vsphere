variable "plan" {
  default = "c1.xlarge.x86"
}

variable "esxi_version" {
  default = "6.5"
}

variable "govc_version" {
  default     = "v0.20.0"
  description = "Version of govc (see https://github.com/vmware/govmomi/releases)"
}

variable "facility" {
  default = "ams1"
}

variable "dns_servers" {
  type    = list(string)
  default = ["8.8.8.8", "8.8.4.4"]
}

variable "ovftool_url" {
  description = "URL from which to download ovftool"
}

variable "vcsa_iso_url" {
  description = "URL from which to download VCSA ISO"
}

locals {
  esxi_username                 = "root"
  esxi_ssl_cert_thumbprint_path = "ssl_cert_thumbprint.txt"
  esxi_cert_thumbprint          = chomp(data.local_file.esxi_thumbprint.content)
  vcsa_domain_name              = "vsphere.local"
  vcenter_username              = "Administrator@${local.vcsa_domain_name}"
  govc_url                      = "https://github.com/vmware/govmomi/releases/download/${var.govc_version}/govc_linux_amd64.gz"
  ubuntu_iso_url                = "http://no.releases.ubuntu.com/18.04.2/ubuntu-18.04.2-live-server-amd64.iso"
  vlans = [
    {
      name         = "private"
      addr         = "172.16.0.1"
      netmask      = "255.255.255.0"
      network_addr = "172.16.0.0/24"
      dhcp_range = {
        from       = "172.16.0.2"
        to         = "172.16.0.250"
        netmask    = "255.255.255.0"
        lease_time = "12h"
      }
      dns = false
      nat = false
    },
    {
      name         = "public"
      addr         = "172.16.1.1"
      netmask      = "255.255.255.0"
      network_addr = "172.16.1.0/24"
      dhcp_range = {
        from       = "172.16.1.2"
        to         = "172.16.1.250"
        netmask    = "255.255.255.0"
        lease_time = "12h"
      }
      dns = true
      nat = true
    },

  ]
  datacenter_name = "TfDatacenter"
}

