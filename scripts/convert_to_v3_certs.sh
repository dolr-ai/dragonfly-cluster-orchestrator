#!/bin/bash
# Regenerate client certificate as X.509 v3
# The original client-cert.pem is v1, but rustls requires v3

set -e

CERTS_DIR="path to certs directory"
cd "$CERTS_DIR"

echo "Backing up original client cert..."
cp client-cert.pem client-cert.pem.v1.bak

# Create extension file for v3 certificate
cat > client-ext.cnf << 'EOF'
basicConstraints=CA:FALSE
keyUsage=digitalSignature,keyEncipherment
extendedKeyUsage=clientAuth
EOF

echo "Regenerating client certificate as v3..."

# Generate a new CSR from the existing private key
openssl req -new -key client-key.pem -out client.csr -subj "/CN=dragonfly-client"

# Sign with CA to create v3 certificate
openssl x509 -req \
    -in client.csr \
    -CA ca-cert.pem \
    -CAkey ca-key.pem \
    -CAcreateserial \
    -out client-cert.pem \
    -days 36500 \
    -sha256 \
    -extfile client-ext.cnf

# Cleanup
rm -f client.csr client-ext.cnf

echo ""
echo "Done! Verifying new certificate:"
openssl x509 -in client-cert.pem -text -noout | head -20

echo ""
echo "Certificate version should now be 'Version: 3 (0x2)'"