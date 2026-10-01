# nixos_slanka — the desktop (MSI MAG X870E Tomahawk, Ryzen 9950X3D, RTX 5090).
# Everything here is specific to this box's hardware or to workloads only it
# runs (GPU compute, Slippi/GameCube adapter, video editing). Shared system
# config lives in ../../configuration.nix.
{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../configuration.nix
  ];

  # The kernel drops the invalid underscore, so `hostname` reports
  # "nixosslanka" — flake.nix exports the config under both names.
  networking.hostName = "nixos_slanka";

  # Resume device for hibernate
  boot.resumeDevice = "/dev/nvme0n1p6";

  # Extra data partition, created in the free gap after /boot. Holds large,
  # relocatable data (PHMUB, build caches, local model weights) so it doesn't
  # fill / (which shares one ext4 partition with /nix).
  fileSystems."/data" = {
    device = "/dev/disk/by-uuid/f9889b12-35a4-4872-961b-a5466ebb6b64";
    fsType = "ext4";
  };

  # pcie_aspm=off removed 2026-07-12: it was added while chasing WiFi
  # enumeration failures blamed on an MT7925, but the card is a Qualcomm
  # WCN7850 (ath12k) and the real fix was BIOS "Onboard Wi-Fi/BT Module
  # Control -> Auto". If WiFi vanishes after a reboot, boot the previous
  # generation from systemd-boot and re-add "pcie_aspm=off" here.

  # IMPORTANT - NVIDIA RTX 5090 Drivers
  services.xserver.videoDrivers = [ "nvidia" ];

   hardware.nvidia = {
    package = config.boot.kernelPackages.nvidiaPackages.beta;
    modesetting.enable = true;
    open = true;  # open kernel modules (required for RTX 5090 / Blackwell)
    powerManagement.enable = true;  # clean GPU state on suspend/session switch
  };

  # Workaround for DIFR soft lockup (nvDIFRPrefetchSurfaces stuck kthread)
  # observed 2026-04-27 on Blackwell + 595.45.04-beta open modules.
  # DIFR has no direct toggle; disabling RTD3 broadens the GPU's stay-awake
  # window. Effectiveness uncertain — being monitored via difr-monitor.sh.
  boot.extraModprobeConfig = ''
    options nvidia NVreg_DynamicPowerManagement=0x00
    # The CPU-side "Ryzen HD Audio Controller" (79:00.6) has no codec wired to
    # it on this board (analog audio is the USB codec at 11:00.0-12), so
    # snd_hda_intel logged "no codecs found!" at boot and registered an empty
    # card. enable[] is indexed by probe order: NVIDIA HDMI audio (01:00.1)
    # first, then 79:00.6 - skip the second one silently.
    options snd_hda_intel enable=1,0
  '';

  # NVIDIA session env for every compositor (Hyprland's lua/env.lua sets the
  # same three itself when it sees the driver; niri and the rest get them here).
  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "nvidia";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    NVD_BACKEND = "direct";
  };

  # GPU-aware suspend guard: while ANY process holds CUDA compute, hold a
  # sleep:idle inhibitor. Catches everything the script-level inhibitors
  # don't know about (Livebook runtimes, python experiments, ad-hoc runs).
  systemd.services.gpu-suspend-inhibitor = {
    description = "Inhibit idle-suspend while GPU compute is active";
    wantedBy = [ "multi-user.target" ];
    path = [ config.hardware.nvidia.package pkgs.systemd pkgs.gnugrep ];
    script = ''
      while true; do
        if nvidia-smi --query-compute-apps=pid --format=csv,noheader 2>/dev/null | grep -q .; then
          # Hold the lock for 60s at a time while compute apps exist
          systemd-inhibit --what=sleep:idle --who=gpu-watch \
            --why="GPU compute active" sleep 60
        else
          sleep 60
        fi
      done
    '';
    serviceConfig.Restart = "always";
  };

  # Local LLM for offline troubleshooting (the 2026-09-07 WiFi-dead-after-reset
  # episode). Ollama speaks the Anthropic Messages API on :11434, so the fish
  # function `claude-local` (home.nix) runs Claude Code against it with no
  # internet. Pull the models once while online:
  #   ollama pull qwen3-coder:30b     # MoE, 3B active — fast on the 5090
  #   ollama pull qwen3:8b            # small general model for scripted jobs
  # 64k context so a repo-sized conversation fits; ~24GB VRAM at that size.
  # That is a DEFAULT, not a cap: short-lived scripted callers should pass
  # options.num_ctx themselves (notif-digest.sh does) rather than pay a 5.9GiB
  # KV cache to summarize five notifications.
  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;
    loadModels = [ "qwen3-coder:30b" "qwen3:8b" ];  # pulled on service start if missing
    # Keep the ~19GB model store off / (was /var/lib/ollama, part of the 2026-09
    # full-disk episode). The module puts `models` in ReadWritePaths, so this
    # works with the default DynamicUser. One-time move (before the rebuild):
    #   sudo systemctl stop ollama ollama-model-loader
    #   sudo mkdir -p /data/ollama && sudo cp -a /var/lib/private/ollama/models /data/ollama/
    models = "/data/ollama/models";
    # Static user instead of DynamicUser: the transient uid couldn't write the
    # root-owned /data path (2026-09-19 startup failure: "mkdir
    # /data/ollama/models/blobs: permission denied"). A stable account lets us
    # chown /data/ollama once. The module creates user+group when set.
    user = "ollama";
    group = "ollama";
    environmentVariables = {
      OLLAMA_CONTEXT_LENGTH = "65536";
      # 5m, not 30m: notif-digest.timer fires hourly, and a 30m keep-alive left
      # the previous runner still holding ~25GB of VRAM when ollama sized the
      # next load. On 2026-09-22 at 16:00 and 17:00 it therefore saw 1.7GiB
      # free, spilled 48/49 layers to system RAM (23.7GiB total, ~10GB of it
      # into swap) and ran the digest on CPU. Any value well under the 60m
      # timer gap avoids the collision.
      OLLAMA_KEEP_ALIVE = "5m";
    };
  };

  # Heal a wedged HDMI handshake at BOOT, before the greeter appears.
  # Symptom (seen 2026-07-12): the ASUS VG27V reports "no signal" from
  # power-on even though the GPU is driving it; a connector off→reprobe cycle
  # forces a fresh link train. Boot-time only: the post-S3-resume wedge is a
  # different failure (165Hz link training fails cold; connector cycling
  # doesn't help) and is handled in-session by scripts/hdmi-wake.sh
  # (60→165Hz bounce) via hypridle after_sleep_cmd and Super+Shift+H.
  # Do NOT hook this unit to post-resume.target: without After= ordering it
  # starts at suspend ENTRY, cycling the connector as the box goes down.
  systemd.services.hdmi-link-retrain = {
    description = "Cycle HDMI connector to retrain a wedged link";
    wantedBy = [ "graphical.target" ];
    before = [ "greetd.service" ];
    serviceConfig.Type = "oneshot";
    script = ''
      for i in $(seq 1 50); do
        set -- /sys/class/drm/card*-HDMI-A-1/status
        [ -e "$1" ] && break
        sleep 0.2
      done
      for st in /sys/class/drm/card*-HDMI-A-1/status; do
        [ -e "$st" ] || continue
        if [ "$(cat "$st")" = "connected" ]; then
          echo off > "$st"
          sleep 1
          echo detect > "$st"
        fi
      done
    '';
  };

  # Heal the VY279HGR (DP-2) after a DPMS-off wake. Seen 2026-09-19: the panel
  # drops its DP AUX channel in deep sleep, nvidia-modeset can't read the EDID
  # on wake and drops the connector; on reconnect the hot-plug arrives before
  # the EDID is readable, so aquamarine caches an EMPTY mode list, falls back
  # to 640x480 (kernel rejects it, EINVAL) and Hyprland shows the output as
  # 0x0@60 — black panel. aquamarine only re-reads modes on a disconnected→
  # connected edge, so nothing in-session (hl.monitor, dpms, disabled=true)
  # helps; a sysfs off→detect bounce once the kernel has the modes does.
  # Not wantedBy anything: fired on demand by scripts/dp-wake.sh (hypridle
  # on-resume / after_sleep, Super+Shift+H) via the polkit rule below.
  systemd.services.dp-link-bounce = {
    description = "Cycle DP-2 connector so the compositor re-reads its modes";
    serviceConfig.Type = "oneshot";
    script = ''
      for st in /sys/class/drm/card*-DP-2/status; do
        [ -e "$st" ] || continue
        echo off > "$st"
        sleep 2
        echo detect > "$st"
      done
    '';
  };

  # Allow blewf to fire the connector retrains on demand without sudo
  # (manual escalation: systemctl restart hdmi-link-retrain / dp-link-bounce).
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.systemd1.manage-units" &&
          (action.lookup("unit") == "hdmi-link-retrain.service" ||
           action.lookup("unit") == "dp-link-bounce.service") &&
          subject.user == "blewf") {
        return polkit.Result.YES;
      }
    });
  '';

  # Pin the NVIDIA HDMI card to the stereo profile so the TV sink
  # (alsa_output.pci-0000_01_00.1.hdmi-stereo) exists at every boot. The TV
  # is on the first HDMI port (ELD slot 0) since 2026-09-19; it used to be
  # "off" (monitors have no speakers) with mirror-toggle.sh flipping it on.
  services.pipewire.wireplumber.extraConfig."50-nvidia-hdmi-stereo" = {
    "monitor.alsa.rules" = [{
      matches = [{ "device.name" = "alsa_card.pci-0000_01_00.1"; }];
      actions.update-props = { "device.profile" = "output:hdmi-stereo"; };
    }];
  };

  # Case/motherboard RGB via OpenRGB (MSI Mystic Light USB controller 0db0:0076
  # on the MAG X870E Tomahawk). Installs udev rules and runs the SDK server so
  # the `openrgb` CLI autoconnects instead of re-detecting hardware every call.
  # `motherboard = "amd"` loads i2c-piix4/i2c-dev for RAM/GPU RGB detection.
  # Toggle keybind: Super+Shift+L (led-toggle.sh).
  services.hardware.openrgb = {
    enable = true;
    motherboard = "amd";
    # 1.0rc2 (nixpkgs) rejects this board ("No matching driver found for
    # MS-7E59"); support landed in master's MSIMysticLight761 driver
    # (gitlab issue #4910). Pin master until the next release ships it.
    # The systemd-service patch is upstream in master, so drop it.
    package = pkgs.openrgb.overrideAttrs (old: {
      version = "1.0rc2-unstable-2026-07-21";
      src = pkgs.fetchFromGitLab {
        owner = "CalcProgrammer1";
        repo = "OpenRGB";
        rev = "bd41ba3b5cb619485899b40c8ff073dcad3aa4ed";
        hash = "sha256-jITHNPieOPuhRqMghnW8NoOoL6GJmwzUWQRCW7KWzNM=";
      };
      patches = builtins.filter
        (p: !(lib.hasInfix "systemd-service" (baseNameOf p))) old.patches;
    });
  };

  # Nintendo / Mayflash GameCube controller adapter (WUP-028, 057e:0337, Wii-U
  # mode) for Slippi Dolphin. The device node otherwise comes up root-only and
  # needs a manual chown after every replug/reboot; this grants access
  # declaratively. uaccess ACLs it to the logged-in seat; MODE=0666 is the belt.
  #
  # OpenRGB SDK server holds the RGB controller's device fd for its whole
  # lifetime; when the MSI Mystic Light USB controller (0db0:0076) re-enumerates
  # (suspend/resume, USB power glitch) that fd goes stale — LEDs stop responding
  # while `openrgb -c` still exits 0. Restart the server whenever the controller
  # re-appears so it re-grabs the live handle. --no-block keeps the udev worker
  # from blocking on the restart. (See memory: openrgb-stale-handle.)
  services.udev.extraRules = ''
    SUBSYSTEM=="usb", ATTRS{idVendor}=="057e", ATTRS{idProduct}=="0337", MODE="0666", TAG+="uaccess"
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0db0", ATTR{idProduct}=="0076", RUN+="${pkgs.systemd}/bin/systemctl --no-block restart openrgb.service"
  '';

  # The udev rule above only catches a genuine unplug/replug. S3 resume instead
  # resets the controller IN PLACE (kernel: "usb 3-11: reset full-speed USB
  # device" — same devnum, no add event), which stales the fd just the same, so
  # also restart the server on every resume. led-ctl.sh resume-apply (hypridle
  # after_sleep_cmd) then re-applies the user's LED state once the SDK port is
  # back up.
  systemd.services.openrgb-resume = {
    description = "Restart OpenRGB after resume (in-place USB reset stales its device fd)";
    after = [
      "suspend.target"
      "hibernate.target"
      "hybrid-sleep.target"
      "suspend-then-hibernate.target"
    ];
    wantedBy = [
      "suspend.target"
      "hibernate.target"
      "hybrid-sleep.target"
      "suspend-then-hibernate.target"
    ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.systemd}/bin/systemctl --no-block restart openrgb.service";
    };
  };

  # Overclock the GC adapter's USB polling from 125Hz to 1000Hz (standard
  # Slippi input-lag fix, ~4-8ms average latency reduction). If inputs ever
  # drop, load with rate=2 (500Hz) via boot.extraModprobeConfig.
  boot.extraModulePackages = [ config.boot.kernelPackages.gcadapter-oc-kmod ];
  boot.kernelModules = [ "gcadapter_oc" ];

  # Steam for Rivals of Aether 1/2 (octopus workshop character project,
  # 2026-08-08). The module wires up 32-bit graphics, FHS wrapper, udev.
  programs.steam.enable = true;

  environment.systemPackages = with pkgs; [
    aseprite  # pixel art/animation for RoA workshop character

    # Game dev — PHMUB (the biota-browser branch). nixpkgs is on 4.6.1 while
    # game/project.godot declares config/features="4.7"; it runs and renders fine,
    # the editor just notes the mismatch. Bump when nixpkgs catches up to 4.7.
    godot_4

    # Video editing (to-dnxhr, the import-format converter, is in the shared config)
    davinci-resolve  # free version: no H.264/H.265/AAC *import* on Linux — use to-dnxhr first

    # rwing — Super Smash Bros. Melee replay viewer (Patreon, closed-source binary).
    # Packaged from the prebuilt Linux binary; see pkgs/rwing.nix. The binary itself is
    # non-redistributable and NOT in git — add it once with:
    #   nix-store --add-fixed sha256 rwing-linux-a2.3
    (callPackage ../../pkgs/rwing.nix { })
  ];
}
