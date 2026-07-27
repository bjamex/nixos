{
  lib,
  rustPlatform,
  fetchFromGitHub,
  cargo-tauri,
  nodejs,
  npmHooks,
  fetchNpmDeps,
  pkg-config,
  wrapGAppsHook3,
  glib-networking,
  openssl,
  webkitgtk_4_1,
  libsoup_3,
  libayatana-appindicator,
  makeDesktopItem,
  copyDesktopItems,
}:

# PoE Campaign Copilot — passive Act 1-10 leveling overlay (Tauri v2: Rust
# backend + React/Vite frontend). Upstream ships no Linux artifact and targets
# Windows only, but the code is cross-platform: the overlay uses Tauri's
# set_ignore_cursor_events (click-through) + transparent/always-on-top window
# props, no Win32. So we just build from source.
#
# Three hashes are lib.fakeHash placeholders — do the standard finish-locally
# dance: `nixos-rebuild build`, copy each "got:" hash in, rebuild. (src first,
# then cargoHash, then npmDeps.)
rustPlatform.buildRustPackage rec {
  pname = "poe-campaign-copilot";
  version = "0.1.10";

  src = fetchFromGitHub {
    owner = "andrewli8";
    repo = "poe-campaign-copilot";
    rev = "v${version}";
    hash = "sha256-WxO7BWqCL6mhy2QZhyZkFqxCLtWBnkrJp0YnalwTbgE=";
  };

  # Cargo workspace root is the repo root (src-tauri/ + crates/* are members);
  # the Tauri binary crate lives in src-tauri/.
  buildAndTestSubdir = "src-tauri";
  cargoHash = "sha256-cat6YQjSZqCZ/yyOAQ2cnAMpnVuCvyCXEm3awtdVXyY=";

  # Frontend deps — package.json + package-lock.json at the repo root.
  # (If upstream actually uses pnpm, swap to pnpm.configHook + fetchDeps.)
  npmDeps = fetchNpmDeps {
    inherit src;
    hash = "sha256-5lJ4SNBZyaeaTF3JoZF9CMAhSo3slb6Nnur7hncV4Ag=";
  };
  npmRoot = ".";

  nativeBuildInputs = [
    cargo-tauri.hook
    nodejs
    npmHooks.npmConfigHook
    pkg-config
    wrapGAppsHook3
    copyDesktopItems
  ];

  buildInputs = [
    glib-networking # TLS for the WebView (updater + PoB share-code fetch)
    openssl
    webkitgtk_4_1 # Tauri v2 WebView backend (GTK3)
    libsoup_3
    libayatana-appindicator # tray icon (dlopened at runtime — see LD_LIBRARY_PATH below)
  ];

  # tauri.conf.json only declares the nsis (Windows) bundle. On Linux skip the
  # bundler entirely — but then cargo-tauri's install hook has no bundle to
  # move, so install the compiled binary ourselves.
  tauriBuildFlags = [ "--no-bundle" ];

  installPhase = ''
    runHook preInstall
    install -Dm755 \
      "$(find target -type f -executable -name poe-copilot-app | head -n1)" \
      "$out/bin/poe-copilot-app"
    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "poe-campaign-copilot";
      desktopName = "PoE Campaign Copilot";
      comment = "Passive campaign-leveling overlay for Path of Exile";
      exec = "poe-copilot-app";
      icon = "poe-campaign-copilot";
      categories = [ "Game" ];
      terminal = false;
    })
  ];

  postInstall = ''
    install -Dm644 src-tauri/icons/128x128.png \
      $out/share/icons/hicolor/128x128/apps/poe-campaign-copilot.png

    # The app loads its game data (exile-leveling routes + zone layouts) at
    # startup from a "data root" that must contain vendor/ and content/layouts/.
    # A bundled install ships these as Tauri resources; since we don't bundle,
    # install the two trees ourselves and point POE_COPILOT_DATA_ROOT at them
    # (below). Without this it panics at "content data must load".
    mkdir -p "$out/share/poe-campaign-copilot/content"
    cp -r vendor "$out/share/poe-campaign-copilot/vendor"
    cp -r content/layouts "$out/share/poe-campaign-copilot/content/layouts"
  '';

  preFixup = ''
    gappsWrapperArgs+=(
      # WebKitGTK's DMABUF renderer crashes transparent Tauri windows on AMD +
      # Wayland — the overlay would start but never map a window.
      --set-default WEBKIT_DISABLE_DMABUF_RENDERER 1
      # Where the vendored routes + layouts installed above live.
      --set-default POE_COPILOT_DATA_ROOT "$out/share/poe-campaign-copilot"
      # The tray icon lib is dlopened by soname, not linked, so it isn't in
      # the binary's RPATH — make it resolvable at runtime.
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ libayatana-appindicator ]}"
    )
  '';

  meta = {
    description = "Passive campaign-leveling overlay for Path of Exile";
    homepage = "https://github.com/andrewli8/poe-campaign-copilot";
    license = lib.licenses.mit; # confirm against the repo LICENSE
    mainProgram = "poe-copilot-app";
    platforms = lib.platforms.linux;
  };
}
