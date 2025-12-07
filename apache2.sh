#!/bin/bash
# CONFIGURAR OCFS2 EN APACHE2 Y MONTAR

DISCO_ISCSI="/dev/sdc"      
CLUSTER_NAME="webcluster"

# 1. Mismo cluster.conf que en APACHE1

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

# 2. Activar o2cb al arranque

sed -i 's/^O2CB_ENABLED=.*/O2CB_ENABLED=true/' /etc/default/o2cb || echo "O2CB_ENABLED=true" >> /etc/default/o2cb
sed -i "s/^O2CB_BOOTCLUSTER=.*/O2CB_BOOTCLUSTER=$CLUSTER_NAME/" /etc/default/o2cb || echo "O2CB_BOOTCLUSTER=$CLUSTER_NAME" >> /etc/default/o2cb

service o2cb restart

# 3. Montar el mismo sistema de ficheros OCFS2 en /var/www/html

mkdir -p /var/www/html
echo "$DISCO_ISCSI  /var/www/html  ocfs2  _netdev,noacl  0  0" >> /etc/fstab

mount -a

echo "OCFS2 MONTADO EN APACHE2"
df -h | grep /var/www/html
