# The flake-parts module every project imports. It provides the dev shell,
# treefmt as the formatter, and the checks behind `just check`.
{localInputs}: {self, ...}: {
  imports = [localInputs.treefmt-nix.flakeModule];

  perSystem = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.devkit;
    requiredRecipes = ["default" "dev" "test" "fmt" "check"];
  in {
    options.devkit = {
      packages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [];
        description = "Tools on PATH in the dev shell and in the test check.";
      };
      testCommand = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          The command `just test` runs. `nix flake check` runs it in the build
          sandbox as `checks.test`, without network access. Leave it null when
          the tests need a dedicated derivation, and define that check instead.
        '';
      };
    };

    config = {
      treefmt = {
        projectRootFile = "flake.nix";
        programs.alejandra.enable = true;
      };

      devShells.default = pkgs.mkShell {
        packages =
          [
            pkgs.just
            pkgs.watchexec
            config.treefmt.build.wrapper
          ]
          ++ cfg.packages;
      };

      checks =
        {
          recipes = pkgs.runCommand "recipes" {nativeBuildInputs = [pkgs.just];} ''
            cd ${self}
            have=" $(just --summary) "
            for recipe in ${lib.concatStringsSep " " requiredRecipes}; do
              case "$have" in
                *" $recipe "*) ;;
                *) echo "justfile lacks the required recipe '$recipe'" >&2; exit 1 ;;
              esac
            done
            touch $out
          '';
        }
        // lib.optionalAttrs (cfg.testCommand != null) {
          test = pkgs.runCommand "test" {nativeBuildInputs = cfg.packages;} ''
            export HOME=$TMPDIR
            cp -r ${self} src
            chmod -R u+w src
            cd src
            ${cfg.testCommand}
            touch $out
          '';
        };
    };
  };
}
