# variables.tf
# Definicion de variables para el despliegue de la VM

variable "host_ip" {
  type = string
  default = "192.168.13.12"
}

variable "private_key" {
  type = string
  default = "/home/abdel/.ssh/id_rsa_vm"
}
