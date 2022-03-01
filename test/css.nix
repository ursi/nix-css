with builtins;
{ config, css-lib, pkgs, ... }:
   let
     l = pkgs.lib;
     inherit (css-lib) make-keyframes-names make-var-values merge merge-all;
     inherit (css-lib.media) gt leq;
     desktop = gt 700;
     mobile = leq 700;
     v = make-var-values config;
     keyframes = make-keyframes-names config;
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

     keyframes.animation =
       let small = "16px"; big = "32px"; in
       { "0%".font-size = small;
         "25%".font-size = big;
         "50%".font-size = small;
         "75%".font-size = big;
         "100%".font-size = small;
       };

     classes =
       let
         make-classes = spec:
           l.mapAttrs'
             (n: v: l.nameValuePair ("spec${toString spec}-${n}") v)
             test-classes;

         test-classes =
           let
             merged =
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
               ];

             extra-rules =
               { extra-rules = c:
                   { "${c} > svg" =
                       { color = "green";
                         ${desktop}.width = "30%";
                         ${mobile}.width = "60%";
                       };

                     "${c} + ${c}".margin-top = "10px";
                   };
               };
           in
           { "1" = merge merged // extra-rules;

             "2" = merge-all
               (merged
                ++ [ extra-rules
                     { extra-rules = c: { "${c}.merge-all".background = "purple"; }; }
                   ]
               );

             "3".animation = [ "1s" "infinite" keyframes.animation ];
           };
       in
       { "1" = make-classes 1 // { extra.color = "red"; };

         "2" =
           with config.classes."1";
           make-classes 2
           // { more-extra =
                  merge
                    [ extra
                      { pointer-events = "none";}
                    ];
              };
       }
       // listToAttrs
            (map
               (spec:
                  l.nameValuePair
                    (toString spec)
                    ({ c.z-index = spec; })
               )
               (l.range 3 9)
            );
   }
