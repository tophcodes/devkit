# Shows what changes between two NixOS systems: dix's package diff, then the
# files under /etc that were added, removed or changed, which includes the
# systemd units. `system-diff <old> <new>`; see system-diff.sh. It calls the
# host's nix-store to find the system inside a closure.
{pkgs, ...}:
pkgs.writeShellApplication {
  name = "system-diff";
  runtimeInputs = [pkgs.dix pkgs.coreutils pkgs.diffutils pkgs.findutils pkgs.gawk pkgs.gnugrep pkgs.gnused];
  text = builtins.readFile ./system-diff.sh;
}
