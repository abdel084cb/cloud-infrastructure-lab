# libvirt.tf
# Este fichero define todos los recursos necesarios para desplegar la VM computenode
# mediante Opentofu y el proveedor libvirt.

# Pool de almacenamiento
resource "libvirt_pool" "tofu_pool_compute" {
  name = "tofu_pool_compute"
  type = "dir"
  target {
	path = "/adsis2/tofu_libvirt_pool-compute"
  }
}


# Volumen base que actua como plantilla del SO
resource "libvirt_volume" "dev_base_devstack" {
  name = "dev_base_devstack"
  pool = libvirt_pool.tofu_pool_compute.name
  #source = "/home/tmp/images/WithCloudinit/debian_base_devstack_2025.1.qcow2"
  source = "/adsis2/WithCloudinit/debian_computenode.qcow2" # Nueva imagen
  format = "qcow2"
}

# Volumen principal de la VM (se crea como clon del volumen base)
resource "libvirt_volume" "server_disk_compute" {
  name           = "server-disk-compute"
  size           = 50000000000
  pool           = libvirt_pool.tofu_pool_compute.name
  base_volume_id = libvirt_volume.dev_base_devstack.id
}

# Configuracion de CloudInit
# Carga el fichero cloud-config.yaml para generar el disco ISO de configuracion
data "cloudinit_config" "user_data_compute" {
  gzip = false
  base64_encode = false

  part {
    filename = "cloud-config.yaml"
    content_type = "text/cloud-config"
    content = file("${path.module}/cloud-config.yaml")
  }
}

# Disco ISO que se inyectará con los datos de cloud-init
resource "libvirt_cloudinit_disk" "commoninit_compute" {
  name           = "commoninit_compute.iso"
  pool           = libvirt_pool.tofu_pool_compute.name # List storage pools with virsh pool-list
  user_data      = "${data.cloudinit_config.user_data_compute.rendered}"
}

# Definicion de la VM
resource "libvirt_domain" "computenode" {
  name   = "computenode"
  memory = "4048"
  vcpu   = 3
  # qemu_agent = true

  # Envio de local.conf
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

  # Pasamos la configuracion del host directamente
  cpu {
    mode = "host-passthrough"
  }

  # Configuracion de red: asignacion de IP, MAC, red libvirt y nombre de host
  network_interface {
    network_name = "openstack13" # List networks with virsh net-list
    hostname       = "computenode"
    addresses      = [ "${var.host_ip}" ] # var.host
    mac            = "52:54:00:ff:ab:ce"
    wait_for_lease = false
  }

  # Disco principal de la VM
  disk {
    volume_id = "${libvirt_volume.server_disk_compute.id}"
  }

  # Disco cloud-init ISO con configuración inicial
  cloudinit = "${libvirt_cloudinit_disk.commoninit_compute.id}"

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
