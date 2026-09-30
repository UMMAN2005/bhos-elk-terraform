terraform {
  required_version = ">= 1.5.0"
  required_providers {
    vcd = {
      source  = "vmware/vcd"
      version = "~> 3.14.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5.0"
    }
  }
}
