{ ... }:
{
  # nix-ld lets unpatched, dynamically-linked binaries run on NixOS by supplying
  # a stand-in loader plus a library path. The libraries below are the runtime
  # deps of Playwright's downloaded Chromium (npm `playwright install`), which
  # otherwise dies with "error while loading shared libraries" on every fresh
  # checkout. Listed here rather than in a per-project shell so any checkout,
  # any Playwright version, just works.
  flake.nixosModules.nixLd =
    { pkgs, ... }:
    {
      programs.nix-ld = {
        enable = true;
        libraries = with pkgs; [
          alsa-lib
          at-spi2-atk
          at-spi2-core
          atk
          cairo
          cups
          dbus
          expat
          glib
          libgbm
          libx11
          libxcb
          libxcomposite
          libxdamage
          libxext
          libxfixes
          libxkbcommon
          libxrandr
          nspr
          nss
          pango
          systemd # libudev
        ];
      };
    };
}
