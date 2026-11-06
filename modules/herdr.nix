# Home Manager module that links the herdr workbench (herdr/ in this
# repository) into the herdr-app home. Importing it makes the links. They point
# at a devkit checkout outside the store, so an edit in the checkout reloads
# the running window. keys.json stays a real file that herdr-app and the person
# edit; activation merges the workbench's section into it, and the workbench's
# keys win.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.devkit.herdr;
  home = ".config/herdr-app";
  paths = ["layouts/workbench.json" "mods/explorer" "mods/workbench-tabs" "mods/workbench-pane"];
in {
  options.devkit.herdr.checkout = lib.mkOption {
    type = lib.types.str;
    default = "${config.home.homeDirectory}/code/devkit";
    description = "The devkit checkout the links point at.";
  };

  config = {
    home.file = lib.listToAttrs (map (path: {
        name = "${home}/${path}";
        value.source = config.lib.file.mkOutOfStoreSymlink "${cfg.checkout}/herdr/${path}";
      })
      paths);

    home.activation.herdrWorkbenchKeys = lib.hm.dag.entryAfter ["writeBoundary"] ''
      keys_file="$HOME/${home}/keys.json"
      if [[ ! -f "$keys_file" ]]; then
        $DRY_RUN_CMD mkdir -p "$(dirname "$keys_file")"
        $DRY_RUN_CMD printf '{}' >"$keys_file"
      fi
      $DRY_RUN_CMD ${pkgs.jq}/bin/jq --slurpfile section ${../herdr/keys.json} \
        '. * $section[0]' "$keys_file" >"$keys_file.tmp"
      $DRY_RUN_CMD mv "$keys_file.tmp" "$keys_file"
    '';
  };
}
