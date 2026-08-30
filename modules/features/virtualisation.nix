{ self, inputs, ... }: {
  flake.nixosModules.virtualisation =
    { pkgs, ... }:
    {
      # libvirt/QEMU-KVM + virt-manager GUI. swtpm gives Windows 11 guests their
      # required emulated TPM 2.0; OVMF (UEFI) firmware now ships by default. USB
      # passthrough for e.g. the Xbox controller firmware update is a GUI click
      # (Add Hardware -> USB Host Device) and is independent of Wayland/Hyprland.
      virtualisation.libvirtd = {
        enable = true;
        qemu.swtpm.enable = true;
      };
      programs.virt-manager.enable = true;

      users.users.swin.extraGroups = [ "libvirtd" ];
    };
}
