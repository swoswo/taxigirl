#!/usr/bin/env ruby
#
# https://github.com/emetriq/taxigirl
# https://www.vagrantup.com/docs/vagrantfile/
#

require 'English'

# constant definitions
VAGRANTFILE_API_VERSION = 2
REQUIRED_PLUGINS = %w( vagrant-auto_network
                       vagrant-faster
                       vagrant-hostmanager
                       vagrant-persistent-storage
                       vagrant-reflect
                       vagrant-remove-old-box-versions
                       vagrant-triggers
                       vbinfo ).freeze

ENV['VAGRANT_DEFAULT_PROVIDER'] = 'virtualbox'

# manage plugins
plugins_to_install = REQUIRED_PLUGINS.select do |p|
  !Vagrant.has_plugin? p
end
unless plugins_to_install.empty?
  puts "Installing: #{plugins_to_install.join(' ')}"
  if system "vagrant plugin install #{plugins_to_install.join(' ')}"
    exec "vagrant #{ARGV.join(' ')}"
  else
    abort 'Installation of plugin failed, aborting.'
  end
end

# ip pool to use
AutoNetwork.default_pool = '172.16.2.0/24'

Vagrant.require_version '>= 1.8.3'
Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.define :taxigirl
  config.vm.provider :virtualbox do |vbox|
    # TODO: cli
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
    # vbox.customize ['setextradata', :id, 'VBoxInternal2/SharedFoldersEnableSymlinksCreate//vagrant', '1']
    vbox.customize ['setextradata', :id, 'VBoxInternal2/SharedFoldersEnableSymlinksCreate//sync', '1']

    # do not sync time with host as the guest should run ntp
    vbox.customize ['setextradata', :id, 'VVBoxInternal/Devices/VMMDev/0/Config/GetHostTimeDisabled', '1']

    if ENV['VIRTUALBOX_GUI']
      vbox.gui = true
      vbox.customize ['modifyvm', :id, '--clipboard', 'bidirectional']
    end
  end # provider

  config.vm.provision 'Wait for unattended-upgrades', type: 'shell', path: './provisioning/wait_unattended_upgrades.sh', args: %w( dpkg apt unattended-upgrade )
  # config.vm.provision 'Bootstrap minimal Python', type: 'shell', path: './provisioning/bootstrap_python.sh', args: ['2.7', 'python python-pkg-resources']

  config.vm.box = ENV['VM_BOX'] || 'geerlingguy/ubuntu1604' # https://github.com/geerlingguy/packer-ubuntu-1604
  config.vm.hostname = ENV['VM_HOSTNAME'] || 'vagrant.taxigirl'
  config.ssh.forward_agent = true
  config.vm.network :private_network, auto_network: true
  # config.vm.network :forwarded_port, guest: 3000, host: 8300, auto_correct: true

  # sync folders
  # config.vm.synced_folder '.', '/vagrant', id: 'sync', type: 'rsync'
  config.vm.synced_folder './sync', '/sync', id: 'sync', type: 'rsync'

  if Vagrant.has_plugin?('vagrant-persistent-storage')
    config.persistent_storage.enabled = ENV['PERSISTENT_STORAGE_ENABLED'] || false
    # config.persistent_storage.filesystem = 'xfs'
    config.persistent_storage.location = './persistent/vbox_persistent.vdi'
    config.persistent_storage.mount = false
    config.persistent_storage.format = false
    config.persistent_storage.diskdevice = ENV['PERSISTENT_STORAGE_DISKDEVICE'] || '/dev/sdb'
    config.persistent_storage.size = 2000
    config.persistent_storage.use_lvm = true
    config.persistent_storage.volgroupname = 'taxigirl'
  end

  if Vagrant.has_plugin?('vagrant-reflect')
    # show sync time next to messages
    # default: false
    config.reflect.show_sync_time = true
  end

  if Vagrant.has_plugin?('vagrant-hostmanager')
    config.hostmanager.enabled = true
    config.hostmanager.manage_host = true
    config.hostmanager.manage_guest = true
    config.hostmanager.ignore_private_ip = false
    config.hostmanager.include_offline = true
  end

  if Vagrant.has_plugin?('vagrant-triggers')
    # # additional check on halt
    # config.trigger.before [:halt] do
    #   confirm = nil
    #   until %w(Y y N n).include?(confirm)
    #     confirm = ask 'Are you sure you want to halt the VM? [y/N] '
    #   end
    #   exit unless confirm.casecmp('Y').zero?
    # end # trigger

    # translate command triggers to notifications
    {
      [:up, :resume] => %w(booting up),
      :suspend       => %w(suspending suspended),
      :destroy       => %w(deconstructing destroyed),
      :reload        => %w(reloading reloaded),
      :provision     => %w(provisioning provisioned),
      :halt          => %w(halting halted)
    }.each do |command, message|
      config.trigger.before command do
        notify(message[0])
      end
      config.trigger.after command do
        notify(message[1])
      end
    end

    config.trigger.after [:resume] do
      run_remote 'command -v ntp && sudo service ntp restart'
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

  def str_to_a(str)
    str.gsub!(/(\,)(\S) /, "\\1 \\2")
    YAML::load(str) || nil
  end

  # ansible provisioning
  # https://www.vagrantup.com/docs/provisioning/ansible_common.html
  config.vm.provision 'ansible' do |ansi|
    ansi.extra_vars = ENV['ANSIBLE_EXTRA_VARS'] || '@./config/test.yml'
    ansi.inventory_path = ENV['ANSIBLE_INVENTORY_PATH'] || './inventory/vagrant.py'
    ansi.limit = ENV['ANSIBLE_LIMIT'] unless ENV['ANSIBLE_LIMIT'].nil?
    ansi.playbook = ENV['ANSIBLE_PLAYBOOK'] || './playbooks/main.yml'
    ansi.start_at_task = ENV['ANSIBLE_START_AT_TASK'] unless ENV['ANSIBLE_START_AT_TASK'].nil?
    ansi.verbose = ENV['ANSIBLE_VERBOSE'] || true

    # duplicate frozen string
    raw_args = ENV['ANSIBLE_RAW_ARGUMENTS'].dup
    ansi.raw_arguments = str_to_a(raw_args) || ['-C', '-D']
  end # provision
end
