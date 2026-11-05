{pkgs, ...}:
pkgs.writeShellApplication {
  name = "arch-check";
  runtimeInputs = [pkgs.jq pkgs.yq-go pkgs.ripgrep pkgs.fd pkgs.coreutils];
  text = builtins.readFile ./arch-check;
}
