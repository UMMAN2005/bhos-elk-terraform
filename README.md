# BHOS ELK lab

Terraform configuration for Elasticsearch, Logstash and Kibana 9.5.4 on an
Ubuntu 22.04 VM in VMware Cloud Director. The VM uses 8 vCPUs, 16 GiB of RAM
and a 60 GiB disk. Nginx provides HTTP and HTTPS access to Kibana.

[Assignment report](docs/BHOS_ELK_Assignment.docx) |
[PDF](docs/BHOS_ELK_Assignment.pdf)

## Setup

Install Terraform 1.5 or later and OpenSSH. The VCD organization, VDC, catalog,
network and storage profile must already exist. Place the Ubuntu cloud OVA at
files/ova/jammy-server-cloudimg-amd64.ova.

Run in PowerShell:

~~~powershell
Copy-Item terraform.tfvars.example terraform.tfvars
notepad terraform.tfvars
terraform init
terraform fmt -check
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
~~~

Fill in the VCD connection details, assigned VM address, domain, SSH key and
password hash before planning. Review the plan before applying it.
The example address and domain must be replaced with the lab values.

The default configuration defines five resources: an OVA template, vApp,
network attachment, VM and provisioner. Set use_custom_tls = true and supply
domain_crt and domain_key to add the two certificate files. Terraform expects
those inputs as base64 strings.

cloud-init creates the devops account. The provisioner then copies files/elk
to the VM and runs setup-elk.sh. The installer generates ELK passwords on the
VM and stores them in /etc/elk/credentials.env with root-only access.

## Access and checks

Connect from PowerShell:

~~~powershell
$vmIp = terraform output -raw vm_ip
ssh "devops@$vmIp"
~~~

Run in the Ubuntu shell:

~~~bash
lsb_release -ds
nproc
free -h
lsblk -dn -o NAME,SIZE,TYPE
systemctl is-active elasticsearch kibana logstash nginx
sudo curl --cacert /etc/elasticsearch/certs/http_ca.crt \
  --fail -u elastic https://localhost:9200/
sudo ss -lnt
~~~

curl prompts for the password. Retrieve it privately on the VM.

| Port | Service |
| --- | --- |
| 22 | SSH |
| 80, 443 | Nginx |
| 5601 | Kibana |
| 9200 | Elasticsearch HTTPS API |
| 5044, 5000 | Logstash Beats and TCP JSON inputs |

Configure DNS or the Windows hosts file for the Kibana hostname. Keep
Nginx server_name, Kibana server.publicBaseUrl and the certificate name
consistent. The installer defaults to kibana.local and creates a self-signed
certificate when no certificate is supplied.

## Files

| File | Purpose |
| --- | --- |
| providers.tf, versions.tf | Provider settings and version constraints |
| catalog.tf, main.tf | OVA, vApp, network attachment and VM |
| variables.tf, terraform.tfvars.example | Input definitions and configuration template |
| elk.tf | Certificate files and SSH provisioning |
| files/userdata/elk-node.yml.tpl | Guest hostname, account and SSH configuration |
| files/elk | Installer, Nginx configuration and Logstash pipeline |
| outputs.tf | VM address and service URLs |

Keep tfvars, state, saved plans, keys, certificates and access logs out of
Git. Terraform's sensitive flag hides values in some output but does not
remove them from state. Keep .terraform.lock.hcl in version control.

This setup enables HTTP, direct Kibana access and SSH password authentication.
Logstash uses the elastic account. Restrict the VM to the lab network.

## Cleanup

Review terraform plan -destroy, then run terraform destroy when the lab is
no longer needed. Keep the state file until cleanup has finished.
