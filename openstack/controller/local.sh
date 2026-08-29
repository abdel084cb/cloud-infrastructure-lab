#!/usr/bin/env bash
# Este script se ejecuta automaticamente al final de la instalacion de Devstack (tras stack.sh).
# Se reservan IPs manualmente del rango de red FIXED_RANGE, en concreto desde 10.4.128.2 hasta 10.4.128.10.
# Esto evita que OpenStack (Neutron) las asigne automaticamente a nuevas instancias.

# La subred queda asi:
# 10.4.128.1 - Gateway de Neutron
# 10.4.128.2 a 10 - Reservadas
# resto del rango - Asignacion dinamica a instancias

for i in `seq 2 10`; do /opt/stack/nova/bin/nova-manage fixed reserve 10.4.128.$i; done