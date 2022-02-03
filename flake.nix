{ outputs = { ... }:
    { __functor = _: { system }:
        module: import ./. { inherit module system; };
    };
}
