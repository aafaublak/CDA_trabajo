#!/bin/bash

# IPs del escenario
BALANCEADOR_IP="193.147.87.47"
APACHE1_IP="10.10.10.11"
APACHE2_IP="10.10.10.22"

# Fichero de configuración específico para el balanceo
NGINX_BAL_FILE="/etc/nginx/conf.d/balanceo_cda.conf"

configurar_nginx() {
    cat > "$NGINX_BAL_FILE" <<EOF
upstream backend_cda {
    server $APACHE1_IP:80;
    server $APACHE2_IP:80;
}

server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://backend_cda; 
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

    echo ">>> Configuración escrita en $NGINX_BAL_FILE"
}

reiniciar_nginx() {
    echo ">>> Comprobando sintaxis de NGINX..."
    nginx -t
    if [ $? -ne 0 ]; then
        echo "ERROR: la configuración de NGINX no es válida."
        exit 1
    fi

    echo ">>> Recargando servicio NGINX..."
    systemctl reload nginx
    # Si no estuviera activo, puedes usar: systemctl restart nginx
}

probar_balanceador() {
    echo ">>> Probando acceso al balanceador desde la propia máquina..."
    curl http://$BALANCEADOR_IP
}

# MAIN
configurar_nginx
reiniciar_nginx
probar_balanceador
