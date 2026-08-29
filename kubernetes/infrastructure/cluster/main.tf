# main.tf para el despliegue de un cluster Kubernetes usando Libvirt
# Este archivo define toda la infraestructura necesaria para un cluster K3s 
# con un nodo master y varios nodos worker usando virtualizacion KVM/QEMU.

# -----------------------------------------------------------
# CONFIGURACION BASICA
# -----------------------------------------------------------

# Define los proveedores necesarios para este despliegue
terraform {
  required_providers {
    # Proveedor libvirt
    libvirt = {
      source = "dmacvicar/libvirt"
    }
    # Proveedor null: permite ejecutar comandos en el sistema host
    null = {
      source = "hashicorp/null"
    }
  }
}

# Variables locales
locals {
  # Dominio DNS
  base_domain = var.base_domain
  # Identificador de red
  w           = var.w_identifier
  # Directorio donde se almacenan los discos e imagenes
  volume_path = var.volume_path
}

provider "libvirt" {
  uri = "qemu:///system"  # Conectar al hipervisor
}

# -----------------------------------------------------------
# ALMACENAMIENTO Y DISCOS
# -----------------------------------------------------------

# Crea un disco adicional para los workers (usado por almacenamiento Ceph)
resource "null_resource" "create_worker_disk" {
  provisioner "local-exec" {
    # Crear archivo de 30GB para discos de almacenamiento Ceph
    command = "qemu-img create -f qcow2 ${var.volume_path}/worker-disk.qcow2 ${var.ceph_disk_gb}G"
    on_failure = continue  # No fallar si el disco ya existe
  }
}

# Crea un pool de almacenamiento para todas las VMs del cluster
resource "libvirt_pool" "k8s_pool" {
  name = "k8s_pool"  # Nombre visible en virsh pool-list
  type = "dir"       # Tipo directorio
  
  target {
    path = var.volume_path  # Ubicacion
  }
}

# Registra la imagen base Ubuntu en el pool
resource "libvirt_volume" "ubuntu_base" {
  name   = var.base_image   # Nombre del volumen
  pool   = libvirt_pool.k8s_pool.name
  source = "${var.volume_path}/${var.base_image}.img"  # Imagen Ubuntu
  format = "qcow2"  # Formato de disco
}

# Crea el disco principal para el nodo master a partir de la imagen base
resource "libvirt_volume" "master_volume" {
  name           = "${var.master_config.name}-volume"  # Nombre descriptivo
  base_volume_id = libvirt_volume.ubuntu_base.id  # Clonar desde imagen base
  pool           = libvirt_pool.k8s_pool.name
  size           = var.master_config.disk_gb * 1024 * 1024 * 1024  # Tamaño en bytes
}

# Crea discos principales para todos los nodos worker a partir de la imagen base
resource "libvirt_volume" "worker_volumes" {
  count          = length(var.workers_config)  # Un volumen por cada worker
  name           = "${var.workers_config[count.index].name}-volume"
  base_volume_id = libvirt_volume.ubuntu_base.id
  pool           = libvirt_pool.k8s_pool.name
  size           = var.workers_config[count.index].disk_gb * 1024 * 1024 * 1024
}

# Crea discos adicionales para el almacenamiento distribuido Ceph en cada worker
resource "libvirt_volume" "worker_ceph_volumes" {
  count  = length(var.workers_config)  # Un volumen Ceph por cada worker
  name   = "${var.workers_config[count.index].name}-ceph"
  source = "${var.volume_path}/worker-disk.qcow2"  # Usa el disco creado anteriormente
  pool   = libvirt_pool.k8s_pool.name
  format = "qcow2"
  depends_on = [null_resource.create_worker_disk]  # Esperar a que el disco este creado
}

# -----------------------------------------------------------
# CONFIGURACION CLOUD-INIT PARA APROVISIONAMIENTO INICIAL
# -----------------------------------------------------------

# Prepara la configuracion cloud-init para el nodo master
# Cloud-init permite automatizar la configuracion inicial de la VM
data "cloudinit_config" "master_user_data" {
  gzip = false
  base64_encode = false

  part {
    filename = "cloud-config-master.yaml"
    content_type = "text/cloud-config"
    content = file("${path.module}/cloud-config-master.yaml")  # Archivo con usuarios, claves SSH, etc.
  }
}

# Prepara la configuracion cloud-init para los nodos worker
data "cloudinit_config" "worker_user_data" {
  gzip = false
  base64_encode = false

  part {
    filename = "cloud-config-worker.yaml"
    content_type = "text/cloud-config"
    content = file("${path.module}/cloud-config-worker.yaml")  # Similar al master pero para workers
  }
}

