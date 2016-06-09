#!/usr/bin/env make
#
# https://github.com/emetriq/taxigirl
# 2016 tom hensel <github@jitter.eu>
#
# tested on osx. usage:
#   $ make install
#   $ PYTHON_VERSION=3.5.1 PIP_BIN_NAME=pip3 make install
#

###
### # defaults
###

BIN_PATH ?= ./bin
PIP_BIN_NAME ?= pip
BREW_BUNDLE_FILE ?= Brewfile
BREW_INSTALL_FILE ?= ./sbin/brew-install
BREW_UNINSTALL_FILE ?= ./sbin/brew-uninstall
BUNDLER_CACHE_PATH ?= ./vendor/cache
GALAXY_REQ_FILE ?= requirements.yml
GEM_BUNDLE_FILE ?= Gemfile
PIP_FREEZE_FILE ?= requirements_freeze.txt
PIP_PRE_FREEZE_FILE ?= requirements_pre_freeze.txt
PIP_REQ_FILE ?= requirements.txt
PLAYBOOK_FILE ?= playbooks/taxigirl.yml
PRE_COMMIT_CONFIG ?= .pre-commit-config.yaml
PYTHON_VERSION ?= 2.7.11
VENV_SCRIPT ?= ./bin/virtualenv.py
VENV_TGZ ?= ./files/virtualenv.tgz
VENV_URI ?= https://pypi.python.org/packages/5c/79/5dae7494b9f5ed061cff9a8ab8d6e1f02db352f3facf907d9eb614fb80e9/virtualenv-15.0.2.tar.gz#md5=0ed59863994daf1292827ffdbba80a63

###
### # intialization
###

# dont stick with traditions, no files will be made
.SUFFIXES:
# due to inter-target dependencies (like gems) we can not parallelize
.NOTPARALLEL:

# if no target is specified on commandline
.DEFAULT_GOAL := list

# some tasks provide multicore options
core_count := 1
# get system name (platform)
sys_name := $(shell uname -s)
ifeq ($(sys_name),)
$(error unable to retrive system name)
else ifeq ($(sys_name),Darwin)
# overwrite with actual amount of cores
core_count := $(shell sysctl -n hw.physicalcpu)
else
$(warning system $(sys_name) is not supported)
endif

# get git rev id or fail
git_rev := $(shell git rev-parse --short HEAD)
ifeq ($(git_rev),)
$(warning unable to retrive git revision)
endif
# compose tag to set if this recipe succeeds
git_tag := $(git_rev)_$(shell date +%s)

# vagrant is installed by some task so don't expect it's presence
_vagrant := $(shell which vagrant)
ifneq ($(_vagrant),)
vagrant_tasks := vagrant-update
endif

# get pyenv prefix or fail
pyenv_prefix := $(shell pyenv prefix $(PYTHON_VERSION))
ifeq ($(pyenv_prefix),)
$(error unable to retrive pyenv prefix)
endif

brew_tasks :=
ifneq ($(wildcard $(BREW_BUNDLE_FILE)),)
brew_tasks := brew-install brew-update brew-upgrade brew-cask-upgrade brew-clean
endif

gem_tasks :=
ifneq ($(wildcard $(GEM_BUNDLE_FILE)),)
gem_tasks := gem-update gem-bundle gem-clean
endif

###
### # tasks
###

install_tasks +=	clean \
			update \
			python-install \
			virtualenv-provide \
			virtualenv-create \
			pip-install \
			precommit-update \
			precommit-run \
			versions \
			_revision \
			_notify

reset_tasks += 		virtualenv-create \
			pip-install \
			clean \
			_notify

update_tasks +=		git-update \
			$(brew_tasks) \
			$(gem_tasks) \
			$(vagrant_tasks)

check_tasks += 		git-secrets-scan \
			precommit-run

distclean_tasks +=	pip-uninstall \
			virtualenv-remove \
			gem-remove gem-clean \
			clean

provision_tasks +=	install \
			ansible-galaxy \
			ansible-lint \
			vagrant-provision

test_tasks +=		provision \
			ansible-test \
			vagrant-destroy \
			distclean

.PHONY: install reset update check lint distclean list provision
install:		$(install_tasks)
reset:			$(reset_tasks)
update:			$(update_tasks)
check:			$(check_tasks)
distclean:		$(distclean_tasks)
provision:		$(provision_tasks)
test:			$(test_tasks)

