{
  description = "A Nix-flake-based .NET development environment";
  outputs = {
    self,
    nixpkgs,
  }: let
    supportedSystems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
    forEachSupportedSystem = f:
      nixpkgs.lib.genAttrs supportedSystems (system:
        f {
          pkgs = import nixpkgs {
            inherit system;
            config = {
              allowUnfree = true;
              permittedInsecurePackages = [
                "dotnet-sdk-6.0.136"
                "dotnet-runtime-6.0.36"
                "dotnet-sdk-6.0.428"
              ];
            };
          };
        });
  in {
    devShells = forEachSupportedSystem ({pkgs}: let
      # ref: https://nixos.org/manual/nixpkgs/unstable/index.html#using-many-sdks-in-a-workflow
      combinedDotNet = with pkgs.dotnetCorePackages;
        combinePackages [
          sdk_6_0_1xx
          sdk_8_0_1xx
          sdk_9_0_1xx
        ];

      # ref: https://nixos.wiki/wiki/DotNET
      aotDeps = [
        # Not all of these are listed as dependencies in the wiki, but I was receiving various failures
        # when compiling against different targets frameworks (8, 9) without all the below.
        # gcc seems to be a requirement for 8, but not 9.
        pkgs.zlib
        pkgs.zlib.dev
        pkgs.openssl
        pkgs.icu
        pkgs.gcc
        pkgs.stdenv.cc.cc
        combinedDotNet
      ];

      toolingDeps = [
        pkgs.stdenv.cc.cc
        pkgs.omnisharp-roslyn
        pkgs.mono
        pkgs.msbuild
        pkgs.nuget-to-nix
      ];

      efCoreDeps = [
        # Required unicode pkg for dotnet core ef tools to run migrations with localization
        pkgs.dotnet-ef
        pkgs.icu60
      ];

      allDeps = aotDeps ++ toolingDeps ++ efCoreDeps ++ [combinedDotNet];
    in {
      default = pkgs.mkShell {
        packages = allDeps;
        nativeBuildInputs = [] ++ aotDeps;

        NIX_LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath (
          []
          ++ aotDeps
        );
        LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath (
          []
          ++ aotDeps
        );
        NIX_LD = "${pkgs.stdenv.cc.libc_bin}/bin/ld.so";

        /*
        Dynamically linked packages have to be added to LD_LIBRARY_PATH.
        When running a .NET project, you can use the below command template to determine if a link is missing:
          ❯ ldd executable/file/path
        */
        shellHook = ''
          export DOTNET_ROOT=${combinedDotNet}/share/dotnet
          export PATH="$DOTNET_ROOT/bin:$PATH"

          # Ensure MSBuild knows about Mono
          export MSBuildExtensionsPath=${pkgs.msbuild}/lib/mono/msbuild
          export FrameworkPathOverride=${pkgs.mono}/lib/mono/4.5

          echo "${pkgs.stdenv.cc.libc_bin}/bin/ld.so"

          # Ensure .config directory exists for local tools
          mkdir -p ./.config

          # Install dotnet-ef locally if not present
          # if [ ! -f ".config/dotnet-tools.json" ]; then
          #   dotnet new tool-manifest
          #   dotnet tool install dotnet-ef

          #   # Add local tools to PATH
          #   export PATH="$PWD/.config/tools:$PATH"
          # fi

        '';
      };
    });
  };
}
