{
  lib,
  pkgs,
  ...
}: let
  mesa-panfork = pkgs.fetchFromGitLab {
    owner = "panfork";
    repo = "mesa";
    rev =  "120202c675749c5ef81ae4c8cdc30019b4de08f4";
    hash = "sha256-4eZHMiYS+sRDHNBtLZTA8ELZnLns7yT3USU5YQswxQ0=";
  };
  rootPartitionUUID = "14e19a7b-0ae0-484d-9d54-43bd6fdc20c7";
  rk-valhal = pkgs.runCommand "" {
    src = pkgs.fetchurl {
      url = "https://github.com/JeffyCN/mirrors/raw/libmali/lib/aarch64-linux-gnu/libmali-valhall-g610-g6p0-x11-wayland-gbm.so";
      sha256 = "0yzwlc1mm7adqv804jqm2ikkn1ji0pv1fpxjb9xxw69r2wbmlhkl";
    };
  } ''
    mkdir $out/lib -p
    cp $src $out/lib/libmali.so.1
    ln -s libmali.so.1 $out/lib/libmali-valhall-g610-g6p0-x11-wayland-gbm.so
    for l in libEGL.so libEGL.so.1 libgbm.so.1 libGLESv2.so libGLESv2.so.2 libOpenCL.so.1; do ln -s libmali.so.1 $out/lib/$l; done
  '';
in {
  boot = {
    kernelPackages = pkgs.linuxPackagesFor (pkgs.callPackage ./pkgs/kernel {});

    # kernelParams copy from Armbian's /boot/armbianEnv.txt & /boot/boot.cmd
    kernelParams = [
      "root=UUID=${rootPartitionUUID}"
      "rootwait"
      "rootfstype=ext4"

      "earlycon" # enable early console, so we can see the boot messages via serial port / HDMI
      "consoleblank=0" # disable console blanking(screen saver)
      "console=ttyS2,1500000" # serial port
      "console=tty1" # HDMI

      # docker optimizations
      "cgroup_enable=cpuset"
      "cgroup_memory=1"
      "cgroup_enable=memory"
      "swapaccount=1"
    ];
    # Some filesystems (e.g. zfs) have some trouble with cross (or with BSP kernels?) here.
    supportedFilesystems = lib.mkForce [
      "vfat"
      "fat32"
      "exfat"
      "ext4"
      "btrfs"
    ];

    loader = {
      grub.enable = lib.mkForce false;
      generic-extlinux-compatible.enable = lib.mkForce true;
    };

    initrd.includeDefaultModules = lib.mkForce false;
    initrd.availableKernelModules = lib.mkForce [ "dm_mod" "dm_crypt" "encrypted_keys" "nvme" "usbhid" ];
  };

  powerManagement.cpuFreqGovernor = lib.mkDefault "ondemand";

  hardware = {
    # driver & firmware for Mali-G610 GPU
    # it works on all rk2588/rk3588s based SBCs.
    opengl = {
      enable = true;
      package =
        lib.mkForce
        (
          (pkgs.mesa.override {
            galliumDrivers = ["panfrost" "swrast"];
            vulkanDrivers = ["swrast"];
          })
          .overrideAttrs (_: {
            pname = "mesa-panfork";
            version = "23.0.0-panfork";
            src = mesa-panfork;
          })
        )
        .drivers;
      extraPackages = [ rk-valhal ];
    };

    enableRedistributableFirmware = lib.mkForce true;
    firmware = [
      # firmware for Mali-G610 GPU
      (pkgs.callPackage ./pkgs/firmware {})
    ];

    # add some missing deviceTree in armbian/linux-rockchip:
    # orange pi 5's deviceTree in armbian/linux-rockchip:
    # https://github.com/armbian/linux-rockchip/blob/rk-5.10-rkr4/arch/arm64/boot/dts/rockchip/rk3588s-orangepi-5.dts
    deviceTree = {
      name = "rockchip/rk3588s-orangepi-5.dtb";
      overlays = [
        {
          # enable pcie2x1l2 (NVMe), disable sata0
          name = "orangepi5-sata-overlay";
          dtsText = ''
            // Orange Pi 5 Pcie M.2 to sata
            /dts-v1/;
            /plugin/;

            / {
              compatible = "rockchip,rk3588s-orangepi-5";

              fragment@0 {
                target = <&sata0>;

                __overlay__ {
                  status = "disabled";
                };
              };

              fragment@1 {
                target = <&pcie2x1l2>;

                __overlay__ {
                  status = "okay";
                };
              };
            };
          '';
        }

        # enable i2c1
        {
          name = "orangepi5-i2c-overlay";
          dtsText = ''
            /dts-v1/;
            /plugin/;

            / {
              compatible = "rockchip,rk3588s-orangepi-5";

              fragment@0 {
                target = <&i2c1>;

                __overlay__ {
                  status = "okay";
                  pinctrl-names = "default";
                  pinctrl-0 = <&i2c1m2_xfer>;
                };
              };
            };
          '';
        }
      ];
    };
  };
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/${rootPartitionUUID}";
    fsType = "ext4";
  };
  swapDevices = [ ];
}