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
        iosevkaInputs = [ pkgs.nodejs pkgs.ttfautohint-nox ];
        nerdfontsInputs = [ font-patcher self.packages.iosevka-custom ];

        privateBuildPlans = builtins.readFile ./private-build-plans.toml;
      in {
        devShells.default = pkgs.mkShell { buildInputs = [ pkgs.nodejs ]; };
        packages = {
          iosevka-custom = pkgs.buildNpmPackage {
            inherit version;
            pname = "iosevka-custom";
            nativeBuildInputs = iosevkaInputs;
            src = pkgs.fetchgit {
              url = "https://github.com/be5invis/Iosevka.git";
              rev = "refs/tags/v29.2.1";
              hash = "sha256-Ir/HS9MFqOO7CDDLnqFX+6vCg06U5cYAcNKFyh5Ioc8=";
            };
            npmDepsHash = "sha256-tzrMAZv1ATYwPVBUiDm4GPVj+TVAA3hMdc3MrdblOIw=";

            inherit privateBuildPlans;
            passAsFile = [ "privateBuildPlans" ];
            configurePhase = ''
              cp $privateBuildPlansPath private-build-plans.toml
            '';

            buildPhase = ''
              npm run build -- ttf::IosevkaCustom
            '';

            installPhase = ''
              fontdir="$out/share/fonts/ttf/IosevkaCustom"
              install -d $fontdir
              install dist/IosevkaCustom/TTF/*.ttf $fontdir
            '';
          };

          iosevka-custom-nerdfonts = pkgs.mkDerivation {
            inherit version;
            pname = "iosevka-custom-nerdfonts";
            nativeBuildInputs = nerdfontsInputs;

            buildPhase = ''
              # for file in dist/IosevkaCustom/TTF/*.ttf; do
              #   fontforge \
              #     -script $(which font-patcher) \
              #     --complete --adjust-line-height \
              #     --quiet --outputdir font \
              #     $file
              # done
            '';

            installPhase = "";
          };

          default = self.packages.${system}.iosevka-custom-nerdfonts;
        };

        formatter = pkgs.nixfmt;
      });
}
