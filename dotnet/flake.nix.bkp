{
  description = "A Nix-flake-based .NET development environment";
  outputs = {nixpkgs}: let
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
    in {
      default = pkgs.mkShell {
        packages = [
          combinedDotNet

          pkgs.omnisharp-roslyn
          pkgs.mono
          pkgs.msbuild
          pkgs.dotnet-ef
          pkgs.nuget-to-nix

          # Debugging / running fails without this.
          pkgs.stdenv.cc.cc.lib

          # Required for AOT compilation
          pkgs.zlib
          pkgs.zlib-ng

          # Required unicode pkg for dotnet core ef tools to run migrations with localization
          pkgs.icu60
        ];

        /*
        Dynamically linked packages have to be added to LD_LIBRARY_PATH.
        When running a .NET project, you can use the below command template to determine if a link is missing:
          ❯ ldd /path/to/project/bin/Debug/framwork_target/Project
        */
        shellHook = ''
          export DOTNET_ROOT=${combinedDotNet}/share/dotnet
          export PATH="$DOTNET_ROOT/bin:$PATH"

          # Ensure MSBuild knows about Mono
          export MSBuildExtensionsPath=${pkgs.msbuild}/lib/mono/msbuild
          export FrameworkPathOverride=${pkgs.mono}/lib/mono/4.5

          # Ensure .config directory exists for local tools
          mkdir -p ./.config

          # Add local tools to PATH
          export PATH="$PWD/.config/tools:$PATH"
          export LD_LIBRARY_PATH="${pkgs.stdenv.cc.cc.lib}/lib:${pkgs.zlib}/lib:${pkgs.icu}/lib:$LD_LIBRARY_PATH"

          ##########################
          # Optional dotnet tooling
          ##########################
          # Uncomment to install dotnet-ef locally if not present
          # if [ ! -f ".config/dotnet-tools.json" ]; then
          #   dotnet new tool-manifest
          #   dotnet tool install dotnet-ef
          # fi
        '';
      };
    });
  };
}
