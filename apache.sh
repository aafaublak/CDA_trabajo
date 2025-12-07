#!/bin/bash
# CONFIGURAR OCFS2 Y FORMATEAR EN APACHE1

DISCO_ISCSI="/dev/sdb"
CLUSTER_NAME="webcluster"

# 1. Crear config del clúster OCFS2

cat > /etc/ocfs2/cluster.conf <<EOF
cluster:
    node_count = 2
    name = $CLUSTER_NAME

node:
    ip_port = 7777
    ip_address = 10.10.10.11
    number = 0
    name = apache1
    cluster = $CLUSTER_NAME

node:
    ip_port = 7777
    ip_address = 10.10.10.22
    number = 1
    name = apache2
    cluster = $CLUSTER_NAME
EOF

# . Activar o2cb al arranque

sed -i 's/^O2CB_ENABLED=.*/O2CB_ENABLED=true/' /etc/default/o2cb || echo "O2CB_ENABLED=true" >> /etc/default/o2cb
sed -i "s/^O2CB_BOOTCLUSTER=.*/O2CB_BOOTCLUSTER=$CLUSTER_NAME/" /etc/default/o2cb || echo "O2CB_BOOTCLUSTER=$CLUSTER_NAME" >> /etc/default/o2cb

service o2cb restart

# 3. FORMATEAR EL DISCO iSCSI COMO OCFS2 

mkfs.ocfs2 -L webdata "$DISCO_ISCSI"

# 4. Montar en /var/www/html y añadir a /etc/fstab

mkdir -p /var/www/html

echo "$DISCO_ISCSI  /var/www/html  ocfs2  _netdev,noacl  0  0" >> /etc/fstab

mount -a

echo "OCFS2 MONTADO EN APACHE1"
df -h | grep /var/www/html
