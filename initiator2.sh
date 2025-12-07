#!/bin/bash
#CONFIG INICIAL EN APACHE1 Y APACHE2

apt update
apt install -y open-iscsi ocfs2-tools

# 1. Nombre único de initiator

NOMBRE_INICIADOR="iqn.2025-01.es.uvigo:cda.apache2"

echo "InitiatorName=$NOMBRE_INICIADOR" > /etc/iscsi/initiatorname.iscsi

# 2. Añadir config CHAP al final de iscsid.conf
cat <<'EOF' >> /etc/iscsi/iscsid.conf

# Configuración CDA CHAP 
node.session.auth.authmethod = CHAP
node.session.auth.username = cda
node.session.auth.password = cdapass
EOF

systemctl restart iscsid.service

# 3. Descubrir el target en DISCOS

iscsiadm -m discovery -t sendtargets -p 10.10.10.33

# 4. Conectarse al target

iscsiadm -m node -T iqn.2025-01.es.uvigo:cda.discos.webcluster -p 10.10.10.33 --login

echo "DISPOSITIVOS DE BLOQUE"
lsblk

