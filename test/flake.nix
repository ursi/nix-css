{ inputs.get-flake.url = "github:ursi/get-flake";

  outputs = { get-flake, ... }:
    let
      nix-css = get-flake ../.;
      inputs = nix-css.inputs // { inherit nix-css; };
    in
    inputs.utils.apply-systems { inherit inputs; }
      ({ make-shell, nix-css, pkgs, ... }:
         let p = pkgs; in
         rec
         { defaultPackage =
             let
               is-equal = p1: p2:
                 ''
                 if ! cmp -s ${p1} ${p2}; then
                   diff ${p1} ${p2}
                 fi
                 '';

               font-path =
                 "${packages.bundle}/67b0kyg2p3wbj6xx43hn8kmc6s7da00b-font/font.css";

               style-path =
                 "${packages.bundle}/a548jysrhrkdrsz2dwa9gzjn5znqpms7-style.css";
             in
             p.runCommand "test" {}
              ''
              ${is-equal style-path ./style.css}
              ${is-equal font-path ./font/font.css}
              ${is-equal packages.formatted ./test.css}

              touch $out
              '';

           packages =
             rec
             { inherit (nix-css ./css.nix) bundle;

               formatted =
                 p.runCommand "test.css" {}
                   "${p.nodePackages.prettier}/bin/prettier ${bundle}/main.css > $out";
             };

           devShell =
             make-shell
               { aliases.overwrite-test = "nix build .#formatted; cp result test.css"; };
         }
      );
}
