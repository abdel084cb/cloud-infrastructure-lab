# main.tf
# Este fichero declara los proveedores libvirt y cloudinit
# y define la configuracion de libvirt.
terraform {
  required_providers {
    # Proveedor libvirt
    libvirt = {
      source = "dmacvicar/libvirt"
    }

    # Proveedor cloudinit: permite aplicar configuraciones automaticas a la VM
    # usando ficheros de tipo cloud-init (como cloud-config.yaml)
    cloudinit = {
      source ="hashicorp/cloudinit"
    }
  }
}

# Configuracion libvirt
provider "libvirt" {
  ## Configuration options
  uri = "qemu:///system"
  #alias = "server2"
  #uri   = "qemu+ssh://root@192.168.100.10/system"
}
