{ ... }:
{
  # System fonts for both desktops. fonts.packages (not systemPackages) is what
  # registers them with fontconfig, so every app — not just ones that go
  # looking in the profile — can find them.
  flake.nixosModules.fonts =
    { pkgs, ... }:
    {
      fonts = {
        enableDefaultPackages = true; # DejaVu, Liberation, a baseline emoji font

        packages = with pkgs; [
          inter
          noto-fonts
          noto-fonts-cjk-sans
          noto-fonts-color-emoji
          nerd-fonts.jetbrains-mono

          # The real Calibri (plus Cambria, Candara, Consolas, Constantia,
          # Corbel), pulled from Microsoft's installer at build time. Unfree, so
          # uncached; if that download ever dies, carlito is the free
          # metric-compatible stand-in for Calibri.
          vista-fonts
        ];

        # What the generic families resolve to for apps that don't name a font.
        # kitty only sets font_size, so monospace here is also kitty's font.
        fontconfig.defaultFonts = {
          monospace = [ "JetBrainsMono Nerd Font" ];
          sansSerif = [ "Inter" ];
          serif = [ "Noto Serif" ];
          emoji = [ "Noto Color Emoji" ];
        };
      };
    };
}
