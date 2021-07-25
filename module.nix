with builtins;
{ config, lib, pkgs, ... }:
  let
    l = lib; p = pkgs; t = l.types;

    inherit (import ./types.nix lib)
      attrs-of
      css-value
      declarations
      extra-rules-type
      checked-attrs
      prefix-check
      no-prefix-check;

    foldAttrs = f: init: attrs:
      foldl' f init (l.mapAttrsToList l.nameValuePair attrs);
  in
  { options =
      { at-rules =
          l.mkOption
            { type = checked-attrs [ (prefix-check "@" (attrs-of declarations)) ];
              default = {};
            };

        bundle = l.mkOption { type = t.package; };

        charsets =
          l.mkOption
            { type = t.listOf t.str;
              default = [];
            };

        classes =
          l.mkOption
            { type =
                let
                  checks =
                    [ { description = ''doesn't start with ":" or "@"'';
                        check = n: !(l.hasPrefix ":" n || l.hasPrefix "@" n);
                        type = css-value;
                      }

                      (prefix-check ":" declarations)
                    ];
                in
                attrs-of
                  (checked-attrs
                     ([ (prefix-check "@" (checked-attrs checks))

                        { description = ''"extra-rules"'';
                          check = n: n == "extra-rules";
                          type = extra-rules-type;
                        }
                      ]
                      ++ checks
                     )
                  );

              default = {};

              apply =
                mapAttrs
                  (class-name:
                     let selector = "." + class-name; in
                     mapAttrs (n: v: if n == "extra-rules" then v selector else v)
                  );

              example =
                { classes =
                    { c1 =
                        { background = "red";
                          ":hover".background = "blue";

                          "@media (min-width: 1000px)" =
                            { display = "flex";
                              ":hover".background = "green";
                            };

                          extra-rules = c:
                            { "${c} > svg" =
                                { fill = "blue";
                                  ${mobile}.width = "10px";
                                };
                            };
                        };

                      c2.color = "purple";
                    };
                };
            };

        extra-css =
          l.mkOption
            { type = t.lines;
              default = "";
            };

        css-imports =
          { paths =
              l.mkOption
                { type = t.listOf t.path;
                  default = [];
                };

            directories =
              l.mkOption
                { type =
                    t.listOf
                      (t.submodule
                         { options =
                             { path = l.mkOption { type = t.path; };

                               files =
                                 l.mkOption
                                   { type = t.listOf t.path;
                                     description = "list of absolute paths corresponding to the paths of the files to be imported, if this directory is root";
                                   };
                             };
                         }
                      );

                  default = [];
                };

            urls =
              l.mkOption
                { type = t.listOf t.str;
                  default = [];
                };
          };

        main =
          l.mkOption
            { type = t.str;
              default = "main.css";
            };

        rules =
          l.mkOption
            { type =
                attrs-of
                  (checked-attrs
                     [ (no-prefix-check "@" css-value)
                       (prefix-check "@" declarations)
                     ]
                  );

              default = {};
            };

        variables =
          l.mkOption
            { type =
                attrs-of
                  (t.either
                     css-value
                     (checked-attrs [ (prefix-check "@" css-value) ])
                  );

              default = {};
            };
      };

    config =
      { at-rules =
          l.recursiveUpdate
            (foldAttrs
                  (acc: { name, value }:
                     l.recursiveUpdate acc
                       (foldAttrs
                          (acc': a:
                             acc' // { ${a.name}.":root".${"--" + name} = a.value; }
                          )
                          {}
                          value
                       )
                  )
                  {}
                  (l.filterAttrs (_: isAttrs) config.variables)
            )
            (foldAttrs
               (acc: { name, value }:
                  l.recursiveUpdate acc
                    (foldAttrs
                       (acc': a:
                          if l.hasPrefix "@" a.name then
                            l.recursiveUpdate acc' { ${a.name}.${name} = a.value; }
                          else
                            acc'
                       )
                       {}
                       value
                    )
               )
               {}
               config.rules
            );

        bundle =
          let
            imps = config.css-imports;
            list-to-str = f: list: concatStringsSep "\n" (map f list);

            make-name = path:
              baseNameOf
                (p.runCommand (baseNameOf path) {} "ln -s ${path} $out");

            css =
              let
                set-to-str = f: set: concatStringsSep "\n" (l.mapAttrsToList f set);

                make-rule = rule: dec-set:
                  if dec-set != {} then
                    ''
                    ${rule} {
                      ${set-to-str (n: v: "${n}: ${toString v};") dec-set}
                    }
                    ''
                  else
                    "";

                set-to-rules = set-to-str make-rule;
              in
              ''
              ${list-to-str (a: ''@charset "${a}";'') config.charsets}
              ${list-to-str (a: ''@import "${a}";'') imps.urls}
              ${list-to-str (a: ''@import "${make-name a}";'') imps.paths}

              ${list-to-str
                  ({ path, files}:
                     list-to-str (a: ''@import "${make-name path}${toString a}";'') files
                  )
                  imps.directories
              }

              ${set-to-rules
                  (mapAttrs (_: l.filterAttrs (_: v: !(isAttrs v))) config.rules)
              }

              ${set-to-str
                  (n: v:
                     ''
                     ${n} {
                       ${set-to-rules v}
                     }
                     ''
                  )
                  (config.at-rules)
              }

              ${config.extra-css}
              '';
          in
          p.runCommand "css" {}
            ''
            mkdir $out; cd $out

            ${list-to-str
                (p: "ln -s ${p} ${make-name p}")
                imps.paths
            }

            ${list-to-str
                (d: "ln -s ${d.path} ${make-name d.path}")
                imps.directories
            }

            ln -s ${p.writeText config.main css} ${config.main}
            '';

        rules =
          l.recursiveUpdate
            { ":root" =
                l.mapAttrs'
                  (n: v: l.nameValuePair ("--" + n) v)
                  (l.filterAttrs
                     (_: v: !(isAttrs v))
                     config.variables
                  );
            }
            (foldAttrs
               (acc: { name, value }:
                  let
                    helper = a:
                      if l.hasPrefix ":" a.name then
                        { ${"." + name + a.name} = a.value; }
                      else if a.name == "extra-rules" then
                        a.value
                      else
                        { ${"." + name}.${a.name} = a.value; };
                  in
                  l.recursiveUpdate acc
                    (foldAttrs
                       (acc': a:
                          l.recursiveUpdate acc'
                            (if l.hasPrefix "@" a.name then
                               foldAttrs
                                 (acc'': b:
                                    l.recursiveUpdate acc''
                                      (mapAttrs (_: v: { ${a.name} = v; }) (helper b))
                                 )
                                 {}
                                 a.value
                             else
                               helper a
                            )
                       )
                       {}
                       value
                    )
               )
               {}
               config.classes
            );
      };
  }
