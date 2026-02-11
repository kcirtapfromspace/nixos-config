#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage: ./scripts/new-disposable-machine.sh <name> <role>

Arguments:
  name   machine suffix (example: ci-rust)
  role   one of: rust, python, zig

Example:
  ./scripts/new-disposable-machine.sh ci-rust rust
USAGE
}

if [[ $# -ne 2 ]]; then
  usage
  exit 1
fi

name="$1"
role="$2"

case "$role" in
  rust|python|zig)
    ;;
  *)
    echo "invalid role: $role" >&2
    usage
    exit 1
    ;;
esac

machine="disposable-${name}-aarch64"
file="machines/${machine}.nix"

if [[ -e "$file" ]]; then
  echo "machine file already exists: $file" >&2
  exit 1
fi

cat > "$file" <<MACHINE
{ ... }:

{
  imports = [
    ./hardware/vm-aarch64-utm.nix
    ./profiles/disposable/common.nix
    ./profiles/disposable/${role}.nix
  ];

  networking.hostName = "${machine}";

  system.stateVersion = "24.11";
}
MACHINE

cat <<INFO
Created ${file}

Add this to flake.nix:

nixosConfigurations.${machine} = mkSystem "${machine}" {
  system = "aarch64-linux";
  user   = "kcirtap";
};

Then deploy:
  make NIXNAME=${machine} vm
INFO
