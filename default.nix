with builtins;
{ config, lib, pkgs, ... }:
  let
    l = lib; p = pkgs; t = l.types;

    foldAttrs = f: init: attrs:
      foldl' f init
        (l.mapAttrsToList l.nameValuePair attrs);
  in
  { options =
      let
        css-value =
          let atom = t.oneOf [ t.str t.int t.float ]; in
          t.either atom (t.listOf atom);

        css-properties = t.attrsOf css-value;

        extra-rules-type =
          l.mkOptionType
            { name = "extra-rules-type";
              description = "function from string to ${css-properties.description}";

              check = f:
                if isFunction f then
                  css-properties.check (f "")
                else
                  false;

              merge = l.mergeEqualOption;
            };

        checked-attrs = checks:
          l.mkOptionType
            { name = "checked-attrs";
              description =
                ''
                attribute set allowing the following attribute-value pairs:
                ${concatStringsSep "\n"
                    (map
                       (a:
                          ''
                          name: ${a.description}
                          type: ${a.type.description}
                          ''
                       )
                       checks
                    )
                }
                '';

              check = attrs:
                isAttrs attrs
                && all
                     ({ name, value }:
                        any (a: a.check name && a.type.check value) checks
                     )
                     (l.mapAttrsToList l.nameValuePair attrs);

              merge = loc: defs:
                let
                                   # because of file'd-values
                  get-type = name: { value, ... }:
                    l.mapNullable
                      (a: a.type)
                      (l.findFirst (c: c.check name && c.type.check value) null checks);

                  file'd-values =
                    map
                      ({ file, value }:
                         mapAttrs (_: v: { inherit file; value = v; }) value
                      )
                      defs;

                 in
                 l.zipAttrsWith
                   (name: values:
                      let type = get-type name (head values); in
                      if type != null then
                        type.merge (loc ++ [ name ]) values
                      else
                        abort "this should never be null if type checking is on"
                   )
                   file'd-values;
            };
      in
      { bundle =
          l.mkOption
            { type = t.package;
              default = "";
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

                      { description = ''starts with ":"'';
                        check = n: l.hasPrefix ":" n;
                        type = css-properties;
                      }

                      { description = ''"extra-rules"'';
                        check = n: n == "extra-rules";
                        type = extra-rules-type;
                      }
                    ];
                in
                t.attrsOf
                  (checked-attrs
                     ([ { description = ''starts with "@"'';
                          check = l.hasPrefix "@";
                          type = checked-attrs checks;
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
                     mapAttrs
                       (n: v:
                          if n == "extra-rules" then
                            v selector
                          else if l.hasPrefix "@" n then
                            mapAttrs
                              (n': v': if n' == "extra-rules" then v' selector else v')
                              v
                          else
                            v
                       )
                  );

              example =
                { classes =
                    { c1 =
                        { background = "red";
                          ":hover".background = "blue";

                          "@media (min-width: 1000px)" =
                            { display = "flex";
                              ":hover".background = "green";
                              extra-rules = c: { "${c} + ${c}".margin-top = "5px"; };
                            };

                          extra-rules = c: { "${c} > svg".fill = "blue"; };
                        };
                    };
                };
            };

        css =
          l.mkOption
            { type = t.lines;
              default = "";
            };

        imports' =
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

        rules =
          l.mkOption
            { type =
                checked-attrs
                  [ { description = ''doesn't start with "@"'';
                      check = n: !(l.hasPrefix "@" n);
                      type =  css-properties;
                    }

                    { description = ''starts with an "@"'';
                      check = l.hasPrefix "@";
                      type = t.attrsOf css-properties;
                    }
                  ];
            };
      };

    config =
      let
        imps = config.imports';
        list-to-str = f: list: concatStringsSep "\n" (map f list);

        make-css = handle-imports:
          let
            set-to-str = f: set: concatStringsSep "\n" (l.mapAttrsToList f set);

            make-rule = rule: dec-set:
              ''
              ${rule} {
                ${set-to-str (n: v: "${n}: ${toString v};") dec-set}
              }
              '';

            set-to-rules = set-to-str make-rule;
          in
          ''
          ${list-to-str (a: ''@import "${a}";'') (imps.urls)}
          ${list-to-str (a: ''@import "${handle-imports a}";'') (imps.paths)}

          ${list-to-str
              ({ path, files}:
                 list-to-str (a: ''@import "${handle-imports path}${toString a}";'') files
              )
              imps.directories
          }

          ${set-to-rules (l.filterAttrs (n: _: !(l.hasPrefix "@" n)) config.rules)}

          ${set-to-str
              (n: v:
                 ''
                 ${n} {
                   ${set-to-rules v}
                 }
                 ''
              )
              (l.filterAttrs (n: _: l.hasPrefix "@" n) config.rules)
          }
          '';
      in
      { bundle =
          let
            make-name = path: baseNameOf "${path}";
            css = make-css make-name;
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

            ln -s ${p.writeText "main.css" css} main.css
            '';

        css = make-css l.id;

        rules =
          let inherit (config) classes; in
          foldAttrs
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
               foldAttrs
                 (acc: a:
                    l.recursiveUpdate acc
                      (if l.hasPrefix "@" a.name then
                         { ${a.name} =
                             foldAttrs
                               (acc': b: l.recursiveUpdate acc' (helper b))
                               {}
                               a.value;
                         }
                       else
                         helper a
                      )
                 )
                 {}
                 value
            )
            {}
            classes;
      };
  }
