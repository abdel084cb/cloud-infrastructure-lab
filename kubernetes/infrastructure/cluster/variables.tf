# variables.tf
# Define todas las variables para el despliegue del cluster K3s

# -----------------------------------------------------------
# CONFIGURACION DE RED
# -----------------------------------------------------------

# Identificador W
variable "w_identifier" {
  description = "Identificador W para la red (192.168.W.0/24)"
  type        = string
  default     = "13"
}

# Nombre de dominio interno para la red del cluster
# Este dominio se usa para la comunicacion DNS entre los servicios
variable "base_domain" {
  description = "Nombre de dominio base para la red del cluster"
  type        = string
  default     = "k8s.local"
}

# -----------------------------------------------------------
# CONFIGURACION DE ALMACENAMIENTO
# -----------------------------------------------------------

# Nombre de la imagen base Ubuntu que se usara como plantilla
variable "base_image" {
  description = "Nombre de la imagen base de Ubuntu"
  type        = string
  default     = "ubuntu-bionic-server-cloudimg-amd64"
}

# Directorio donde se almacenaran todos los volumenes y discos
variable "volume_path" {
  description = "Ruta para almacenar volumenes en libvirt"
  type        = string
  default     = "/adsis2/k3"  # Ruta en el sistema host
}

# Tamaño del disco adicional para el sistema de almacenamiento Ceph
variable "ceph_disk_gb" {
  description = "Tamaño del disco adicional para Ceph en GB"
  type        = number
  default     = 30  # 30GB por disco adicional en cada worker
}

# -----------------------------------------------------------
# CONFIGURACION DE NODOS
# -----------------------------------------------------------

# Configuracion del nodo master
variable "master_config" {
  description = "Configuracion del nodo master"
  type = object({
    name    = string  # Nombre del nodo
    memory  = string  # RAM en MB
    vcpu    = number  # Nucleos
    ip      = string  # Ultimo octeto de la IP
    disk_gb = number  # Tamaño del disco principal en GB
  })
  default = {
    name    = "master"
    memory  = "1536"  # 1.5GB de RAM
    vcpu    = 1       # 1 CPU virtual
    ip      = "6"     # 192.168.W.6
    disk_gb = 20      # Disco de 20GB
  }
}

# Configuracion detallada de los nodos worker
# Se define como lista para crear multiples nodos con diferentes especificaciones
variable "workers_config" {
  description = "Configuracion de los nodos worker"
  type = list(object({
    name    = string  # Nombre del nodo
    memory  = string  # RAM en MB
    vcpu    = number  # Nucleos virtuales
    ip      = string  # Ultimo octeto de la IP
    disk_gb = number  # Tamaño del disco principal en GB
  }))
  default = [
    {
      name    = "worker1"
      memory  = "2560"  # 2.5GB de RAM
      vcpu    = 1
      ip      = "7"     # 192.168.W.7
      disk_gb = 20
    },
    {
      name    = "worker2"
      memory  = "2560"
      vcpu    = 1
      ip      = "8"     # 192.168.W.8
      disk_gb = 20
    },
    {
      name    = "worker3"
      memory  = "2560"
      vcpu    = 1
      ip      = "9"     # 192.168.W.9
      disk_gb = 20
    }
  ]
}

# -----------------------------------------------------------
# CONFIGURACION DE ACCESO Y SEGURIDAD
# -----------------------------------------------------------

# Ruta al archivo de clave SSH privada para acceder a las VMs
variable "ssh_key_file" {
  description = "Ruta del archivo de clave privada SSH"
  type        = string
  default     = "~/.ssh/id_rsa_vm"  # La clave publica debe estar en cloud-init
}

# Nombre de usuario SSH para acceder a las VMs
variable "ssh_user_name" {
  description = "Nombre del usuario SSH en las VMs"
  type        = string
  default     = "ubuntu" 
}

# Token de seguridad para la comunicacion entre nodos del cluster K3s
variable "k3s_token" {
  description = "Token para la comunicacion entre nodos K3s"
  type        = string
  default     = "X"
}

# -----------------------------------------------------------
# CONFIGURACION DE DESPLIEGUE
# -----------------------------------------------------------

# Ruta al directorio con scripts de instalacion y binarios K3s
variable "scripts_path" {
  description = "Ruta a los scripts y binarios de K3s"
  type        = string
  default     = "scripts"  # Relativo al directorio donde se ejecuta tofu
}