# Crea el disco ISO de cloud-init para el nodo master
# Este ISO se monta en la VM y ejecuta la configuracion inicial
resource "libvirt_cloudinit_disk" "master_cloudinit" {
  name           = "${var.master_config.name}-cloudinit.iso"
  pool           = libvirt_pool.k8s_pool.name
  user_data      = data.cloudinit_config.master_user_data.rendered
}

# Crea discos ISO cloud-init para todos los workers
resource "libvirt_cloudinit_disk" "worker_cloudinit" {
  count          = length(var.workers_config)
  name           = "${var.workers_config[count.index].name}-cloudinit.iso"
  pool           = libvirt_pool.k8s_pool.name
  user_data      = data.cloudinit_config.worker_user_data.rendered
}

# -----------------------------------------------------------
# DEFINICION DE LAS MAQUINAS VIRTUALES
# -----------------------------------------------------------

# Define la VM para el nodo master del cluster K3s
resource "libvirt_domain" "master" {
  name    = var.master_config.name   # Nombre de la VM
  memory  = var.master_config.memory # Memoria RAM en MB
  vcpu    = var.master_config.vcpu   # NUmero de CPUs
  
  cloudinit = libvirt_cloudinit_disk.master_cloudinit.id  # Asocia el disco cloud-init

  # Pasamos las caracteristicas CPU del host a la VM
  cpu {
    mode = "host-passthrough"
  }

  # Configuracion de red con IP estatica en la red openstack13
  network_interface {
    network_name   = "openstack13"  # Red existente en KVM
    addresses      = ["192.168.${var.w_identifier}.${var.master_config.ip}"]  # IP fija 192.168.13.6
    mac            = "52:54:00:ff:13:01"  # MAC fija para el master
    hostname       = var.master_config.name
    wait_for_lease = false  # No esperar a DHCP, usamos IP estatica
  }

  # Asigna el disco principal creado anteriormente
  disk {
    volume_id = libvirt_volume.master_volume.id
  }

  # Configura acceso a consola
  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  # -----------------------------------------------------------
  # APROVISIONAMIENTO DEL NODO MASTER
  # -----------------------------------------------------------

  # Copia el binario K3s al nodo master
  provisioner "file" {
    source      = "${path.module}/${var.scripts_path}/k3s" 
    destination = "/tmp/k3s"

    connection {
      type        = "ssh"
      user        = var.ssh_user_name  # Usuario creado por cloud-init
      private_key = file(var.ssh_key_file)  # Clave SSH para acceder
      host        = "192.168.${var.w_identifier}.${var.master_config.ip}"
    }
  }

  # Copia el script de instalacion para K3s
  provisioner "file" {
    source      = "${path.module}/${var.scripts_path}/install.sh"
    destination = "/home/${var.ssh_user_name}/install.sh"
    
    connection {
      type        = "ssh"
      user        = var.ssh_user_name
      private_key = file(var.ssh_key_file)
      host        = "192.168.${var.w_identifier}.${var.master_config.ip}"
    }
  }

  # Ejecuta comandos para instalar K3s
  provisioner "remote-exec" {
    inline = [
      # Configura el nombre del host
      "sudo hostnamectl set-hostname ${var.master_config.name}",
      # Mueve y hace ejecutable el binario K3s
      "sudo mv /tmp/k3s /usr/local/bin/k3s",
      "sudo chmod +x /usr/local/bin/k3s",
      "chmod +x /home/${var.ssh_user_name}/install.sh",
      # Instala K3s como servidor
      "INSTALL_K3S_SKIP_DOWNLOAD=true ./install.sh server --token \"${var.k3s_token}\" --flannel-iface ens3 --bind-address 192.168.${var.w_identifier}.${var.master_config.ip} --node-ip 192.168.${var.w_identifier}.${var.master_config.ip} --node-name ${var.master_config.name} --disable traefik --disable servicelb --node-taint k3s-controlplane=true:NoExecute",
      # Da permisos de lectura al kubeconfig para copiarlo despues
      "sudo chmod 644 /etc/rancher/k3s/k3s.yaml"
    ]
    
    connection {
      type        = "ssh"
      user        = var.ssh_user_name
      private_key = file(var.ssh_key_file)
      host        = "192.168.${var.w_identifier}.${var.master_config.ip}"
    }
  }
}

