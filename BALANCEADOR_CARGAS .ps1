#Dirección base de descarga y almacenamiento de las imagenes
$URL_BASE ="http://cda.drordas.info"
#Direccion base local para almacenar las imagenes (en mi equipo local)
$DIR_BASE ="C:\Users\faubl\OneDrive\Escritorio\AAFA\UVIGO\3º\1º CUATRI\CDA\BALANCEO DE CARGAS"
#Direccion base de sde donde se ejecutará VBoxManage.exe
$VBOX_MANAGE = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" 
& $VBOX_MANAGE list vms

function Extraer-ZIP($file, $destination) {
  $shell = new-object -com shell.application
  $zip = $shell.NameSpace($file)
  $shell.NameSpace($destination).copyhere($zip.items())
}


function Preparar-Imagen($nombre_imagen, $url_base_origen, $dir_base_destino) {
  if(!(Test-Path -Path "$dir_base_destino\$nombre_imagen.vdi"))  {
      if(!(Test-Path -Path "$dir_base_destino\$nombre_imagen.vdi.zip"))  {
           Write-Host "Iniciando descarga de $url_base_origen/$nombre_imagen.vdi.zip ..."
           # Invoke-WebRequest "$url_base_origen\$nombre_imagen.vdi.zip"-OutFile "$dir_base_destino\$nombre_imagen.vdi.zip"
           $web_client = New-Object System.Net.WebClient
           $web_client.DownloadFile("$url_base_origen/$nombre_imagen.vdi.zip", "$dir_base_destino/$nombre_imagen.vdi.zip")
      }
      Write-Host "Descomprimiendo $dir_base_destino\$nombre_imagen.vdi.zip ..."
      Extraer-Zip "$dir_base_destino\$nombre_imagen.vdi.zip" "$dir_base_destino"
      Remove-Item "$dir_base_destino\$nombre_imagen.vdi.zip"
  }
}

