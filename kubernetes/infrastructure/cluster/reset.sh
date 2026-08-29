#!/bin/bash

# Eliminar las entradas de known_hosts para evitar errores de SSH
echo "Eliminando entradas de known_hosts..."
ssh-keygen -f "$HOME/.ssh/known_hosts" -R "192.168.13.6" # master
ssh-keygen -f "$HOME/.ssh/known_hosts" -R "192.168.13.7" # worker1
ssh-keygen -f "$HOME/.ssh/known_hosts" -R "192.168.13.8" # worker2
ssh-keygen -f "$HOME/.ssh/known_hosts" -R "192.168.13.9" # worker3

# Eliminar las VMs del cluster
sudo virsh destroy master 2>/dev/null || true
sudo virsh undefine master --remove-all-storage 2>/dev/null || true
sudo virsh destroy worker1 2>/dev/null || true
sudo virsh undefine worker1 --remove-all-storage 2>/dev/null || true
sudo virsh destroy worker2 2>/dev/null || true
sudo virsh undefine worker2 --remove-all-storage 2>/dev/null || true
sudo virsh destroy worker3 2>/dev/null || true
sudo virsh undefine worker3 --remove-all-storage 2>/dev/null || true

# Detener y eliminar el pool k8s_pool
sudo virsh pool-destroy k8s_pool 2>/dev/null || true
sudo virsh pool-undefine k8s_pool 2>/dev/null || true

# Eliminar archivos de volumen creados
sudo rm -f /adsis2/k3/worker-disk.qcow2 2>/dev/null || true
sudo rm -f /adsis2/k3/*-volume 2>/dev/null || true
sudo rm -f /adsis2/k3/*-ceph 2>/dev/null || true
sudo rm -f /adsis2/k3/*-cloudinit.iso 2>/dev/null || true

# Eliminar archivos de estado y bloqueo
rm -f terraform.tfstate*
rm -f .terraform.lock.hcl
rm -f .tofu.lock.hcl
rm -rf .terraform/
rm -rf .tofu/

echo "Limpieza completada."