# libvirt.tf
# Este fichero define todos los recursos necesarios para desplegar la VM controlador
# utilizando Opentofu y el proveedor libvirt.

# Definicion del pool de almacenamiento
resource "libvirt_pool" "tofu_pool" {
  name = "tofu_pool"
  type = "dir" # carpeta
  target {
    # modificar con PATH /misc/alumnos/as2/as22024/aXXXXXX/images/
    # creado previamente ?
  
  # ruta donde se almacenaran los volumenes del pool
	path = "/adsis2/tofu_libvirt_pool-controller"
  }
}

# Definicion de los volumenes de disco
resource "libvirt_volume" "dev_base_devstack" {
  # volumen base
  name = "dev_base_devstack"
  # se almacena en el pool definido anteriormente
  pool = libvirt_pool.tofu_pool.name # List storage pools using virsh pool-list
  # imagen base
  source = "/adsis2/WithCloudinit/debian_base_devstack_2025.1.qcow2"
  #source = "/home/tmp/images/WithCloudinit/ubuntu22.04-base.qcow2"
  format = "qcow2"
}

resource "libvirt_volume" "server_disk" {
  # nombre del disco principal
  name           = "server-disk"
  # 20GB
  size           = 20000000000
  # pool donde se almacenara el volumen
  pool           = libvirt_pool.tofu_pool.name
  # clonamos el volumen base
  base_volume_id = libvirt_volume.dev_base_devstack.id
}

# Definir e inyectar la configuracion de cloud-init
data "cloudinit_config" "user_data" {
  gzip = false
  base64_encode = false

  part {
    filename = "cloud-config.yaml"
    content_type = "text/cloud-config"
    # ruta al fichero a inyectar
    content = file("${path.module}/cloud-config.yaml")
  }
}

resource "libvirt_cloudinit_disk" "commoninit" {
  name           = "commoninit.iso"
  pool           = libvirt_pool.tofu_pool.name # List storage pools with virsh pool-list
  user_data      = "${data.cloudinit_config.user_data.rendered}"
}

# Definir la VM controlador
resource "libvirt_domain" "controlador" {
  name   = "controlador"
  memory = "6000"
  vcpu   = 4
  # qemu_agent = true

  boot_device {
    dev = [ "hd" ]
  }

  # Envio del fichero local.conf tras la creacion de la VM
  provisioner "file" {
    source      = "local.conf"
    destination = "/opt/stack/devstack/local.conf"

    connection {
      type     = "ssh"
      user     = "stack"
      host     = "${var.host_ip}"
      private_key = "${file("${var.private_key}")}" # host key validation disabled by default

    }
  }

  # Envio del fichero local.sh
  provisioner "file" {
    source      = "local.sh"
    destination = "/opt/stack/devstack/local.sh"

    connection {
      type     = "ssh"
      user     = "stack"
      host     = "${var.host_ip}"
      private_key = "${file("${var.private_key}")}" # host key validation disabled by default
    }
  }

  cpu {
    mode = "host-passthrough"
  }

  # Configuracion de la red, indicando la mac, la ip, el hostname y la red openstack13
  network_interface {
    network_name   = "openstack13" # List networks with virsh net-list
    hostname       = "controlador"
    addresses      = [ "${var.host_ip}" ] # var.host
    mac            = "52:54:00:ff:ab:cd"
    wait_for_lease = false
  }

  disk {
    volume_id = "${libvirt_volume.server_disk.id}"
  }

  # disco iso generado por cloud-init
  cloudinit = "${libvirt_cloudinit_disk.commoninit.id}"

  console {
    type = "pty"
    target_type = "serial"
    target_port = "0"
  }

  graphics {
    type = "spice"
    listen_type = "address"
    autoport = true
  }
}

# Output Server IP
#output "ip" {
#  value = "${libvirt_domain.controladorceph.0.addresses.0}"
#}
