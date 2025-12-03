{ self, ... }:
{
  flake.homeManagerModules.persistence =
    { lib, ... }:
    {
      options = {
        persistence = {
          enable = lib.mkEnableOption "persistence";
          persistPath = lib.mkOption {
            type = lib.types.singleLineStr;
            default = "/persist";
          };
          files = lib.mkOption {
            type = lib.types.listOf lib.types.anything; # let the impermanence module do the type checking
            default = [ ];
          };
          directories = lib.mkOption {
            type = lib.types.listOf lib.types.anything; # let the impermanence module do the type checking
            default = [ ];
          };
        };
      };
      # we don't actually set anything from the above options here; that's done by the nixos/home-manager-integration module
    };
  flake.homeManagerModules.default = self.homeManagerModules.persistence;
}
