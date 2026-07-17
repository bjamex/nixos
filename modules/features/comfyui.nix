{ ... }: {

  flake.nixosModules.comfyui =
    { pkgs, ... }:
    let
      libPath = pkgs.lib.makeLibraryPath [
        pkgs.stdenv.cc.cc.lib
        pkgs.zlib
        pkgs.zstd
        pkgs.xz
        pkgs.bzip2
        pkgs.libGL
        pkgs.glib
      ];
      startScript = pkgs.writeShellScript "comfyui-start" ''
        set -e
        export LD_LIBRARY_PATH="${libPath}"
        COMFYUI_DIR="/var/lib/comfyui/ComfyUI"
        VENV_DIR="/var/lib/comfyui/venv"

        if [ ! -d "$COMFYUI_DIR" ]; then
          echo "Cloning ComfyUI..."
          ${pkgs.git}/bin/git clone https://github.com/comfyanonymous/ComfyUI "$COMFYUI_DIR"
        fi

        # A venv's bin/python symlinks into /nix/store; a `nix flake update` or GC
        # can leave that interpreter path gone, dangling the symlink (exec: python:
        # not found). If the interpreter no longer resolves, nuke the venv so the
        # block below rebuilds it from scratch (this also clears .installed).
        if [ -e "$VENV_DIR" ] && ! "$VENV_DIR/bin/python" --version >/dev/null 2>&1; then
          echo "venv python is broken (interpreter GC'd?), recreating..."
          rm -rf "$VENV_DIR"
        fi

        if [ ! -f "$VENV_DIR/.installed" ]; then
          echo "Creating venv and installing PyTorch ROCm 6.5..."
          ${pkgs.python312}/bin/python -m venv "$VENV_DIR"
          "$VENV_DIR/bin/pip" install --quiet torch torchvision torchaudio \
            --index-url https://download.pytorch.org/whl/rocm6.5
          echo "Installing ComfyUI requirements..."
          "$VENV_DIR/bin/pip" install --quiet -r "$COMFYUI_DIR/requirements.txt"
          echo "Installing ComfyUI Manager..."
          "$VENV_DIR/bin/pip" install --quiet -U --pre comfyui-manager
          touch "$VENV_DIR/.installed"
        fi

        export VIRTUAL_ENV="$VENV_DIR"
        export PATH="$VENV_DIR/bin:$PATH"
        exec python "$COMFYUI_DIR/main.py" \
          --listen 127.0.0.1 --port 8188 --enable-manager
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
        path = [ pkgs.uv pkgs.git ];
        environment = {
          HSA_OVERRIDE_GFX_VERSION = "12.0.1";
          PYTORCH_ROCM_ARCH = "gfx1201";
          HOME = "/var/lib/comfyui";
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
