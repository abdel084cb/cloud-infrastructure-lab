# cloud-infrastructure-lab

Project focused on building and automating private cloud and Kubernetes environments from scratch.

The repository includes two labs:

* A multi-node OpenStack environment running on KVM/libvirt.
* A multi-node K3s cluster with distributed storage using Rook and Ceph.

The infrastructure is mainly defined with Terraform/OpenTofu, which is used to create and configure virtual machines, networks and other infrastructure resources.

## OpenStack

The OpenStack lab builds a small multi-node cloud with separate controller and compute nodes.

The virtual machines and network are created on top of KVM/libvirt using Terraform/OpenTofu.

The lab also includes basic OpenStack networking and compute resources, such as private networks, routers, security groups and virtual machines.

## Kubernetes

The Kubernetes lab builds a K3s cluster with one control-plane node and multiple workers.

Terraform/OpenTofu is used to create the virtual machines and automate the cluster setup, including node configuration and worker registration.

A distributed storage layer is added with Rook and Ceph. Each worker has a dedicated storage disk, allowing persistent volumes to be replicated across the cluster instead of depending on local storage.

A WordPress and MySQL deployment is used to test the setup with a real stateful workload.
