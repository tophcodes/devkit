# pt runs a command in a herdr popup terminal. It calls `hc`, which the machine
# provides: herdr-app on a desktop, herdr-core on a machine the tabs run on.
{pkgs, ...}:
pkgs.writeShellApplication {
  name = "pt";
  text = builtins.readFile ./pt.sh;
}
