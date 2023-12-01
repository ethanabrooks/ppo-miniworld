{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/";
    utils.url = "github:numtide/flake-utils/";
    nixgl.url = "github:guibou/nixGL";
  };

  outputs = {
    self,
    nixpkgs,
    utils,
    nixgl,
  }: let
    out = system: let
      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
        };
        overlays = [nixgl.overlay];
      };
      inherit (pkgs) poetry2nix;

      python = pkgs.python39;
      overrides = pyfinal: pyprev: rec {
        # Based on https://github.com/NixOS/nixpkgs/blob/nixos-22.11/pkgs/development/python-modules/torch/bin.nix#L107
        torch = pyprev.buildPythonPackage {
          version = "1.13.1";

          pname = "torch";
          # Don't forget to update torch to the same version.

          format = "wheel";

          src = pkgs.fetchurl {
            url = "https://download.pytorch.org/whl/cu116/torch-1.13.1%2Bcu116-cp39-cp39-linux_x86_64.whl";
            sha256 = "sha256-20V6gi1zYBO2/+UJBTABvJGL3Xj+aJZ7YF9TmEqa+sU=";
          };
        };
        torchrl = pyprev.torchrl.overridePythonAttrs (old: {
          preFixup = "addAutoPatchelfSearchPath ${pyfinal.torch}";
        });
      };
      poetryEnv = pkgs.poetry2nix.mkPoetryEnv {
        inherit python;
        projectDir = ./.;
        preferWheels = true;
        overrides = poetry2nix.overrides.withDefaults overrides;
      };

      myNixgl = pkgs.nixgl.override {
        nvidiaVersion = "535.86.05";
        nvidiaHash = "sha256-QH3wyjZjLr2Fj8YtpbixJP/DvM7VAzgXusnCcaI69ts=";
      };
    in {
      devShell = pkgs.mkShell {
        LD_LIBRARY_PATH = with pkgs; "${libGLU}/lib:${freetype}/lib";
        buildInputs = with pkgs; [
          alejandra
          ffmpeg
          myNixgl.nixGLNvidia
          poetry
          poetryEnv
        ];
        PYTHONBREAKPOINT = "ipdb.set_trace";
        shellHook = ''
          set -o allexport
          source .env
          set +o allexport
        '';
      };
    };
  in
    utils.lib.eachDefaultSystem out;
}
