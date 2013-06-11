#!/bin/bash
echo "Bootstrapping the Virtual Machine"
echo "Installing puppet-server and puppet"
if [ -f /etc/fedora-release ] ; then
  yum -y install puppet-server puppet > /dev/null 2>&1
fi

