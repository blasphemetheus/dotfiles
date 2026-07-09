{ stdenv, autoPatchelfHook, makeWrapper, writeShellScriptBin, lib, requireFile
, jq, coreutils
, glib, gtk3, gdk-pixbuf, cairo, pango, harfbuzz, at-spi2-core
, fribidi, graphite2, libthai, libdatrie, fontconfig, freetype, libjpeg, libpng, pixman
, libepoxy, wayland, libxkbcommon, libGL, libglvnd, vulkan-loader
, dbus, expat, libffi, brotli, bzip2, pcre2, util-linux, libselinux, systemd
, json-glib, tinysparql, libxml2, zlib, openssl
, libx11, libxcb, libxcursor, libxi, libxrandr
, libxrender, libxext, libxfixes, libxdamage, libxcomposite, libxinerama }:
let
  # ── bump these two for a new release (or run scripts/update-rwing.sh) ──
  version = "a2.3";
  # `nix hash file rwing-linux-<version>`
  hash = "sha256-6BuQQItReOa2xnoMV7xR2yYCdWNrkqNRic/s+VkQf94=";

  # rwing is a Rust app: winit 0.30 (X11-only) + wgpu/vello for GPU rendering + rfd (GTK) dialogs.
  # It links GTK3 directly (DT_NEEDED) but wgpu/winit dlopen libs by soname (vulkan-loader, libGL,
  # libwayland-*) at runtime — so they must be in buildInputs (autoPatchelf RPATH) AND on
  # LD_LIBRARY_PATH (for the dlopens). vulkan-loader + /run/opengl-driver/lib put wgpu on the NVIDIA
  # GPU (verified: rwing shows up in nvidia-smi) instead of falling back to llvmpipe.
  libs = [
    stdenv.cc.cc.lib zlib openssl
    glib gtk3 gdk-pixbuf cairo pango harfbuzz at-spi2-core
    fribidi graphite2 libthai libdatrie fontconfig freetype libjpeg libpng pixman
    libepoxy wayland libxkbcommon libGL libglvnd vulkan-loader
    dbus expat libffi brotli bzip2 pcre2 util-linux libselinux systemd
    json-glib tinysparql libxml2
    libx11 libxcb libxcursor libxi libxrandr
    libxrender libxext libxfixes libxdamage libxcomposite libxinerama
  ];

  # Patched binary + env wrapper. `--argv0 rwing` fixes the X11 WM_CLASS: winit takes it from argv[0],
  # so without this the window class is `.rwing-unwrapped` (breaks Hyprland window-rule matching).
  core = stdenv.mkDerivation {
    pname = "rwing-unwrapped";
    inherit version;

    # rwing is paywalled / non-redistributable, so it can't be committed to the (public) dotfiles repo
    # or fetched by URL. requireFile keeps the flake pure: add the binary to the store once with
    #   nix-store --add-fixed sha256 rwing-linux-<version>
    # then this resolves it by hash.
    src = requireFile {
      name = "rwing-linux-${version}";
      inherit hash;
      message = ''
        rwing is closed-source and distributed via Patreon. Download the Linux build
        (rwing-linux-${version}) from https://patreon.com/rwing_aitch, then add it to the store:
          nix-store --add-fixed sha256 rwing-linux-${version}
      '';
    };
    dontUnpack = true;

    nativeBuildInputs = [ autoPatchelfHook makeWrapper ];
    buildInputs = libs;

    installPhase = ''
      runHook preInstall
      install -Dm755 $src $out/bin/.rwing-unwrapped
      # WINIT_X11_SCALE_FACTOR=1 pins winit to 1:1 (sane default; does NOT fix the click offset — see
      # the launcher below). GDK_BACKEND=wayland only affects the GTK (rfd) file dialogs.
      makeWrapper $out/bin/.rwing-unwrapped $out/bin/rwing \
        --argv0 rwing \
        --set-default WINIT_X11_SCALE_FACTOR 1 \
        --set-default GDK_BACKEND wayland \
        --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath libs}:/run/opengl-driver/lib"
      runHook postInstall
    '';

    meta = {
      description = "Advanced Super Smash Bros. Melee replay viewer (Patreon, closed-source)";
      homepage = "https://melee.cool/rwing/";
      platforms = [ "x86_64-linux" ];
      sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    };
  };
in
# Launcher: start rwing, then issue ONE post-map move so winit re-reads its geometry. winit/XWayland
# maps the window with the wrong geometry every time, causing a click-coordinate offset that grows
# toward the bottom; any configure event (move/resize/float-toggle) re-syncs it — this automates the
# Super+Arrow nudge. Requires the `rwing` float window-rule in Hyprland (so the move is honoured) and
# is a harmless no-op outside Hyprland.
writeShellScriptBin "rwing" ''
  if command -v hyprctl >/dev/null 2>&1; then
    (
      addr=""
      for _ in $(${coreutils}/bin/seq 1 250); do
        addr=$(hyprctl clients -j 2>/dev/null | ${jq}/bin/jq -r 'first(.[]|select(.class=="rwing"))|.address // empty' 2>/dev/null || true)
        [ -n "$addr" ] && break
        ${coreutils}/bin/sleep 0.2
      done
      if [ -n "$addr" ]; then
        ${coreutils}/bin/sleep 0.3
        hyprctl dispatch movewindowpixel "exact 968 50,address:$addr" >/dev/null 2>&1 || true
      fi
    ) &
  fi
  exec ${core}/bin/rwing "$@"
''
