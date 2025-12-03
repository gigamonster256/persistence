{ self, inputs, ... }:
{
  flake.nixosModules.persistence =
    { lib, config, ... }:
    {
      imports = [
        inputs.impermanence.nixosModules.impermanence
      ];

      options = {
        persistence = {
          enable = lib.mkEnableOption "persistence";
          persistPath = lib.mkOption {
            type = lib.types.singleLineStr;
            default = "/persist";
            description = "Path to the impermanence mount point.";
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

      config = lib.mkIf config.persistence.enable (
        let
          inherit (config.persistence) persistPath;
        in

        {
          assertions = [
            {
              assertion = config.fileSystems."${persistPath}".device != null;
              message = ''"${persistPath}" must be a specified mount to use persistence'';
            }
          ];
          fileSystems."${persistPath}".neededForBoot = true;
          environment.persistence."${persistPath}" = {
            inherit (config.persistence) directories files;
            hideMounts = lib.mkDefault true;
          };
        }

      );
    };
  flake.nixosModules.default = self.nixosModules.persistence;
}
