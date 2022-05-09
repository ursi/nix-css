{ inputs =
    { deadnix.url = "github:astro/deadnix";
      doc-gen.url = "path:/home/mason/git/nix-doc-gen";
      make-shell.url = "github:ursi/nix-make-shell/1";
      nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
      utils.url = "github:ursi/flake-utils/8";
    };

  outputs = { nixpkgs, utils, ... }@inputs:
    with builtins;
    { __functor = _: { system }:
        module:
          import ./.
            { inherit module;
              pkgs = nixpkgs.legacyPackages.${system};
            };
    }
    // (utils.apply-systems { inherit inputs; }
          ({ deadnix, make-shell, doc-gen, pkgs, ... }:
             let l = p.lib; p = pkgs; in
             { devShell =
                 make-shell
                   { packages = [ deadnix ];
                     aliases.lint = ''find -name "*.nix" | xargs deadnix'';
                   };

               packages.docs =
                 let
                   l = p.lib ;p = pkgs;
                   example-strings = import ./example-strings.nix;

                   options =
                     (l.evalModules
                        { modules =
                            [ { _module.args = { inherit pkgs; }; }
                              ./module.nix
                            ];
                        }
                     ).options;

                   tuple = fst: snd: { inherit fst snd; };

                   flatten =
                     let
                       f = path-so-far: attrset:
                         foldl'
                           (acc: { path, value }:
                              let
                                escaped = l.strings.escapeNixIdentifier path;
                                return = acc ++ [ (tuple (path-so-far + escaped) value) ];
                              in
                              if l.hasPrefix "_" path then
                                acc
                              else if isAttrs value then
                                if value?_type then
                                  return
                                else
                                  acc ++ f (path-so-far + escaped + ".") value
                              else
                                return)
                           []
                           (l.mapAttrsToList
                              (path: value: { inherit path value; })
                              attrset);
                     in
                     f "";

                   something =
                     foldl'
                       (acc: { fst, snd }:
                         if l.hasPrefix "classes" fst then
                           if fst == ''classes."1"'' then
                             acc
                             // { ${fst} =
                                    ''
                                    ${fst}: (also classes."2", ... classes."9")
                                    ${snd.description or ":("}
                                    type: ${snd.type.description}
                                    ${if snd?default
                                      then "default: ${toJSON snd.default}"
                                      else ""
                                    }

                                    example:
                                    ${example-strings.${fst} or ":("}
                                    '';
                                }
                           else
                             acc
                         else
                           acc
                           // { ${fst} =
                                  ''
                                  ${fst}:
                                  ${snd.description or ":("}
                                  type: ${snd.type.description}
                                  ${if snd?default
                                    then "default: ${toJSON snd.default}"
                                    else ""
                                  }

                                  example:
                                  ${example-strings.${fst} or ":("}
                                  '';
                              }
                       )
                       {}
                       (flatten options);
                 in
                 doc-gen.options { inherit options; };

               packages.lib-docs = doc-gen (import ./lib.nix pkgs.lib);

               # packages.docs' =
               #   (l.evalModules
               #      { modules =
               #          [ { _module.args = { inherit pkgs; }; }
               #            ./module.nix
               #          ];
               #      }
               #   ).options;
             }
          )
       );
}
