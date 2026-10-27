# Project to relay specific meshcore packets from one region to another over the internet.

Notes
- .bash_profile should have MC_FQDN exported prior to running any setup
  `export MC_FQDN=fqdn.of.the.meshcore.vm`

Create meshcore VM, currently needs to be Rocky Linux 10+

As root, run `0-create-meshcore-user.sh`

Extract github zip in meshcore user directory, ensure meshcore owns all files
`cd /home/meshcore`
`unzip meshcore-bridge.zip`
`sudo chown -R meshcore: /home/meshcore`

For your VM, setup /etc/hosts, ensure hostname on loopback
`127.0.0.1 your.vm.fqdn.here  your`

For each Raspberry Pi, shortname on loopback
`127.0.1.1	meshcore-tx1`
