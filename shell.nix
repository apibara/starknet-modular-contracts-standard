with import <nixpkgs> {};
let
    fhs = pkgs.buildFHSUserEnv {
        name = "starknet-diamond-standard";

        targetPkgs = _: [
            pkgs.bash
            pkgs.bashInteractive
            pkgs.gcc
            pkgs.micromamba
        ];

        multiPkgs = _: [
            pkgs.gmpxx.dev
        ];

        profile = ''
        set -e
        eval "$(micromamba shell hook -s bash)"
        export MAMBA_ROOT_PREFIX=${builtins.getEnv "PWD"}/.mamba
        micromamba create -q -f environment.yml --yes -c conda-forge
        micromamba activate diamond-standard
        set +e
        '';
    };
in fhs.env