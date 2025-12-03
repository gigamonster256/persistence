# Persistence

A [flake-parts](https://github.com/hercules-ci/flake-parts) module set for managing [impermanence](https://github.com/nix-community/impermanence) configurations declaratively. This flake provides utilities for:

- Defining persistence directories/files for programs at the flake level
- Wrapping packages with `enable`/`package` options for easy toggling of impermanence files/directories
- Automatic btrfs root subvolume wiping on boot
- Home Manager integration for NixOS systems

## Installation

Add the flake to your inputs:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    persistence.url = "github:yourusername/persistence";
    # ...
  };
}
```

Import the flake modules in your flake-parts configuration:

```nix
{
  imports = [
    inputs.persistence.flakeModules.default
    inputs.persistence.flakeModules.programModules
  ];
}
```

## Flake Modules

| Module | Description |
|--------|-------------|
| `flakeModules.default/programPresistence` | NixOS and Home Manager persistence program definitions |
| `flakeModules.programModules` | Package wrapper module generators |
| `flakeModules.homeProgramPresistence` | Home persistence options via NixOS |

## NixOS/Home Manager Modules

| Module | Description |
|--------|-------------|
| `nixosModules.default/persistence` | Main NixOS persistence module (includes impermanence) |
| `homeManagerModules.default/persistence` | Home Manager persistence options (usually auto imported by the nixos module) |

## Usage

### Basic Persistence Configuration

The generated modules need to be imported into your NixOS and Home Manager configurations:

```nix
{
  # NixOS configuration imports
  {
    imports = [
        inputs.persistence.nixosModules.default
        config.persistence.modules.nixos.wrappedPrograms  # if using wrappers
    ];
  }

  # Home Manager configuration imports  
  {
    imports = [
        # homeManagerModules are auto-included via NixOS integration
        config.persistence.modules.homeManager.wrappedPrograms  # if using wrappers
    ];
  }

  # Impermanence module imports (where persistence options are applied)
  {
    imports = [
        config.persistence.modules.nixos.default
        config.persistence.modules.nixos.homeManager
    ];
  }

  {
    imports = [
        config.persistence.modules.homeManager.default
    ];
  }
}
```

### Defining Persistence for Programs

Add persistence directories and files for programs at the flake level:

```nix
{
  # Home Manager programs
  persistence.programs.homeManager = {
    slack = {
      directories = [ ".config/Slack" ];
    };
    firefox = {
      directories = [ ".mozilla" ];
    };
    sonusmix = {
      directories = [ ".local/share/org.sonusmix.Sonusmix" ];
    };
  };

  # NixOS programs
  persistence.programs.nixos = {
    docker = {
      directories = [ "/var/lib/docker" ];
    };
  };

  # Programs in non-standard namespaces
  persistence.programs.nixos = {
    lanzaboote = {
      namespace = "boot";  # Creates options at boot.lanzaboote.persistence
    };
  };
}
```

### Wrapping Packages

Many applications don't have dedicated NixOS or Home Manager modules, they're just packages you install with environment.systemPackages or home.packages. When using impermanence, you often want to:

1. Persist certain directories or files only when an app is enabled
2. Have a clean way to enable/disable the app and its persistence together
3. Override the package version if needed

The wrapper system solves this by generating `programs.<name>.enable` and `programs.<name>.package` options for any package. Combined with `persistence.programs`, you get automatic persistence that activates when the program is enabled:

```nix
{
  # Simple string syntax - package name matches program name
  persistence.wrappers.homeManager = [
    "slack"
    "spotify"
  ];

  # NixOS wrappers work the same way
  persistence.wrappers.nixos = [
    "htop"
  ];

  # Wrap a service in a non-default namespace
  persistence.wrappers.homeManager = [
    {
      name = "keyring";
      packageName = "gnome-keyring";
      namespace = [ "services" "gnome" ];  # creates services.gnome.keyring.enable/package
    }
  ];
}
```

Then define persistence for these wrapped programs:

```nix
{
  persistence.programs.homeManager = {
    # Standard program persistence
    slack.directories = [ ".config/Slack" ];
    spotify.directories = [ ".config/spotify" ];

    # Persistence for a wrapped service in a nested namespace
    keyring = {
      namespace = [ "services" "gnome" ];
      directories = [ ".local/share/keyrings" ];
    };
  };
}
```

### Overriding Wrapped Package Defaults

After wrapping a package, you can override its defaults in your configuration:

```nix
{
  # Wrap spotify
  persistence.wrappers.homeManager = [ "spotify" ];
}

