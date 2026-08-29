# variables.tf (openstackvmconipflotante)
# Este fichero define variables reutilizables que permiten configurar
# la imagen, el sabor, el usuario SSH, la clave y la red

variable "image" {
  default = "ubuntu18.04"
}

# Se ha modificado con el nuevo sabor creado
variable "flavor" {
  default = "2Gcon256M"
}

# Se ha modificado con la clave que utilizo para las maquinas
variable "ssh_key_file" {
  default = "~/.ssh/id_rsa_vm"
}

variable "ssh_user_name" {
  default = "ubuntu"
}

# Nombre del pool de red externa (red publica) que se usara para
# asignar una IP flotante a la instancia
variable "pool" {
  default = "public"
}