list help:
	$(info $@: available targets)
	@# http://stackoverflow.com/a/26339924/1972627
	# please note: some targets have aliases
	@$(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>/dev/null | awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | egrep -v -e '^[^[:alnum:]]' -e '^$@$$' | xargs

###
### # homebrew
###

.PHONY: brew-install
brew-install:
	$(info $@: installing homebrew)
	# returns non-zero when already installed
	-$(BREW_INSTALL_FILE) 2>/dev/null
	brew tap Homebrew/bundle >/dev/null

brew-update: $(BREW_BUNDLE_FILE)
	$(info $@: resolving $(BREW_BUNDLE_FILE))
	brew update >/dev/null
	brew bundle --file=$(BREW_BUNDLE_FILE) >/dev/null
	# returns non-zero if nothing to link
	-brew linkapps >/dev/null

brew-upgrade: $(BREW_BUNDLE_FILE)
	$(info $@: uprading brews)
	brew update >/dev/null
	brew upgrade --cleanup

brew-cask-upgrade: $(BREW_BUNDLE_FILE)
	$(info $@: uprading casks)
	@sbin/cask-up

.PHONY: brew-clean
brew-clean:
	$(info $@: cleaning up homebrew)
	brew cleanup >/dev/null
	brew cask cleanup >/dev/null
	brew prune >/dev/null
	brew services cleanup >/dev/null

.PHONY: brew-uninstall
brew-uninstall:
	$(info $@: uninstalling homebrew)
	$(BREW_UNINSTALL_FILE) 2>/dev/null

###
### # ruby
###

.PHONY: gem-update
gem-update:
	$(info $@: installing and updating gems)
	# returns non-zero if up-to-date
	-gem update --quiet --no-document --env-shebang --wrappers --system
	yes | gem update  --quiet --no-document --env-shebang --wrappers
	gem check -q --doctor
	gem install bundler >/dev/null

gem-bundle: $(GEM_BUNDLE_FILE)
	$(info $@: bundler might take some time)
	bundle --quiet --binstubs --clean --jobs=${core_count} --retry=2 --path $(BUNDLER_CACHE_PATH)
	bundle up --quiet

.PHONY: gem-clean
gem-clean:
	$(info $@: cleaning up gems)
	gem cleanup -q
	-bundle clean --force

.PHONY: gem-remove
gem-remove:
	$(info $@: uninstalling all gems)
	-yes | gem uninstall --force -D -I -a

###
### # python
###

.PHONY: python-install
python-install:
	$(info $@: compiling python $(PYTHON_VERSION))
	# install only if not existing
	pyenv install --skip-existing $(PYTHON_VERSION)

.PHONY: python-uninstall
python-uninstall:
	$(info $@: uninstalling python $(PYTHON_VERSION))
	pyenv uninstall $(PYTHON_VERSION)

###
### # virtualenv
###

.PHONY: virtualenv-provide
virtualenv-provide:
	$(info $@: providing virtualenv script)
	curl -s $(VENV_URI) -o $(VENV_TGZ)
	tar xzf $(VENV_TGZ) --strip-components=1 -C $(BIN_PATH) \*\*/virtualenv.py
	chmod +x $(VENV_SCRIPT)
	# virtualenv version
	@$(BIN_PATH)/virtualenv.py --version

.PHONY: virtualenv-create
virtualenv-create:
	$(info $@: creating virtual environment)
	$(VENV_SCRIPT) -q --clear --no-setuptools --no-wheel --no-pip --always-copy -p $(pyenv_prefix)/$(BIN_PATH)/python .
	$(BIN_PATH)/python -m ensurepip -U
	$(BIN_PATH)/$(PIP_BIN_NAME) install -q -U setuptools pip

.ONESHELL: virtualenv-remove
.PHONY: virtualenv-remove
virtualenv-remove:
	$(info $@: trashing virtual environment)
	-rm -rf $(BIN_PATH)/* include/* lib/*
	-rm -f .Python pip-selfcheck.json $(PIP_FREEZE_FILE) $(PIP_PRE_FREEZE_FILE)

###
### # pip
###

pip-update pip-install: $(PIP_REQ_FILE)
	$(info $@: installing requirements via pip)
	$(BIN_PATH)/$(PIP_BIN_NAME) freeze > $(PIP_PRE_FREEZE_FILE)
	$(BIN_PATH)/$(PIP_BIN_NAME) install -q -U -r $(PIP_REQ_FILE)
	$(BIN_PATH)/$(PIP_BIN_NAME) freeze > $(PIP_FREEZE_FILE)
	# returns non-zero on difference
	-diff -N $(PIP_PRE_FREEZE_FILE) $(PIP_FREEZE_FILE)

pip-uninstall: $(PIP_REQ_FILE)
	$(info $@: remove all packages)
	-$(BIN_PATH)/$(PIP_BIN_NAME) uninstall -q -y -r $(PIP_FREEZE_FILE)

###
### # vagrant
###

vagrant-update: Vagrantfile
	$(info $@: updating plugins and boxen, pruning outdated)
	vagrant plugin update >/dev/null
	vagrant box update >/dev/null
	# returns non-zero when nothing to remove
	-vagrant remove-old-check >/dev/null

vagrant-provision: Vagrantfile
	$(info $@: kick the box)
	vagrant up --no-provision
	vagrant provision

vagrant-destroy: Vagrantfile
	$(info $@: bringing the box down)
	vagrant destroy -f

###
### # ansible
###

ansible-galaxy: $(GALAXY_REQ_FILE)
	$(info $@: updating role dependencies)
	$(BIN_PATH)/ansible-galaxy install -f -r $(GALAXY_REQ_FILE)

.PHONY: ansible-lint
ansible-lint:
	$(info $@: checking ansible related files)
	pre-commit run --no-stash --allow-unstaged-config --files \
		.envrc \
		ansible.cfg Makefile README.md Vagrantfile requirements.txt \
		action_plugins/* callback_plugins/* \
		config/* group_vars/* \
		inventory/* library/* \
		meta/* \
		playbooks/** roles/** tests/** \
		pre-commit-hooks/* \
		provisioning/* sbin/*
	$(BIN_PATH)/ansible-lint $(PLAYBOOK_FILE)

.PHONY: ansible-test
ansible-test:
	$(info $@: run test)
	# TODO: abstraction
	$(BIN_PATH)/ansible-playbook -C -i inventory/vagrant.ini -e "@config/test.yml" --skip-tags="apt_upgrade" $(PLAYBOOK_FILE)

###
### # pre-commit
###

precommit-update: $(PRE_COMMIT_CONFIG)
	$(info $@: update and build pre-commit environments)
	$(BIN_PATH)/pre-commit-validate-config
	$(BIN_PATH)/pre-commit autoupdate
	$(BIN_PATH)/pre-commit install -f

precommit-run: $(PRE_COMMIT_CONFIG)
	$(info $@: checking cached files)
	$(BIN_PATH)/pre-commit run --all-files --allow-unstaged-config

precommit-clean: $(PRE_COMMIT_CONFIG)
	$(info $@: cleanup pre-commit)
	$(BIN_PATH)/pre-commit clean

###
### # git
###

.DELETE_ON_ERROR: _revision
.PHONY: _revision
_revision:
	$(info $@: tagging as $(git_tag))
	# conditional
	test -n "$(git_rev)" && echo $(git_tag) > .revision
	# conditional
	test -n "$(git_rev)" && git tag "Makefile_$(git_tag)"

.PHONY: git-secrets-scan
git-secrets-scan:
	$(info $@: scanning for secrects psst)
	# returns non-zero if something is revealed
	git secrets --scan --cached .

.PHONY: git-update
git-update:
	$(info $@: updating $(git_rev))
	# returns non-zero if host is unreachable
	-git pull
	-git gc --auto

###
### # notification
###

.PHONY: _notify
_notify:
	@-terminal-notifier -message 'All done!' -title 'Taxigirl - Makefile' -subtitle '🚖👧🔧💟'

###
### # 'test'
###

.ONESHELL: versions
.PHONY: versions
versions:
	$(info $@: gathering version strings)
	# ruby
	@-command -v ruby; ruby -v
	# ruby gems
	@-command -v gem; gem -v
	# bundler
	@-command -v bundle; bundle -v
	# vagrant
	@-command -v vagrant; vagrant --version
	# virtualbox
	@-command -v VBoxManage; VBoxManage --version
	# git
	@-command -v git; git --version
	# pyenv
	@-command -v pyenv; pyenv -v; pyenv version
	# python easy_install
	@-command -v easy_install; $(BIN_PATH)/easy_install --version
	# python virtualenv
	@-command -v virtualenv; $(BIN_PATH)/virtualenv --version
	# python pip
	@-command -v pip; $(BIN_PATH)/$(PIP_BIN_NAME) --version
	# yelp pre-commit
	@-command -v pre-commit; $(BIN_PATH)/pre-commit --version
	# python
	@-command -v python; $(BIN_PATH)/python -V
	# ansible
	@-command -v ansible; $(BIN_PATH)/ansible --version

###
### # cleansing
###

.PHONY: clean
clean:
	$(info $@: cleaning temporary files)
	-rm -rf log/* cache/* tmp/*
	-rm -f *.spec

.ONESHELL: clobber
.PHONY: clobber
clobber:
	$(warning $@: are you sure? press any key to continue)
	@read -t 10
	$(info $@: wiping it all away)
	# box might not exist
	-vagrant destroy -f
	# might not be present
	-pre-commit clean
	rm -f .revision
	rm -f pip-selfcheck.json $(PIP_FREEZE_FILE) $(PIP_PRE_FREEZE_FILE)
	rm -f $(VENV_TGZ)
	rm -rf .vagrant
	rm -rf $(BIN_PATH)/* include/* lib/* .Python *.spec
	rm -rf log/* cache/* tmp/*
	rm -rf vendor/* Gemfile.lock
	# might not be present
	-git gc --auto
	sync
