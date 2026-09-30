data "vcd_catalog" "devops_catalog" {
  org  = var.vcd_org
  name = var.catalog_name
}

resource "vcd_catalog_vapp_template" "ubuntu_jammy" {
  org               = var.vcd_org
  catalog_id        = data.vcd_catalog.devops_catalog.id
  name              = "ubuntu-jammy"
  description       = "Ubuntu 22.04 LTS (Jammy Jellyfish) Cloud Image"
  ova_path          = "${path.root}/files/ova/jammy-server-cloudimg-amd64.ova"
  upload_piece_size = 10

  metadata_entry {
    key         = "license"
    value       = "public"
    type        = "MetadataStringValue"
    user_access = "READWRITE"
    is_system   = false
  }

  metadata_entry {
    key         = "owner"
    value       = "DevOps"
    type        = "MetadataStringValue"
    user_access = "READWRITE"
    is_system   = false
  }
}
