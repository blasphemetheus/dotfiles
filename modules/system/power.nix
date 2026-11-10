{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.power;
  laptop = config.dotfiles.profile == "laptop";
  sleepAction = if cfg.hibernate then "suspend-then-hibernate" else "suspend";
  criticalAction = if cfg.hibernate then "hibernate" else "poweroff";
  sessionSleep = pkgs.writeShellApplication {
    name = "session-sleep";
    runtimeInputs = [ pkgs.systemd ];
    text = ''
      dry_run=false
      if [[ "''${1:-}" == --dry-run ]]; then dry_run=true; shift; fi
      if [[ $# -gt 1 ]]; then echo "Too many arguments" >&2; exit 2; fi
      case "''${1:-normal}" in
        normal) action=${sleepAction} ;;
        critical) action=${criticalAction} ;;
        *) echo "Usage: session-sleep [--dry-run] [normal|critical]" >&2; exit 2 ;;
      esac
      if "$dry_run"; then printf '%s\n' "$action"; else exec systemctl "$action"; fi
    '';
  };
in
{
  options.dotfiles = {
    profile = lib.mkOption {
      type = lib.types.enum [
        "laptop"
        "desktop"
      ];
      description = "Machine role, selected by importing a profile.";
    };
    power = {
      lockSeconds = lib.mkOption { type = lib.types.ints.positive; };
      screenOffSeconds = lib.mkOption { type = lib.types.ints.positive; };
      sleepSeconds = lib.mkOption { type = lib.types.ints.positive; };
      hibernate = lib.mkOption {
        type = lib.types.bool;
        description = "Use disk hibernation for delayed sleep and critical battery.";
      };
      hibernateDelay = lib.mkOption {
        type = lib.types.str;
        default = "2h";
      };
      package = lib.mkOption {
        type = lib.types.package;
        readOnly = true;
        description = "Profile-aware sleep command, also exposed for validation.";
      };
    };
  };

  config = {
    dotfiles.power.package = sessionSleep;
    assertions = [
      {
        assertion = !cfg.hibernate || (config.swapDevices != [ ] && config.boot.resumeDevice != "");
        message = "The hibernating profile needs disk swap and an explicit boot.resumeDevice.";
      }
      {
        assertion = cfg.sleepSeconds > cfg.lockSeconds && cfg.sleepSeconds > cfg.screenOffSeconds;
        message = "Idle sleep must follow both screen locking and screen power-off.";
      }
    ];

    environment.systemPackages = [ sessionSleep ];
    environment.etc."dotfiles/power.json".text = builtins.toJSON {
      inherit (config.dotfiles) profile;
      inherit sleepAction criticalAction;
      inherit (cfg) lockSeconds screenOffSeconds sleepSeconds;
    };
    # Keep the shared live-edit config for hooks; replace only its three
    # listener timeouts/actions in the generated, host-specific config.
    environment.etc."dotfiles/hypridle.conf".text =
      builtins.replaceStrings
        [ "timeout = 900" "timeout = 1500" "timeout = 2400" "systemctl suspend" ]
        [
          "timeout = ${toString cfg.screenOffSeconds}"
          "timeout = ${toString cfg.lockSeconds}"
          "timeout = ${toString cfg.sleepSeconds}"
          "${sessionSleep}/bin/session-sleep"
        ]
        (builtins.readFile ../../hypr/.config/hypr/hypridle.conf);

    services.logind.settings.Login = lib.mkIf laptop {
      HandleLidSwitch = sleepAction;
      HandleLidSwitchExternalPower = sleepAction;
      # Preserve an external-monitor/dock session when the lid closes.
      HandleLidSwitchDocked = "ignore";
    };
    # Backstop the 3% session-script action even at the greeter or in another
    # compositor. Never let UPower's default HybridSleep keep draining RAM.
    services.upower = lib.mkIf laptop {
      enable = true;
      usePercentageForPolicy = true;
      percentageLow = 20;
      percentageCritical = 5;
      percentageAction = 2;
      criticalPowerAction = if cfg.hibernate then "Hibernate" else "PowerOff";
    };
    systemd.sleep.settings.Sleep = lib.mkIf cfg.hibernate {
      HibernateDelaySec = cfg.hibernateDelay;
    };
  };
}
