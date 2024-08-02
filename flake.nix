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
        nerd-fonts-version = "3.2.1";
        iosevka-version = "31.0.0";
        pkgs = nixpkgs.legacyPackages.${system};

        nerd-font-patcher = pkgs.nerd-font-patcher.overrideAttrs (prev: rec {
          version = nerd-fonts-version;
          src = pkgs.fetchzip {
            url =
              "https://github.com/ryanoasis/nerd-fonts/releases/download/v${version}/FontPatcher.zip";
            sha256 = "sha256-gW+TQvwyb+932skNxMZ2TdbobpZ2MK1oJe+Z5IR0nkQ=";
            stripRoot = false;
          };
        });
        privateBuildPlans = builtins.readFile ./private-build-plans.toml;
      in {
        packages = {
          iosevka-custom-nerdfont = pkgs.buildNpmPackage {
            inherit version;
            pname = "iosevka-custom-nerdfont";
            nativeBuildInputs = [
              nerd-font-patcher
              pkgs.nodejs
              pkgs.ttfautohint-nox
              pkgs.fontforge
            ];
            src = pkgs.fetchgit {
              url = "https://github.com/be5invis/Iosevka.git";
              rev = "refs/tags/v${iosevka-version}";
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

              for file in dist/IosevkaCustom/TTF/*.ttf; do
                nerd-font-patcher \
                  --complete --adjust-line-height \
                  --quiet --outputdir patched \
                  $file
              done
            '';

            installPhase = ''
              fontdir="$out/share/fonts/ttf/IosevkaCustom Nerd Font"
              install -d "$fontdir"
              install patched/*.ttf "$fontdir"
            '';
          };

          default = self.packages.${system}.iosevka-custom-nerdfont;
        };

        formatter = pkgs.nixfmt;
      });
}
