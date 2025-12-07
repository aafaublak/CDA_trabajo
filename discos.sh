#!/bin/bash
# CONFIGURAR TARGET iSCSI EN DISCOS

apt update
apt install -y tgt
systemctl start tgt


DISCO_ISCSI="/dev/sdf"


tgtadm --lld iscsi --mode target --op delete --tid 1 2>/dev/null || true

# 1. Crear target iSCSI
tgtadm --lld iscsi --op new --mode target --tid 1 \
  --targetname iqn.2025-01.es.uvigo:cda.discos.webcluster

# 2. Crear LUN asociado al disco físico
tgtadm --lld iscsi --op new --mode logicalunit --tid 1 --lun 1 \
  --backing-store "$DISCO_ISCSI"

# 3. Restringir el acceso a APACHE1 y APACHE2 (por IP)
tgtadm --lld iscsi --op bind --mode target --tid 1 \
  --initiator-address 10.10.10.11
tgtadm --lld iscsi --op bind --mode target --tid 1 \
  --initiator-address 10.10.10.22

# 4. Crear cuenta CHAP y asociarla al target
tgtadm --lld iscsi --op new --mode account --user cda --password cdapass
tgtadm --lld iscsi --op bind --mode account --tid 1 --user cda

# 5. Mostrar resumen del target

echo "TARGETS CONFIGURADOS"
tgtadm --lld iscsi --mode target --op show
