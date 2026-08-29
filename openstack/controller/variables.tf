# variables.tf
# Este fichero define variables utilizadas en los manifiestos tofu
# para el despliegue de la VM controlador.

variable "host_ip" {
  type = string
  default = "192.168.13.11"
}

variable "private_key" {
  type = string
  default = "/home/abdel/.ssh/id_rsa_vm"
}
