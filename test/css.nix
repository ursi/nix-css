{ config, css-lib, pkgs, ... }:
   let
     l = pkgs.lib;
     inherit (css-lib) make-var-values merge;
     inherit (css-lib.media) gt leq;
     desktop = gt 700;
     mobile = leq 700;
     v = make-var-values config.variables;
   in
   { css-imports =
       { urls = [ "test.com" ];
         paths = [ ./style.css ];

         directories =
           [ { path = ./font;
               files = [ /fonts.css ];
             }
           ];
       };

     charset = "utf-8";

     variables =
       { red1 = "red";
         font-size1 = "16px";

         scale =
           { ${desktop} = "1";
             ${mobile} = ".5";
           };
       };

     extra-css = "/* comment */";

     rules =
       { a.text-decoration = "none";

         body =
           { font-size = v.font-size1;
             ${desktop}.color = "red";
             ${mobile}.color = "green";
           };
       };

     classes =
       let
         make-classes = prefix:
           l.mapAttrs'
             (n: v: l.nameValuePair (prefix + n) v)
             test-classes;

         test-classes =
           { "1" =
               merge
                 [ { background = v.red1;
                     ":hover".background = "blue";

                     ${desktop} =
                       { display = "flex";
                         ":hover".background = "green";
                       };

                     ${mobile}.display = "grid";
                   }

                   { font-family = "sans-serif"; }
                   { ${desktop}.color = "green"; }
                 ]
                 // { extra-rules = c:
                        { "${c} > svg" =
                            { color = "green";
                              ${desktop}.width = "30%";
                              ${mobile}.width = "60%";
                            };

                          "${c} + ${c}".margin-top = "10px";
                        };
                    };
           };
       in
       { low-spec =
           make-classes "l"
           // { extra.color = "red"; };

         high-spec =
           with config.classes.low-spec;
           make-classes "h"
           // { more-extra =
                  merge
                    [ extra
                      { pointer-events = "none";}
                    ];
              };
       };
   }