# main.tf (openstackvmconipflotante)
# Este fichero define el proveedor principal (OpenStack) necesario
# para que Opentofu pueda interactuar con el cloud.
# Incluye tambien su configuracion.

terraform {
  required_providers {
    # Proveedor de OpenStack, necesario para interactuar con el cloud
    openstack = {
      source = "terraform-provider-openstack/openstack"
      version = "3.0.0"
      # version = "~> 3.0.0"
    }
  }
}

# Configuracion del proveedor OpenStack
provider "openstack" {
  # usuario
  user_name   = "demo"
  # proyecto
  tenant_name = "demo"
  # clave
  password    = "X"
  #auth_url    = "http://192.168.13.11/v3"
  # Direccion del endpoint de la API de OpenStack
  # autenticacion keystone
  auth_url    = "http://192.168.13.11/identity/"
  # region por defecto
  region      = "RegionOne"
}
