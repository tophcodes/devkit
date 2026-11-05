# The flake-parts module every project imports. It provides the dev shell,
# treefmt with formatters and linters, and the checks behind `just check`.
{localInputs}: {
  self,
  lib,
  ...
}: {
  imports = [localInputs.treefmt-nix.flakeModule];

  systems = lib.mkDefault ["x86_64-linux" "aarch64-linux"];

  perSystem = {
    config,
    lib,
    pkgs,
    system,
    ...
  }: let
    cfg = config.devkit;
    requiredRecipes = ["default" "dev" "test" "fmt" "check"];
    prose-check = localInputs.self.packages.${system}.prose-check;

    # typos knows only English. German words its dictionary maps to an English
    # correction are allowed here; a repository adds its own in `_typos.toml`,
    # which is merged over this base.
    typosBase.default.extend-words = {
      als = "als";
      ein = "ein";
      Geometrie = "Geometrie";
      ist = "ist";
      legt = "legt";
      vor = "vor";
    };
    typosLocal = self + "/_typos.toml";
    typosConfig =
      (pkgs.formats.toml {}).generate "typos.toml" (lib.recursiveUpdate typosBase
        (lib.optionalAttrs (builtins.pathExists typosLocal) (lib.importTOML typosLocal)));
  in {
    options.devkit = {
      fixtures = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = ["**/testdata/**" ".prose-check/**"];
        description = "Globs of files that contain bad text on purpose, such as linter fixtures. The prose check and typos skip them.";
      };
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
        programs = {
          alejandra.enable = true;
          deadnix.enable = true;
          statix.enable = true;
          shellcheck.enable = true;
          typos = {
            enable = true;
            # Reports only: the corrections are English and would rewrite German words.
            autoFix = false;
            configFile = toString typosConfig;
            # Encrypted secrets are random text to typos.
            excludes = cfg.fixtures ++ ["*.age"];
          };
        };
      };

      devShells.default = pkgs.mkShell {
        packages =
          [
            pkgs.just
            pkgs.watchexec
            config.treefmt.build.wrapper
            prose-check
          ]
          ++ cfg.packages;
      };

      checks =
        {
          # Fails on error-level alerts only; warnings are for the writer, not the gate.
          prose = pkgs.runCommand "prose" {nativeBuildInputs = [prose-check];} ''
            export HOME=$TMPDIR
            cd ${self}
            prose-check --minAlertLevel=error \
              --glob='!{${lib.concatStringsSep "," cfg.fixtures}}' .
            touch $out
          '';

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
