output "esxi_host" {
  value = packet_device.esxi.access_public_ipv4
}

output "esxi_user" {
  value = local.esxi_username
}

output "esxi_password" {
  value = packet_device.esxi.root_password
}

output "esxi_ssl_cert_thumbprint" {
  value = chomp(data.local_file.esxi_thumbprint.content)
}

output "vsphere_endpoint" {
  value = cidrhost(
    format(
      "%s/%s",
      packet_device.esxi.network[0].gateway,
      packet_device.esxi.public_ipv4_subnet_size,
    ),
    3,
  )
}

output "vsphere_user" {
  value = local.vcenter_username
}

output "vsphere_password" {
  value = random_string.password.result
}

output "dns_servers" {
  value = var.dns_servers
}

output "datacenter_name" {
  value = local.datacenter_name
}

output "helper_host" {
  value = packet_device.helper.access_public_ipv4
}

