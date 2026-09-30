resource "local_sensitive_file" "domain_crt" {
  count           = var.use_custom_tls ? 1 : 0
  content         = base64decode(var.domain_crt)
  filename        = "${path.root}/files/elk/server.crt"
  file_permission = "0600"

  lifecycle {
    precondition {
      condition     = var.domain_crt != "" && var.domain_key != ""
      error_message = "Custom TLS requires both domain_crt and domain_key."
    }
  }
}

resource "local_sensitive_file" "domain_key" {
  count           = var.use_custom_tls ? 1 : 0
  content         = base64decode(var.domain_key)
  filename        = "${path.root}/files/elk/server.key"
  file_permission = "0600"
}

resource "null_resource" "provision_elk" {
  depends_on = [
    vcd_vapp_vm.elk,
    local_sensitive_file.domain_crt,
    local_sensitive_file.domain_key
  ]

  triggers = {
    vm_id        = vcd_vapp_vm.elk.id
    vm_ip        = var.vm_ip
    script_hash  = filemd5("${path.root}/files/elk/setup-elk.sh")
    nginx_hash   = filemd5("${path.root}/files/elk/nginx-kibana.conf")
    logstash_md5 = filemd5("${path.root}/files/elk/logstash.conf")
  }

  connection {
    type        = "ssh"
    host        = var.vm_ip
    user        = "devops"
    private_key = file(pathexpand(var.ssh_private_key_path))
    timeout     = "15m"
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p /tmp/elk"
    ]
  }

  provisioner "file" {
    source      = "${path.root}/files/elk/"
    destination = "/tmp/elk"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/elk/setup-elk.sh",
      "sudo /tmp/elk/setup-elk.sh",
      "rm -f /tmp/elk/server.key /tmp/elk/server.crt"
    ]
  }
}
