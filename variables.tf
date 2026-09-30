variable "vcd_user" {
  description = "VMware Cloud Director API username"
  type        = string
}

variable "vcd_password" {
  description = "VMware Cloud Director API password"
  type        = string
  sensitive   = true
}

variable "vcd_org" {
  description = "VMware Cloud Director Organization name"
  type        = string
  default     = "your-organization"
}

variable "vcd_vdc" {
  description = "VMware Cloud Director VDC name"
  type        = string
  default     = "your-vdc-name"
}

variable "vcd_url" {
  description = "VMware Cloud Director API URL"
  type        = string
  default     = "https://vcloud.example.com/api"
}

variable "vapp_name" {
  description = "Name of the vApp to create"
  type        = string
  default     = "bhos-elk-systems"
}

variable "catalog_name" {
  description = "Catalog containing or receiving vApp templates"
  type        = string
  default     = "devops-catalog"
}

variable "org_network_name" {
  description = "Direct/routed Org Network to attach the VM to"
  type        = string
  default     = "your-org-network"
}

variable "storage_profile" {
  description = "Storage profile name in VDC"
  type        = string
  default     = "standard-ssd"
}

variable "vm_name" {
  description = "VM name in vCloud Director"
  type        = string
  default     = "BHOSElk01"
}

variable "hostname" {
  description = "Internal hostname for the VM"
  type        = string
  default     = "kibana"
}

variable "vm_ip" {
  description = "Static IP address for the ELK VM; replace the documentation-only default"
  type        = string
  default     = "192.0.2.50"
}

variable "vm_cpus" {
  description = "Number of vCPUs for the ELK VM"
  type        = number
  default     = 8
}

variable "vm_cpu_cores" {
  description = "Number of cores per socket"
  type        = number
  default     = 1
}

variable "vm_memory" {
  description = "Memory in MB for the ELK VM"
  type        = number
  default     = 16384
}

variable "vm_disk_size" {
  description = "Primary disk size in MB"
  type        = number
  default     = 61440 # 60 GB
}

variable "environment" {
  description = "Environment tag (e.g. prod, demo, dev, bhos)"
  type        = string
  default     = "bhos"
}

variable "domain" {
  description = "Domain name for hostname and reverse proxy"
  type        = string
  default     = "example.com"
}

variable "hashed_pass" {
  description = "SHA-512 password hash for the devops account"
  type        = string
  sensitive   = true
}

variable "ssh_public_key" {
  description = "Public SSH key for devops user access"
  type        = string
}

variable "ssh_private_key_path" {
  description = "Path to private SSH key for remote provisioning"
  type        = string
  default     = "~/.ssh/id_rsa"
}

variable "domain_root_crt" {
  description = "Base64 encoded domain root CA certificate"
  type        = string
  default     = ""
}

variable "domain_crt" {
  description = "Base64 encoded domain wildcard certificate"
  type        = string
  default     = ""
}

variable "use_custom_tls" {
  description = "Write the supplied certificate and private key for Nginx; otherwise use a lab self-signed certificate"
  type        = bool
  default     = false
}

variable "domain_key" {
  description = "Base64 encoded domain private key"
  type        = string
  sensitive   = true
  default     = ""
}
