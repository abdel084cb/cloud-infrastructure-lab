# main.tf (redlibvirt)
# Este fichero declara los proveedores libvirt y cloudinit, ademas de definir la configuracion de libvirt.
# indicando la red virtual NAT.

# Se requieren los siguientes proveedores:
# - libvirt
# - cloudinit
terraform {
  required_providers {
    libvirt = {
      source = "dmacvicar/libvirt"
    }
    cloudinit = {
      source ="hashicorp/cloudinit"
    }
  }
}

# Se configura el proveedor libvirt, que se conecta al hipervisor local mediante URI.
provider "libvirt" {
  ## Configuration options
  uri = "qemu:///system"
  #alias = "server2"
  #uri   = "qemu+ssh://root@192.168.100.10/system"
}

# Definicion de la red virtual openstack13.
resource "libvirt_network" "openstack_networkW" {
  # Nombre de la red
  name = "openstack13"
  # Modo NAT: salida a Internet mediante el host
  mode = "nat"
  # Rango de IPs asignadas a esta red
  addresses = ["192.168.13.0/24"]
}
