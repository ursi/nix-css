{ inputs =
    { make-shell.url = "github:ursi/nix-make-shell/1";
      nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
      utils.url = "github:ursi/flake-utils/8";
    };

  outputs = { nixpkgs, ... }:
    { __functor = _: { system }:
        module:
          import ./.
            { inherit module;
              pkgs = nixpkgs.legacyPackages.${system};
            };
    };
}
