#!/usr/bin/env bash
# Disable tracing before reading credentials.
set +x
set -euo pipefail
umask 077

echo "Installing Elastic Stack 9.5.4 on Ubuntu 22.04"

# Reuse credentials when provisioning runs again.
install -d -m 700 /etc/elk
CREDENTIALS_FILE=/etc/elk/credentials.env
if [ ! -f "$CREDENTIALS_FILE" ]; then
    printf 'ELASTIC_PASSWORD=%s\nKIBANA_PASSWORD=%s\n' \
        "$(openssl rand -hex 24)" "$(openssl rand -hex 24)" > "$CREDENTIALS_FILE"
fi
chown root:root "$CREDENTIALS_FILE"
chmod 600 "$CREDENTIALS_FILE"
# shellcheck source=/dev/null
source "$CREDENTIALS_FILE"
: "${ELASTIC_PASSWORD:?Missing Elasticsearch credential}"
: "${KIBANA_PASSWORD:?Missing Kibana credential}"

# Package installers may print passwords.
INSTALL_LOG=/var/log/elk-install.log
touch "$INSTALL_LOG"
chmod 600 "$INSTALL_LOG"

es_request() {
    curl --fail --silent --show-error \
        --cacert /etc/elasticsearch/certs/http_ca.crt \
        --config <(printf 'user = "elastic:%s"\n' "$ELASTIC_PASSWORD") "$@"
}

echo "Waiting for package manager locks..."
while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do
    echo "Waiting for apt/dpkg lock..."
    sleep 3
done

echo "Installing dependencies and Nginx..."
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y nginx curl wget jq default-jre-headless net-tools

