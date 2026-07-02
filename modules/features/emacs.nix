{ self, inputs, ... }: {

  flake.nixosModules.emacs = { pkgs, lib, ... }: {
    # emacs-pgtk: native Wayland (pure GTK) build — right choice under Hyprland.
    # Doom itself is installed imperatively into ~/.config/{emacs,doom}; Nix only
    # provides emacs and the CLI tools Doom shells out to.

    # Run Emacs as a per-user systemd daemon so `emacsclient` connects to one
    # long-lived session (instant frames, buffers persist across windows) instead
    # of booting all of Doom each launch. `emacs`/`emacs -nw` still work as normal
    # standalone instances — this only adds the daemon, it doesn't replace them.
    #
    # startWithGraphical = false (NOT true): our Hyprland session is launched
    # directly via greetd and does no `systemctl --user import-environment`, so
    # graphical-session.target is never reached — binding the daemon there leaves
    # it dead forever. default.target IS reached at login, so the daemon starts
    # reliably from there. Trade-off: a default.target daemon has no WAYLAND_DISPLAY,
    # so `emacsclient -c` GUI frames won't work from it — but all our call sites use
    # `emacsclient -t` (terminal frames, no display needed), and plain `emacs` still
    # does GUI standalone. defaultEditor: EDITOR=emacsclient.
    # After editing ~/.config/doom: `doom sync` + `systemctl --user restart emacs`
    # (or M-x doom/reload) — the daemon loads config once at startup.
    services.emacs = {
      enable = true;
      package = pkgs.emacs-pgtk;
      defaultEditor = true;
      startWithGraphical = false;
    };

    environment.systemPackages = with pkgs; [
      emacs-pgtk

      # `ec`: open a terminal frame on the daemon. `-a ""` makes it self-start a
      # daemon if one isn't up yet (e.g. before the systemd unit has run, or if it
      # died), so it never errors out + closes the window. Used by the `n` alias,
      # yazi, the gdoc fallback, and Hyprland's SUPER+N.
      (writeShellScriptBin "ec" ''exec ${emacs-pgtk}/bin/emacsclient -t -a "" "$@"'')

      # `doom` CLI lives in the imperative ~/.config/emacs/bin; wrap it so it's
      # on PATH without clobbering PATH or relying on $HOME login-time expansion.
      (writeShellScriptBin "doom" ''exec "$HOME/.config/emacs/bin/doom" "$@"'')

      # Doom dependencies / "doom doctor" wants these
      git
      ripgrep
      fd
      coreutils                # gls etc.
      gnumake
      gcc                      # native-comp + some packages
      cmake                    # vterm
      (lib.lowPrio binutils)

      # Common module extras
      nodejs                   # many LSP/format modules
      shellcheck               # :checkers
      pandoc                   # :lang org export
    ];
  };
}
