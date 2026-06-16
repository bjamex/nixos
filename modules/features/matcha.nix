{ ... }:
{
  # Matcha (matcha.email) — a TUI email client by Floatpane, built in Go with
  # Bubble Tea. Not in nixpkgs (the `matcha` attr there is an unrelated Haskell
  # web framework), so we build it from the upstream GitHub release.
  #
  # Notes:
  #  - go.mod pins `go 1.26.4` but nixpkgs currently ships 1.26.3; the gap is a
  #    patch-level toolchain bump, so we rewrite the directive rather than vendor
  #    a newer Go. Revisit (drop the postPatch) once nixpkgs catches up.
  #  - The `scard` dependency needs PCSC-lite + pkg-config for smartcard/PGP.
  #  - `subPackages = [ "." ]` so we ship just `matcha`, not its helper mains.
  #  - At runtime matcha shells out to `python3` to run its bundled OAuth2 helper
  #    (~/.config/matcha/oauth/oauth.py — used by Gmail batch operations even when
  #    IMAP login is via app password). The script is stdlib-only, so we just put
  #    python3 on matcha's PATH via a wrapper; otherwise those ops fail with
  #    `exec: "python3": executable file not found in $PATH`.
  flake.nixosModules.matcha =
    { pkgs, ... }:
    let
      matcha = pkgs.buildGoModule (finalAttrs: {
        pname = "matcha";
        version = "0.42.0";

        src = pkgs.fetchFromGitHub {
          owner = "floatpane";
          repo = "matcha";
          rev = "v${finalAttrs.version}";
          hash = "sha256-2dgvVbQxU8rdgE4dUCpBtsZvwzdiQr5cW4mMREL8YjM=";
        };

        vendorHash = "sha256-KCxx0RqZwXSGX852g857DWKmxpKE6zH0CPRhU4bNmIw=";

        postPatch = ''
          substituteInPlace go.mod --replace-fail "go 1.26.4" "go 1.26.3"
        '';

        subPackages = [ "." ];

        nativeBuildInputs = [
          pkgs.pkg-config
          pkgs.makeWrapper
        ];
        buildInputs = [ pkgs.pcsclite ];

        # Nix owns the binary; skip the upstream test suite (its integration
        # package is gated behind build tags that exclude all files here).
        doCheck = false;

        # matcha execs `python3` for its bundled OAuth2 helper; give it one.
        postInstall = ''
          wrapProgram $out/bin/matcha \
            --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.python3 ]}
        '';

        meta = {
          description = "Beautiful and functional TUI email client (matcha.email)";
          homepage = "https://github.com/floatpane/matcha";
          license = pkgs.lib.licenses.mit;
          mainProgram = "matcha";
        };
      });
    in
    {
      environment.systemPackages = [ matcha ];

      # Oxocarbon theme (IBM Carbon dark), matching the palette used by the Zen
      # module. Dropping a JSON file into ~/.config/matcha/themes/ makes it show
      # up in the in-app picker (Settings > Theme). We don't manage config.json
      # — matcha writes the active-theme choice there itself — so after a switch,
      # pick "Oxocarbon" once in Settings and it persists.
      hjem.users.swin.files.".config/matcha/themes/oxocarbon.json".text = builtins.toJSON {
        name = "Oxocarbon";
        accent = "#33b1ff"; # blue — selected/focused, primary highlights
        accent_dark = "#262626"; # layer — borders, title backgrounds
        accent_text = "#161616"; # base — text on accent-colored backgrounds
        secondary = "#525252"; # help text, blurred/unfocused elements
        subtle_text = "#78a9ff"; # list headers, hints
        muted_text = "#525252"; # dates, timestamps
        dim_text = "#dde1e6"; # sender names, secondary info
        danger = "#ee5396"; # magenta-pink — delete confirmations, errors
        warning = "#ff7eb6"; # softer pink — update notifications
        tip = "#42be65"; # green — contextual tips
        link = "#3ddbd9"; # cyan — hyperlinks
        directory = "#be95ff"; # purple — file-picker directories
        contrast = "#161616"; # base — text on active-folder accent
      };
    };
}
