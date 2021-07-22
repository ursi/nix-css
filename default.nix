{ pkgs
  ? import
      (fetchTarball
         { url = "https://github.com/NixOS/nixpkgs/archive/c7e7f90108ff7bb7924e6f70136dd72c0f916954.tar.gz";
           sha256 = "0k7y9zx37jsbqf2jh8gk6l4q8qv19lpnyqhigj54llz9s5c4zszp";
         }
      )
      {}
, module
}:
  (pkgs.lib.evalModules
     { modules =
         [ { _module.args =
               { inherit pkgs;
                 css-lib = import ./lib.nix;
               };
           }
           ./module.nix
           module
         ];
     }
  ).config
