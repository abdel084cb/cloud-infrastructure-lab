# datasources.tf (openstackvmconipflotante)
# Este bloque consulta una red y expone sus datos.
data "openstack_networking_network_v2" "public" {
  name = "${var.pool}"
}
