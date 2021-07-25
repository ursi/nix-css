with builtins;
l:
  let
    t = l.types;
    allAttrs = f: attrs: all f (l.mapAttrsToList l.nameValuePair attrs);
  in
  rec
  { attrs-of = type:
      t.attrsOf type
      // { name = "attrs-of";

           check = a:
             if isAttrs a then
               allAttrs (b: type.check b.value) a
             else
               false;
         };

    css-value =
      let atom = t.oneOf [ t.str t.int t.float ]; in
      t.either atom (t.listOf atom);

    declarations = attrs-of css-value;

    extra-rules-type =
      let
        type =
          (attrs-of
             (checked-attrs
                [ (no-prefix-check "@" css-value)
                  (prefix-check "@" declarations)
                ]
             )
          );
      in
      l.mkOptionType
        { name = "extra-rules-type";
          description = "function from string to ${declarations.description}";

          check = f:
            if isFunction f then type.check (f "class")
            else false;

          merge = loc: defs:
            let
              try-merge =
                l.pipe defs
                  [ (map (a: a // { value = a.value "class"; }))
                    (type.merge loc)
                    tryEval
                  ];
            in
            if try-merge.success then
              c: type.merge loc (map (a: a // { value = a.value c; }) defs)
            else
              abort "merge was not successufl at ${toString loc}";
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
            && allAttrs
                 ({ name, value }:
                    any (a: a.check name && a.type.check value) checks
                 )
                 attrs;

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

    prefix-check = prefix: type:
      { description = ''starts with "${prefix}"'';
        check = l.hasPrefix prefix;
        inherit type;
      };

    no-prefix-check = prefix: type:
      { description = ''does not start with "${prefix}"'';
        check = n: !(l.hasPrefix prefix n);
        inherit type;
      };
  }
