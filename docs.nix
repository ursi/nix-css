with builtins;
{ h, library, pkgs }:
  let
    l = p.lib; p = pkgs;

    recurse-with-name = attrs:
      let
        a2l = l.mapAttrsToList l.nameValuePair;

        f = acc: name-modifier: attrs-list:
          if attrs-list == [] then
            acc
          else
            let
              h = head attrs-list;
              cont = add: f (acc ++ add) name-modifier (tail attrs-list);
            in
            if isAttrs h.value then
              if h.value?__functor then
                cont
                  [ { name = name-modifier h.name;
                      inherit (h) value;
                    }
                  ]
              else
                f acc
                  (a:
                     name-modifier
                       (l.strings.escapeNixIdentifier h.name
                        + "."
                        + a
                       )
                  )
                  (a2l h.value)
            else
              cont [];
      in
      f [] l.id (a2l attrs);

    md =
      let
        functions = recurse-with-name library;

        page-link = name:
          h.a
            { href = "#${name}";

              style =
                { text-decoration = "none";
                  color = "inherit";
                };
            }
            name;
      in
      p.writeText "docs.md"
        (h.element "html" ""
           [ (h.head "" "")
             (h.body
                { style =
                    { font = "1rem sans-serif";
                      margin = 0;
                      display = "grid";
                      grid-template-columns = "max-content 1fr";
                      # height = "100%";
                    };
                }
                [ (h.div ""
                     (map
                        ({ name, ... }: h.div "" (page-link name))
                        functions))

                  (h.div
                     { style =
                         { height = "100vh";
                           overflow-y = "scroll";
                         };
                     }
                     (l.concatStringsSep (h.hr "")
                        (map
                           ({ name, value }:
                              h.div ""
                                [ (h.h2 { id = name; } (page-link name))

                                  (h.table { style.border-collapse = "collapse"; }
                                     (map
                                        ({ name, description }:
                                           let
                                             td =
                                               h.td
                                                 { style =
                                                     { border = "1px solid black";
                                                       padding = "5px";
                                                     };
                                                 };
                                           in
                                           h.tr ""
                                             [ (td (h.code "" name))
                                               (td description)
                                             ])
                                        value.args))

                                  (if value?notes
                                   then h.p { style.white-space = "pre-wrap"; } value.notes
                                   else ""
                                  )

                                  (h.h3 "" "Returns")
                                  (h.div "" value.returns)
                                  (h.h3 "" "Examples")
                                  (map (e: h.div "" (h.code "" e)) value.examples)
                                ]
                           )
                           functions)))
                ])
           ]);

    markdown = str:
      readFile
        (p.runCommand "markdown-to-html" {}
           ''
           ${p.cmark-gfm}/bin/cmark-gfm --github-pre-lang ${toFile "md" str} >> $out
           ''
        );
  in
  p.runCommand "docs" {}
    ''
    # so brave will know what to do with it
    mkdir $out
    ${p.pandoc}/bin/pandoc -f markdown -t html -o $out/index.html ${md}
    ''
