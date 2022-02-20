{ module, pkgs }:
  (pkgs.lib.evalModules
     { modules =
         [ { _module.args =
               { inherit pkgs;
                 css-lib = import ./lib.nix pkgs.lib;
               };
           }
           ./module.nix
           module
         ];
     }
  ).config
