# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  # Every Vagrant virtual environment requires a box to build off of.
  config.vm.box = "fedora-18-x86-2"

  # Bootstraps the VM with the bootstrap script.
  config.vm.provision :shell, :path => "bootstrap.sh"

  # The url from where the 'config.vm.box' box will be fetched if it
  # doesn't already exist on the user's system.
  # config.vm.box_url = "http://domain.com/path/to/above.box"

  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine. In the example below,
  # accessing "localhost:8080" will access port 80 on the guest machine.
  config.vm.network :forwarded_port, :guest => 3000, :host => 4000, :auto_correct => true
  config.vm.network :forwarded_port, :guest => 80, :host => 8888, :auto_correct => true

  # Create a private network, which allows host-only access to the machine
  # using a specific IP.
  config.vm.network :private_network, :ip => "10.10.10.10"

  # Puppet provision manifests
  config.vm.provision :puppet do |puppet|
    puppet.manifests_path = "manifests"
    puppet.manifest_file = "init.pp"
  end

end
