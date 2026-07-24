{
  description = "C# dev environment and standard .sln/.csproj build";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs =
    { self, nixpkgs }:
    let
      eachSystem = f: nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed (system: f system (import nixpkgs { inherit system; }));
    in
    {
      lib = eachSystem (system: pkgs: {
        mkBuild = { src, name ? "csharp-build" }:
          pkgs.stdenvNoCC.mkDerivation {
            inherit name src;
            nativeBuildInputs = [ pkgs.dotnet-sdk_8 ];
            buildPhase = ''
              export DOTNET_CLI_HOME="$TMPDIR/dotnet"
              export NUGET_PACKAGES="$TMPDIR/nuget"
              mkdir -p "$DOTNET_CLI_HOME" "$NUGET_PACKAGES" "$out"
              target=$(find . -name '*.sln' -print -quit)
              test -n "$target" || target=$(find . -name '*.csproj' -print -quit)
              test -n "$target" || { echo 'No .sln or .csproj found' >&2; exit 1; }
              dotnet build "$target" -c Release
              find . -type f -path '*/bin/Release/*' -exec cp --parents {} "$out" \;
            '';
            installPhase = "true";
          };
      });

      devShells = eachSystem (system: pkgs: {
        default = pkgs.mkShell {
          packages = [ pkgs.dotnet-sdk_10 pkgs.csharp-ls ];
        };
      });

      formatter = eachSystem (system: pkgs: pkgs.nixfmt-rfc-style);
    };
}
