# Secure Boot for NixOS, via lanzaboote.
#
# Why this exists: Warzone's Ricochet anti-cheat requires Secure Boot (and TPM
# 2.0) *on Windows*, which means enabling Secure Boot in the firmware. Once the
# firmware enforces it, an unsigned bootloader is refused — so stock
# systemd-boot stops booting NixOS and the machine would only start Windows.
# lanzaboote fixes that by building a signed unified kernel image (kernel +
# initrd + cmdline in one PE binary) and signing it with keys you own, so NixOS
# satisfies the same check Windows does.
#
# This module is deliberately inert: importing it changes nothing until
# `mySecureBoot.enable = true`. lanzaboote's own config block is wrapped in
# `lib.mkIf cfg.enable` upstream, so the import alone can't disturb the current
# systemd-boot setup.
#
# ── Bring-up order (do NOT enable this first) ────────────────────────────────
# 1. Install Windows, and confirm it boots. Windows should own its own ESP on
#    its own disk; it will happily hijack an existing one if it finds it.
# 2. `sudo nixos-rebuild switch` with mySecureBoot.enable = true. Nothing is
#    signed into the firmware yet — this only installs lanzaboote and sbctl.
# 3. Create keys:            sudo sbctl create-keys
# 4. Rebuild so the boot files get signed with them:
#                            sudo nixos-rebuild switch
# 5. Put the firmware into Setup Mode (BIOS: clear/reset Secure Boot keys to
#    setup mode — NOT "Clear All Secure Boot Keys", which also drops the dbx
#    forbidden-signature database and weakens the whole point).
# 6. Enrol:                  sudo sbctl enroll-keys --microsoft
#    The --microsoft flag is not optional here. It keeps Microsoft's OEM
#    certificates alongside your own; without them the Windows install from
#    step 1 stops booting, and some option ROMs (GPU/NIC firmware) refuse to
#    initialise.
# 7. Enable Secure Boot in the BIOS, reboot, then verify:
#                            bootctl status
#    Look for "Secure Boot: enabled (user)".
#
# Recovery: if NixOS won't boot at any point, turn Secure Boot back off in the
# BIOS. Nothing here is destructive to the NixOS install itself.
{ inputs, ... }:
{
  flake.nixosModules.secureboot =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      imports = [ inputs.lanzaboote.nixosModules.lanzaboote ];

      options.mySecureBoot.enable = lib.mkEnableOption ''
        Secure Boot via lanzaboote, replacing systemd-boot with signed unified
        kernel images. Requires the manual sbctl key ceremony in this file's
        header before the firmware will accept them — enabling this option
        alone does not make the machine boot under Secure Boot.
      '';

      config = lib.mkIf config.mySecureBoot.enable {
        # lanzaboote drives boot.loader.external, which can't coexist with
        # systemd-boot. mkForce because common.nix turns systemd-boot on for
        # both desktops.
        boot.loader.systemd-boot.enable = lib.mkForce false;

        boot.lanzaboote = {
          enable = true;
          # sbctl's own default key location. The module derives
          # <pkiBundle>/keys/db/db.{pem,key} from this, which is exactly where
          # `sbctl create-keys` writes, so the two agree without further
          # configuration. The option has no default upstream.
          pkiBundle = "/var/lib/sbctl";
        };

        # `sbctl create-keys`, `enroll-keys`, and `sbctl status` for verifying.
        environment.systemPackages = [ pkgs.sbctl ];
      };
    };
}
