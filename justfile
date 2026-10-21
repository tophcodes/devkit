# list recipes
default:
    @just --list

# rerun all checks on every change
dev:
    watchexec -e nix,py,toml -- nix flake check

# build every template and check this repository
test:
    nix flake check

# format all files
fmt:
    treefmt

# everything CI checks
check:
    nix flake check