function Registrar-Imagen($nombre_imagen, $dir_base_destino, $tipo, $vboxmanage) {
  if(!(Test-Path -Path "$dir_base_destino\CDA_NO_BORRAR"))  {
     Start-Process $vboxmanage  "createvm  --name CDA_NO_BORRAR --basefolder `"$dir_base_destino`" --register " -NoNewWindow -Wait    
     Start-Process $vboxmanage  "storagectl CDA_NO_BORRAR --name STORAGE_CDA_NO_BORRAR  --add sata  --portcount 4   " -NoNewWindow -Wait     
  } 
  $IMAGEN = "$dir_base_destino\$nombre_imagen.vdi"
  Start-Process $vboxmanage  "storageattach CDA_NO_BORRAR --storagectl STORAGE_CDA_NO_BORRAR --port 0 --device 0 --type hdd --medium `"$IMAGEN`" --mtype normal " -NoNewWindow -Wait
  Start-Process $vboxmanage  "storageattach CDA_NO_BORRAR --storagectl STORAGE_CDA_NO_BORRAR --port 0 --device 0 --type hdd --medium none " -NoNewWindow -Wait
  Start-Process $vboxmanage  "modifymedium `"$IMAGEN`" --type $tipo " -NoNewWindow -Wait 
}



if(!(Test-Path -Path $DIR_BASE))  {
   New-Item $DIR_BASE -itemtype directory
}


Preparar-Imagen "swap1GB" "$URL_BASE" "$DIR_BASE"
Preparar-Imagen "base_cda"     "$URL_BASE" "$DIR_BASE"


Write-Host ">> CDA 2025/26 -- Ejemplo balanceo de carga con HAproxy"
$ID = Read-Host ">> Introducir identificador de las MVs (sin espacios) "



$BASE_VBOX = $env:VBOX_MSI_INSTALL_PATH
if ([string]::IsNullOrEmpty($BASE_VBOX)) {
   $BASE_VBOX = $env:VBOX_INSTALL_PATH
}
if ([string]::IsNullOrEmpty($BASE_VBOX)) {
   $READ_BASE_VBOX = Read-Host ">> Introducir directorio de instalacion de VirtualBox (habitualente `"C:\\Program Files\Oracle\VirtualBox`") :"
   if ([string]::IsNullOrEmpty($READ_BASE_VBOX)) {
      $READ_BASE_VBOX = "`"C:\\Program Files\Oracle\VirtualBox`""
   }
   $BASE_VBOX = $READ_BASE_VBOX
}

$VBOX_MANAGE = "$BASE_VBOX\VBoxManage.exe"

echo $VBOX_MANAGE

Registrar-Imagen "base_cda" "$DIR_BASE" "multiattach" $VBOX_MANAGE
Registrar-Imagen "swap1GB" "$DIR_BASE" "immutable" $VBOX_MANAGE


Write-Host ">> Configurando maquinas virtuales ..."

# Crear imagen DEL CLIENTE (1º)
$MV_CLIENTE="CLIENTE_$ID"
if (!(Test-Path -Path "$DIR_BASE\$MV_CLIENTE"))  {
# Solo 1 vez
  Start-Process $VBOX_MANAGE  "createvm  --name $MV_CLIENTE --basefolder `"$DIR_BASE`"  --register --ostype Debian_64 " -NoNewWindow -Wait        
  Start-Process $VBOX_MANAGE  "storagectl $MV_CLIENTE --name STORAGE_$MV_CLIENTE  --add sata --portcount 4" -NoNewWindow -Wait         
  Start-Process $VBOX_MANAGE  "storageattach $MV_CLIENTE --storagectl STORAGE_$MV_CLIENTE --port 0 --device 0 --type hdd --medium `"$DIR_BASE\base_cda.vdi`"  --mtype multiattach " -NoNewWindow -Wait    
  Start-Process $VBOX_MANAGE  "storageattach $MV_CLIENTE --storagectl STORAGE_$MV_CLIENTE --port 1 --device 0 --type hdd --medium `"$DIR_BASE\swap1GB.vdi`"  --mtype immutable " -NoNewWindow -Wait    
  Start-Process $VBOX_MANAGE  "modifyvm $MV_CLIENTE --cpus 2 --memory 512 --pae on --vram 16 --graphicscontroller vboxsvga" -NoNewWindow -Wait    
  Start-Process $VBOX_MANAGE  "modifyvm $MV_CLIENTE --nic1 intnet --intnet1 vlan1 --macaddress1 080027111111 --cableconnected1 on --nictype1 82540EM " -NoNewWindow -Wait    

  Start-Process $VBOX_MANAGE  "modifyvm $MV_CLIENTE --nic2 nat  --macaddress2 080027111104 --cableconnected2 on --nictype2 82540EM" -NoNewWindow -Wait  
  Start-Process $VBOX_MANAGE  "modifyvm $MV_CLIENTE --nat-pf2 `"guestssh,tcp,,2222,,22`" " -NoNewWindow -Wait 
  Start-Process $VBOX_MANAGE  "modifyvm $MV_CLIENTE --clipboard-mode bidirectional " -NoNewWindow -Wait   
  
  Start-Process $VBOX_MANAGE  "guestproperty set $MV_CLIENTE /DSBOX/num_interfaces 2" -NoNewWindow -Wait    
  Start-Process $VBOX_MANAGE  "guestproperty set $MV_CLIENTE /DSBOX/eth/0/type static" -NoNewWindow -Wait    
  Start-Process $VBOX_MANAGE  "guestproperty set $MV_CLIENTE /DSBOX/eth/0/address 193.147.87.33" -NoNewWindow -Wait    
  Start-Process $VBOX_MANAGE  "guestproperty set $MV_CLIENTE /DSBOX/eth/0/netmask 24" -NoNewWindow -Wait    
  Start-Process $VBOX_MANAGE  "guestproperty set $MV_CLIENTE /DSBOX/eth/1/type static" -NoNewWindow -Wait    
  Start-Process $VBOX_MANAGE  "guestproperty set $MV_CLIENTE /DSBOX/eth/1/address 10.0.3.15" -NoNewWindow -Wait    
  Start-Process $VBOX_MANAGE  "guestproperty set $MV_CLIENTE /DSBOX/eth/1/netmask 24" -NoNewWindow -Wait    
  
  Start-Process $VBOX_MANAGE  "guestproperty set $MV_CLIENTE /DSBOX/default_gateway 193.147.87.1" -NoNewWindow -Wait    
  Start-Process $VBOX_MANAGE  "guestproperty set $MV_CLIENTE /DSBOX/host_name cliente" -NoNewWindow -Wait    
  Start-Process $VBOX_MANAGE  "guestproperty set $MV_CLIENTE /DSBOX/etc_hosts_dump `"cliente:193.147.87.33,balanceador.cda.net:193.147.87.47`" " -NoNewWindow -Wait    
}

# Crear imagen DEL SERVER1 (2º)
$MV_APACHE1="APACHE1_$ID"
if (!(Test-Path -Path "$DIR_BASE\$MV_APACHE1"))  {
# Solo 1 vez
  Start-Process $VBOX_MANAGE  "createvm  --name $MV_APACHE1 --basefolder `"$DIR_BASE`"  --register --ostype Debian_64  " -NoNewWindow -Wait       
  Start-Process $VBOX_MANAGE  "storagectl $MV_APACHE1 --name STORAGE_$MV_APACHE1  --add sata  --portcount 4  " -NoNewWindow -Wait    
  Start-Process $VBOX_MANAGE  "storageattach $MV_APACHE1 --storagectl STORAGE_$MV_APACHE1 --port 0 --device 0 --type hdd --medium `"$DIR_BASE\base_cda.vdi`"  --mtype multiattach " -NoNewWindow -Wait    
  Start-Process $VBOX_MANAGE  "storageattach $MV_APACHE1 --storagectl STORAGE_$MV_APACHE1 --port 1 --device 0 --type hdd --medium `"$DIR_BASE\swap1GB.vdi`"  --mtype immutable " -NoNewWindow -Wait    
  Start-Process $VBOX_MANAGE  "modifyvm $MV_APACHE1 --cpus 2 --memory 512 --pae on --vram 16 --graphicscontroller vboxsvga  --cpuexecutioncap  30 " -NoNewWindow -Wait    
  Start-Process $VBOX_MANAGE  "modifyvm $MV_APACHE1 --nic1 intnet --intnet1 vlan2 --macaddress1 080027222222 --cableconnected1 on --nictype1 82540EM" -NoNewWindow -Wait    

  Start-Process $VBOX_MANAGE  "modifyvm $MV_APACHE1 --nic2 nat  --macaddress2 080027111101 --cableconnected2 on --nictype2 82540EM" -NoNewWindow -Wait  
  Start-Process $VBOX_MANAGE  "modifyvm $MV_APACHE1 --nat-pf2 `"guestssh,tcp,,2223,,22`" " -NoNewWindow -Wait 
  Start-Process $VBOX_MANAGE  "modifyvm $MV_APACHE1 --clipboard-mode bidirectional " -NoNewWindow -Wait   

  Start-Process $VBOX_MANAGE  "guestproperty set $MV_APACHE1 /DSBOX/num_interfaces 2" -NoNewWindow -Wait    
  Start-Process $VBOX_MANAGE  "guestproperty set $MV_APACHE1 /DSBOX/eth/0/type static" -NoNewWindow -Wait    
  Start-Process $VBOX_MANAGE  "guestproperty set $MV_APACHE1 /DSBOX/eth/0/address 10.10.10.11" -NoNewWindow -Wait    
  Start-Process $VBOX_MANAGE  "guestproperty set $MV_APACHE1 /DSBOX/eth/0/netmask 24" -NoNewWindow -Wait    
  Start-Process $VBOX_MANAGE  "guestproperty set $MV_APACHE1 /DSBOX/eth/1/type static" -NoNewWindow -Wait    
  Start-Process $VBOX_MANAGE  "guestproperty set $MV_APACHE1 /DSBOX/eth/1/address 10.0.3.15" -NoNewWindow -Wait    
  Start-Process $VBOX_MANAGE  "guestproperty set $MV_APACHE1 /DSBOX/eth/1/netmask 24" -NoNewWindow -Wait    
  Start-Process $VBOX_MANAGE  "guestproperty set $MV_APACHE1 /DSBOX/default_gateway 10.10.10.1" -NoNewWindow -Wait    
  Start-Process $VBOX_MANAGE  "guestproperty set $MV_APACHE1 /DSBOX/host_name apache1" -NoNewWindow -Wait    
  Start-Process $VBOX_MANAGE  "guestproperty set $MV_APACHE1 /DSBOX/etc_hosts_dump `"balanceador:10.10.10.1,apache2:10.10.10.22`" " -NoNewWindow -Wait    
}

# Crear imagen DEL SERVER2 (3º)
$MV_APACHE2="APACHE2_$ID"
if (!(Test-Path -Path "$DIR_BASE\$MV_APACHE2"))  {
# Solo 1 vez
  Start-Process $VBOX_MANAGE  "createvm  --name $MV_APACHE2 --basefolder `"$DIR_BASE`"  --register --ostype Debian_64 " -NoNewWindow -Wait       
  Start-Process $VBOX_MANAGE  "storagectl $MV_APACHE2 --name STORAGE_$MV_APACHE2  --add sata  --portcount 4   " -NoNewWindow -Wait    
  Start-Process $VBOX_MANAGE  "storageattach $MV_APACHE2 --storagectl STORAGE_$MV_APACHE2 --port 0 --device 0 --type hdd --medium `"$DIR_BASE\base_cda.vdi`"  --mtype multiattach " -NoNewWindow -Wait    
  Start-Process $VBOX_MANAGE  "storageattach $MV_APACHE2 --storagectl STORAGE_$MV_APACHE2 --port 1 --device 0 --type hdd --medium `"$DIR_BASE\swap1GB.vdi`"  --mtype immutable " -NoNewWindow -Wait    
  Start-Process $VBOX_MANAGE  "modifyvm $MV_APACHE2 --cpus 2 --memory 512 --pae on --vram 16 --graphicscontroller vboxsvga  --cpuexecutioncap  30 " -NoNewWindow -Wait    
  Start-Process $VBOX_MANAGE  "modifyvm $MV_APACHE2 --nic1 intnet --intnet1 vlan2 --macaddress1 080027222223 --cableconnected1 on --nictype1 82540EM" -NoNewWindow -Wait    

  Start-Process $VBOX_MANAGE  "modifyvm $MV_APACHE2 --nic2 nat  --macaddress2 080027111102 --cableconnected2 on --nictype2 82540EM" -NoNewWindow -Wait  
  Start-Process $VBOX_MANAGE  "modifyvm $MV_APACHE2 --nat-pf2 `"guestssh,tcp,,2224,,22`" " -NoNewWindow -Wait 
  Start-Process $VBOX_MANAGE  "modifyvm $MV_APACHE2 --clipboard-mode bidirectional " -NoNewWindow -Wait     
  
  Start-Process $VBOX_MANAGE  "guestproperty set $MV_APACHE2 /DSBOX/num_interfaces 2" -NoNewWindow -Wait    
  Start-Process $VBOX_MANAGE  "guestproperty set $MV_APACHE2 /DSBOX/eth/0/type static" -NoNewWindow -Wait    
  Start-Process $VBOX_MANAGE  "guestproperty set $MV_APACHE2 /DSBOX/eth/0/address 10.10.10.22" -NoNewWindow -Wait    
  Start-Process $VBOX_MANAGE  "guestproperty set $MV_APACHE2 /DSBOX/eth/0/netmask 24" -NoNewWindow -Wait    
  Start-Process $VBOX_MANAGE  "guestproperty set $MV_APACHE2 /DSBOX/eth/1/type static" -NoNewWindow -Wait    
  Start-Process $VBOX_MANAGE  "guestproperty set $MV_APACHE2 /DSBOX/eth/1/address 10.0.3.15" -NoNewWindow -Wait    
  Start-Process $VBOX_MANAGE  "guestproperty set $MV_APACHE2 /DSBOX/eth/1/netmask 24" -NoNewWindow -Wait    
  Start-Process $VBOX_MANAGE  "guestproperty set $MV_APACHE2 /DSBOX/default_gateway 10.10.10.1" -NoNewWindow -Wait    
  Start-Process $VBOX_MANAGE  "guestproperty set $MV_APACHE2 /DSBOX/host_name apache2" -NoNewWindow -Wait    
  Start-Process $VBOX_MANAGE  "guestproperty set $MV_APACHE2 /DSBOX/etc_hosts_dump `"balanceador:10.10.10.1,apache1:10.10.10.11`" " -NoNewWindow -Wait    
}

# Crear imagen DEL BALANCEADOR (4º)
$MV_BALANCEADOR="BALANCEADOR_$ID"
if (!(Test-Path -Path "$DIR_BASE\$MV_BALANCEADOR"))  {
# Solo 1 vez
  Start-Process $VBOX_MANAGE  "createvm  --name $MV_BALANCEADOR --basefolder `"$DIR_BASE`"  --register  --ostype Debian_64   " -NoNewWindow -Wait    
  Start-Process $VBOX_MANAGE  "storagectl $MV_BALANCEADOR --name STORAGE_$MV_BALANCEADOR  --add sata     " -NoNewWindow -Wait    
  Start-Process $VBOX_MANAGE  "storageattach $MV_BALANCEADOR --storagectl STORAGE_$MV_BALANCEADOR --port 0 --device 0 --type hdd --medium `"$DIR_BASE\base_cda.vdi`"  --mtype multiattach " -NoNewWindow -Wait    
  Start-Process $VBOX_MANAGE  "storageattach $MV_BALANCEADOR --storagectl STORAGE_$MV_BALANCEADOR --port 1 --device 0 --type hdd --medium `"$DIR_BASE\swap1GB.vdi`"  --mtype immutable " -NoNewWindow -Wait    
  Start-Process $VBOX_MANAGE  "modifyvm $MV_BALANCEADOR --cpus 2 --memory 512 --pae on --vram 16 --graphicscontroller vboxsvga" -NoNewWindow -Wait    
  Start-Process $VBOX_MANAGE  "modifyvm $MV_BALANCEADOR --nic1 intnet --intnet1 vlan1 --macaddress1 080027444444 --cableconnected1 on --nictype1 82540EM " -NoNewWindow -Wait    
  Start-Process $VBOX_MANAGE  "modifyvm $MV_BALANCEADOR --nic2 intnet --intnet2 vlan2 --macaddress2 080027555555 --cableconnected2 on --nictype2 82540EM " -NoNewWindow -Wait    
  Start-Process $VBOX_MANAGE  "modifyvm $MV_BALANCEADOR --nic3 nat --macaddress3 080027666666 --cableconnected3 on --nictype3 82540EM " -NoNewWindow -Wait    
  
  Start-Process $VBOX_MANAGE  "modifyvm $MV_BALANCEADOR --nat-pf3 `"guestssh,tcp,,2225,,22`" " -NoNewWindow -Wait 
  Start-Process $VBOX_MANAGE  "modifyvm $MV_BALANCEADOR --clipboard-mode bidirectional " -NoNewWindow -Wait     
  

  Start-Process $VBOX_MANAGE  "guestproperty set $MV_BALANCEADOR /DSBOX/num_interfaces 3" -NoNewWindow -Wait    
  Start-Process $VBOX_MANAGE  "guestproperty set $MV_BALANCEADOR /DSBOX/eth/0/type static" -NoNewWindow -Wait    
  Start-Process $VBOX_MANAGE  "guestproperty set $MV_BALANCEADOR /DSBOX/eth/0/address 193.147.87.47" -NoNewWindow -Wait    
  Start-Process $VBOX_MANAGE  "guestproperty set $MV_BALANCEADOR /DSBOX/eth/0/netmask 24" -NoNewWindow -Wait    
  Start-Process $VBOX_MANAGE  "guestproperty set $MV_BALANCEADOR /DSBOX/eth/1/type static" -NoNewWindow -Wait    
  Start-Process $VBOX_MANAGE  "guestproperty set $MV_BALANCEADOR /DSBOX/eth/1/address 10.10.10.1" -NoNewWindow -Wait    
  Start-Process $VBOX_MANAGE  "guestproperty set $MV_BALANCEADOR /DSBOX/eth/1/netmask 24" -NoNewWindow -Wait    
  Start-Process $VBOX_MANAGE  "guestproperty set $MV_BALANCEADOR /DSBOX/eth/2/type static" -NoNewWindow -Wait    
  Start-Process $VBOX_MANAGE  "guestproperty set $MV_BALANCEADOR /DSBOX/eth/2/address 10.0.4.15" -NoNewWindow -Wait    
  Start-Process $VBOX_MANAGE  "guestproperty set $MV_BALANCEADOR /DSBOX/eth/2/netmask 24" -NoNewWindow -Wait    
  Start-Process $VBOX_MANAGE  "guestproperty set $MV_BALANCEADOR /DSBOX/default_gateway 10.0.4.2" -NoNewWindow -Wait    
  Start-Process $VBOX_MANAGE  "guestproperty set $MV_BALANCEADOR /DSBOX/host_name balanceador.cda.net" -NoNewWindow -Wait    
  Start-Process $VBOX_MANAGE  "guestproperty set $MV_BALANCEADOR /DSBOX/etc_hosts_dump `"balanceador.cda.net:193.147.87.47,cliente:193.147.87.33,apache1:10.10.10.11,apache2:10.10.10.22`" " -NoNewWindow -Wait    
}

# Crear imagen DEL TARGET iSCSI (5º)
$MV_DISCOS="DISCOS_$ID"
if (!(Test-Path -Path "$DIR_BASE\$MV_DISCOS"))  {
# Solo 1 vez
  Start-Process $VBOX_MANAGE  "createvm  --name $MV_DISCOS --basefolder `"$DIR_BASE`"  --register --ostype Debian_64 " -NoNewWindow -Wait
  Start-Process $VBOX_MANAGE  "storagectl $MV_DISCOS --name STORAGE_$MV_DISCOS  --add sata --portcount 4" -NoNewWindow -Wait
  Start-Process $VBOX_MANAGE  "storageattach $MV_DISCOS --storagectl STORAGE_$MV_DISCOS --port 0 --device 0 --type hdd --medium `"$DIR_BASE\base_cda.vdi`"  --mtype multiattach " -NoNewWindow -Wait
  Start-Process $VBOX_MANAGE  "storageattach $MV_DISCOS --storagectl STORAGE_$MV_DISCOS --port 1 --device 0 --type hdd --medium `"$DIR_BASE\swap1GB.vdi`"  --mtype immutable " -NoNewWindow -Wait
  Start-Process $VBOX_MANAGE  "modifyvm $MV_DISCOS --cpus 2 --memory 512 --pae on --vram 16 --graphicscontroller vboxsvga" -NoNewWindow -Wait
  Start-Process $VBOX_MANAGE  "modifyvm $MV_DISCOS --nic1 intnet --intnet1 vlan1 --macaddress1 080027111112 --cableconnected1 on --nictype1 82540EM " -NoNewWindow -Wait

  Start-Process $VBOX_MANAGE  "modifyvm $MV_DISCOS --nic2 nat  --macaddress2 080027111104 --cableconnected2 on --nictype2 82540EM" -NoNewWindow -Wait
  Start-Process $VBOX_MANAGE  "modifyvm $MV_DISCOS --nat-pf2 `"guestssh,tcp,,2222,,22`" " -NoNewWindow -Wait
  Start-Process $VBOX_MANAGE  "modifyvm $MV_DISCOS --clipboard-mode bidirectional " -NoNewWindow -Wait
  
  Start-Process $VBOX_MANAGE  "guestproperty set $MV_DISCOS /DSBOX/num_interfaces 2" -NoNewWindow -Wait
  Start-Process $VBOX_MANAGE  "guestproperty set $MV_DISCOS /DSBOX/eth/0/type static" -NoNewWindow -Wait
  Start-Process $VBOX_MANAGE  "guestproperty set $MV_DISCOS /DSBOX/eth/0/address 192.168.100.11" -NoNewWindow -Wait
  Start-Process $VBOX_MANAGE  "guestproperty set $MV_DISCOS /DSBOX/eth/0/netmask 24" -NoNewWindow -Wait

  Start-Process $VBOX_MANAGE  "guestproperty set $MV_DISCOS /DSBOX/eth/1/type static" -NoNewWindow -Wait
  Start-Process $VBOX_MANAGE  "guestproperty set $MV_DISCOS /DSBOX/eth/1/address 10.0.3.15" -NoNewWindow -Wait
  Start-Process $VBOX_MANAGE  "guestproperty set $MV_DISCOS /DSBOX/eth/1/netmask 24" -NoNewWindow -Wait
  
  Start-Process $VBOX_MANAGE  "guestproperty set $MV_DISCOS /DSBOX/default_gateway 10.0.3.2" -NoNewWindow -Wait
  Start-Process $VBOX_MANAGE  "guestproperty set $MV_DISCOS /DSBOX/default_nameserver 8.8.8.8" -NoNewWindow -Wait
  Start-Process $VBOX_MANAGE  "guestproperty set $MV_DISCOS /DSBOX/host_name discos.cda.net" -NoNewWindow -Wait
  Start-Process $VBOX_MANAGE  "guestproperty set $MV_DISCOS /DSBOX/etc_hosts_dump `"discos.cda.net:192.168.100.11,cliente1.cda.net:192.168.100.22,cliente2.cda.net:192.168.100.33`" " -NoNewWindow -Wait

  if ( !(Test-Path -Path "$DIR_BASE/ISCSI1_$MV_DISCOS.vdi" )) {
    Start-Process $VBOX_MANAGE "createhd --filename `"$DIR_BASE/ISCSI1_$MV_DISCOS.vdi`" --size 100 --format VDI" -NoNewWindow -Wait
    Start-Process $VBOX_MANAGE "storageattach $MV_DISCOS --storagectl STORAGE_$MV_DISCOS --port 2 --device 0 --type hdd --medium `"$DIR_BASE/ISCSI1_$MV_DISCOS.vdi`" " -NoNewWindow -Wait
  }
  
  if ( !(Test-Path -Path "$DIR_BASE/ISCSI2_$MV_DISCOS.vdi" )) {
    Start-Process $VBOX_MANAGE "createhd --filename `"$DIR_BASE/ISCSI2_$MV_DISCOS.vdi`" --size 100 --format VDI"  -NoNewWindow -Wait
    Start-Process $VBOX_MANAGE "storageattach $MV_DISCOS --storagectl STORAGE_$MV_DISCOS --port 3 --device 0 --type hdd --medium `"$DIR_BASE/ISCSI2_$MV_DISCOS.vdi`" "  -NoNewWindow -Wait 
  }
  
  if ( !(Test-Path -Path "$DIR_BASE/ISCSI3_$MV_DISCOS.vdi" )){
    Start-Process $VBOX_MANAGE "createhd --filename `"$DIR_BASE/ISCSI3_$MV_DISCOS.vdi`" --size 100 --format VDI" -NoNewWindow -Wait
    Start-Process $VBOX_MANAGE "storageattach $MV_DISCOS --storagectl STORAGE_$MV_DISCOS --port 4 --device 0 --type hdd --medium `"$DIR_BASE/ISCSI3_$MV_DISCOS.vdi`" " -NoNewWindow -Wait
  }
  
  if ( !(Test-Path -Path "$DIR_BASE/ISCSI4_$MV_DISCOS.vdi" )) {
    Start-Process $VBOX_MANAGE "createhd --filename `"$DIR_BASE/ISCSI4_$MV_DISCOS.vdi`" --size 100 --format VDI" -NoNewWindow -Wait
    Start-Process $VBOX_MANAGE "storageattach $MV_DISCOS --storagectl STORAGE_$MV_DISCOS --port 5 --device 0 --type hdd --medium `"$DIR_BASE/ISCSI4_$MV_DISCOS.vdi`"" -NoNewWindow -Wait
  }

}


Write-Host "Arrancando maquinas virtuales ..."
Start-Process $VBOX_MANAGE  "startvm $MV_CLIENTE" -NoNewWindow -Wait    
Start-Process $VBOX_MANAGE  "startvm $MV_APACHE1" -NoNewWindow -Wait    
Start-Process $VBOX_MANAGE  "startvm $MV_APACHE2" -NoNewWindow -Wait    
Start-Process $VBOX_MANAGE  "startvm $MV_BALANCEADOR" -NoNewWindow -Wait  
Start-Process $VBOX_MANAGE  "startvm $MV_DISCOS" -NoNewWindow -Wait  

Write-Host "Maquinas virtuales arrancadas"
Start-Process $VBOX_MANAGE  "controlvm  $MV_CLIENTE clipboard mode bidirectional" -NoNewWindow -Wait
Start-Process $VBOX_MANAGE  "controlvm  $MV_APACHE1 clipboard mode bidirectional" -NoNewWindow -Wait
Start-Process $VBOX_MANAGE  "controlvm  $MV_APACHE2 clipboard mode bidirectional" -NoNewWindow -Wait
Start-Process $VBOX_MANAGE  "controlvm  $MV_BALANCEADOR clipboard mode bidirectional" -NoNewWindow -Wait
Start-Process $VBOX_MANAGE  "controlvm  $MV_DISCOS clipboard mode bidirectional" -NoNewWindow -Wait