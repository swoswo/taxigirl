#!/usr/bin/env make
#
# https://github.com/emetriq/taxigirl
# 2016 tom hensel <github@jitter.eu>
#
# tested on osx.
# usage:
#   $ make install
#   or i.e.:
#   $ PYTHON_VERSION=3.5.1 PIP_BIN_NAME=pip3 make install
#

###
### # defaults
###

MKDIR_LIST		?= bin files log roles.galaxy persistent sync tmp vendor
ANSIBLE_PLAYBOOK_FILE	?= playbooks/main.yml
BIN_PATH 		?= ./bin
BREW_BUNDLE_FILE 	?= Brewfile
BREW_INSTALL_FILE 	?= ./sbin/brew-install
BREW_UNINSTALL_FILE 	?= ./sbin/brew-uninstall
BUNDLER_CACHE_PATH 	?= ./vendor/cache
GALAXY_REQ_FILE 	?= requirements.yml
GEM_BUNDLE_FILE		?= Gemfile
PIP_BIN_NAME 		?= pip
PIP_FREEZE_FILE 	?= requirements_freeze.txt
PIP_PRE_FREEZE_FILE 	?= requirements_pre_freeze.txt
PIP_REQ_FILE 		?= requirements.txt
PRE_COMMIT_CONFIG	?= .pre-commit-config.yaml
PYTHON_VERSION 		?= 2.7.11
VENV_SCRIPT 		?= ./bin/virtualenv.py
VENV_TGZ 		?= ./files/virtualenv.tgz
# note: hashes need to be escaped!
VENV_URI 		?= https://pypi.python.org/packages/5c/79/5dae7494b9f5ed061cff9a8ab8d6e1f02db352f3facf907d9eb614fb80e9/virtualenv-15.0.2.tar.gz\#md5=0ed59863994daf1292827ffdbba80a63

###
### # intialization
###

# dont stick with traditions, no files will be made
.SUFFIXES:
# due to inter-target dependencies (like gems) we can not parallelize
.NOTPARALLEL:

# if no target is specified on commandline
.DEFAULT_GOAL := list

# get system name (platform)
sys_name := $(shell uname -s)
# some tasks provide multicore options
core_count := $(shell getconf _NPROCESSORS_ONLN)


# vagrant is installed by some task so don't expect it's presence
_vagrant := $(shell which vagrant)
ifneq ($(_vagrant),)
vagrant_tasks := vagrant-update
endif

brew_tasks :=
ifneq ($(wildcard $(BREW_BUNDLE_FILE)),)
brew_tasks := brew-install brew-update brew-cask-upgrade brew-clean
endif

gem_tasks :=
ifneq ($(wildcard $(GEM_BUNDLE_FILE)),)
gem_tasks := gem-update gem-bundle gem-clean
endif

###
### # tasks
###

update_tasks +=		git-update \
			$(brew_tasks) \
			$(gem_tasks) \
			$(vagrant_tasks)

bootstrap_tasks +=	clean \
			update \
			python-install \
			virtualenv-provide

install_tasks +=	virtualenv-provide \
			virtualenv-create \
			pip-install \
			versions \
			precommit-update \
			_revision

lint_tasks += 		git-check \
			git-secrets-scan \
			precommit-run

run_tasks +=		ansible-lint \
			vagrant-provision

provision_tasks +=	vagrant-up \
			ansible-galaxy \
			ansible-lint \
			vagrant-provision

distclean_tasks +=	vagrant-halt \
			gem-remove gem-clean \
			pip-uninstall \
			virtualenv-remove \
			clean

test_tasks +=		git-check \
			install \
			provision \
			vagrant-destroy \
			distclean

all_tasks += 		update \
			install \
			provision \
			run

.PHONY: install reset update check install distclean test
update:			$(update_tasks)
bootstrap:		$(bootstrap_tasks)
install:		$(install_tasks)
lint:			$(lint_tasks)
run:			$(run_tasks)
provision:		$(provision_tasks)
distclean:		$(distclean_tasks)
test:			$(test_tasks)
all:			$(all_tasks)

