with builtins;
{ config, lib, pkgs, ... }:
  let
    l = lib; p = pkgs; t = l.types;

    inherit (import ./types.nix lib)
      attrs-of
      checked-attrs
      class-type
      css-value
      declarations
      keyframes
      list-of
      prefix-check
      no-prefix-check;

    foldAttrs = f: init: attrs:
      foldl' f init (l.mapAttrsToList l.nameValuePair attrs);

    spec-values = l.range 1 9;
    make-class-modifier = spec: str: l.concatMapStrings (l.const str) (l.range 1 spec);

    examples =
      mapAttrs
        (n: v: import (p.writeText n v))
        (import ./example-strings.nix);
  in
  { options =
      { at-rules =
          l.mkOption
            { type = checked-attrs [ (prefix-check "@" (attrs-of declarations)) ];
              default = {};
              description = "An attrset of @-prefixed attributes whose values contain rules.";
              example = examples.at-rules;
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
            make-classes = spec:
              l.mkOption
                { type = attrs-of class-type;
                  default = {};

                  apply =
                    mapAttrs
                      (class-name:
                         let selector = make-class-modifier spec ".${class-name}"; in
                         mapAttrs
                           (n: v: if n == "extra-rules" then v selector else v)
                      );

                  description =
                    ''
                    - Class names and corresponding declarations
                    - Pseudo-classes, pseudo-elements, and @-rules
                    - Arbitray selectors as functions of the class name
                    '';

                  example = examples."classes.\"1\"";
                };

            toInt = fromJSON;
          in
          l.genAttrs
            (map toString spec-values)
            (n: make-classes (toInt n));

        extra-css =
          l.mkOption
            { type = t.lines;
              default = "";
              description = "Extra CSS added to the file.";
            };

        css-imports =
          { paths =
              l.mkOption
                { type = list-of t.path;
                  default = [];
                  description = "Paths of files that will be imported in the CSS file and included in the bundle.";
                };

            directories =
              l.mkOption
                { type =
                    list-of
                      (t.submodule
                         { options =
                             { path =
                                 l.mkOption
                                   { type = t.path;
                                     description = "The path of the directory that contains the files to be imported.";
                                   };

                               files =
                                 l.mkOption
                                   { type = list-of t.path;
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
                { type = list-of t.str;
                  default = [];
                  description = "URLs that will be imported in the CSS file.";
                };
          };

        keyframes =
          l.mkOption
            { type = keyframes;
              default = {};
              description = "@keyframes rules";
              example = examples.keyframes;
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
              example = examples.rules;
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
              example = examples.variables;
            };
      };

    config =
      { at-rules =
          let
            extracted-at-rules =
              { rules =
                  foldAttrs
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
                    config.rules;

                variables =
                  foldAttrs
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
                    (l.filterAttrs (_: isAttrs) config.variables);
              };

            keyframes =
              l.mapAttrs'
                (n: l.nameValuePair "@keyframes ${n}")
                config.keyframes;
          in
          l.pipe {}
            (map l.recursiveUpdate
               [ extracted-at-rules.rules
                 extracted-at-rules.variables
                 keyframes
               ]
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

                charset =
                  if isNull config.charset
                  then ""
                  else ''@charset "${config.charset}";'';

                imports =
                  ''
                  ${list-to-str (a: ''@import "${a}";'') imps.urls}
                  ${list-to-str (a: ''@import "${make-name a}";'') imps.paths}

                  ${list-to-str
                      ({ path, files }:
                         list-to-str (a: ''@import "${make-name path}${toString a}";'') files
                      )
                      imps.directories
                  }
                  '';

                rules =
                  set-to-rules
                    (mapAttrs (_: l.filterAttrs (_: v: !(isAttrs v))) config.rules);

                at-rules =
                  let
                    build-keyframes = set:
                      let toNumber = pc: fromJSON (l.removeSuffix "%" pc); in
                      l.pipe set
                        [ (l.mapAttrs'
                             (n: v:
                                l.nameValuePair
                                  (if n == "from" then "0%"
                                   else if n == "to" then "100%"
                                   else n
                                  )
                                  v
                             )
                          )

                          (l.mapAttrsToList l.nameValuePair)
                          (sort (a: b: toNumber a.name < toNumber b.name))

                          (l.concatMapStringsSep "\n"
                             ({ name, value }: make-rule name value)
                          )
                        ];
                  in
                  set-to-str
                    (n: v:
                       ''
                       ${n} {
                         ${(if l.hasPrefix "@keyframes" n
                            then build-keyframes
                            else set-to-rules
                           )
                             v
                         }
                       }
                       ''
                    )
                    config.at-rules;
              in
              ''
              ${charset}
              ${imports}
              ${rules}
              ${at-rules}
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
            from-classes = spec:
              foldAttrs
                (acc: { name, value }:
                   let
                     class-rules =
                       let
                         helper = a:
                           let class-selector = make-class-modifier spec ".${name}"; in
                           if l.hasPrefix ":" a.name then
                             { ${class-selector + a.name} = a.value; }
                           else if a.name == "extra-rules" then
                             a.value
                           else
                             { ${class-selector}.${a.name} = a.value; };
                       in
                       foldAttrs
                         (acc': a:
                            let
                              extract-at-rules =
                                foldAttrs
                                  (acc'': b:
                                     l.recursiveUpdate acc''
                                       (mapAttrs (_: v: { ${a.name} = v; }) (helper b))
                                  )
                                  {}
                                  a.value;
                            in
                            l.recursiveUpdate acc'
                              (if l.hasPrefix "@" a.name
                               then extract-at-rules
                               else helper a
                              )
                         )
                         {}
                         value;
                   in
                   l.recursiveUpdate acc class-rules
                )
                {};
          in
          l.mkMerge
            ([ { ":root" =
                  l.mapAttrs'
                    (n: v: l.nameValuePair ("--" + n) v)
                    (l.filterAttrs
                       (_: v: !(isAttrs v))
                       config.variables
                    );
               }
             ]
             ++ map (spec: from-classes spec config.classes.${toString spec}) spec-values
            );
      };
  }
