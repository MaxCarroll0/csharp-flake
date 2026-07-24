{
  description = "C# dev environment and standard .sln/.csproj build";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs =
    { self, nixpkgs }:
    let
      eachSystem = f: nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed (system: f system (import nixpkgs { inherit system; }));
    in
    {
      packages = eachSystem (system: pkgs: {
        fmt = pkgs.writeShellApplication {
          name = "fmt-csharp";
          runtimeInputs = [ pkgs.csharpier ];
          text = ''
            if (( $# )); then csharpier format "$@"; else csharpier format .; fi
          '';
        };

        pre-commit-hook = pkgs.writeShellScript "fmt-csharp-pre-commit" ''
          set -euo pipefail
          mapfile -t staged < <(git diff --cached --name-only --diff-filter=ACM)
          files=()
          for file in "''${staged[@]}"; do
            [[ "$file" =~ \.cs$|\.csproj$ ]] && files+=("$file")
          done
          (( ''${#files[@]} )) || exit 0
          ${self.packages.${system}.fmt}/bin/fmt-csharp "''${files[@]}"
          git add -- "''${files[@]}"
        '';
      });

      lib = eachSystem (system: pkgs: {
        mkBuild = { src, name ? "csharp-build" }:
          pkgs.stdenvNoCC.mkDerivation {
            inherit name src;
            nativeBuildInputs = [ pkgs.dotnet-sdk_8 pkgs.csharpier ];
            buildPhase = ''
              export DOTNET_CLI_HOME="$TMPDIR/dotnet"
              export NUGET_PACKAGES="$TMPDIR/nuget"
              mkdir -p "$DOTNET_CLI_HOME" "$NUGET_PACKAGES" "$out"
              csharpier format .
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
          packages = [
            pkgs.dotnet-sdk_10
            pkgs.csharp-ls
            pkgs.csharpier
            self.packages.${system}.fmt
          ];
          shellHook = ''
            if [ -d .git ] && [ ! -e .git/hooks/pre-commit ]; then
              install -m 755 ${self.packages.${system}.pre-commit-hook} .git/hooks/pre-commit
              echo "C# format pre-commit hook installed"
            fi
          '';
        };
      });

      formatter = eachSystem (system: pkgs: self.packages.${system}.fmt);
    };
}
