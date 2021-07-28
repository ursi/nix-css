with builtins;
lib:
  let
    l = lib;

    merge-with-check = check: error-msg: classes:
      if check classes then
        (import ./types.nix lib).class-type.merge []
          (map (c: { value = c; file = "unknown"; }) classes)
      else
        abort error-msg;

    merge-allowing-extra-rules-name = "merge-all";
  in
  { media =
      rec
      { between = lower: upper: inclusive-between (lower + 1) upper;
        between' = lower: upper: inclusive-between lower (upper - 1);

        inclusive-between = lower: upper:
          "@media (min-width: ${toString lower}px) and (max-width: ${toString upper}px)";

        geq = px: "@media (min-width: ${toString px}px)";
        gt = px: geq (px + 1);
        lt = px: leq (px - 1);
        leq = px: "@media (max-width: ${toString px}px)";
      };

    make-var-values = mapAttrs (n: _: "var(--${n})");

    merge =
      merge-with-check
        (all (a: !a?extra-rules))
        ''
        You are trying to merge classes that define `extra-rules`. This is not allowed by default, as it can easily have unintended side effects if you're not careful. To get around this, you can use the function `css-lib.${merge-allowing-extra-rules-name}`. However, if you only need to merge classes without `extra-rules` into an attribute set literal that has `extra-rules`, it is recommended that you do the following:

            merge
              [ class1
                class2
                { ... }
              ]
            // { extra-rules = c: { ... }; }
        '';

    ${merge-allowing-extra-rules-name} = merge-with-check (l.const true) "";
  }
