# openstack.tf
# Este fichero define todos los recursos necesarios para desplegar una VM
# en el cloud OpenStack mediante Opentofu: red, router, subred, grupo de seguridad,
# clave SSH, instancia y asociacion de IP flotante.

# Par de claves SSH
resource "openstack_compute_keypair_v2" "pruebakeypair" {
  name       = "pruebakeypair"
  public_key = "${file("${var.ssh_key_file}.pub")}"
}

# Red privada
resource "openstack_networking_network_v2" "pruebanetwork" {
  name           = "pruebanetwork"
  admin_state_up = "true"
}

# Subred dentro de la red privada
# Se le asigna el rango de IPs y se le asignan servidores DNS
resource "openstack_networking_subnet_v2" "pruebasubnet" {
  name            = "pruebasubnet"
  network_id      = "${openstack_networking_network_v2.pruebanetwork.id}"
  cidr            = "10.0.0.0/24"
  ip_version      = 4
  dns_nameservers = ["9.9.9.9", "9.9.9.11"]
}

# Crea un router virtual de Neutron que conecta la subred privada con la red
# publica, permitiendo que la instancias tenga salida al exterior mediante 
# NAT (cuando se le asigna una IP flotante).
resource "openstack_networking_router_v2" "pruebarouter" {
  name                = "pruebarouter"
  admin_state_up      = "true"
  external_network_id = "${data.openstack_networking_network_v2.public.id}"
}

# Conecta la subred privada al router, permitiendo el trafico entre ambas redes.
resource "openstack_networking_router_interface_v2" "pruebarouterinterface" {
  router_id = "${openstack_networking_router_v2.pruebarouter.id}"
  subnet_id = "${openstack_networking_subnet_v2.pruebasubnet.id}"
}

# Creamos un grupo de seguridad para la instancia
resource "openstack_networking_secgroup_v2" "pruebasecgroup" {
  name        = "pruebasecgroup"
  description = "Security group for the Terraform example instances"
}

# Permitimos el trafico SSH (22) desde cualquier IP
resource "openstack_networking_secgroup_rule_v2" "prueba_22" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = "${openstack_networking_secgroup_v2.pruebasecgroup.id}"
}

#resource "openstack_networking_secgroup_rule_v2" "prueba_80" {
#  direction         = "ingress"
#  ethertype         = "IPv4"
#  protocol          = "tcp"
#  port_range_min    = 80
#  port_range_max    = 80
#  remote_ip_prefix  = "0.0.0.0/0"
#  security_group_id = "${openstack_networking_secgroup_v2.pruebasecgroup.id}"
#}

# Permitimos el trafico ICMP (ping) desde cualquier IP
resource "openstack_networking_secgroup_rule_v2" "prueba_icmp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = "${openstack_networking_secgroup_v2.pruebasecgroup.id}"
}

# Solicita una IP flotante desde la red publica definida en var.pool
resource "openstack_networking_floatingip_v2" "pruebafloatingip" {
  pool = "${var.pool}"
}

# Definimos la instancia
resource "openstack_compute_instance_v2" "pruebainstance" {
  name            = "pruebainstance"
  image_name      = "${var.image}"
  flavor_name     = "${var.flavor}"
  key_pair        = "${openstack_compute_keypair_v2.pruebakeypair.name}"
  security_groups = ["${openstack_networking_secgroup_v2.pruebasecgroup.name}"]
  user_data = "#cloud-config\npassword: ubuntu\nchpasswd: { expire: False }\nssh_pwauth: True"

  # Conexion a la red privada creada anteriormente
  network {
    uuid = "${openstack_networking_network_v2.pruebanetwork.id}"
  }
  # Se asegura que la subred este creada antes que la instancia
  depends_on = [
    openstack_networking_subnet_v2.pruebasubnet
  ]
}

# Consulta el puerto de red asignado automaticamente a la instancia.
# Se usara para asociar la IP flotante.
data "openstack_networking_port_v2" "port" {
  device_id  = openstack_compute_instance_v2.pruebainstance.id
  network_id = openstack_compute_instance_v2.pruebainstance.network.0.uuid
}

# Asocia la IP flotante al puerto de la instancia
# Esto permite conectarse desde fuera con SSH al usuario ubuntu.
resource "openstack_networking_floatingip_associate_v2" "fip_associate" {
  floating_ip = "${openstack_networking_floatingip_v2.pruebafloatingip.address}"
  port_id     = data.openstack_networking_port_v2.port.id

  #provisioner "remote-exec" {
  #  connection {
  #    type     = "ssh"
  #    host        = "${openstack_networking_floatingip_v2.pruebafloatingip.address}"
  #    user        = "${var.ssh_user_name}"
  #    private_key = "${file("${var.ssh_key_file}")}"
  #  }

   # inline = [
   #   "sudo apt-get -y update",
   #   "sudo apt-get -y install nginx",
   #   "sudo service nginx start",
   # ]
  #}
}
