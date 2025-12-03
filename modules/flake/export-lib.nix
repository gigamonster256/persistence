{ persistence-lib, ... }:
{
  flake.flakeModules.default = {
    _module.args.persistence-lib = persistence-lib;
  };
}
