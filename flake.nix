{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    flake-utils.url = "github:numtide/flake-utils";

    logc-src = {
      url = "github:rxi/log.c";
      flake = false;
    };
  };

  outputs = {
    nixpkgs,
    flake-utils,
    logc-src,
    self,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {inherit system;};
      runBearMake = pkgs.writeShellScript "bear" ''
        exec ${pkgs.bear}/bin/bear -- make clean all
      '';
    in {
      devShells.default = pkgs.mkShell {
        nativeBuildInputs = with pkgs; [
          bats
          bear
          criterion
          gcc
          gnumake
          self.packages.${system}.logc
          shfmt
        ];
        shellHook = ''
          ${runBearMake}
        '';
      };
      apps = {
        runBearMake = {
          type = "app";
          program = "${runBearMake}";
        };
        runTests = {
          type = "app";
          program = "${pkgs.writeShellApplication {
            name = "mydns-tests";
            runtimeInputs = with pkgs; [
              gcc
              gnumake
            ];
            text = ''
              set -euo pipefail
              make
              echo "Running tests..."
            '';
          }}/bin/mydns-tests";
        };
      };
      packages = rec {
        default = mydns;

        format-fix = pkgs.writeShellApplication {
          name = "mydns-format-fix";
          runtimeInputs = with pkgs; [alejandra clang-tools fd shfmt];
          text = ''
            set -euo pipefail
            root="$(git rev-parse --show-toplevel)"

            echo "Formatting Nix files formatting with alejandra..."
            alejandra "$root"

            echo "Formatting Shell files formatting with shfmt..."
            shfmt -i 2 -w -d "$root"

            echo "Formatting C/C++ files with clang-format..."
            fd . "$root" --extension cpp --extension hpp --extension c --extension h -X clang-format -i
          '';
        };

        format-check = pkgs.writeShellApplication {
          name = "mydns-format-check";
          runtimeInputs = with pkgs; [alejandra clang-tools fd shfmt];
          text = ''
            set -euo pipefail
            root="$(git rev-parse --show-toplevel)"

            echo "Checking Nix files formatting with alejandra..."
            alejandra --check "$root"

            echo "Checking Shell files formatting with shfmt..."
            shfmt -i 2 -w -d "$root"

            echo "Checking C/C++ files formatting with clang-format..."
            fd . "$root" --extension cpp --extension hpp --extension c --extension h \
              -X clang-format --dry-run --Werror
          '';
        };

        gitlint = pkgs.writeShellApplication {
          name = "mydns-gitlint-check";
          runtimeInputs = [pkgs.gitlint];
          text = ''
            #!/usr/bin/env bash
            set -euo pipefail
            exec gitlint --config ./.gitlint --commits "origin/main..HEAD" "$@"
          '';
        };

        logc = pkgs.stdenv.mkDerivation {
          pname = "log-c";
          version = "unstable-2020-06-20";

          src = logc-src;

          dontConfigure = true;
          buildPhase = ''
            CFLAGS=""
            $CC -O2 -fPIC \
              -DLOG_USE_COLOR \
              -c src/log.c -o log.o

            ar rcs liblog.a log.o
          '';
          installPhase = ''
            mkdir -p $out/include $out/lib
            cp src/log.h $out/include/
            cp liblog.a $out/lib/
          '';

          meta = with pkgs.lib; {
            description = "A simple logging library implemented in C99";
            homepage = "https://github.com/rxi/log.c";
            license = licenses.mit;
            platforms = platforms.all;
          };
        };

        mydns = pkgs.stdenv.mkDerivation {
          name = "mydns";
          src = ./.;
          buildInputs = with pkgs; [gcc gnumake logc];
          nativeBuildInputs = [];
          buildPhase = ''
            make
          '';
          installPhase = ''
            mkdir -p $out/bin
            cp main.out $out/bin/mydns
          '';
        };
      };
    });
}
