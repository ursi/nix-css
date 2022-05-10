{ at-rules =
    ''
    { "@media (min-width: 750px)" =
        { body =
            { font-size = "12px";
              margin = 0;
            };
        };
    }
    '';

  "classes.\"1\"" =
    ''
    { c1 =
        { background = "red";
          ":hover".background = "blue";

          "@media (min-width: 1000px)" =
            { display = "flex";
              ":hover".background = "green";
            };

          extra-rules = c:
            { "''${c} > svg".fill = "blue"; };
        };

      c2.color = "purple";
    }
    '';

  keyframes =
    ''
    { font-size-wiggle =
        { "0%".font-size = "16px";
          "25%".font-size = "32px";
          "50%".font-size = "16px";
          "75%".font-size = "32px";
          "100%".font-size = "16px";
        };
    }
    '';

  rules =
    ''
    { body =
        { background = "red";

          "@media (min-width: 750px)" =
            { font-size = "12px";
              margin = 0;
            };
        };
    }
    '';

  variables =
    ''
    { red1 = "#f00000";

      font-size =
        { "@media (min-width: 751px)" = "16px";
          "@media (max-width: 750px)" = "12px";
        };
    }
    '';
}
