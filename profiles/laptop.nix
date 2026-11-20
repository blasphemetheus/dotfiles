{ lib, ... }:
{
  dotfiles.profile = "laptop";
  dotfiles.power = {
    lockSeconds = lib.mkDefault 300;
    screenOffSeconds = lib.mkDefault 600;
    sleepSeconds = lib.mkDefault 1200;
    hibernate = lib.mkDefault true;
    hibernateDelay = lib.mkDefault "2h";
  };
  zramSwap.enable = lib.mkDefault true;
  services.fwupd.enable = lib.mkDefault true;

  # Local model server for pooter (AGENT-DESKTOP.md), shared by every account on
  # the machine. CPU build on purpose: on the Aspire's Radeon 610M the Vulkan build
  # read prompts faster but wrote answers slower, and lost overall for 3-4B routers
  # (pooter's evals/RESULTS.md, 2026-11-13). granite4.1:3b is pooter's default
  # router: ~2 GB on disk, pulled on the service's first start; ~2 GB of RAM while
  # loaded, freed after the keep-alive (pooter asks for 30 min).
  services.ollama = {
    enable = lib.mkDefault true;
    loadModels = [ "granite4.1:3b" ];
  };
}
