# JDownloader 2. Not in nixpkgs, and it self-updates by rewriting its own jar
# and plugin tree, so it can't run out of the read-only store. The wrapper
# bootstraps upstream's JDownloader.jar into a writable data dir on first
# launch and runs it with nixpkgs' JRE; from then on JDownloader's own
# updater keeps that dir current. Delete the dir to reinstall from scratch.
{ ... }:
{
  flake.nixosModules.jdownloader =
    { pkgs, ... }:
    let
      jdownloader = pkgs.writeShellApplication {
        name = "jdownloader";
        runtimeInputs = with pkgs; [
          jre
          curl
          coreutils
        ];
        text = ''
          dir="''${XDG_DATA_HOME:-$HOME/.local/share}/jdownloader"
          mkdir -p "$dir"
          if [ ! -f "$dir/JDownloader.jar" ]; then
            echo "jdownloader: first run, fetching JDownloader.jar into $dir"
            curl -fL --retry 3 -o "$dir/JDownloader.jar.part" \
              https://installer.jdownloader.org/JDownloader.jar
            mv "$dir/JDownloader.jar.part" "$dir/JDownloader.jar"
          fi
          cd "$dir"

          # Swing under Hyprland (via Xwayland) draws blank grey windows unless
          # it's told the WM doesn't reparent.
          export _JAVA_AWT_WM_NONREPARENTING=1
          exec java \
            -Dawt.useSystemAAFontSettings=on \
            -Dswing.aatext=true \
            -jar JDownloader.jar "$@"
        '';
      };

      desktopItem = pkgs.makeDesktopItem {
        name = "jdownloader";
        desktopName = "JDownloader";
        comment = "Download manager";
        exec = "jdownloader";
        icon = "folder-download";
        categories = [
          "Network"
          "FileTransfer"
        ];
      };
    in
    {
      environment.systemPackages = [
        jdownloader
        desktopItem
      ];
    };
}
