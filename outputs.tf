output "vm_name" {
  description = "Name of the created VM in vCloud Director"
  value       = vcd_vapp_vm.elk.name
}

output "vm_ip" {
  description = "Primary IP address of the ELK VM"
  value       = var.vm_ip
}

output "ssh_command" {
  description = "SSH login command for devops user"
  value       = "ssh devops@${var.vm_ip}"
}

output "kibana_https_url" {
  description = "Kibana HTTPS URL using domain wildcard SSL"
  value       = "https://kibana.${var.domain}/"
}

output "kibana_http_url" {
  description = "Kibana HTTP URL on port 80"
  value       = "http://kibana.${var.domain}/"
}

output "kibana_direct_url" {
  description = "Direct Kibana URL on port 5601"
  value       = "http://${var.vm_ip}:5601/"
}

output "elasticsearch_url" {
  description = "Elasticsearch API endpoint on port 9200"
  value       = "https://${var.vm_ip}:9200/"
}

output "hosts_entry" {
  description = "Entry to add to client /etc/hosts for domain access"
  value       = "${var.vm_ip} kibana.${var.domain}"
}
