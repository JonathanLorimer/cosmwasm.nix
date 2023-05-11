{
  description = "cosmwasm.nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rustOverlay.url = "github:oxalica/rust-overlay";
    cosmos.url = "github:informalsystems/cosmos.nix/romac/wasmd-0.40";
    crane.url = "github:ipetkov/crane";
    cosmwasm-src = {
      url = "github:CosmWasm/cosmwasm";
      flake = false;
    };
    # TODO: add nixos test that spins up a cosmwasm chain and uploads a contract via wasmd
    # cw-plus-src = {
    #   url = "github:CosmWasm/cw-plus";
    #   flake = false;
    # };
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    rustOverlay,
    crane,
    cosmos,
    cosmwasm-src,
  }:
    flake-utils.lib.eachSystem
      [ "x86_64-linux"
        "aarch64-linux"
        "x86-64-darwin"
        "aarch64-darwin"
      ]
      (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [
              (import rustOverlay)
            ];
          };

          rustToolchain = pkgs.rust-bin.selectLatestNightlyWith (toolchain:
            toolchain.default.override {
              targets = ["wasm32-unknown-unknown"];
            });

          craneLib = crane.lib.${system}.overrideToolchain rustToolchain;

          crateNameFromCargoToml = packageName: craneLib.crateNameFromCargoToml {cargoToml = "${cosmwasm-src}/packages/${packageName}/Cargo.toml";};

          cosmwasm-check = craneLib.buildPackage {
            inherit (crateNameFromCargoToml "check") pname version;
            src = cosmwasm-src;
            cargoExtraArgs = "-p cosmwasm-check";
            nativeBuildInputs = [ pkgs.pkg-config ];
            PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig";
          };

        in {
          checks = {};

          formatter = pkgs.alejandra;

          packages = {
            inherit cosmwasm-check;
          };

          apps = {
            cosmwasm-check = {
              type = "app";
              program = "${self.packages.${system}.cosmwasm-check}/bin/cosmwasm-check";
            };
          };

          devShells.default = pkgs.mkShell {
            nativeBuildInputs = with pkgs; [
              binaryen
              rustToolchain
              cosmwasm-check
              cosmos.packages.${system}.wasmd_next
            ];
          };
        });
}
