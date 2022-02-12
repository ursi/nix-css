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
      no-prefix-check
      class-type;

    foldAttrs = f: init: attrs:
      foldl' f init (l.mapAttrsToList l.nameValuePair attrs);
  in
  { options =
      { at-rules =
          l.mkOption
            { type = checked-attrs [ (prefix-check "@" (attrs-of declarations)) ];
              default = {};
              description = "An attrset of @-prefixed attributes whose values contain rules.";

              example =
                { "@media (min-width: 750px)" =
                    { body =
                        { font-size = "12px";
                          margin = 0;
                        };
                    };
                };
            };

        bundle =
          l.mkOption
            { type = t.package;
              description = "A derivation containing the CSS file and all the imports.";
            };

        charset =
          l.mkOption
            { type = t.nullOr t.str;
              default = null;
            };

        classes =
          let
            make-classes = example-property: modifier:
              l.mkOption
                { type = attrs-of class-type;
                  default = {};

                  apply =
                    mapAttrs
                      (class-name:
                         let selector = modifier ".${class-name}"; in
                         mapAttrs
                           (n: v: if n == "extra-rules" then v selector else v)
                      );

                  description =
                    let
                      other-property =
                        if example-property == "low-spec" then "high-spec"
                        else "low-spec";

                      relative =
                        if example-property == "low-spec" then "lower" else "higher";
                    in
                    ''Class names and corresponding declarations, plus a syntax for @-rules, pseudo-classes and pseudo-elements, and arbitray selectors as functions of the class name. These classes have ${relative} specificity than the classes in '${other-property}'. i.e. if a low-spec class's declaration collides with a declaration from high-spec, the high-spec one takes priority.
                    '';


                  example =
                    { ${example-property} =
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
          in
          { low-spec = make-classes "low-spec" l.id;
            high-spec = make-classes "high-spec" (s: s + s);
          };

        extra-css =
          l.mkOption
            { type = t.lines;
              default = "";
              description = "Extra CSS added to the file.";
            };

        css-imports =
          { paths =
              l.mkOption
                { type = t.listOf t.path;
                  default = [];
                  description = "Paths of files that will be imported in the CSS file and included in the bundle.";
                };

            directories =
              l.mkOption
                { type =
                    t.listOf
                      (t.submodule
                         { options =
                             { path =
                                 l.mkOption
                                   { type = t.path;
                                     description = "The path of the directory that contains the files to be imported.";
                                   };

                               files =
                                 l.mkOption
                                   { type = t.listOf t.path;
                                     description = "A List of absolute paths, relative to 'path', corresponding to the paths of the files to be imported.";
                                   };
                             };
                         }
                      );

                  default = [];
                  description = "Directories and paths of files that will be imported in CSS and included in the bundle.";
                };

            urls =
              l.mkOption
                { type = t.listOf t.str;
                  default = [];
                  description = "URLs that will be imported in the CSS file.";
                };
          };

        main =
          l.mkOption
            { type = t.str;
              default = "main.css";
              description = "The name of the main CSS file.";
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
              description = "CSS rules as nix expressions, with a special syntax for @-rules.";
              example =
                { body =
                    { background = "red";

                      "@media (min-width: 750px)" =
                        { font-size = "12px";
                          margin = 0;
                        };
                    };
                };
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
              description = "CSS variables that will be added to :root, plus a syntax for @-rules";

              example =
                { red1 = "#f00000";

                  font-size =
                    { "@media (min-width: 751px)" = "16px";
                      "@media (max-width: 750px)" = "12px";
                    };
                };
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
              in (if config.charset == null then "" else ''
	        @charset "${config.charset}"
	      '') +
              ''
              ${list-to-str (a: ''@import "${a}";'') imps.urls}
              ${list-to-str (a: ''@import "${make-name a}";'') imps.paths}

              ${list-to-str
                  ({ path, files }:
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
          let
            from-classes = modifier:
              foldAttrs
                (acc: { name, value }:
                   let
                     helper = a:
                       let class-selector = modifier ".${name}"; in
                       if l.hasPrefix ":" a.name then
                         { ${class-selector + a.name} = a.value; }
                       else if a.name == "extra-rules" then
                         a.value
                       else
                         { ${class-selector}.${a.name} = a.value; };
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
                {};
          in
          l.mkMerge
            [ { ":root" =
                  l.mapAttrs'
                    (n: v: l.nameValuePair ("--" + n) v)
                    (l.filterAttrs
                       (_: v: !(isAttrs v))
                       config.variables
                    );
              }

              (from-classes l.id config.classes.low-spec)
              (from-classes (s: s + s) config.classes.high-spec)
            ];
      };
  }
