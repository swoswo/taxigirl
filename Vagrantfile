#!/usr/bin/env ruby
#
# https://github.com/emetriq/taxigirl
# https://www.vagrantup.com/docs/vagrantfile/
#

require 'English'

# constant definitions
VAGRANTFILE_API_VERSION = 2
REQUIRED_PLUGINS = %w( vagrant-auto_network
                       vagrant-cachier
                       vagrant-faster
                       landrush
                       vagrant-persistent-storage
                       vagrant-remove-old-box-versions
                       vagrant-reflect
                       vagrant-triggers
                       vbinfo ).freeze

ENV['VAGRANT_DEFAULT_PROVIDER'] = 'virtualbox'
VIRTUALBOX_GUI = true

# manage plugins
plugins_to_install = REQUIRED_PLUGINS.select {
  |p| !Vagrant.has_plugin? p
}
unless plugins_to_install.empty?
  puts "Installing: #{plugins_to_install.join(' ')}"
  if system "vagrant plugin install #{plugins_to_install.join(' ')}"
    exec "vagrant #{ARGV.join(' ')}"
  else
    abort 'Plugin installation failed, aborting.'
  end
end

# ip pool to use
AutoNetwork.default_pool = '172.16.1.0/24'

Vagrant.require_version '>= 1.8.1'
Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.define :taxigirl
  config.vm.provider :virtualbox do |vbox|
    vbox.name = 'taxigirl'

    # vbox.linked_clone = true
    vbox.customize ['modifyvm', :id,
                    '--ioapic', 'on',
                    '--nictype1', 'virtio',
                    '--nictype2', 'virtio',
                    '--rtcuseutc', 'on',
                    '--natdnshostresolver1', 'on',
                    '--natdnspassdomain1', 'off',
                    '--natdnsproxy1', 'on']

    # allow symlinks in synced foldersnam
    vbox.customize ['setextradata', :id, 'VBoxInternal2/SharedFoldersEnableSymlinksCreate//vagrant', '1']
    # do not sync time with host as the guest should run ntp
    vbox.customize ['setextradata', :id, 'VVBoxInternal/Devices/VMMDev/0/Config/GetHostTimeDisabled', '1']

    if VIRTUALBOX_GUI
      vbox.gui = true
      vbox.customize ['modifyvm', :id, '--clipboard', 'bidirectional']
    end
  end # provider

  config.vm.box = 'geerlingguy/ubuntu1604' # https://github.com/geerlingguy/packer-ubuntu-1604
  # config.vm.box = 'ubuntu/xenial64'

  config.vm.hostname = 'vagrant.taxigirl'
  config.ssh.forward_agent = true

  config.vm.network :private_network, auto_network: true
  # config.vm.network :forwarded_port, guest: 3000, host: 8300, auto_correct: true

  # # pre-provisiong scripts
  # config.vm.provision 'Fix Xenial issues', type: 'shell', path: 'provisioning/fix_xenial.sh'
  # SSH_PUBLIC_KEY = "#{Dir.home}/.ssh/id_rsa_dev_dev_keypair.pem".freeze
  # ssh_pub_key = File.readlines(SSH_PUBLIC_KEY).first.strip
  # config.vm.provision 'Authorize SSH Key', type: 'shell', path: 'provisioning/authorize_key.sh', args: [ssh_pub_key], privileged: false
  # config.vm.provision 'Wait for unattended-upgrades', type: 'shell', path: 'provisioning/wait_unattended_upgrades.sh'
  # config.vm.provision 'Bootstrap Python', type: 'shell', path: 'provisioning/bootstrap_python.sh', args: ['2.7']

  # sync folders
  config.vm.synced_folder '.', '/vagrant', id: 'sync', type: 'rsync'
  config.vm.synced_folder './sync', '/sync', id: 'sync', type: 'rsync'

  if Vagrant.has_plugin?('landrush')
    config.landrush.enabled = true
    config.landrush.tld = 'taxigirl'
    config.landrush.upstream '10.0.23.1' # FIXME
    # config.landrush.host 'myhost.example.com', '1.2.3.4'
  end

  if Vagrant.has_plugin?('vagrant-cachier')
    # config.cache.scope = :box
    config.cache.scope = :machine
    config.cache.synced_folder_opts = {
      type: 'nfs',
      mount_options: ['rw', 'vers=3', 'udp', 'nolock', 'actimeo=2', 'noatime', 'fsc']
    }
  end # plugin

  if Vagrant.has_plugin?('vagrant-persistent-storage')
    config.persistent_storage.enabled = true
    config.persistent_storage.filesystem = 'ext4'
    config.persistent_storage.location = './persistent/vbox_persistent.vdi'
    config.persistent_storage.mountname = 'storage'
    config.persistent_storage.mountpoint = '/opt/storage'
    config.persistent_storage.size = 2000
    config.persistent_storage.volgroupname = 'taxigirl'
    config.persistent_storage.mountoptions = ['noatime']
  end

  if Vagrant.has_plugin?('vagrant-reflect')
    # show sync time next to messages
    # default: false
    config.reflect.show_sync_time = true
  end

  if Vagrant.has_plugin?('vagrant-triggers')
    # additional check on halt
    config.trigger.before [:halt] do
      confirm = nil
      until %w(Y y N n).include?(confirm)
        confirm = ask 'Are you sure you want to halt the VM? [y/N] '
      end
      exit unless confirm.casecmp('Y').zero?
    end # trigger

    # translate command triggers to notifications
    {
      [:up, :resume] => ['booting', 'up'],
      :suspend       => ['suspending', 'suspended'],
      :destroy       => ['deconstructing', 'destroyed'],
      :reload        => ['reloading', 'reloaded'],
      :provision     => ['provisioning', 'provisioned'],
      :halt          => ['halting', 'halted']
    }.each do |command, message|
      config.trigger.before command do
        notify(message[0])
      end
      config.trigger.after command do
        notify(message[1])
      end
    end

    config.trigger.after [:resume] do
      run_remote 'sudo service ntp restart'
    end # trigger
  end # plugin

  # virtualbox guest additions
  if Vagrant.has_plugin?('vagrant-vbguest')
    config.vbguest.no_remote = false
    config.vbguest.auto_update = true
  end # plugin

  def notify(msg)
    info "VM is #{msg}!"
    `terminal-notifier -message 'VM is #{msg}' -title 'Taxigirl - Vagrant' -subtitle '🚖👧💾🌍'`
  end

  # ansible provisioning
  config.vm.provision 'ansible' do |ansible|
    ansible.verbose = 'v'
    ansible.playbook = './playbooks/taxigirl.yml'
    ansible.inventory_path = './inventory/vagrant.ini'
    ansible.limit = 'local'
    ansible.extra_vars = ENV['TAXIGIRL_CONFIG']
  end # provision
end
