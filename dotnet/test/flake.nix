{
  description = "A Nix-flake-based .NET development environment";

  outputs = {
    self,
    nixpkgs,
  }: let
    dotnetEol = ["6" "7"];
    dotnetActive = ["8" "9" "10"];
    dotnetPreview = ["11"];

    #######################################
    ### Configuration
    #######################################
    # versions of dotnet to be installed ("6", "7", "8" ...)
    dotnetIncluded = dotnetActive; # []

    # languages used in the environment ("fsharp" or "csharp")
    languages = ["fsharp" "csharp"];

    #######################################
    ### Insecure package whitelisting
    #######################################
    supportedSystems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
    forEachSupportedSystem = f:
      nixpkgs.lib.genAttrs supportedSystems (system:
        f {
          pkgs = import nixpkgs {
            inherit system;
            config = {
              allowUnfree = true;
              allowInsecurePredicate = pkg: let
                pname = pkg.pname or "";
                version = pkg.version or "";
              in
                builtins.match "dotnet-.*" pname
                != null
                && builtins.any (
                  v:
                    builtins.match "${v}\..*" version != null
                )
                dotnetEol;
            };
          };
        });
  in {
    devShells = forEachSupportedSystem ({pkgs}: let
      # picks out all dotnet core packages available for a supplied version.
      dotnetSdk = v: let
        d = pkgs.dotnetCorePackages;
      in
        d.${"sdk_${v}_0_1xx"} or d.${"sdk_${v}_0_1xx-bin"} or d.${"sdk_${v}_0-bin"};

      # ref: https://nixos.org/manual/nixpkgs/unstable/index.html#using-many-sdks-in-a-workflow
      combinedDotNet =
        pkgs.dotnetCorePackages.combinePackages
        (map dotnetSdk dotnetIncluded);

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
      ];

      fsharpToolingDeps = nixpkgs.lib.optionals (builtins.elem "fsharp" languages) [
        pkgs.fantomas
      ];

      csharpToolingDeps = nixpkgs.lib.optionals (builtins.elem "csharp" languages) [
        pkgs.omnisharp-roslyn
        pkgs.csharpier
      ];

      toolingDeps = [
        pkgs.stdenv.cc.cc
        pkgs.mono
        pkgs.msbuild

        # This is only required if dotnet packages are being built for nix consumption.
        # pkgs.nuget-to-json
      ];

      efCoreDeps = [
        # Required unicode pkg for dotnet core ef tools to run migrations with localization
        pkgs.icu60

        # dotnet tools should generally be managed by the dotnet-tools.json manifest.
        # pkgs.dotnet-ef
      ];

      allDeps = aotDeps ++ toolingDeps ++ efCoreDeps ++ [combinedDotNet] ++ fsharpToolingDeps ++ csharpToolingDeps;
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

          # Ensure dotnet tool manifest exists, then restore
          if [ ! -f "dotnet-tools.json" ]; then
            dotnet new tool-manifest
            ${nixpkgs.lib.optionalString (builtins.elem "fsharp" languages) "dotnet tool install fantomas"}
          fi
          dotnet tool restore
          export PATH="$PWD/.config/tools:$PATH"

        '';
      };
    });
  };
}
