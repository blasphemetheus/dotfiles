{ stdenvNoCC, fetchurl, dpkg, buildFHSEnv, appimageTools, lib
, tpm2-tss, libnotify, libcanberra-gtk3, libusb1, xdg-utils, xz, git }:
let
  # ── bump these two for a new release ──
  #   curl -s https://persistent.oaistatic.com/codex-app-prod/linux/deb/dists/stable/main/binary-amd64/Packages \
  #     | grep -E '^(Version|SHA256)'
  # (nixpkgs' `chatgpt` is the aarch64-darwin build only — this is OpenAI's official Linux .deb.)
  version = "26.917.62051";
  sha256 = "75536e3f197c6db8881a634f8bb9b0515184a8eff7cec9be5f408d0f4ae6e696";

  # Unpacked bundle, left unpatched: it ships ~40 prebuilt ELFs (Electron, codex, rg, node, tectonic,
  # native .node modules incl. musl/arm prebuilds) — the FHS env below is simpler than autoPatchelf.
  bundle = stdenvNoCC.mkDerivation {
    pname = "chatgpt-bundle";
    inherit version;
    src = fetchurl {
      url = "https://persistent.oaistatic.com/codex-app-prod/linux/deb/pool/main/c/chatgpt/chatgpt_${version}_amd64.deb";
      inherit sha256;
    };
    nativeBuildInputs = [ dpkg ];
    dontUnpack = true;
    dontStrip = true;
    dontPatchELF = true;
    installPhase = ''
      runHook preInstall
      dpkg-deb -x $src $out
      runHook postInstall
    '';
  };
in
buildFHSEnv (appimageTools.defaultFhsEnvArgs // {
  pname = "chatgpt";
  inherit version;

  targetPkgs = pkgs: (appimageTools.defaultFhsEnvArgs.targetPkgs pkgs) ++ [
    tpm2-tss libnotify libcanberra-gtk3 libusb1 xdg-utils xz git
  ];

  # Electron picks Wayland itself via ELECTRON_OZONE_PLATFORM_HINT/NIXOS_OZONE_WL if set; the
  # codex-launcher also reads extra flags from ~/.config/chatgpt-flags.conf.
  runScript = "${bundle}/usr/lib/chatgpt/codex-launcher";

  extraInstallCommands = ''
    install -Dm644 ${bundle}/usr/share/pixmaps/chatgpt.png $out/share/pixmaps/chatgpt.png
    # Drop the http/https handler claim so it can't become the default browser.
    sed -e 's|x-scheme-handler/http;x-scheme-handler/https;||' \
      ${bundle}/usr/share/applications/chatgpt.desktop \
      | install -Dm644 /dev/stdin $out/share/applications/chatgpt.desktop
  '';

  meta = {
    description = "ChatGPT desktop app (ChatGPT, Work, Codex) — official Linux preview build";
    homepage = "https://chatgpt.com/download";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "chatgpt";
  };
})
