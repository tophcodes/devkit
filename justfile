# list recipes
default:
    @just --list

# rerun all checks on every change
dev:
    watchexec -e nix,py,toml -- nix flake check

# copy the herdr workbench into a remote herdr-app home on every change
herdr-sync target="vasa":
    watchexec -n -w herdr/mods -w herdr/layouts -- \
        rsync -aR --no-group --delete --exclude jsconfig.json --exclude '*.d.ts' \
        herdr/./mods/explorer herdr/./mods/workbench-tabs herdr/./mods/workbench-pane \
        herdr/./layouts/workbench.json {{ target }}:.config/herdr-app/

# build every template and check this repository
test:
    nix flake check

# format all files
fmt:
    treefmt

# everything CI checks
check:
    nix flake check