mkdir -p /etc/nginx/ssl
if ls /tmp/elk/*.crt 1>/dev/null 2>&1 && ls /tmp/elk/*.key 1>/dev/null 2>&1; then
    cp /tmp/elk/*.crt /etc/nginx/ssl/kibana.crt
    cp /tmp/elk/*.key /etc/nginx/ssl/kibana.key
    chmod 644 /etc/nginx/ssl/kibana.crt
    chmod 600 /etc/nginx/ssl/kibana.key
    echo "TLS certificate installed."
elif [ -f /etc/nginx/ssl/kibana.crt ] && [ -f /etc/nginx/ssl/kibana.key ]; then
    echo "Using the existing TLS certificate."
else
    echo "Creating self-signed fallback certificate..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/nginx/ssl/kibana.key \
        -out /etc/nginx/ssl/kibana.crt \
        -subj "/C=AZ/ST=Baku/O=DevOps/CN=*.local"
fi
chmod 600 /etc/nginx/ssl/kibana.key
chmod 644 /etc/nginx/ssl/kibana.crt

cp /tmp/elk/nginx-kibana.conf /etc/nginx/sites-available/kibana
chmod 644 /etc/nginx/sites-available/kibana
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/kibana /etc/nginx/sites-enabled/kibana
nginx -t
systemctl restart nginx
systemctl enable nginx

echo "Downloading Elastic Stack packages..."
mkdir -p /opt/elk-debs
cd /opt/elk-debs

if [ ! -s "elasticsearch-9.5.4-amd64.deb" ]; then
    echo "Downloading Elasticsearch 9.5.4..."
    wget -q --show-progress -c https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-9.5.4-amd64.deb
fi

if [ ! -s "kibana-9.5.4-amd64.deb" ]; then
    echo "Downloading Kibana 9.5.4..."
    wget -q --show-progress -c https://artifacts.elastic.co/downloads/kibana/kibana-9.5.4-amd64.deb
fi

if [ ! -s "logstash-9.5.4-amd64.deb" ]; then
    echo "Downloading Logstash 9.5.4..."
    wget -q --show-progress -c https://artifacts.elastic.co/downloads/logstash/logstash-9.5.4-amd64.deb
fi

echo "Configuring Elasticsearch..."
dpkg -i elasticsearch-9.5.4-amd64.deb >> "$INSTALL_LOG" 2>&1

VM_IP=$(ip -4 addr show ens192 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' || hostname -I | awk '{print $1}')
echo "Detected VM IP: ${VM_IP}"

cat << EOF > /etc/elasticsearch/elasticsearch.yml
cluster.name: bhos-elk-cluster
node.name: kibana-elk
path.data: /var/lib/elasticsearch
path.logs: /var/log/elasticsearch
network.host: ["127.0.0.1", "${VM_IP}"]
http.port: 9200
discovery.type: single-node

xpack.security.enabled: true
xpack.security.enrollment.enabled: true

xpack.security.http.ssl:
  enabled: true
  keystore.path: certs/http.p12

xpack.security.transport.ssl:
  enabled: true
  verification_mode: certificate
  keystore.path: certs/transport.p12
  truststore.path: certs/transport.p12
EOF

mkdir -p /etc/elasticsearch/jvm.options.d
cat << 'EOF' > /etc/elasticsearch/jvm.options.d/heap.options
-Xms4g
-Xmx4g
EOF

if [ ! -f /etc/elasticsearch/elasticsearch.keystore ]; then
    /usr/share/elasticsearch/bin/elasticsearch-keystore create
fi
echo "Configuring initial keystore..."
printf "%s" "${ELASTIC_PASSWORD}" | /usr/share/elasticsearch/bin/elasticsearch-keystore add -x -f "bootstrap.password"

chown -R root:elasticsearch /etc/elasticsearch
chmod 750 /etc/elasticsearch/jvm.options.d
chmod 640 /etc/elasticsearch/elasticsearch.yml \
    /etc/elasticsearch/elasticsearch.keystore \
    /etc/elasticsearch/jvm.options.d/heap.options
systemctl daemon-reload
systemctl enable --now elasticsearch

echo "Waiting for Elasticsearch to initialize..."
ES_UP=false
for i in $(seq 1 45); do
    if curl -s --cacert /etc/elasticsearch/certs/http_ca.crt https://127.0.0.1:9200 >/dev/null 2>&1; then
        echo "Elasticsearch is accepting connections on port 9200."
        ES_UP=true
        break
    fi
    echo "Waiting for Elasticsearch... ($i/45)"
    sleep 3
done

if [ "$ES_UP" = false ]; then
    echo "Elasticsearch service status:"
    systemctl status elasticsearch --no-pager || true
    journalctl -u elasticsearch -n 50 --no-pager
    exit 1
fi

echo "Configuring elastic superuser password..."
if ! es_request https://127.0.0.1:9200 >/dev/null 2>&1; then
    printf '%s\n%s\n' "$ELASTIC_PASSWORD" "$ELASTIC_PASSWORD" | \
        /usr/share/elasticsearch/bin/elasticsearch-reset-password -u elastic -i -b \
        >> "$INSTALL_LOG" 2>&1
fi

es_request https://127.0.0.1:9200 >/dev/null
echo "Elasticsearch authentication verified."

echo "Setting kibana_system user password..."
printf '{"password":"%s"}' "$KIBANA_PASSWORD" | \
    es_request -X POST "https://127.0.0.1:9200/_security/user/kibana_system/_password" \
     -H "Content-Type: application/json" \
     --data-binary @- >/dev/null

echo "Configuring Kibana..."
dpkg -i kibana-9.5.4-amd64.deb >> "$INSTALL_LOG" 2>&1

mkdir -p /etc/kibana/certs
cp /etc/elasticsearch/certs/http_ca.crt /etc/kibana/certs/http_ca.crt
chown -R kibana:kibana /etc/kibana/certs
chmod 644 /etc/kibana/certs/http_ca.crt

cat << EOF > /etc/kibana/kibana.yml
server.port: 5601
server.host: "0.0.0.0"
server.name: "kibana.local"
server.publicBaseUrl: "https://kibana.local"
elasticsearch.hosts: ["https://127.0.0.1:9200"]
elasticsearch.username: "kibana_system"
elasticsearch.password: "${KIBANA_PASSWORD}"
elasticsearch.ssl.certificateAuthorities: [ "/etc/kibana/certs/http_ca.crt" ]
EOF
chown root:kibana /etc/kibana/kibana.yml
chmod 640 /etc/kibana/kibana.yml

systemctl daemon-reload
systemctl enable --now kibana

echo "Waiting for Kibana to initialize..."
KIBANA_UP=false
for i in $(seq 1 45); do
    STATUS_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:5601/status || true)
    if [ "$STATUS_CODE" = "200" ] || [ "$STATUS_CODE" = "302" ]; then
        echo "Kibana is responding. (HTTP ${STATUS_CODE})"
        KIBANA_UP=true
        break
    fi
    echo "Waiting for Kibana HTTP response... ($i/45, HTTP ${STATUS_CODE})"
    sleep 4
done
if [ "$KIBANA_UP" = false ]; then
    echo "Kibana did not become ready; inspect its service logs on the VM."
    exit 1
fi

echo "Configuring Logstash..."
dpkg -i logstash-9.5.4-amd64.deb >> "$INSTALL_LOG" 2>&1

cp /tmp/elk/logstash.conf /etc/logstash/conf.d/01-default.conf
cp /etc/elasticsearch/certs/http_ca.crt /etc/logstash/http_ca.crt
if [ ! -f /etc/logstash/logstash.keystore ]; then
    /usr/share/logstash/bin/logstash-keystore --path.settings /etc/logstash create
fi
printf '%s' "$ELASTIC_PASSWORD" | \
    /usr/share/logstash/bin/logstash-keystore --path.settings /etc/logstash \
    add ELASTIC_PASSWORD --stdin --force
chown -R logstash:logstash /etc/logstash
chmod 600 /etc/logstash/logstash.keystore

systemctl daemon-reload
systemctl enable --now logstash

echo "Writing access details..."
DETAILS_FILE="/home/devops/ELK_ACCESS_DETAILS.txt"
cat << EOF > "$DETAILS_FILE"
BHOS ELK 9.5.4
Node IP:           ${VM_IP}
Hostname:          kibana.local
OS:                Ubuntu 22.04 LTS (Jammy)
Stack Version:     9.5.4 (Elasticsearch, Kibana, Logstash)

URLs:
  * HTTPS:         https://kibana.local/ (Port 443 with SSL)
  * HTTP:          http://kibana.local/  (Port 80)
  * Direct Kibana: http://${VM_IP}:5601/
  * Elasticsearch: https://${VM_IP}:9200/

Accounts:
  * Superuser:     elastic
  * Kibana System: kibana_system
  * Passwords:     Stored privately in /etc/elk/credentials.env (root only)

SSH:
  * User:          devops
  * Command:       ssh devops@${VM_IP}
EOF

chown devops:devops "$DETAILS_FILE"
chmod 600 "$DETAILS_FILE"
echo "Access details saved on the VM."

echo "ELK setup finished."
