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
      { between =
          { args =
              [ { name = "lower";
                  description = "number of pixels";
                }

                { name = "upper";
                  description = "number of pixels";
                }
              ];

            returns = "a media query that appplies inclusively to widths between `lower + 1` and `upper`";

            notes =
              ''
              Meant to be used with `leq`, `gt`, and itself:

              ```
              ''${leq 600}.font-size = 16px;
              ''${between 600 700}.font-size = 20px;
              ''${between 700 800}.font-size = 24px;
              ''${gt 800}.font-size = 28px;
              ```
              '';

            examples =
              [ ''between 600 800 == "@media (min-width: 601px) and (max-width: 800px)"'' ];

            __functor = _: lower: upper: inclusive-between (lower + 1) upper;
          };

        between' =
          { args =
              [ { name = "lower";
                  description = "number of pixels";
                }

                { name = "upper";
                  description = "number of pixels";
                }
              ];

            returns = "a media query that appplies inclusively to widths between `lower` and `upper + 1`";

            notes =
              ''
              Meant to be used with `lt`, `geq`, and itself:

              ```
              ''${lt 600}.font-size = 16px;
              ''${between 600 700}.font-size = 20px;
              ''${between 700 800}.font-size = 24px;
              ''${geq 800}.font-size = 28px;
              ```
              '';

            examples =
              [ ''between' 600 800 == "@media (min-width: 600px) and (max-width: 799px)"'' ];

            __functor = _: lower: upper: inclusive-between lower (upper - 1);
          };

        inclusive-between =
          { args =
              [ { name = "lower";
                  description = "number of pixels";
                }

                { name = "upper";
                  description = "number of pixels";
                }
              ];

            returns = "a media query that appplies inclusively to widths between `lower` and `upper`";

            examples =
              [ ''inclusive-between 600 800 == "@media (min-width: 600px) and (max-width: 800px)"'' ];

            __functor = _: lower: upper:
              "@media (min-width: ${toString lower}px) and (max-width: ${toString upper}px)";
          };

        geq =
          { args =
              [ { name = "px";
                  description = "number";
                }
              ];

            returns = "a media query for widths greater than or equal to `px`";

            examples = [ ''geq 700 == "@media (min-width: 700px)"'' ];
            __functor = _: px: "@media (min-width: ${toString px}px)";
          };

        gt =
          { args =
              [ { name = "px";
                  description = "Number";
                }
              ];

            returns = "a media query for widths greater than `px`";

            examples = [ ''gt 700 == "@media (min-width: 701px)"'' ];
            __functor = _: px: geq (px + 1);
          };

        leq =
          { args =
              [ { name = "px";
                  description = "number";
                }
              ];

            returns = "a media query for widths less than or equal to `px`";

            examples = [ ''leq 700 == "@media (max-width: 700px)"'' ];
            __functor = _: px: "@media (max-width: ${toString px}px)";
          };

        lt =
          { args =
              [ { name = "px";
                  description = "number";
                }
              ];

            returns = "a media query for widths less than `px`";

            examples = [ ''lt 700 == "@media (max-width: 699px)"'' ];
            __functor = _: px: leq (px - 1);
          };
      };

    make-keyframes-names = config: mapAttrs l.const config.keyframes;

    make-var-values =
      { args =
          [ { name = "config";
              description = "The `config` attrset passed into the module";
            }
          ];

        returns = ''an attributes set containing such that `set.varname == "var(--varname)"` for each variable in your config.'';

        examples =
          [ ''(make-var-value { variables.name = "green"; }).name = "var(--name)"'' ];

        # __functor = _: config: mapAttrs (n: _: "var(--${n})") config.variables;
      };

    merge =
      { args =
          [ { name = "rules";
              description = "A set of declarations that do not have an `extra-rules` attribute";
            }
          ];

        notes =
        ''
        This is preferable to // because it'll throw an error if you have confilictin declarations.

        Allowing `extra-rules` can easily have unintended side effects, so they are prohibited in this function. If you feel you need it, you can use `${merge-allowing-extra-rules-name}`. In most cases though, you can just do the following:

        ```
        merge
          [ class1
            class2
            { ... }
          ]
        // { extra-rules = c: { ... }; }
        ```
        '';

        returns = "A set of declarations that is the combination of the arguments";

        examples =
          [ ''
            merge [ { color = "black"; } { font-size = "16px"; } ]
            == { color = black; font-size = "16px" }
            ''
          ];

        __functor = _:
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
      };

    ${merge-allowing-extra-rules-name} =
      { args =
          [ { name = "rules";
              description = "A set of declarations";
            }
          ];

        returns = "null";

        examples =
          [ ''
            ${merge-allowing-extra-rules-name} [ { color = "black"; } { font-size = "16px"; } ]
            == { color = black; font-size = "16px" }''
          ];

        __functor = _: merge-with-check (l.const true) "";
      };
  }
