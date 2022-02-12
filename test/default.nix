with builtins;
let
  l = p.lib;

  p =
    import
      (fetchTarball
         { url = "https://github.com/NixOS/nixpkgs/archive/c7e7f90108ff7bb7924e6f70136dd72c0f916954.tar.gz";
           sha256 = "0k7y9zx37jsbqf2jh8gk6l4q8qv19lpnyqhigj54llz9s5c4zszp";
         }
      )
      {};

  log = a: trace a a;
in
rec
{ bundle = (import ../.  { module = ./css.nix; }).bundle;

  formatted =
    p.runCommand "test.css" {}
      ''
      ${p.nodePackages.prettier}/bin/prettier \
        ${(import ../.  { module = ./css.nix; }).bundle}/main.css \
        > $out
      '';

  test =
   let
     is-equal = p1: p2:
       ''
       if ! cmp -s ${p1} ${p2}; then
         diff ${p1} ${p2}
       fi
       '';

     font-path = "${bundle}/69f6s1ak9samjr5b4v3mqiajg6yzp3z4-font/font.css";
     style-path = "${bundle}/aqq6w72fabwzhlfcdyavnrl4vib27fmy-style.css";
   in
   p.runCommand "test" {}
    ''
    ${is-equal style-path ./style.css}
    ${is-equal font-path ./font/font.css}
    ${is-equal formatted ./test.css}

    touch $out
    '';
}
