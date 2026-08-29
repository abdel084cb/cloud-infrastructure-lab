# outputs.tf (openstackvmconipflotante)
# Muestra por consola la IP flotante asignada a la instancia.
output "address" {
  value = "${openstack_networking_floatingip_v2.pruebafloatingip.address}"
}
