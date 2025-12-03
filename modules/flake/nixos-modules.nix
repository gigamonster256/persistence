{ persistence-lib, ... }:
let
  class = "nixos";
  programPresistence = persistence-lib.mkPersistenceFlakeModule {
    inherit class;
    optionPath = [
      "persistence"
      "programs"
      "nixos"
    ];
    modulePath = [
      "persistence"
      "modules"
      "nixos"
      "default"
    ];
    configFn = persistence-lib.defaultNixosPersistenceConfigFn;
    description = "List of nixos programs to set impermanence options for.";
  };

  homeProgramPresistence = persistence-lib.mkPersistenceFlakeModule {
    inherit class;
    optionPath = [
      "persistence"
      "programs"
      "nixos-home"
    ];
    modulePath = [
      "persistence"
      "modules"
      "nixos"
      "homeManager"
    ];
    # TODO: use impermanence built-in user level impermanence options
    # rather than home-manager.sharedModules? then put this into the default
    # generated module rather than a separate one?
    configFn = persistence-lib.defaultNixosHomePersistenceConfigFn;
    description = "List of nixos programs that need home impermanence options.";
  };
  programModules = persistence-lib.mkPackageFlakeModule {
    inherit class;
    optionPath = [
      "persistence"
      "wrappers"
      "nixos"
    ];
    modulePath = [
      "persistence"
      "modules"
      "nixos"
      "wrappedPrograms"
    ];
    configFn = persistence-lib.defaultNixosPackageConfigFn;
    description = "List of nixos programs to wrap with package option.";
  };
in
{
  flake.flakeModules = {
    inherit programPresistence homeProgramPresistence programModules;
    default = {
      imports = [
        programPresistence
        homeProgramPresistence
      ];
    };
  };
}
