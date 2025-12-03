{ self, inputs, ... }:
{
  flake.nixosModules.persistence =
    {
      lib,
      options,
      config,
      ...
    }:
    {
      options = {
        persistence.homeManagerIntegration = {
          enable = (lib.mkEnableOption "persistence home manager integration") // {
            default = true;
          };
          module = lib.mkOption {
            internal = true;
            readOnly = true;
          };
        };
      };

      config = lib.mkIf config.persistence.enable (
        lib.optionalAttrs (options ? home-manager) (
          lib.mkIf config.persistence.homeManagerIntegration.enable {
            home-manager.sharedModules = [
              inputs.impermanence.homeManagerModules.impermanence
              self.homeManagerModules.persistence
              # set defaults for impermanence paths (between mkOption and mkDefault)
              {
                persistence.enable = lib.mkOverride 1250 config.persistence.enable;
                persistence.persistPath = lib.mkOverride 1250 config.persistence.persistPath;
              }
              (
                { config, ... }:
                let
                  cfg = config.persistence;
                in
                {
                  config = lib.mkIf cfg.enable {
                    home.persistence."${cfg.persistPath}" = {
                      inherit (cfg) directories files;
                    };
                  };
                }
              )
            ];
          }
        )
      );
    };
}
