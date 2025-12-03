{
  flake.nixosModules.persistence =
    {
      lib,
      utils,
      config,
      ...
    }:
    {
      options = {
        # TODO: add a toggleable warning about data loss?
        persistence.btrfsWipe = {
          enable = lib.mkEnableOption "Enable btrfs wipe of root subvolume on boot for impermanence setups.";
        };
      };
      config = lib.mkIf (config.persistence.enable && config.persistence.btrfsWipe.enable) (
        let
          rootFS = config.fileSystems."/";
        in
        {
          assertions = [
            {
              assertion = rootFS.fsType == "btrfs";
              message = "persustence btrfs requires btrfs filesystem";
            }
            # make sure btrfs-progs is at least 6.12? (for --recursive flag)
            # TODO: this is kind of hacky, possibly upstream a btrfs-progs package option?
            # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/tasks/filesystems/btrfs.nix
            (
              let
                # get the installed version of btrfs-progs from system.fsPackages
                packages = lib.filter (
                  pkg: (builtins.match "^btrfs-progs(-.*)?$" pkg.name) != null
                ) config.system.fsPackages;
                package = lib.head packages;
              in
              {
                assertion = lib.versionAtLeast (package.version or "0.0") "6.12";
                message = "btrfs-progs version 6.12 or higher is required for persistence btrfsWipe";
              }
            )
          ];
          boot.initrd.systemd = {
            # try to resume from hibernation before we go mucking about with the persist subvolume
            services.create-needed-for-boot-dirs.after = [ "systemd-hibernate-resume.service" ];
            services.btrfs-wipe = {
              description = "Prepare btrfs subvolumes for root";
              wantedBy = [ "initrd-root-device.target" ];
              after = [
                "${utils.escapeSystemdPath rootFS.device}.device"
                "local-fs-pre.target"
              ];
              before = [ "sysroot.mount" ];
              unitConfig.DefaultDependencies = "no";
              serviceConfig.Type = "oneshot";
              script =
                let
                  # parse for "subvol=<subvolume>" option
                  inherit (rootFS) options;
                  subvolOption = builtins.head (
                    builtins.filter (opt: builtins.match "subvol=.*" opt != null) options
                  );
                  subvolName = builtins.match "subvol=(.*)" subvolOption;
                  rootSubvolume = builtins.head subvolName;
                in
                # bash
                ''
                  mount --mkdir ${rootFS.device} /btrfs_tmp
                  if [[ -e /btrfs_tmp/${rootSubvolume} ]]; then
                      mkdir -p /btrfs_tmp/old_roots
                      timestamp=$(date --date="@$(stat -c %Y /btrfs_tmp/${rootSubvolume})" "+%Y-%m-%-d_%H:%M:%S")
                      mv /btrfs_tmp/${rootSubvolume} "/btrfs_tmp/old_roots/$timestamp"
                  fi

                  # Delete old roots after 30 days
                  for old_root in $(find /btrfs_tmp/old_roots/ -maxdepth 1 -mtime +30); do
                      btrfs subvolume delete --recursive "$old_root"
                  done

                  # Create new root subvolume
                  btrfs subvolume create /btrfs_tmp/${rootSubvolume}
                  umount /btrfs_tmp
                '';
            };
          };
        }
      );
    };
}
