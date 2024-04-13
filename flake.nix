{
  description = "Deterministic LaTeX compilation with Nix";

  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.git-hooks.url = "github:michaelvanstraten/git-hooks.nix";

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      git-hooks,
    }:
    {
      templates.default = {
        path = ./.;
        description = "A LaTeX project";
      };

      lib.latexmk = import ./build-document.nix;
    }
    // flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };

        texlive = pkgs.texliveSmall.withPackages (
          packages: with packages; [
            comment
            latexmk
            luatex
            biblatex
            biber
          ]
        );
      in
      {
        packages = flake-utils.lib.flattenTree {
          default = import ./build-document.nix {
            inherit pkgs;
            inherit texlive;
            SOURCE_DATE_EPOCH = toString self.lastModified;
          };
        };

        checks =
          # let
          #   inherit (pkgs.lib.fileset) fileFilter toList union;
          #   inherit (builtins) concatStringsSep;
          #   find-files = ext: fileFilter (file: file.hasExt ext) ./.;
          #   latex-files = find-files "tex";
          #   markdown-files = find-files "md";
          # in
          {
            # lint =
            #   pkgs.runCommand "lint-checks"
            #     {
            #       buildInputs = with pkgs; [
            #         ltex-ls
            #       ];
            #     }
            #     ''
            #       mkdir -p "$out"
            #       ltex-cli --server-command-line=ltex-ls ${concatStringsSep " " (toList (union latex-files markdown-files))}
            #     '';
            git-hooks = git-hooks.lib.${system}.run {
              src = ./.;
              hooks = {
                # nix checks
                nixfmt = {
                  enable = true;
                  package = pkgs.nixfmt-rfc-style;
                };
                statix.enable = true;
                # LaTeX checks
                chktex.enable = true;
                latexindent.enable = true;
                lacheck.enable = true;
                # Other checks
                actionlint.enable = true;
                markdownlint.enable = true;
                prettier.enable = true;
                trim-trailing-whitespace.enable = true;
              };
            };
          };

        formatter = pkgs.nixfmt-rfc-style;

        devShells.default = pkgs.mkShell {
          inherit (self.checks.${system}.git-hooks) shellHook;
          buildInputs = [
            self.checks.${system}.git-hooks.enabledPackages
            (texlive.withPackages (
              packages: with packages; [
                latexdiff
                latexpand
                git-latexdiff
              ]
            ))
          ];
        };
      }
    );
}
