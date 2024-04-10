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

        latex-packages = with pkgs; [
          (texlive.combine {
            inherit (texlive)
              scheme-medium
              framed
              titlesec
              cleveref
              multirow
              wrapfig
              tabu
              threeparttable
              threeparttablex
              makecell
              environ
              biblatex
              biber
              fvextra
              upquote
              catchfile
              xstring
              csquotes
              minted
              dejavu
              comment
              footmisc
              xltabular
              ltablex
              ;
          })
          which
          python39Packages.pygments
        ];

        dev-packages = with pkgs; [
          texlab
          zathura
          wmctrl
        ];
      in
      {
        packages = flake-utils.lib.flattenTree {
          default = import ./build-document.nix {
            inherit pkgs;
            texlive = latex-packages;
            shellEscape = true;
            minted = true;
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
            #         latex-packages
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
                # LaTeX checks
                chktex.enable = true;
                latexindent.enable = true;
                lacheck.enable = true;
              };
            };
          };

        formatter = pkgs.nixfmt-rfc-style;

        devShells.default = pkgs.mkShell {
          inherit (self.checks.${system}.git-hooks) shellHook;
          buildInputs = [
            self.checks.${system}.git-hooks.enabledPackages
            latex-packages
            dev-packages
          ];
        };
      }
    );
}
