{ ... }: {

  flake.nixosModules.comfyui =
    { pkgs, ... }:
    let
      startScript = pkgs.writeShellScript "comfyui-start" ''
        set -e
        COMFYUI_DIR="/var/lib/comfyui/ComfyUI"
        VENV_DIR="/var/lib/comfyui/venv"

        if [ ! -d "$COMFYUI_DIR" ]; then
          echo "Cloning ComfyUI..."
          ${pkgs.git}/bin/git clone https://github.com/comfyanonymous/ComfyUI "$COMFYUI_DIR"
        fi

        if [ ! -d "$VENV_DIR" ]; then
          echo "Creating venv and installing PyTorch ROCm 6.4..."
          ${pkgs.python312}/bin/python -m venv "$VENV_DIR"
          "$VENV_DIR/bin/pip" install --quiet torch torchvision torchaudio \
            --index-url https://download.pytorch.org/whl/rocm6.4
          echo "Installing ComfyUI requirements..."
          "$VENV_DIR/bin/pip" install --quiet -r "$COMFYUI_DIR/requirements.txt"
        fi

        exec "$VENV_DIR/bin/python" "$COMFYUI_DIR/main.py" \
          --listen 127.0.0.1 --port 8188
      '';
    in
    {
      users.users.comfyui = {
        isSystemUser = true;
        group = "comfyui";
        extraGroups = [ "video" "render" ];
      };
      users.groups.comfyui = { };

      systemd.tmpfiles.rules = [
        "d /var/lib/comfyui 0755 comfyui comfyui -"
      ];

      systemd.services.comfyui = {
        description = "ComfyUI";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];
        environment = {
          HSA_OVERRIDE_GFX_VERSION = "12.0.1";
          PYTORCH_ROCM_ARCH = "gfx1201";
          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [
            pkgs.stdenv.cc.cc.lib  # libstdc++.so.6
            pkgs.zlib              # libz.so.1
            pkgs.zstd              # libzstd.so.1
            pkgs.xz                # liblzma.so.5
            pkgs.bzip2             # libbz2.so.1
          ];
        };
        serviceConfig = {
          Type = "simple";
          User = "comfyui";
          Group = "comfyui";
          ExecStart = startScript;
          WorkingDirectory = "/var/lib/comfyui";
          Restart = "on-failure";
          RestartSec = 10;
          ReadWritePaths = [ "/var/lib/comfyui" ];
        };
      };

      # No longer need Docker for ComfyUI
      virtualisation.oci-containers.containers = { };
    };
}
