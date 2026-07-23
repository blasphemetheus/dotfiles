# hyprexpo — expo-style workspace overview.
#
# hyprwm abandoned the original and removed it from hyprland-plugins (#663);
# sandwichfarm/hyprexpo is the maintained fork. Its master has already moved to
# Hyprland 0.56 (which our pinned 0.55.4 compositor can't load), and the flake
# was only added alongside that 0.56 port — so the last 0.55.x release tag
# (v0.55.4) has no flake.nix. We package that tag by hand and build it against
# the flake Hyprland passed in as `hyprlandPkg`, the same way KZDKM/Hyprspace's
# own flake builds: reuse the compositor's build inputs so headers/ABI match.
{
  stdenv,
  fetchFromGitHub,
  pkg-config,
  lua5_4,
  hyprlandPkg,
}:
stdenv.mkDerivation {
  pname = "hyprexpo";
  version = "0.55.4";

  src = fetchFromGitHub {
    owner = "sandwichfarm";
    repo = "hyprexpo";
    rev = "v0.55.4";
    hash = "sha256-sERoTu9NcGD0RA3jAdHc4GOPkRbgqMrgDT8f7+Jv9fc=";
  };

  nativeBuildInputs = [ pkg-config ] ++ hyprlandPkg.nativeBuildInputs;
  buildInputs = [ lua5_4 hyprlandPkg ] ++ hyprlandPkg.buildInputs;

  # There is a CMakeLists.txt too, but we build via the Makefile.
  dontConfigure = true;

  # Pin the baked version so the Makefile's scripts/version.sh — which shells
  # out to git for a "-dev+<hash>" suffix — is never invoked in the sandbox.
  buildPhase = ''
    runHook preBuild
    make all VERSION=v0.55.4 VERSION_BASE=v0.55.4
    runHook postBuild
  '';

  # Makefile emits hyprexpo.so; install as lib*.so to match the flake master's
  # output name, so the /etc plugin path is stable if we ever move to the flake.
  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib
    cp hyprexpo.so $out/lib/libhyprexpo.so
    runHook postInstall
  '';
}
