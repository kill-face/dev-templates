{
  description = "A Nix-flake-based C# development environment";
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
    devShells = forEachSupportedSystem ({pkgs}: {
      default = pkgs.mkShell {
        packages = [
          # ref: https://nixos.org/manual/nixpkgs/unstable/index.html#using-many-sdks-in-a-workflow
          (with pkgs.dotnetCorePackages; combinePackages [
            sdk_6_0_1xx
            sdk_8_0_1xx
          ])

          pkgs.omnisharp-roslyn
          pkgs.mono
          pkgs.msbuild
          pkgs.dotnet-ef
          pkgs.nuget-to-nix

          # Debugging / running fails without this.
          pkgs.stdenv.cc.cc.lib
          pkgs.zlib

          # Required unicode pkg for dotnet core ef tools to run migrations with localization
          pkgs.icu60
        ];

        /*
        Dynamically linked packages have to be added to LD_LIBRARY_PATH.
        When running a .NET project, you can use the below command template to determine if a link is missing:
          ❯ ldd /home/kill-face/code/workflow-armored-core/test/ScratchPad/bin/Debug/net6.0/ScratchPad
        */
        shellHook = ''
          export DOTNET_ROOT=${pkgs.dotnetCorePackages.sdk_6_0_1xx}/share/dotnet
          export MSBuildSDKsPath=$DOTNET_ROOT/sdk/6.0.136/Sdks
          export PATH="$DOTNET_ROOT/bin:$PATH"
          
          # Ensure MSBuild knows about Mono
          export MSBuildExtensionsPath=${pkgs.msbuild}/lib/mono/msbuild
          export FrameworkPathOverride=${pkgs.mono}/lib/mono/4.5
  

          # Ensure .config directory exists for local tools
          mkdir -p ./.config

          # Install dotnet-ef locally if not present
          if [ ! -f ".config/dotnet-tools.json" ]; then
            dotnet new tool-manifest
            dotnet tool install dotnet-ef
          fi

          # Add local tools to PATH
          export PATH="$PWD/.config/tools:$PATH"
          export LD_LIBRARY_PATH="${pkgs.stdenv.cc.cc.lib}/lib:${pkgs.zlib}/lib:${pkgs.icu}/lib:$LD_LIBRARY_PATH"
        '';
      };
    });
  };
}
