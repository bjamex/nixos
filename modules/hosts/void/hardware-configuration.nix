{ self, inputs, ... }: {

  flake.nixosModules.voidHardware = { config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "thunderbolt" "nvme" "usbhid" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    { device = "/dev/mapper/luks-4f9f3478-a753-41c5-b585-66b8e75384aa";
      fsType = "ext4";
    };

  boot.initrd.luks.devices."luks-4f9f3478-a753-41c5-b585-66b8e75384aa".device = "/dev/disk/by-uuid/4f9f3478-a753-41c5-b585-66b8e75384aa";

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/42B3-9546";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };

  swapDevices = [];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
};

}

