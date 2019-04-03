locals {
  vcsa_template = {
    __version = "2.13.0"
    new_vcsa = {
      esxi = {
        hostname           = packet_device.esxi.access_public_ipv4
        username           = local.esxi_username
        password           = packet_device.esxi.root_password
        deployment_network = "VM Network"
        datastore          = "datastore1"
        ssl_certificate_verification = {
          thumbprint = chomp(data.local_file.esxi_thumbprint.content)
        }
      }
      appliance = {
        thin_disk_mode    = true
        deployment_option = "small"
        name              = "vcenter"
      }
      network = {
        ip_family   = "ipv4"
        mode        = "static"
        dns_servers = var.dns_servers
        ip          = local.vcenter_ipv4
        prefix      = tostring(packet_device.esxi.public_ipv4_subnet_size)
        gateway     = packet_device.esxi.network[0].gateway
        system_name = local.vcenter_ipv4
      }
      os = {
        password    = random_string.password.result
        ntp_servers = "time.nist.gov"
        ssh_enable  = true
      }
      sso = {
        password       = random_string.password.result
        domain_name    = local.vcsa_domain_name
        first_instance = true
      }
    }
    ceip = {
      settings = {
        ceip_enabled = false
      }
    }
  }
}
