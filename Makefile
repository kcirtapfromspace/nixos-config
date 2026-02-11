# Get the path to this Makefile and directory
MAKEFILE_DIR := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))

# The name of the nixosConfiguration in the flake
# NIXNAME ?= mac-studio-m1
NIXNAME ?= vm-aarch64-utm

# Connectivity info for Linux VM
# You can still override these per command:
#   make NIXNAME=... NIXADDR=... NIXUSER=... vm
NIXADDR_DEFAULT ?= 192.168.72.2
NIXUSER_DEFAULT ?= kcirtap
NIXPORT ?= 22

# Known machine defaults
NIXADDR_vm-aarch64-utm ?= 192.168.72.2
NIXUSER_vm-aarch64-utm ?= kcirtap

# Disposable builders on UTM host
NIXADDR_disposable-rust-aarch64 ?= 192.168.64.13
NIXUSER_disposable-rust-aarch64 ?= root
NIXADDR_disposable-python-aarch64 ?= 192.168.64.13
NIXUSER_disposable-python-aarch64 ?= root
NIXADDR_disposable-zig-aarch64 ?= 192.168.64.13
NIXUSER_disposable-zig-aarch64 ?= root

NIXADDR ?= $(if $(NIXADDR_$(NIXNAME)),$(NIXADDR_$(NIXNAME)),$(NIXADDR_DEFAULT))
NIXUSER ?= $(if $(NIXUSER_$(NIXNAME)),$(NIXUSER_$(NIXNAME)),$(NIXUSER_DEFAULT))
VM_ALLOW_NON_NIXOS ?= false

# The block device prefix to use.
#   - sda for SATA/IDE
#   - vda for virtio

NIXBLOCKDEVICE ?= vda
# SSH options that are used. These aren't meant to be overridden but are
# reused a lot so we just store them up here.
SSH_OPTIONS=-o PubkeyAuthentication=no -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=6 -o ConnectionAttempts=1
SSH_BASE=ssh $(SSH_OPTIONS) -p$(NIXPORT)
ifeq ($(strip $(NIXPASS)),)
SSH_CMD=$(SSH_BASE)
RSYNC_SSH=$(SSH_BASE)
else
SSH_CMD=sshpass -p '$(NIXPASS)' $(SSH_BASE)
RSYNC_SSH=sshpass -p '$(NIXPASS)' $(SSH_BASE)
endif

# We need to do some OS switching below.
UNAME := $(shell uname)

switch:
ifeq ($(UNAME), Darwin)
	nix build --extra-experimental-features nix-command --extra-experimental-features flakes ".#darwinConfigurations.${NIXNAME}.system"
	./result/sw/bin/darwin-rebuild switch --flake "$$(pwd)#${NIXNAME}"
else
	sudo NIXPKGS_ALLOW_UNSUPPORTED_SYSTEM=1 nixos-rebuild switch --flake ".#${NIXNAME}"
endif

test:
ifeq ($(UNAME), Darwin)
	nix build ".#darwinConfigurations.${NIXNAME}.system"
	./result/sw/bin/darwin-rebuild test --flake "$$(pwd)#${NIXNAME}"
else
	sudo NIXPKGS_ALLOW_UNSUPPORTED_SYSTEM=1 nixos-rebuild test --flake ".#$(NIXNAME)"
endif

# This builds the given NixOS configuration and pushes the results to the
# cache. This does not alter the current running system. This requires
# cachix authentication to be configured out of band.
cache:
	NIXPKGS_ALLOW_UNSUPPORTED_SYSTEM=1 nix build '.#nixosConfigurations.$(NIXNAME).config.system.build.toplevel' --json \
		| jq -r '.[].outputs | to_entries[].value' \
		| cachix push kcirtapfromspace-nixos-config

