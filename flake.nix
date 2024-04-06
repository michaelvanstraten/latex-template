{
  description = "Deterministic LaTeX compilation with Nix";

  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
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
        devShells.default = pkgs.mkShell {
          buildInputs = [
            latex-packages
            dev-packages
          ];
        };

        packages = flake-utils.lib.flattenTree {
          default = import ./build-document.nix {
            inherit pkgs;
            texlive = latex-packages;
            shellEscape = true;
            minted = true;
            SOURCE_DATE_EPOCH = toString self.lastModified;
          };
        };

        formatter = pkgs.nixfmt-rfc-style;

        checks =
          let
            inherit (pkgs.lib.fileset) fileFilter toList union;
            inherit (builtins) concatStringsSep;
            find-files = ext: fileFilter (file: file.hasExt ext) ./.;
            nix-files = find-files "nix";
            latex-files = find-files "tex";
            markdown-files = find-files "md";
          in
          {
            fmt =
              pkgs.runCommand "fmt-checks"
                {
                  buildInputs = with pkgs; [
                    latex-packages
                    nixfmt-rfc-style
                  ];
                }
                ''
                  # We *must* create some output, usually contains test logs for checks
                  mkdir -p "$out"

                  nixfmt --check ${concatStringsSep " " (toList nix-files)} 
                  latexindent -check ${concatStringsSep " " (toList latex-files)} 
                '';
            lint =
              pkgs.runCommand "lint-checks"
                {
                  buildInputs = with pkgs; [
                    latex-packages
                    ltex-ls
                  ];
                }
                ''
                  mkdir -p "$out"

                  chktex ${concatStringsSep " " (toList latex-files)} 
                  echo \'${concatStringsSep " " (toList latex-files)}\' | xargs lacheck
                  ltex-cli --server-command-line=ltex-ls ${concatStringsSep " " (toList (union latex-files markdown-files))}
                '';
          };
      }
    );
}