list help:
	$(info $@: available targets)
	@# http://stackoverflow.com/a/26339924/1972627
	@$(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>/dev/null | awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | egrep -v -e '^[^[:alnum:]]' -e '^$@$$' | xargs

###
### # homebrew
###

.PHONY: brew-install
brew-install:
	$(info $@: installing homebrew)
	# returns non-zero when already installed
	@-$(BREW_INSTALL_FILE) 2>/dev/null
	@brew tap Homebrew/bundle >/dev/null

brew-update: $(BREW_BUNDLE_FILE)
	$(info $@: resolving $(BREW_BUNDLE_FILE) requirements)
	@brew update
	@brew bundle --file=$(BREW_BUNDLE_FILE)
	@brew upgrade --cleanup
	@# returns non-zero if nothing to link
	@-brew linkapps >/dev/null

brew-cask-upgrade: $(BREW_BUNDLE_FILE)
	$(info $@: uprading casks)
	@sbin/cask-up.sh

.PHONY: brew-clean
brew-clean:
	$(info $@: cleaning up homebrew)
	@brew cleanup >/dev/null
	@brew cask cleanup >/dev/null
	@brew prune >/dev/null
	@brew services cleanup >/dev/null

.PHONY: brew-uninstall
brew-uninstall:
	$(info $@: uninstalling homebrew)
	@$(BREW_UNINSTALL_FILE) 2>/dev/null

###
### # ruby
###

.PHONY: gem-update
gem-update:
	$(info $@: installing and updating gems)
	@# returns non-zero if up-to-date
	@-gem update --quiet --no-document --env-shebang --wrappers --system
	@yes | gem update --quiet --no-document --env-shebang --wrappers
	@gem check -q --doctor
	@gem install --quiet bundler

gem-bundle: $(GEM_BUNDLE_FILE)
	$(info $@: resolving $(GEM_BUNDLE_FILE) requirements)
	@bundle --binstubs --clean --jobs=${core_count} --retry=2 --path $(BUNDLER_CACHE_PATH)
	@bundle up

.PHONY: gem-clean
gem-clean:
	$(info $@: cleaning up gems)
	@gem cleanup -q
	@-bundle clean --force

.PHONY: gem-remove
gem-remove:
	$(info $@: uninstalling all gems)
	@-yes | gem uninstall --force -D -I -a

###
### # python
###

.PHONY: python-install
python-install:
	$(info $@: compiling python $(PYTHON_VERSION))
	@# install only if not existing
	@pyenv install --skip-existing $(PYTHON_VERSION)

.PHONY: python-uninstall
python-uninstall:
	$(info $@: removing installation of python $(PYTHON_VERSION))
	@pyenv uninstall $(PYTHON_VERSION)

###
### # virtualenv
###

# GNU needs extrawurst
ifeq ($(sys_name),Linux)
tar_options := --wildcards
else
tar_options :=
endif

.PHONY: virtualenv-provide
virtualenv-provide:
	$(info $@: providing virtualenv script)
	@-mkdir $(MKDIR_LIST) 2>/dev/null
	@curl -s $(VENV_URI) -o $(VENV_TGZ)
	@tar xzf $(VENV_TGZ) $(tar_options) --strip-components=1 -C $(BIN_PATH) \*\*/virtualenv.py
	@chmod +x $(VENV_SCRIPT)
	# virtualenv check
	@$(BIN_PATH)/virtualenv.py --version

# get python prefix
pyenv_prefix := $(shell pyenv prefix $(PYTHON_VERSION))
ifeq ($(pyenv_prefix),)
$(info unable to retrive pyenv prefix, using system)
sys_python := $(shell which python)
else
sys_python := $(pyenv_prefix)/bin/python
endif

.PHONY: virtualenv-create
virtualenv-create:
	$(info $@: creating virtual environment)
	@$(VENV_SCRIPT) -q --clear --always-copy --no-setuptools --no-wheel --no-pip -p $(sys_python) .
	@$(BIN_PATH)/python -m ensurepip -U
	@$(BIN_PATH)/$(PIP_BIN_NAME) install -q -U setuptools pip

.ONESHELL: virtualenv-remove
.PHONY: virtualenv-remove
virtualenv-remove:
	$(info $@: trashing virtual environment)
	@-rm -rf $(BIN_PATH)/* include/* lib/*
	@-rm -f .Python pip-selfcheck.json $(PIP_FREEZE_FILE) $(PIP_PRE_FREEZE_FILE)

###
### # pip
###

pip-update pip-install: $(PIP_REQ_FILE)
	$(info $@: resolving $(PIP_REQ_FILE) requirements)
	@$(BIN_PATH)/$(PIP_BIN_NAME) freeze > $(PIP_PRE_FREEZE_FILE) >/dev/null
	@$(BIN_PATH)/$(PIP_BIN_NAME) install -q -U setuptools pip
	@$(BIN_PATH)/$(PIP_BIN_NAME) install -U -r $(PIP_REQ_FILE)
	@$(BIN_PATH)/$(PIP_BIN_NAME) freeze > $(PIP_FREEZE_FILE) >/dev/null
	@# returns non-zero on difference
	@-diff -N $(PIP_PRE_FREEZE_FILE) $(PIP_FREEZE_FILE) > log/pip_diff.txt
	@-cat log/pip_diff.txt

pip-uninstall: $(PIP_REQ_FILE)
	$(info $@: removing all packages)
	@-$(BIN_PATH)/$(PIP_BIN_NAME) uninstall -q -y -r $(PIP_FREEZE_FILE)

###
### # vagrant
###

vagrant-update: Vagrantfile
	$(info $@: updating plugins and boxen, pruning outdated)
	@vagrant version
	@vagrant plugin update
	@vagrant box update
	@# returns non-zero when nothing to remove
	@-vagrant remove-old-check >/dev/null

vagrant-up: Vagrantfile
	$(info $@: bringing the box up)
	@vagrant up --no-provision
	@-vagrant vbinfo

vagrant-provision: Vagrantfile
	$(info $@: running provisioner inside the box)
	@source bin/activate; vagrant provision

vagrant-halt: Vagrantfile
	$(info $@: halting the box)
	@-vagrant halt --force

vagrant-destroy: Vagrantfile
	$(info $@: bringing the box down for destruction)
	@-vagrant destroy --force

###
### # ansible
###

ansible-galaxy: $(GALAXY_REQ_FILE)
	$(info $@: updating role dependencies)
	$(BIN_PATH)/ansible-galaxy install -f -r $(GALAXY_REQ_FILE)

.PHONY: ansible-check
ansible-check:
	$(info $@: checking all components)
	@# TODO: abstraction
	@pre-commit run --no-stash --allow-unstaged-config \
					--files \
		.envrc \
		ansible.cfg Makefile README.md Vagrantfile requirements.txt \
		action_plugins/* callback_plugins/* \
		config/* group_vars/* \
		inventory/* library/* \
		meta/* \
		playbooks/** roles/** tests/** \
		pre-commit-hooks/* \
		provisioning/* sbin/*

.PHONY: ansible-lint
ansible-lint:
	$(info $@: linting playbook $(ANSIBLE_PLAYBOOK_FILE))
	$(BIN_PATH)/ansible-lint --exclude=roles.galaxy --exclude=tests $(ANSIBLE_PLAYBOOK_FILE)

.PHONY: ansible-run
ansible-run:
	$(info $@: running playbook $(ANSIBLE_PLAYBOOK_FILE))
	$(BIN_PATH)/ansible-playbook $(ANSIBLE_PLAYBOOK_FILE) --inventory-file="inventory/localhost.ini" --extra-vars="@./config/test.yml" --timeout=60 -vvv

###
### # pre-commit
###

precommit-update: $(PRE_COMMIT_CONFIG)
	$(info $@: building pre-commit environments)
	@$(BIN_PATH)/pre-commit-validate-config
	@$(BIN_PATH)/pre-commit autoupdate
	@$(BIN_PATH)/pre-commit install

precommit-run: $(PRE_COMMIT_CONFIG)
	$(info $@: checking cached files)
	@$(BIN_PATH)/pre-commit run --all-files --allow-unstaged-config

precommit-clean: $(PRE_COMMIT_CONFIG)
	$(info $@: cleaning up pre-commit)
	@$(BIN_PATH)/pre-commit clean

###
### # git
###

# get git rev id or fail
git_rev := $(shell git rev-parse --short HEAD)
ifeq ($(git_rev),)
$(warning unable to retrive git revision)
endif
# compose tag to set if this recipe succeeds
rev_tag := $(git_rev)_$(shell date +%s)

.DELETE_ON_ERROR: _revision
.PHONY: _revision
_revision:
	$(info $@: storing tag $(rev_tag))
	@test -n "$(git_rev)" && echo $(rev_tag) > .revision

.PHONY: git-secrets-scan
git-secrets-scan:
	$(info $@: scanning for secrects.. psst)
	@# returns non-zero if something is revealed
	@git-secrets --scan --cached .

.PHONY: git-check
git-check:
	$(info $@: checking state of $(git_rev))
	@-git fetch
	# returns non-zero if our local copy is outdated
	@git log HEAD.. --oneline

.PHONY: git-update
git-update:
	$(info $@: updating $(git_rev))
	@# returns non-zero if host is unreachable
	@-git pull
	@-git gc --auto

###
### # versions
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
	# pyenv
	@-command -v pyenv; pyenv -v; pyenv version
	# pyenv
	@-command -v ry; ry version
	# git
	@command -v git; git --version
	# python
	@command -v python; $(BIN_PATH)/python -V
	# python virtualenv
	@command -v virtualenv; $(BIN_PATH)/virtualenv --version
	# python pip
	@command -v pip; $(BIN_PATH)/$(PIP_BIN_NAME) --version
	# ansible
	@command -v ansible; $(BIN_PATH)/ansible --version

###
### # cleansing
###

.PHONY: clean
clean:
	$(info $@: cleaning temporary files)
	@-rm -rf log/* cache/* tmp/*
	@-rm -f *.spec

.ONESHELL: clobber
.PHONY: clobber
clobber:
	$(warning $@: are you sure? press any key to continue)
	@read -t 10
	$(info $@: wiping all away)
	@-vagrant destroy -f
	@-pre-commit clean >/dev/null
	@-rm -f .revision *.spec
	@-rm -f pip-selfcheck.json $(PIP_FREEZE_FILE) $(PIP_PRE_FREEZE_FILE)
	@-rm -f $(VENV_TGZ)
	@-rm -rf .vagrant
	@-rm -rf $(BIN_PATH)/* include/* lib/* .Python
	@-rm -rf log/* cache/* tmp/*
	@-rm -rf vendor/* Gemfile.lock
	@-sync
