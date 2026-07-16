{ self, inputs, ... }:
{
  # Wyoming faster-whisper ASR, reachable tailnet-wide. Runs on styx.
  #
  # CPU only: faster-whisper (CTranslate2) has no ROCm backend, so the 9070XT
  # doesn't help here — that's the GPU-accelerated Ollama path instead (see
  # llm.nix). "small-int8" is the practical sweet spot for a short-command
  # workload: sub-2s transcription on a desktop CPU without the accuracy hit
  # of "tiny".
  flake.nixosModules.voiceServer =
    { lib, ... }:
    {
      services.wyoming.faster-whisper.servers.default = {
        enable = true;
        uri = "tcp://0.0.0.0:10300";
        model = "small-int8";
        language = "en";
        device = "cpu";
      };

      networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 10300 ];

      # When voiceSatellite is also imported on this host (styx runs both),
      # talk to the ASR server over loopback instead of round-tripping
      # through Tailscale.
      voice.satellite.whisperUri = lib.mkDefault "tcp://127.0.0.1:10300";
    };

  # Per-PC voice control: local wake-word detection -> remote ASR -> local
  # shell command. No Home Assistant, no intent engine — just an ordered list
  # of regexes matched against the transcript.
  flake.nixosModules.voiceSatellite =
    { pkgs, lib, config, ... }:
    let
      cfg = config.voice.satellite;

      hyprctl = "${config.programs.hyprland.package}/bin/hyprctl";
      wpctl = lib.getExe' pkgs.wireplumber "wpctl";

      commandsFile = pkgs.writeText "voice-commands.json" (builtins.toJSON cfg.commands);

      pythonEnv = pkgs.python3.withPackages (ps: [
        ps.wyoming
        ps.sounddevice
      ]);

      # Runs for the lifetime of the graphical session (see hyprland.nix's
      # extraStartupExec) with no systemd supervision, so the outer loop is
      # our restart-on-crash: a dropped mic device or a transient ASR
      # connection failure shouldn't leave voice control dead until reboot.
      voiceSatelliteScript = pkgs.writeShellApplication {
        name = "voice-satellite";
        runtimeInputs = [
          pythonEnv
          pkgs.libnotify
        ];
        text = ''
          mkdir -p "$HOME/.local/state"
          while true; do
            python3 ${./voice-satellite.py} \
              --whisper-uri "${cfg.whisperUri}" \
              --wake-word "${cfg.wakeWord}" \
              --commands "${commandsFile}" \
              >>"$HOME/.local/state/voice-satellite.log" 2>&1 || true
            sleep 5
          done
        '';
      };
    in
    {
      options.voice.satellite = {
        wakeWord = lib.mkOption {
          type = lib.types.enum [
            "hey_jarvis"
            "okay_nabu"
            "hey_mycroft"
            "alexa"
            "hey_rhasspy"
          ];
          default = "hey_jarvis";
          description = "Built-in openWakeWord model to listen for.";
        };

        whisperUri = lib.mkOption {
          type = lib.types.str;
          default = "tcp://styx.pancake-ling.ts.net:10300";
          description = ''
            Wyoming ASR server URI. Defaults to styx over Tailscale MagicDNS;
            styx itself overrides this to loopback (see voiceServer).
          '';
        };

        commands = lib.mkOption {
          type = lib.types.listOf (
            lib.types.submodule {
              options = {
                pattern = lib.mkOption {
                  type = lib.types.str;
                  description = "Regex (case-insensitive, re.search) matched against the transcript.";
                };
                description = lib.mkOption {
                  type = lib.types.str;
                  description = "Shown in the notify-send confirmation on match.";
                };
                command = lib.mkOption {
                  type = lib.types.str;
                  description = "Shell command run on match (via `sh -c`).";
                };
              };
            }
          );
          default = [
            {
              pattern = "\\bmic\\b";
              description = "Toggle microphone mute";
              command = "${wpctl} set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
            }
            {
              pattern = "\\b(volume\\s*up|turn\\s*up|louder)\\b";
              description = "Volume up";
              command = "${lib.getExe pkgs.pamixer} -i 10";
            }
            {
              pattern = "\\b(volume\\s*down|turn\\s*down|quieter)\\b";
              description = "Volume down";
              command = "${lib.getExe pkgs.pamixer} -d 10";
            }
            {
              pattern = "\\b(mute|unmute|silence)\\b";
              description = "Toggle speaker mute";
              command = "${wpctl} set-mute @DEFAULT_AUDIO_SINK@ toggle";
            }
            {
              pattern = "\\b(play|pause)\\b";
              description = "Play/pause";
              command = "${lib.getExe pkgs.playerctl} play-pause";
            }
            {
              pattern = "\\bnext\\b";
              description = "Next track";
              command = "${lib.getExe pkgs.playerctl} next";
            }
            {
              pattern = "\\b(previous|back)\\b";
              description = "Previous track";
              command = "${lib.getExe pkgs.playerctl} previous";
            }
            {
              pattern = "\\block\\b";
              description = "Lock screen";
              command = lib.getExe pkgs.hyprlock;
            }
            {
              pattern = "\\bscreen\\s*shot\\b";
              description = "Screenshot";
              command = "mkdir -p ~/Pictures/Screenshots && ${lib.getExe pkgs.grimblast} copysave screen ~/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png";
            }
            {
              pattern = "\\b(close|kill)\\b";
              description = "Close window";
              command = "${hyprctl} dispatch killactive";
            }
          ];
          description = "Ordered list of transcript-matching commands; first match wins.";
        };
      };

      config = {
        # Local-only wake word detection (loopback, no firewall exposure).
        services.wyoming.openwakeword.enable = true;

        myHyprland.extraStartupExec = [ "${voiceSatelliteScript}/bin/voice-satellite" ];

        environment.systemPackages = [ voiceSatelliteScript ];
      };
    };
}
