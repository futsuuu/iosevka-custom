{
  description = "";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        version = "0.12.3";
        pkgs = nixpkgs.legacyPackages.${system};

        font-patcher = pkgs.stdenv.mkDerivation rec {
          pname = "font-patcher";
          version = "3.2.0";
          src = pkgs.fetchzip {
            url =
              "https://github.com/ryanoasis/nerd-fonts/releases/download/v${version}/FontPatcher.zip";
            sha256 = "sha256-gW+TQvwyb+932skNxMZ2TdbobpZ2MK1oJe+Z5IR0nkQ=";
            stripRoot = false;
          };
          installPhase = ''
            mkdir -p $out/bin
            cp ${src}/font-patcher $out/bin
          '';
        };
        privateBuildPlans = builtins.readFile ./private-build-plans.toml;
        fontPatcherInputs =
          [ pkgs.python311 pkgs.python311Packages.fontforge font-patcher ];
        iosevkaInputs = [
          pkgs.nodejs
          pkgs.ttfautohint-nox # no GUI
        ];
      in {
        devShells.default = pkgs.mkShell {
          buildInputs = [ pkgs.fontforge-gtk ] ++ fontPatcherInputs
            ++ iosevkaInputs;
        };

        packages = {
          iosevka-custom-nerdfont = pkgs.buildNpmPackage {
            inherit version;
            pname = "iosevka-custom-nerdfont";
            nativeBuildInputs = [ pkgs.fontforge ] ++ fontPatcherInputs
              ++ iosevkaInputs;
            src = pkgs.fetchgit {
              url = "https://github.com/be5invis/Iosevka.git";
              rev = "refs/tags/v29.2.1";
              hash = "sha256-WWumGi6+jaQUGi1eArS9l3G8sOQL4ZetixVB5RWDPQ4=";
            };
            npmDepsHash = "sha256-Gm3R8lWmYbLOfyGW+f8CYXlodp11vMCMAhagILxLKFA=";

            inherit privateBuildPlans;
            passAsFile = [ "privateBuildPlans" ];
            configurePhase = ''
              cp $privateBuildPlansPath private-build-plans.toml
            '';

            buildPhase = ''
              npm run build -- ttf::IosevkaCustom

              find dist/ -type f

              for file in dist/IosevkaCustom/TTF/*.ttf; do
                font-patcher \
                  --complete --adjust-line-height \
                  --quiet --outputdir patched \
                  $file
              done
            '';

            installPhase = ''
              fontdir="$out/share/fonts/ttf/IosevkaCustom Nerd Font"
              install -d $fontdir
              install patched/*.ttf $fontdir
            '';
          };

          default = self.packages.${system}.iosevka-custom-nerdfont;
        };

        formatter = pkgs.nixfmt;
      });
}
