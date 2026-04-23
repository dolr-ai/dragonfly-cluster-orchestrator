#!/usr/bin/env bash
set -euo pipefail

# ================================
# Configuration
# ================================

PRIMARY_HOST="$1" #naitik-1
REPLICA_HOST="$2" #naitik-3
SENTINEL_HOST="$3" #naitik-2
PRIMARY_DNS="$4"  
REPLICA_DNS="$5"
SENTINEL_DNS="$6"
CERT_DIR="path to certs directory"
DAYS=36500

# ================================
# Validation
# ================================

if [[ -z "${PRIMARY_HOST}" || -z "${REPLICA_HOST}" || -z "${SENTINEL_HOST}" || \
      -z "${PRIMARY_DNS}" || -z "${REPLICA_DNS}" || -z "${SENTINEL_DNS}" ]]; then
  echo "Usage: $0 <PRIMARY_IP> <REPLICA_IP> <SENTINEL_IP> <PRIMARY_DNS> <REPLICA_DNS> <SENTINEL_DNS>"
  exit 1
fi

mkdir -p "$CERT_DIR"

# ================================
# Create SAN config
# ================================

SAN_CNF=$(mktemp)
cat > "$SAN_CNF" <<EOF
subjectAltName = IP:${PRIMARY_HOST},IP:${REPLICA_HOST},IP:${SENTINEL_HOST},DNS:${PRIMARY_DNS},DNS:${REPLICA_DNS},DNS:${SENTINEL_DNS}
EOF

echo "📜 SAN config:"
cat "$SAN_CNF"
echo

# ================================
# Generate CA
# ================================

echo "🔐 Generating CA..."
openssl req -x509 -new -nodes -newkey rsa:4096 \
  -keyout "$CERT_DIR/ca-key.pem" \
  -out "$CERT_DIR/ca-cert.pem" \
  -days "$DAYS" \
  -subj "/CN=dragonfly-internal-ca"

# ================================
# Generate Server Certificate
# ================================

echo "🖥️ Generating Server Certificate..."
openssl req -newkey rsa:4096 -nodes \
  -keyout "$CERT_DIR/server-key.pem" \
  -out "$CERT_DIR/server-req.pem" \
  -subj "/CN=dragonfly-server" \
  -config <(cat /etc/ssl/openssl.cnf "$SAN_CNF")

openssl x509 -req \
  -in "$CERT_DIR/server-req.pem" \
  -CA "$CERT_DIR/ca-cert.pem" \
  -CAkey "$CERT_DIR/ca-key.pem" \
  -CAcreateserial \
  -out "$CERT_DIR/server-cert.pem" \
  -days "$DAYS" \
  -extfile "$SAN_CNF"

# ================================
# Generate Client Certificate
# ================================

echo "👤 Generating Client Certificate..."
openssl req -newkey rsa:4096 -nodes \
  -keyout "$CERT_DIR/client-key.pem" \
  -out "$CERT_DIR/client-req.pem" \
  -subj "/CN=dragonfly-client"

openssl x509 -req \
  -in "$CERT_DIR/client-req.pem" \
  -CA "$CERT_DIR/ca-cert.pem" \
  -CAkey "$CERT_DIR/ca-key.pem" \
  -CAcreateserial \
  -out "$CERT_DIR/client-cert.pem" \
  -days "$DAYS"

# ================================
# Permissions & Cleanup
# ================================

chmod 600 "$CERT_DIR"/*-key.pem
chmod 644 "$CERT_DIR"/*-cert.pem

rm -f "$SAN_CNF" "$CERT_DIR"/*.srl "$CERT_DIR"/*-req.pem

echo
echo "✅ Certificates generated successfully:"
ls -lh "$CERT_DIR"