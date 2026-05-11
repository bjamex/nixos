{ ... }:
{
  perSystem = { pkgs, ... }: {
    devShells.freematics = pkgs.mkShell {
      name = "freematics";
      packages = with pkgs; [
        platformio  # build, upload, serial monitor
        esptool     # direct ESP32 flash/erase
        picocom     # serial terminal
        usbutils    # lsusb for device identification
      ];
    };
  };
}
