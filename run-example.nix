with builtins;
{ nixpkgs
, with'
}:
example:
  let
    full-example =
    ''
    with builtins;
    let
      lib = pkgs.lib;
      pkgs = import ${nixpkgs} {};
    in
    with ${with'};
    ${example}
    '';
  in
  if import (toFile "example" full-example) then null else abort example
