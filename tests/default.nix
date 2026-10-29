{ pkgs, nixosConfigurations }:
let
  hostCheck =
    name: role: normal: critical:
    let
      cfg = nixosConfigurations.${name}.config;
      power = cfg.dotfiles.power;
      # Force the full NixOS toplevel evaluation, including NixOS assertions,
      # without requiring a complete build (or the private rwing source).
      evaluated = cfg.system.build.toplevel.drvPath;
    in
    assert cfg.dotfiles.profile == role;
    assert
      role != "laptop"
      || (
        cfg.services.logind.settings.Login.HandleLidSwitch == normal
        && cfg.services.logind.settings.Login.HandleLidSwitchExternalPower == normal
        && cfg.systemd.sleep.settings.Sleep.HibernateDelaySec == "2h"
        && cfg.systemd.sleep.settings.Sleep.HibernateMode == "shutdown"
        && cfg.services.upower.enable
        && cfg.services.upower.criticalPowerAction == "Hibernate"
        && cfg.services.upower.percentageAction == 2
        && power.lockSeconds == 300
        && power.sleepSeconds == 1200
      );
    assert role != "desktop" || (power.lockSeconds == 1500 && power.sleepSeconds == 2400);
    pkgs.runCommand "validate-${name}"
      {
        nativeBuildInputs = [ pkgs.jq ];
        # String context is deliberately discarded: this is evaluation, not a
        # hidden dependency on the entire system closure.
        evaluatedSystem = builtins.unsafeDiscardStringContext evaluated;
      }
      ''
        test "$(${power.package}/bin/session-sleep --dry-run)" = '${normal}'
        test "$(${power.package}/bin/session-sleep --dry-run critical)" = '${critical}'
        if ${power.package}/bin/session-sleep --dry-run invalid; then exit 1; fi
        jq -e '.profile == "${role}" and .sleepAction == "${normal}" and .criticalAction == "${critical}"' \
          ${cfg.environment.etc."dotfiles/power.json".source}
        grep -F 'timeout = ${toString power.lockSeconds}' ${
          cfg.environment.etc."dotfiles/hypridle.conf".source
        }
        grep -F 'timeout = ${toString power.screenOffSeconds}' ${
          cfg.environment.etc."dotfiles/hypridle.conf".source
        }
        grep -F 'timeout = ${toString power.sleepSeconds}' ${
          cfg.environment.etc."dotfiles/hypridle.conf".source
        }
        grep -F '${power.package}/bin/session-sleep' ${cfg.environment.etc."dotfiles/hypridle.conf".source}
        printf '%s\n' "$evaluatedSystem" > "$out"
      '';
in
{
  desktop = hostCheck "nixos_slanka" "desktop" "suspend" "poweroff";
  laptop = hostCheck "aspire" "laptop" "suspend-then-hibernate" "hibernate";

  hyprlock-pam =
    let
      hostPkgs = nixosConfigurations.nixos_slanka.pkgs;
    in
    assert hostPkgs.hyprlock.outPath == nixosConfigurations.aspire.pkgs.hyprlock.outPath;
    hostPkgs.runCommand "validate-hyprlock-pam"
      { nativeBuildInputs = [ hostPkgs.glibc.bin hostPkgs.python3 ]; }
      ''
        # PAM loads system modules at authentication time. A standalone locker
        # built with an older libc can start normally yet fail every unlock.
        ldd ${hostPkgs.hyprlock}/bin/hyprlock | grep -F '${hostPkgs.glibc}/lib/libc.so.6'
        python3 - <<'PY'
        import ctypes
        for module in ("pam_unix", "pam_env"):
            ctypes.CDLL("${hostPkgs.pam}/lib/security/" + module + ".so")
        PY
        touch "$out"
      '';

  input-age =
    pkgs.runCommand "validate-input-age"
      {
        nativeBuildInputs = [
          pkgs.jq
          (pkgs.callPackage ../pkgs/flake-input-age.nix { })
        ];
      }
      ''
        bash ${./input-age.sh} ${../scripts/flake-input-age.jq}
        flake-input-age --json ${../flake.lock} | jq -e 'length > 0 and all(.[]; .ageDays == null or .ageDays >= 0)'
        flake-input-age ${../flake.lock} | grep 'nixpkgs:.*locked source'
        touch "$out"
      '';

  health-scripts =
    let
      aspire = nixosConfigurations.aspire.config;
      services = aspire.home-manager.users.${aspire.dotfiles.user.name}.systemd.user.services;
      hints = builtins.head services.nixos-health-hints.Service.ExecStart;
      advisor = pkgs.lib.last (
        pkgs.lib.splitString " " (builtins.head services.nixos-setup-advisor.Service.ExecStart)
      );
    in
    pkgs.runCommand "validate-health-scripts" { } ''
      # Building these writeShellApplications runs their generated-script
      # ShellCheck checks; don't actually send notifications or run the advisor.
      test -x ${hints}
      test -x ${advisor}
      touch "$out"
    '';

  shell =
    pkgs.runCommand "validate-shell"
      {
        nativeBuildInputs = [ pkgs.shellcheck ];
      }
      ''
        shellcheck ${../scripts/validate.sh} \
          ${../tests/input-age.sh} \
          ${../hypr/.config/hypr/scripts/start-idle.sh} \
          ${../hypr/.config/hypr/scripts/battery-monitor.sh}
        touch "$out"
      '';
}
