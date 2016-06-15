# Emetriq's Taxi Girl

## Ambivalent Provisioning and Deployment Tool based on Ansible

[![Build Status](https://travis-ci.org/emetriq/taxigirl.svg?branch=master)](https://travis-ci.org/emetriq/taxigirl)

### Introduction

Let's see what the *Internet* says about her:

> [Taxi Girl](https://en.wikipedia.org/wiki/Taxi_Girl) were a French new wave band, adopting the New Romantic aesthetics of the time, such as clashing red and black clothing ... :fr:

> ... locally abundant [freelance](http://www.urbandictionary.com/define.php?term=Taxi+Girl) working girls found in parks, bars, clubs, and public places ... :girl:

> ... an attractive girl [employed by the management](http://www.thefreedictionary.com/bar+girl) of a bar to befriend male customers and encourage them to buy drinks ... :purple_heart:

That's quite a lot! Let's get her over and see for ourselves:

```bash
$ git clone https://github.com/emetriq/taxigirl
$ cd taxigirl
$ direnv allow
```

Wait, you don't have `direnv` installed? Let's take care of your toolbox! :wrench:

#### Prerequisites

##### Makefile

> On OSX the repository containts a `Makefile` which automates most of the tasks required to bootstrap the toolchain.

```bash
$ make update
$ make bootstrap
$ make install
...
```

> While the `Makefile` is not very complex it bundles a lot of functionality -
> please read the file before using it.

##### Targets

> Instead of remembering, copy-pasting or yelling shell-code to coworkers these targets provide a error-resilient way of working with *Taxigirl*. Of course, all commands can be called in whatever way you prefer.

To list all targets available (including aliases which bundle a group of targets) a _special_ task is available:

```bash
$ make help
help: available targets
ansible-galaxy ansible-lint ansible-run bootstrap brew-cask-upgrade brew-clean brew-install brew-uninstall brew-update check clean clobber distclean gem-bundle gem-clean gem-remove gem-update git-check git-secrets-scan git-update install lint list pip-install pip-uninstall pip-update precommit-clean precommit-run precommit-update provision python-install python-uninstall reset run test update vagrant-destroy vagrant-halt vagrant-provision vagrant-up vagrant-update versions virtualenv-create virtualenv-provide virtualenv-remove
```

##### Meta Targets

Each target can be called seperately while for general use there are some _meta_ targets available to promoto _batch_ style execution.

Updates all components of the toolchain:

    * update

Provides toolchain required to install *Taxigirl*:

    * bootstrap

> Naturally, executing this target is required for most targets following.

Installs *Taxigirl*:

    * install

> Can be called repeatedly to update requirements and refresh the virtualenv.

Including the `install` target this one brings up a virtual machine using the configuration preset:

    * provision

Provision box, lint- and run *Ansible*:

    * run

Run a complete cycle inclduing the previous provisioning and destruction of a virtual machine running *Taxigirl*:

    * test

Cleaning up most, removing the virtualenv - but leaving caches and downloaded files intact:

    * distclean

> This target shouldn't remove your work. Please ensure proper commits before running this task in any case!

The above targets wrap around the actual targets used to compose the setup as a whole. Most of these can be called directly to ease your development work.

##### Special Targets

Some targets are not called by any others due to their dedicated purposes.

Basically, same as `vagrant provision` but calls `ansible` directly:

    * ansible-run

Uninstall homebrew (including *Cask*):

    * brew-uninstall

Uninstalls the python version preset:

    * python-uninstall

This tagret really tidies up, including all caches.

    * clobber

> Ensure you will not loose anything importing before executing this target!

##### Autobitch

`...`

##### pyenv

`...`

##### ry

`...`

#### AWS Credentials

> Ansible makes uses of [boto: A Python interface to Amazon Web Services](http://boto.cloudhackers.com/en/latest/boto_config_tut.html) - similar to what `fog` does on `Ruby`.

A defacto-standard on how to share AWS credentials between the SDKs and many open-source frameworks has been established. For our case, we are going to jump on that train and use [`~/.aws/credentials`](http://docs.aws.amazon.com/AWSSdkDocsJava/latest/DeveloperGuide/credentials.html) to set the credentials:

```ini
[default]
aws_access_key_id=DONOTSHAREYOURKEY
aws_secret_access_key=ANDTAKECAREOFTHESECRET
```

Ensure minimal file permissions:

`$ chmod 0400 ~/.aws/credentials`

> _Do not_ put this file in any place shared with more than your user or commit it to any version control or continuous integration system! If in doubt please revoke your credentials immediately.

Boto comes with a bunch of [commandline tools](http://boto.cloudhackers.com/en/latest/commandline.html) which can be used to verify proper authentication and access rights, i.e.:

```bash
$ list_instances -r eu-west-1 -H ID,Zone,T:Name,T:xpl:service,State | less
ID             Zone           T:Name                        T:xpl:service                 State
---------------------------------------------------------------------------------------------------------
i-6c9ffed4     eu-west-1a     Cassandra34                   Cassandra                     running
i-2e468b82     eu-west-1b     Cassandra17                   Cassandra                     running
i-5808a7d4     eu-west-1a     elasticsearch_new_az_0_0      Kibana                        running
...
```
Looks like a tie! :bowtie:

#### Directory Based Environments (Direnv)

[comment]: # (Copy part from graphite on direnv)

`...`

> Any errors at this point will eventually lead to failure. Please ensure proper function of `direnv`!

#### Setup Ansible

* inventory
* hosts
  * `ansible_python_interpreter`

#### Play with the books

Ok, let's get on with the business:

```bash
$ ansible-playbook -C -v playbooks/provision.yml --extra-vars 'config=@config/minimal.json'
```

#### Vagrant

Vagrant is used to provision virtual machines on the fly. These can be used for development, testing or even production purposes. While the `Vagrantfile` as supplied suppports mainly development the changes required to i.e. set network configuration statically is very well documented.

> Currently, `libvirt` is now working as reliable as `VirtualBox` does on `OSX`. Though, i do recommend getting there some time not only because *Oracle* is a debatable company but for portability.

### Permissions and `sudo`

For please and comfort the `Vagrantfile` sports some features:

* suppport high-performance `NFS` file system _synchronization_ for the host and guest system, bidirectonally
* automatically adjust `/etc/hosts` on the hosts in accordance to the network configuration of the `Vagrant` instances for easy reachabilty

Both require superuser priviliges to be set-up during the provisioning - `sudo` is invoked and you are required to enter your system password. As this can be annoying and prevent automated testing it is recommended to configure `sudo` as follows:

```bash
$ whoami
gretel
$ sudo visudo -f /private/etc/sudoers.d/vagrant
Password:
# https://www.vagrantup.com/docs/synced-folders/nfs.html
Cmnd_Alias VAGRANT_NFSD = /sbin/nfsd restart
Cmnd_Alias VAGRANT_EXPORTS_ADD = /usr/bin/tee -a /etc/exports
Cmnd_Alias VAGRANT_EXPORTS_REMOVE = /usr/bin/sed -E -e /*/ d -ibak /etc/exports

# https://github.com/cogitatio/vagrant-hostsupdater
# TODO: still in use?
Cmnd_Alias VAGRANT_HOSTS_ADD = /bin/sh -c echo "*" >> /etc/hosts
Cmnd_Alias VAGRANT_HOSTS_REMOVE = /usr/bin/sed -i -e /*/ d /etc/hosts

# https://github.com/vagrant-landrush/landrush
Cmnd_Alias VAGRANT_LANDRUSH_HOST_MKDIR = /bin/mkdir /etc/resolver/*
Cmnd_Alias VAGRANT_LANDRUSH_HOST_CP = /bin/cp /*/vagrant_landrush_host_config /etc/resolver/*
Cmnd_Alias VAGRANT_LANDRUSH_HOST_CHMOD = /bin/chmod 644 /etc/resolver/*

%admin ALL=(root) NOPASSWD: VAGRANT_EXPORTS_ADD, VAGRANT_NFSD, VAGRANT_EXPORTS_REMOVE, VAGRANT_HOSTS_ADD, VAGRANT_HOSTS_REMOVE, VAGRANT_LANDRUSH_HOST_MKDIR, VAGRANT_LANDRUSH_HOST_CP, VAGRANT_LANDRUSH_HOST_CHMOD
<save and quit editor>
"vagrant.tmp" 11L, 492C written
```

> DO NOT edit the file direclty, always use `visudo`. Otherwise you might find yourself locked out of any superuser privilges. (Hint: Use the Finder to eset permissions of the `sudoers.d/vagrant` file to read/write for everyone.)

### Vagrant Plugins

> A working installation of some recent-enough `ruby` is required by `vagrant` to manage it's own plugins. Please ensure a proper setup!

On the first call to `vagrant` the required plugins will be installed automagically:

```bash
Installing plugins: vagrant-cachier vagrant-faster vagrant-hosts vagrant-hostsupdater vagrant-vbguest vagrant-reload vagrant-sshfs
...
```

### The Vagrantfile

We are going to have a look at the `Vagrantfile` focussing on the Ansible related part:

```ruby
  config.vm.provision 'ansible' do |ansible|
    ansible.extra_vars = ENV['TAXIGIRL_EXTRA_ARGS']
    ansible.inventory_path = ENV['TAXIGIRL_INVENTORY_PATH']
    ansible.limit = ENV['TAXIGIRL_LIMIT']
    ansible.playbook = ENV['TAXIGIRL_PLAYBOOK']
    ansible.verbose = ENV['TAXIGIRL_VERBOSE']
  end # provision
```

`...`

#### Provision

```bash
$ make vagrant-up vagrant-provision
```

```bash
$ env ANSIBLE_EXTRA_ARGS=@config/test.yml make vagrant-up vagrant-provision
```

### Update Vagrant Box

Let's check for updates:

```bash
$ make vagrant-update
...
==> default: Successfully added box 'ubuntu/xenial64' (v20160509.0.0) for 'virtualbox'!
```

`...`

#### Concept

**Taxigirl** tries to do each job in exactly the same way, following the client's intentions as close as possible.

Typical Flow:

* Intention

      The customer defines what **Taxigirl** will actually do. Each step can have a distinctive set of parameters she will stick to. A typical flow consists of the following phases:

* Provision

    **Taxigirl** takes good care of setting up the right environment. She knows what different types of customers require and how to set them up. While local ones usually require less steps remote ones can be quite intensive.

* Deployment

    This step is the essence of her work. She brings up something new to a system that might not have done much before. While there is no guarantee that the customer will actually appreciate the service she tries for the best.

* Service

    When everything went fine the customer should be happy about the service. **Taxigirl** is ready to call it a day while the customer should continue to head on happily until further notice.

* Destruction

    Nothing stays forever - so is the fun. At some point the customer will vanish and won't require **Taxigirl** anymore. Nonetheless **Taxigirl** may assist to let her customers fade away depending on the environment she set up during provisioning.

#### Configuration

More technically speaking, the _intention_ is a configuration file either in `JSON` or `YAML` format located in the `config/` directory of the project:

* each file represents a different intention
* each intention can be applied to a group
* each group consists of at least one host
* the extent of a group can be limited or have a single member
* each group is bound to a certain environment
* each environment is related to the various Ansible modules

In the end, it's quite simple. Let's have a look at a configuration file to reflect our intention to have a [`rundeck`]() service realized:

`...`

#### Commands

**Taxigirl** will ensure proper communication protocols and executes a set of predefined commands. As she is skilled with linguistics the set of commands is flexible and can be adjusted to almost any demands. The limit is what is [implemented in Ansible](http://docs.ansible.com/ansible/modules_core.html) - or can be [added as modules](http://docs.ansible.com/ansible/developing_modules.html).

The projects comes with a mix of `playbooks` and `roles` while the playbooks will include the `roles` if applicable.

The configuration is shared. It's up to the customer to have his the extent of his intentions clearly stated. For instance

* virtual machines (in the cloud) might require *provisioning* before *deployment* can take place
* dedicated bare metal machines are usually _pre-provisioned_ and won't require as much care but milage varies
* usually dedicated machines will not require _destruction_ :money:
* while virtual ones can be prone to destruction (i.e. to replace them)
* if in doubt an _inventory_ can be helpful as well as `list` command to gather facts about all machines

Enough of theory. Let's get touchy:

`...`

#### Development

##### git-secrets

##### pre-commit
