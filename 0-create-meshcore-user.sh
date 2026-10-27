#!/bin/bash
#
# create-meshcore-user.sh
#
# run as root immediately after creating the virtual server
# 
# meshcore user on the vps does not need dialout group access
# since there are no radios attached to the vps. it is added
# to the wheel group on both raspberry pi's and vps to give
# it sudo permission

groupadd -g 3001 meshcore
useradd  -u 3001 -g 3001 -d /home/meshcore -c 'meshcore relay' -s /bin/bash meshcore
usermod -aG dialout,wheel meshcore
passwd -d meshcore
sudo -u meshcore ssh-keygen -t rsa -b 2048 -N "" -f /home/meshcore/.ssh/id_rsa
