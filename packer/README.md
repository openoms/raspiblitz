#### Using `packer`

To build an Ubuntu 18.04 box for only the VirtualBox provider

```
$ cd packer_templates/ubuntu
$ packer build -only=virtualbox-iso ubuntu-18.04-amd64.json
```

To build Debian 11.4 32bit boxes for all possible providers (simultaneously)

```
$ cd packer_templates/debian
$ packer build debian-11.4-i386.json
```

To build CentOS 7.7 boxes for all providers except VMware and Parallels

```
$ cd packer_templates/centos
$ packer build -except=parallels-iso,vmware-iso centos-7.7-x86_64.json
```


cd packer/debian
packer build -only=virtualbox-iso debian-11.4-amd64.json


Running manually:
```
cd packer/debian

rm -rf ../../builds
rm ~/VirtualBox\ VMs/debian-11.4-amd64/debian-11.4-amd64.vbox

packer init
PACKER_LOG=1 packer build -only=virtualbox-iso debian-11.4-amd64.json
```