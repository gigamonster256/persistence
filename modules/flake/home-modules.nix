{ persistence-lib, ... }:
let
  class = "homeManager";
  programPresistence = persistence-lib.mkPersistenceFlakeModule {
    inherit class;
    optionPath = [
      "persistence"
      "programs"
      "homeManager"
    ];
    modulePath = [
      "persistence"
      "modules"
      "homeManager"
      "default"
    ];
    configFn = persistence-lib.defaultHomeManagerPersistenceConfigFn;
    description = "List of home programs to set persistence options for.";
  };

  programModules = persistence-lib.mkPackageFlakeModule {
    inherit class;
    optionPath = [
      "persistence"
      "wrappers"
      "homeManager"
    ];
    modulePath = [
      "persistence"
      "modules"
      "homeManager"
      "wrappedPrograms"
    ];
    configFn = persistence-lib.defaultHomeManagerPackageConfigFn;
    description = "List of home programs to wrap with package option.";
  };
in
{
  flake.flakeModules = {
    inherit programPresistence programModules;
    default = programPresistence;
  };
}
