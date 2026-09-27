{
  description = "Native macOS visualizer powered by projectM";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/f83fc3c307e74bc5fd5adb7eb6b8b13ffd2a36e1";
  outputs = { self, nixpkgs }:
    let
      systems = [ "aarch64-darwin" "x86_64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in {
      devShells = forAllSystems (system:
        let pkgs = import nixpkgs { inherit system; };
        in { default = pkgs.mkShell {
          packages = [ pkgs.cmake pkgs.ninja pkgs.pkg-config ];
          buildInputs = [ pkgs.apple-sdk_15 ];
          shellHook = ''
            export CC="${pkgs.stdenv.cc}/bin/clang"
            export CXX="${pkgs.stdenv.cc}/bin/clang++"
            export OBJC="$CC"
            export OBJCXX="$CXX"
          '';
        }; });
    };
}
