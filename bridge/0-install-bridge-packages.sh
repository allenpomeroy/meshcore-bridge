#!/bin/bash
#
# install-bridge-packages.sh
#
# install packages needed for both meshcore-bridge functions
# and remote ssh management tunnels

sudo dnf install -y dnf-plugins-core # provides config-manager
sudo dnf config-manager --set-enabled crb # EPEL 10 packages depend on CRB
sudo dnf install -y epel-release
sudo dnf install -y mosquitto 
sudo dnf install -y python3-cryptography
