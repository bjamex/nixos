# `nix develop .#freematics` — toolchain for flashing and debugging the
# Freematics ESP32 board. A dev shell, not a NixOS module.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      devShells.freematics = pkgs.mkShell {
        name = "freematics";
        packages = with pkgs; [
          platformio # build, upload, serial monitor
          esptool # direct ESP32 flash/erase
          picocom # serial terminal
          usbutils # lsusb for device identification
        ];
      };
    };
}
