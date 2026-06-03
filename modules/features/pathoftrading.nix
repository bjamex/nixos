{ self, inputs, ... }:
{
  flake.nixosModules.pathoftrading =
    { pkgs, lib, ... }:
    let
      python = pkgs.python3.withPackages (ps: [ ps.requests ]);

      src = pkgs.fetchFromGitHub {
        owner = "brendancohan";
        repo = "PathofTrading";
        rev = "3d1a65745353edebd727e98fc1252425da95bdcf";
        hash = "sha256-/qgtITWokYghxqoys1q603FZVp/DSeEZEmLSKXYrfks=";
      };

      # Install backend + QML in the same directory so backend.py can find PathofTrading.qml
      # via os.path.dirname(__file__)
      scripts = pkgs.stdenv.mkDerivation {
        pname = "pathoftrading-scripts";
        version = "1.0";
        inherit src;
        dontBuild = true;
        installPhase = ''
          mkdir -p $out/share/pathoftrading
          cp backend.py PathofTrading.qml $out/share/pathoftrading/
          sed -i 's/PanelWindow {/PanelWindow {\n    aboveWindows: true/' $out/share/pathoftrading/PathofTrading.qml
        '';
      };

      pathoftrading = pkgs.writeShellScriptBin "pathoftrading" ''
        export YDOTOOL_SOCKET="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/.ydotool_socket"
        ${lib.getExe pkgs.ydotool} key 29:1 46:1 46:0 29:0
        sleep 0.4
        ${python}/bin/python3 ${scripts}/share/pathoftrading/backend.py &
      '';
    in
    {
      programs.ydotool.enable = true;

      systemd.user.services.ydotool.wantedBy = [ "default.target" ];

      environment.systemPackages = [
        pkgs.quickshell
        pkgs.wl-clipboard
        pkgs.xclip
        pathoftrading
      ];
    };
}