# bootstrap a brand new VM. The VM should have NixOS ISO on the CD drive
# and just set the password of the root user to "root". This will install
# NixOS. After installing NixOS, you must reboot and set the root password
# for the next step.
#
# NOTE(kcirtapfromspace): I'm sure there is a way to do this and bootstrap all
# in one step but when I tried to merge them I got errors. One day.
vm/bootstrap0:
	$(SSH_CMD) root@$(NIXADDR) " \
		parted /dev/$(NIXBLOCKDEVICE) -- mklabel gpt; \
		parted /dev/$(NIXBLOCKDEVICE) -- mkpart primary 512MiB -8GiB; \
		parted /dev/$(NIXBLOCKDEVICE) -- mkpart primary linux-swap -8GiB 100\%; \
		parted /dev/$(NIXBLOCKDEVICE) -- mkpart ESP fat32 1MiB 512MiB; \
		parted /dev/$(NIXBLOCKDEVICE) -- set 3 esp on; \
		sleep 1; \
		mkfs.ext4 -L nixos /dev/$(NIXBLOCKDEVICE)1; \
		mkswap -L swap /dev/$(NIXBLOCKDEVICE)2; \
		mkfs.fat -F 32 -n boot /dev/$(NIXBLOCKDEVICE)3; \
		sleep 1; \
		mount /dev/disk/by-label/nixos /mnt; \
		mkdir -p /mnt/boot; \
		mount /dev/disk/by-label/boot /mnt/boot; \
		nixos-generate-config --root /mnt; \
		sed --in-place '/system\.stateVersion = .*/a \
			nix.package = pkgs.nixUnstable;\n \
			nix.extraOptions = \"experimental-features = nix-command flakes\";\n \
			nix.settings.substituters = [\"https://kcirtapfromspace-nixos-config.cachix.org\"];\n \
			nix.settings.trusted-public-keys = [\"kcirtapfromspace-nixos-config.cachix.org-1:WvCbexA5U/18jpd+S1Xdl83HIRkibSQJdSUXWfQpz00=\"];\n \
  			services.openssh.enable = true;\n \
			services.openssh.settings.PasswordAuthentication = true;\n \
			services.openssh.settings.PermitRootLogin = \"yes\";\n \
			users.users.root.initialPassword = \"root\";\n \
		' /mnt/etc/nixos/configuration.nix; \
		nixos-install --no-root-passwd && reboot; \
	"

# after bootstrap0, run this to finalize. After this, do everything else
# in the VM unless secrets change.
vm/bootstrap:
	NIXUSER=root NIXPASS='$(NIXPASS)' $(MAKE) vm/copy
	NIXUSER=root NIXPASS='$(NIXPASS)' $(MAKE) vm/switch
	NIXPASS='$(NIXPASS)' $(MAKE) vm/secrets
	$(SSH_CMD) $(NIXUSER)@$(NIXADDR) " \
		sudo reboot; \
	"
vm/garbage:
	NIXUSER=root NIXPASS='$(NIXPASS)' $(MAKE) vm/gc
	"

# copy our secrets into the VM
vm/secrets:
	# GPG keyring
	rsync -av -e "$(RSYNC_SSH)" \
		--exclude='.#*' \
		--exclude='S.*' \
		--exclude='*.conf' \
		$(HOME)/.gnupg/ $(NIXUSER)@$(NIXADDR):~/.gnupg
	# SSH keys
	rsync -av -e "$(RSYNC_SSH)" \
		--exclude='environment' \
		$(HOME)/.ssh/ $(NIXUSER)@$(NIXADDR):~/.ssh

# copy the Nix configurations into the VM.
vm/copy:
	rsync -av -e "$(RSYNC_SSH)" \
		--exclude='vendor/' \
		--exclude='.git/' \
		--exclude='.git-crypt/' \
		--exclude='iso/' \
		--rsync-path="sudo rsync" \
		$(MAKEFILE_DIR)/ $(NIXUSER)@$(NIXADDR):/nix-config

# run the nixos-rebuild switch command. This does NOT copy files so you
# have to run vm/copy before.
vm/switch:
	$(SSH_CMD) $(NIXUSER)@$(NIXADDR) " \
		sudo NIXPKGS_ALLOW_UNSUPPORTED_SYSTEM=1 nixos-rebuild switch --flake \"/nix-config#${NIXNAME}\"\
	"

