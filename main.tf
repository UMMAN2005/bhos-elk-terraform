resource "vcd_vapp" "elk" {
  name        = var.vapp_name
  description = "BHOS ELK 9.5.4"
}

resource "vcd_vapp_org_network" "elk_net" {
  vapp_name              = vcd_vapp.elk.name
  org_network_name       = var.org_network_name
  reboot_vapp_on_removal = true
}

resource "vcd_vapp_vm" "elk" {
  name             = var.vm_name
  computer_name    = var.hostname
  vapp_name        = vcd_vapp.elk.name
  vapp_template_id = vcd_catalog_vapp_template.ubuntu_jammy.id

  memory    = var.vm_memory
  cpus      = var.vm_cpus
  cpu_cores = var.vm_cpu_cores

  guest_properties = {
    "user-data" = base64encode(templatefile("${path.root}/files/userdata/elk-node.yml.tpl", {
      hostname        = var.hostname
      domain          = var.domain
      hashed_pass     = var.hashed_pass
      ssh_public_key  = var.ssh_public_key
      domain_root_crt = var.domain_root_crt
    }))
    "local-hostname" = var.hostname
  }

  lifecycle {
    ignore_changes = [
      guest_properties["user-data"]
    ]
  }

  network {
    type               = "org"
    name               = vcd_vapp_org_network.elk_net.org_network_name
    ip_allocation_mode = "MANUAL"
    ip                 = var.vm_ip
    is_primary         = true
  }

  override_template_disk {
    bus_number      = 0
    bus_type        = "paravirtual"
    size_in_mb      = var.vm_disk_size
    unit_number     = 0
    storage_profile = var.storage_profile
  }

  metadata_entry {
    key         = "environment"
    value       = var.environment
    type        = "MetadataStringValue"
    is_system   = false
    user_access = "READWRITE"
  }

  metadata_entry {
    key         = "owner"
    value       = "DevOps"
    type        = "MetadataStringValue"
    is_system   = false
    user_access = "READWRITE"
  }

  metadata_entry {
    key         = "role"
    value       = "elk-all-in-one"
    type        = "MetadataStringValue"
    is_system   = false
    user_access = "READWRITE"
  }
}