# Define las VMs para los nodos worker
resource "libvirt_domain" "worker" {
  count   = length(var.workers_config)  # Creamos varios worker con count
  name    = var.workers_config[count.index].name
  memory  = var.workers_config[count.index].memory
  vcpu    = var.workers_config[count.index].vcpu

  cloudinit = libvirt_cloudinit_disk.worker_cloudinit[count.index].id

  # Pasamos las caracteristicas CPU del host a la VM
  cpu {
    mode = "host-passthrough"
  }

  # Configuracion de red con IPs estaticas (192.168.13.7, .8, .9)
  network_interface {
    network_name   = "openstack13"
    addresses      = ["192.168.${var.w_identifier}.${var.workers_config[count.index].ip}"]
    mac            = "52:54:00:ff:13:${count.index + 2}"  # MACs secuenciales
    hostname       = var.workers_config[count.index].name
    wait_for_lease = false
  }

  # Disco principal del sistema
  disk {
    volume_id = libvirt_volume.worker_volumes[count.index].id
  }

  # Disco adicional para Ceph (almacenamiento distribuido)
  disk {
    volume_id = libvirt_volume.worker_ceph_volumes[count.index].id
  }

  # Configuracion de consola
  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  # -----------------------------------------------------------
  # APROVISIONAMIENTO DE LOS NODOS WORKER
  # -----------------------------------------------------------

  # Copia el binario K3s a cada worker
  provisioner "file" {
    source      = "${path.module}/${var.scripts_path}/k3s"
    destination = "/tmp/k3s"
    
    connection {
      type        = "ssh"
      user        = var.ssh_user_name
      private_key = file(var.ssh_key_file)
      host        = "192.168.${var.w_identifier}.${var.workers_config[count.index].ip}"
    }
  }

  # Copia el script de instalacion a cada worker
  provisioner "file" {
    source      = "${path.module}/${var.scripts_path}/install.sh"
    destination = "/home/${var.ssh_user_name}/install.sh"
    
    connection {
      type        = "ssh"
      user        = var.ssh_user_name
      private_key = file(var.ssh_key_file)
      host        = "192.168.${var.w_identifier}.${var.workers_config[count.index].ip}"
    }
  }

  # Ejecuta comandos para instalar K3s como agente (worker)
  provisioner "remote-exec" {
    inline = [
      # Configura el nombre del host
      "sudo hostnamectl set-hostname ${var.workers_config[count.index].name}",
      # Mueve y hace ejecutable el binario K3s
      "sudo mv /tmp/k3s /usr/local/bin/k3s",
      "sudo chmod +x /usr/local/bin/k3s",
      "chmod +x /home/${var.ssh_user_name}/install.sh",
      # Instala K3s como agente
      "INSTALL_K3S_SKIP_DOWNLOAD=true ./install.sh agent --server https://192.168.${var.w_identifier}.${var.master_config.ip}:6443 --token \"${var.k3s_token}\" --node-ip 192.168.${var.w_identifier}.${var.workers_config[count.index].ip} --node-name ${var.workers_config[count.index].name} --flannel-iface ens3"
    ]
    
    connection {
      type        = "ssh"
      user        = var.ssh_user_name
      private_key = file(var.ssh_key_file)
      host        = "192.168.${var.w_identifier}.${var.workers_config[count.index].ip}"
    }
  }

  # Asegurarse de que el master este listo antes de crear los workers
  depends_on = [libvirt_domain.master]
}

# -----------------------------------------------------------
# CONFIGURACION LOCAL PARA ADMINISTRAR EL CLUSTER
# -----------------------------------------------------------

# Configura el entorno local para administrar el cluster
resource "null_resource" "copy_kubeconfig" {
  provisioner "local-exec" {
    command = <<-EOT
      mkdir -p ~/.kube
      scp -o StrictHostKeyChecking=no -i ${var.ssh_key_file} ${var.ssh_user_name}@192.168.${var.w_identifier}.${var.master_config.ip}:/etc/rancher/k3s/k3s.yaml ~/.kube/config
      sed -i 's/127.0.0.1/192.168.${var.w_identifier}.${var.master_config.ip}/g' ~/.kube/config
      mkdir -p ~/.local/bin
      scp -o StrictHostKeyChecking=no -i ${var.ssh_key_file} ${var.ssh_user_name}@192.168.${var.w_identifier}.${var.master_config.ip}:/usr/local/bin/kubectl ~/.local/bin/
      chmod +x ~/.local/bin/kubectl
    EOT
  }

  # Esperar a que el nodo master este completamente configurado
  depends_on = [libvirt_domain.master]
}
