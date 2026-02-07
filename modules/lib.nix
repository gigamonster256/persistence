let
  mkPackageModule =
    {
      name,
      packageName ? name,
      namespace ? [ "programs" ],
      configFn,
    }:
    {
      lib,
      pkgs,
      config,
      ...
    }:
    let
      optionPath = namespace ++ [ name ];
      cfg = lib.attrByPath optionPath { } config;
    in
    {
      options = lib.setAttrByPath optionPath {
        enable = lib.mkEnableOption name;
        package = lib.mkPackageOption pkgs packageName { };
      };

      config = lib.mkIf cfg.enable (configFn cfg);
    };

  mkPackageFlakeModule =
    {
      class,
      optionPath,
      modulePath,
      configFn,
      description,
    }:
    { lib, config, ... }:
    {
      options =
        lib.recursiveUpdate
          (lib.setAttrByPath optionPath (
            lib.mkOption {
              type = lib.types.listOf (
                lib.types.coercedTo lib.types.str
                  (name: {
                    inherit name;
                    packageName = name;
                    namespace = [ "programs" ];
                  })
                  (
                    lib.types.submodule {
                      options = {
                        name = lib.mkOption { type = lib.types.str; };
                        packageName = lib.mkOption {
                          type = lib.types.str;
                          default = null;
                        };
                        namespace = lib.mkOption {
                          type = lib.types.coercedTo lib.types.str lib.singleton (lib.types.listOf lib.types.str);
                          default = [ "programs" ];
                          description = "Namespace for the program option.";
                        };
                      };
                    }
                  )
              );
              default = [ ];
              inherit description;
            }
          ))
          (
            lib.setAttrByPath modulePath (
              lib.mkOption {
                type = lib.types.deferredModule;
                default = { };
              }
            )
          );

      config = lib.setAttrByPath modulePath {
        imports = builtins.map (
          prog:
          mkPackageModule {
            inherit (prog)
              name
              packageName
              namespace
              ;
            inherit configFn;
          }
        ) (lib.attrByPath optionPath [ ] config);
      };
    };

  mkPersistenceModule =
    {
      name,
      namespace ? [ "programs" ],
      directories ? [ ],
      files ? [ ],
      configFn,
    }:
    { lib, config, ... }:
    let
      optionPath = namespace ++ [ name ];
      persistencePath = optionPath ++ [ "persistence" ];
      getVal = p: default: lib.attrByPath p default config;
      persistenceCfg = getVal persistencePath { };
    in
    {
      options = lib.setAttrByPath persistencePath {
        enable = (lib.mkEnableOption ("persistence for " + name)) // {
          default = getVal (optionPath ++ [ "enable" ]) false;
        };
        files = lib.mkOption {
          type = lib.types.listOf lib.types.anything; # let the impermanence module do the type checking
          default = [ ];
          description = "List of files to persist for ${name}.";
        };
        directories = lib.mkOption {
          type = lib.types.listOf lib.types.anything; # let the impermanence module do the type checking
          default = [ ];
          description = "List of directories to persist for ${name}.";
        };
      };
      config = lib.mkMerge [
        (lib.setAttrByPath persistencePath {
          inherit directories files;
        })
        (lib.mkIf persistenceCfg.enable (configFn persistenceCfg))
      ];
    };

  mkPersistenceFlakeModule =
    {
      class,
      optionPath,
      modulePath,
      configFn,
      description,
    }:
    { lib, config, ... }:
    {
      options =
        lib.recursiveUpdate
          (lib.setAttrByPath optionPath (
            lib.mkOption {
              type = lib.types.attrsOf (
                lib.types.submodule (
                  { name, ... }:
                  {
                    options = {
                      name = lib.mkOption {
                        default = name;
                        type = lib.types.str;
                        description = "Name of the nixos option to create persistence options for.";
                      };
                      namespace = lib.mkOption {
                        default = "programs";
                        type = lib.types.coercedTo lib.types.str lib.singleton (lib.types.listOf lib.types.str);
                        description = "Namespace of the program to set impermanence options for.";
                      };
                      files = lib.mkOption {
                        type = lib.types.listOf lib.types.str;
                        default = [ ];
                      };
                      directories = lib.mkOption {
                        type = lib.types.listOf lib.types.str;
                        default = [ ];
                      };
                    };
                  }
                )
              );
              default = { };
              inherit description;
            }
          ))
          (
            lib.setAttrByPath modulePath (
              lib.mkOption {
                type = lib.types.deferredModule;
                default = { };
              }
            )
          );

      config = lib.setAttrByPath modulePath {
        imports = lib.mapAttrsToList (
          _name: cfg:
          mkPersistenceModule {
            inherit configFn;
            inherit (cfg)
              name
              namespace
              directories
              files
              ;
          }
        ) (lib.attrByPath optionPath { } config);
      };
    };

  defaultNixosPersistenceConfigFn = cfg: {
    persistence = {
      inherit (cfg) directories files;
    };
  };
  defaultHomeManagerPersistenceConfigFn = cfg: {
    persistence = {
      inherit (cfg) directories files;
    };
  };
  defaultNixosHomePersistenceConfigFn = cfg: {
    home-manager.sharedModules = [
      {
        persistence = {
          inherit (cfg) directories files;
        };
      }
    ];
  };
  defaultNixosPackageConfigFn = cfg: {
    environment.systemPackages = [ cfg.package ];
  };
  defaultHomeManagerPackageConfigFn = cfg: {
    home.packages = [ cfg.package ];
  };
in
{
  _module.args.persistence-lib = {
    inherit
      mkPersistenceFlakeModule
      mkPackageFlakeModule
      mkPackageModule
      mkPersistenceModule
      defaultNixosPersistenceConfigFn
      defaultHomeManagerPersistenceConfigFn
      defaultNixosHomePersistenceConfigFn
      defaultNixosPackageConfigFn
      defaultHomeManagerPackageConfigFn
      ;
  };
}
