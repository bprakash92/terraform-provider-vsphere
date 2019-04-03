resource "packet_vlan" "default" {
  count       = length(local.vlans)
  description = local.vlans[count.index].name
  facility    = var.facility
  project_id  = packet_project.test.id
}

resource "packet_port_vlan_attachment" "esxi" {
  count     = length(local.vlans)
  device_id = packet_device.esxi.id
  vlan_vnid = packet_vlan.default[count.index].vxlan
  port_name = "eth1"
}

resource "packet_port_vlan_attachment" "helper" {
  count     = length(local.vlans)
  device_id = packet_device.helper.id
  vlan_vnid = packet_vlan.default[count.index].vxlan
  port_name = "eth1"
}