# sudo NIXPKGS_ALLOW_UNSUPPORTED_SYSTEM=1 nixos-rebuild switch --flake nix-config#vm-aarch64-utm
vm/gc:
	$(SSH_CMD) $(NIXUSER)@$(NIXADDR) " \
		sudo NIXPKGS_ALLOW_UNSUPPORTED_SYSTEM=1 nix-store --gc \
	"

.PHONY: vm/vars
vm/vars:
	@echo "NIXNAME=$(NIXNAME)"
	@echo "NIXADDR=$(NIXADDR)"
	@echo "NIXPORT=$(NIXPORT)"
	@echo "NIXUSER=$(NIXUSER)"
	@echo "VM_ALLOW_NON_NIXOS=$(VM_ALLOW_NON_NIXOS)"

.PHONY: vm/preflight
vm/preflight:
	@$(SSH_CMD) $(NIXUSER)@$(NIXADDR) " \
		if ! command -v nixos-rebuild >/dev/null 2>&1; then \
			echo 'ERROR: remote target does not have nixos-rebuild.'; \
			echo '       This host is not ready for nixos-config vm deployment.'; \
			echo '       target=$(NIXUSER)@$(NIXADDR):$(NIXPORT)'; \
			if [ -r /etc/os-release ]; then \
				. /etc/os-release; \
				echo \"       remote_os=\$${PRETTY_NAME:-unknown}\"; \
			else \
				echo '       remote_os=unknown'; \
			fi; \
			echo '       expected: NixOS target with nixos-rebuild available'; \
			if [ '$(VM_ALLOW_NON_NIXOS)' = 'true' ]; then \
				echo 'WARN: VM_ALLOW_NON_NIXOS=true, allowing copy-only flow.'; \
				exit 0; \
			fi; \
			exit 2; \
		fi \
	"

.PHONY: vm/copy-only
vm/copy-only:
	$(MAKE) vm/vars VM_ALLOW_NON_NIXOS=true NIXPASS='$(NIXPASS)'
	$(MAKE) vm/preflight VM_ALLOW_NON_NIXOS=true NIXPASS='$(NIXPASS)'
	$(MAKE) vm/copy NIXPASS='$(NIXPASS)'
	@echo "INFO: copy-only flow complete (remote is non-NixOS)."
	@echo "INFO: skipped nix-store gc + nixos-rebuild switch."

vm:
	$(MAKE) vm/vars NIXPASS='$(NIXPASS)' VM_ALLOW_NON_NIXOS='$(VM_ALLOW_NON_NIXOS)'
	$(MAKE) vm/preflight NIXPASS='$(NIXPASS)' VM_ALLOW_NON_NIXOS='$(VM_ALLOW_NON_NIXOS)'
	@if [ "$(VM_ALLOW_NON_NIXOS)" = "true" ]; then \
		$(MAKE) vm/copy NIXPASS='$(NIXPASS)'; \
		echo "INFO: VM_ALLOW_NON_NIXOS=true -> copy-only flow complete."; \
		echo "INFO: skipped nix-store gc + nixos-rebuild switch."; \
	else \
		$(MAKE) vm/gc NIXPASS='$(NIXPASS)'; \
		$(MAKE) vm/copy NIXPASS='$(NIXPASS)'; \
		$(MAKE) vm/switch NIXPASS='$(NIXPASS)'; \
	fi
	
# Build a WSL installer
.PHONY: wsl
wsl:
	nix build ".#nixosConfigurations.wsl.config.system.build.installer"
# Image publish helper defaults
IMAGE_NAME ?=
IMAGE_TAG ?=
IMAGE_PLATFORM ?= linux/arm64
IMAGE_CONTEXT ?= .
IMAGE_DOCKERFILE ?= Dockerfile

publish-image:
	./scripts/publish-image.sh \
		--image "$(IMAGE_NAME)" \
		--tag "$(IMAGE_TAG)" \
		--platform "$(IMAGE_PLATFORM)" \
		--context "$(IMAGE_CONTEXT)" \
		--dockerfile "$(IMAGE_DOCKERFILE)"

new-disposable:
	./scripts/new-disposable-machine.sh "$(NAME)" "$(ROLE)"
