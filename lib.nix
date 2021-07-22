{ media =
    rec
    { between = lower: upper: inclusive-between (lower + 1) upper;
      between' = lower: upper: inclusive-between lower (upper - 1);

      inclusive-between = lower: upper:
        "@media (min-width: ${toString lower}px) and (max-width: ${toString upper}px)";

      geq = px: "@media (min-width: ${toString px}px)";
      gt = px: geq (px + 1);
      lt = px: leq (px - 1);
      leq = px: "@media (max-width: ${toString px}px)";
    };
}