# Then in your Home Manager config:
{
  programs.spotify.enable = true;
  programs.spotify.package = config.programs.spicetify.spicedSpotify;
}
```

### Dynamic Persistence Configuration

For programs where persistence paths depend on configuration values, use the generated options in other modules:

```nix
{
  # Define persistence options for lanzaboote in the boot namespace
  persistence.programs.nixos = {
    lanzaboote = {
      namespace = "boot";
    };
  };
}

# Then in your impermanence NixOS module:
{ config, ... }:
{
  boot.lanzaboote.persistence.directories = [
    config.boot.lanzaboote.pkiBundle
  ];
}
```

### System Persistence Defaults

Configure base system persistence in your impermanence module:

```nix
{
  # NixOS impermanence
  impermanence.nixos = {
    persistence.enable = true;
    persistence.persistPath = "/persist";
    persistence.btrfsWipe.enable = true;  # Enable btrfs root wipe
    persistence = {
      directories = [
        "/var/log"
        "/var/lib/nixos"
        "/var/lib/systemd/coredump"
        "/var/lib/systemd/timers"
      ];
      files = [
        "/etc/machine-id"
        "/etc/ssh/ssh_host_ed25519_key"
      ];
    };
  };

  # Home Manager impermanence
  impermanence.home = {
    persistence = {
      directories = [
        ".ssh"
        ".gnupg"
        ".local/share/nix"
      ];
    };
  };
}
```

## Generated Options

### Persistence Program Options

For each program defined in `persistence.programs.*`, the following options are generated:

```nix
# For persistence.programs.homeManager.slack:
programs.slack.persistence = {
  enable = true;  # defaults to programs.slack.enable
  directories = [ ".config/Slack" ];
  files = [ ];
};
```

### Wrapper Program Options

For each program in `persistence.wrappers.*`:

```nix
# For persistence.wrappers.homeManager = [ "slack" ]:
programs.slack = {
  enable = false;  # mkEnableOption
  package = pkgs.slack;  # mkPackageOption
};
```

## Btrfs Wipe

The `persistence.btrfsWipe` option enables automatic root subvolume wiping on boot:

- Requires btrfs filesystem for root
- Requires btrfs-progs >= 6.12
- Moves old roots to `/old_roots/` with timestamps
- Cleans up roots older than 30 days
- Runs in initrd before root mount

## Complete Example

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    home-manager.url = "github:nix-community/home-manager";
    persistence.url = "github:gigamonster256/persistence";
  };

  outputs = { flake-parts, ... }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } (
    { config, ... }:
    {
      systems = [ "x86_64-linux" ];
      
      imports = [
        inputs.persistence.flakeModules.default
        inputs.persistence.flakeModules.programModules
      ];

      # Define wrapped programs
      persistence.wrappers.homeManager = [
        "slack"
        "spotify"
      ];

      # Define persistence paths
      persistence.programs.homeManager = {
        slack.directories = [ ".config/Slack" ];
        firefox.directories = [ ".mozilla" ];
      };

      persistence.programs.nixos = {
        docker.directories = [ "/var/lib/docker" ];
      };

      flake = {
        nixosConfigurations.myhost = inputs.nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            inputs.home-manager.nixosModules.default
            inputs.persistence.nixosModules.default
            config.persistence.modules.nixos.wrappedPrograms
            config.persistence.modules.nixos.default
            config.persistence.modules.nixos.homeManager
            {
              # Impermanence configuration
              persistence.enable = true;
              persistence.btrfsWipe.enable = true;
              persistence.directories = [
                "/var/log"
                "/var/lib/nixos"
              ];
            }
            # Home Manager configuration
            {
              home-manager.sharedModules = [
                config.persistence.modules.homeManager.wrappedPrograms
                config.persistence.modules.homeManager.default
                {
                  persistence.directories = [
                    ".ssh"
                    ".gnupg"
                  ];
                }
              ];
            }
            # ... your other modules
          ];
        };
      };
    });
}
```

## License

MIT
