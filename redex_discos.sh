#  Activar el reenvío de IP (routing)
echo 1 > /proc/sys/net/ipv4/ip_forward
sed -i 's/^#\?net.ipv4.ip_forward.*/net.ipv4.ip_forward=1/' /etc/sysctl.conf
sysctl -p
#  NAT hacia la interfaz de salida enp0s9
iptables -t nat -A POSTROUTING -o enp0s9 -j MASQUERADE
# Permitir tráfico entre la LAN (enp0s8) y la salida (enp0s9)
iptables -A FORWARD -i enp0s8 -o enp0s9 -j ACCEPT
iptables -A FORWARD -i enp0s9 -o enp0s8 -m state --state RELATED,ESTABLISHED -j ACCEPT
echo "configurado"
