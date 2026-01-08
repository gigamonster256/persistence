{
  inputs = {
    # nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    impermanence.url = "github:nix-community/impermanence";
    # impermanence.inputs.nixpkgs.follows = "nixpkgs";
    import-tree.url = "github:vic/import-tree";
  };

  outputs =
    { flake-parts, import-tree, ... }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } (
      { config, ... }:
      {
        systems = [
          "x86_64-linux"
          "aarch64-linux"
          "aarch64-darwin"
        ];

        imports = [
          inputs.flake-parts.flakeModules.partitions
          inputs.flake-parts.flakeModules.flakeModules
          (import-tree ./modules)
        ];

        partitionedAttrs = {
          formatter = "dev";
        };
        partitions.dev = {
          extraInputsFlake = ./dev;
          module = {
            perSystem =
              { pkgs, ... }:
              {
                formatter = pkgs.nixfmt-tree;
              };
          };
        };
      }
    );
}
