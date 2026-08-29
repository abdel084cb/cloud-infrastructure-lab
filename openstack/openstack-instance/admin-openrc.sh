#!/usr/bin/env bash

# Este script permite configurar las variables de entorno necesarias para
# autenticarse con OpenStack desde la terminal usando la cuenta admin.

# API de autenticacion de OpenStack
export OS_AUTH_URL=http://192.168.13.11/identity

export OS_PROJECT_ID=X
export OS_PROJECT_NAME="admin"

# Dominio del usuario que realiza la autenticacion (por defecto)
export OS_USER_DOMAIN_NAME="Default"
if [ -z "$OS_USER_DOMAIN_NAME" ]; then unset OS_USER_DOMAIN_NAME; fi


# Dominio del proyecto (tambien por defecto)
export OS_PROJECT_DOMAIN_ID="default"
if [ -z "$OS_PROJECT_DOMAIN_ID" ]; then unset OS_PROJECT_DOMAIN_ID; fi

# Estas dos variables eran usadas en la API v2.0 y se eliminan para evitar conflictos
unset OS_TENANT_ID
unset OS_TENANT_NAME

# Usuario que se va a autenticar (admin)
export OS_USERNAME="admin"

# Solicita por consola la contrasenya del usuario
echo "Please enter your OpenStack Password for project $OS_PROJECT_NAME as user $OS_USERNAME: "
read -sr OS_PASSWORD_INPUT
export OS_PASSWORD=$OS_PASSWORD_INPUT

export OS_REGION_NAME="RegionOne"
if [ -z "$OS_REGION_NAME" ]; then unset OS_REGION_NAME; fi

# Tipo de interfaz de red usada para acceder a los servicios
export OS_INTERFACE=public

# Version de la API del servicio de identidad (Keystone v3)
export OS_IDENTITY_API_VERSION=3
