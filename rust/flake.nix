{
  description = "A Nix-flake-based Rust development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    rust-overlay,
  }:
    flake-utils.lib.eachDefaultSystem
    (
      system: let
        overlays = [(import rust-overlay)];
        pkgs = import nixpkgs {
          inherit system overlays;
        };
        rustToolchain = pkgs.pkgsBuildHost.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;
      in {
        devShells = {
          default = pkgs.mkShell {
            packages = [
              rustToolchain
              pkgs.openssl
              pkgs.pkg-config
              pkgs.cargo-deny
              pkgs.cargo-edit
              pkgs.cargo-watch
              pkgs.rust-analyzer
            ];
          };
          env = {
            # Required by rust-analyzer
            RUST_SRC_PATH = "${pkgs.rustToolchain}/lib/rustlib/src/rust/library";
          };
        };
      }
    );
}
