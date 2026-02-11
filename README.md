# nixos-config

Disposable UTM-focused NixOS machine configurations with role-based builder profiles.

## Included disposable builders

- `disposable-rust-aarch64`
- `disposable-python-aarch64`
- `disposable-zig-aarch64`

Each disposable machine is:

- `aarch64-linux`
- headless (no X server)
- Docker-enabled with BuildKit
- prepared for registry publishing (`REGISTRY_PUSH`, `REGISTRY_PULL` env defaults)

## Deploy a disposable machine

From this repo:

```bash
make NIXNAME=disposable-rust-aarch64 vm/vars
make NIXNAME=disposable-rust-aarch64 vm/preflight
make NIXNAME=disposable-rust-aarch64 vm
make NIXNAME=disposable-python-aarch64 vm
make NIXNAME=disposable-zig-aarch64 vm
```

Default target mapping:

- `vm-aarch64-utm` -> `kcirtap@192.168.72.2`
- `disposable-*-aarch64` -> `root@192.168.64.13`

Override any default inline when needed:

```bash
make NIXNAME=disposable-rust-aarch64 NIXADDR=192.168.64.50 NIXUSER=root vm
```

If you want non-interactive password auth (for scripts/CI), pass `NIXPASS`:

```bash
make NIXNAME=disposable-rust-aarch64 NIXPASS=root vm/preflight
```

## Create a new disposable machine

```bash
./scripts/new-disposable-machine.sh <name> <role>
```

Example:

```bash
./scripts/new-disposable-machine.sh ci-rust rust
```

The script creates `machines/disposable-<name>-aarch64.nix` and prints the `flake.nix` block to add.

## Build and publish container images

Use the generic build/publish helper:

```bash
./scripts/publish-image.sh \
  --image kiro/backend \
  --tag dev \
  --registry localhost:5001 \
  --platform linux/arm64 \
  --dockerfile ./backend/Dockerfile \
  --context ./backend \
  --latest
```

Notes:

- Add `--no-push` to build locally without publishing.
- Default tag is git short SHA (or timestamp when outside git).
- Default registry is `REGISTRY_PUSH` or `localhost:5001`.
