#cloud-config
preserve_hostname: false
hostname: ${hostname}
fqdn: ${hostname}.${domain}

groups:
  - ubuntu: [root,sys]
  - devops

users:
  - default
  - name: devops
    primary_group: devops
    groups: sudo
    sudo: "ALL=(ALL) NOPASSWD:ALL"
    lock_passwd: false
    passwd: ${hashed_pass}
    shell: /bin/bash
    ssh_authorized_keys:
      - "${ssh_public_key}"

write_files:
  - path: /etc/ssh/sshd_config.d/60-devops.conf
    permissions: '0644'
    content: |
      PasswordAuthentication yes
      PubkeyAuthentication yes
      PermitRootLogin prohibit-password

  - path: /usr/local/share/ca-certificates/${domain}-root.crt
    permissions: '0644'
    encoding: b64
    content: ${domain_root_crt}

bootcmd:
  - printf "[Resolve]\nDNS=8.8.8.8 8.8.4.4\n" > /etc/systemd/resolved.conf
  - [ systemctl, restart, systemd-resolved ]

packages:
  - curl
  - wget
  - apt-transport-https
  - gnupg
  - software-properties-common
  - net-tools
  - jq
  - vim
  - git

runcmd:
  - [ update-ca-certificates ]
  - [ sed -i, "s/^PasswordAuthentication no/PasswordAuthentication yes/", /etc/ssh/sshd_config.d/60-cloudimg-settings.conf ]
  - [ systemctl, restart, sshd ]
  - [ timedatectl, set-timezone, Asia/Baku ]
