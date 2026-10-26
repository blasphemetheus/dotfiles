# Login, greeter assets, lock-screen authentication, and the polkit agent.
{ config, pkgs, ... }:
let
  # Hyprland session command used by both greetd paths (autologin and the
  # tuigreet menu). Hyprland writes its first ~20 log lines to stdout before
  # the config turns stdout logging off (one of them is "Creating the Error
  # Overlay!"), and every exec-once child inherits the same fds, so the TTY
  # collected a screenful of noise that flashed up on the next login.
  # systemd-cat execs the compositor with stdout/stderr on the journal instead:
  # `journalctl -b -t hyprland-session`.
  hyprlandSession = pkgs.writeShellScript "hyprland-session" ''
    printf '\033[H\033[2J\033[3J'
    exec ${pkgs.systemd}/bin/systemd-cat -t hyprland-session \
      ${config.programs.hyprland.package}/bin/start-hyprland
  '';

  # Session list for the greeter: everything the display manager knows about
  # except hyprland-uwsm.desktop — the hyprland package ships that entry
  # unconditionally, and we always launch plain Hyprland.
  #
  # Default session = Hyprland. tuigreet sorts the menu by Name= with a plain
  # (case-sensitive) compare and picks index 0 when nothing is remembered, so
  # "GNOME" used to beat "Hyprland". The GNOME entries are copied with a
  # lowercase name so they sort last. The list is also exposed at the stable
  # path /etc/greeter-sessions (see environment.etc + --sessions below):
  # --remember-session stores the absolute .desktop path, and a /nix/store
  # path went stale on every rebuild, which is what kept resetting the default.
  greeterSessions = pkgs.runCommand "greeter-sessions" { } ''
    mkdir -p $out/share/wayland-sessions
    for f in ${config.services.displayManager.sessionData.desktops}/share/wayland-sessions/*.desktop; do
      case "$(basename "$f")" in
        hyprland-uwsm.desktop) ;;
        hyprland.desktop)
          sed -e 's|^Exec=.*|Exec=${hyprlandSession}|' "$f" > "$out/share/wayland-sessions/$(basename "$f")" ;;
        gnome*.desktop)
          sed -e 's/^Name=GNOME on Wayland$/Name=gnome on Wayland (fallback)/' \
              -e 's/^Name=GNOME$/Name=gnome (fallback)/' "$f" > "$out/share/wayland-sessions/$(basename "$f")" ;;
        *) ln -s "$f" "$out/share/wayland-sessions/" ;;
      esac
    done
  '';

  # tuigreet launcher: ASCII banner + one random (real) quote per boot.
  # Quotes live in greeter/quotes.txt — add lines there, rebuild to apply.
  # greet-align stays left: tuigreet centers each greeting line separately,
  # which would shear the ASCII art; the banner file carries its own indent.
  # Banner/quotes are read from /etc/greeter (environment.etc below) so the
  # hyprlock lock screen shows the same files (scripts/greeter-{banner,quote}.sh).
  greeterLaunch = pkgs.writeShellScript "tuigreet-launch" ''
        # Wipe tty1 (screen + scrollback). greetd never clears the VT between
        # sessions, and tuigreet draws on the alternate screen, so whatever the
        # previous compositor left on the main screen (its startup lines, stray
        # stderr from autostarted apps, a kernel segfault line) reappeared for a
        # second when tuigreet exited and the next session started.
        printf '\033[H\033[2J\033[3J'
        banner="$(${pkgs.coreutils}/bin/cat /etc/greeter/banner.txt)"
        quote="$(${pkgs.gnugrep}/bin/grep -Ev '^[[:space:]]*(#|$)' /etc/greeter/quotes.txt \
          | ${pkgs.coreutils}/bin/shuf -n 1 \
          | ${pkgs.coreutils}/bin/fold -s -w 72)"
        exec ${pkgs.tuigreet}/bin/tuigreet \
          --time --time-format '%I:%M %p  |  %A, %B %d' \
          --remember --remember-session --user-menu \
          --width 80 --window-padding 1 --container-padding 2 --greet-align left \
          --power-shutdown 'systemctl poweroff' \
          --power-reboot 'systemctl reboot' \
          --theme 'border=yellow;title=yellow;greet=magenta;time=white;prompt=yellow;input=white;action=magenta;button=yellow;container=black' \
          --greeting "$banner

    $quote" \
          --sessions /etc/greeter-sessions
  '';
in
{
  # Display manager — greetd + tuigreet (GDM core-dumps with NVIDIA open modules)
  services.greetd = {
    enable = true;
    settings = {
      # Boot → straight into Hyprland, which locks itself immediately
      # (hyprland.conf exec-once on HYPR_AUTOLOGIN_LOCK; hyprlock is the
      # login screen). No password is taken here, so the keyring is unlocked
      # by hyprlock's PAM stack instead — see security.pam.services.hyprlock.
      initial_session = {
        command = "${pkgs.writeShellScript "hyprland-autologin" ''
          export HYPR_AUTOLOGIN_LOCK=1
          exec ${hyprlandSession}
        ''}";
        user = "blewf";
      };
      # After logout (or if the session dies) greetd falls back to tuigreet.
      default_session = {
        command = "${greeterLaunch}";
        user = "greeter";
      };
    };
  };
  # Stable paths for tuigreet's session list and the shared banner/quotes
  # (see greeterSessions / greeterLaunch above; hyprlock reads the same files).
  environment.etc."greeter-sessions".source = "${greeterSessions}/share/wayland-sessions";
  environment.etc."greeter/banner.txt".source = ../../greeter/banner.txt;
  environment.etc."greeter/quotes.txt".source = ../../greeter/quotes.txt;

  # Give hyprlock its own PAM stack. Without /etc/pam.d/hyprlock it falls
  # back to the `su` stack, which includes pam_faillock: three typos at the
  # lockscreen would lock the ACCOUNT for 10 minutes on top of the screen —
  # journal showed `pam_unix(su:auth)` entries from exactly this fallback.
  # enableGnomeKeyring: with greetd autologin nobody types a password at
  # session start, so the first hyprlock unlock is what opens the keyring
  # (pam_gnome_keyring auth against the already-running daemon).
  security.pam.services.hyprlock = {
    enableGnomeKeyring = true;
  };

  # Polkit authentication agent (for privilege escalation prompts in Hyprland)
  systemd.user.services.polkit-gnome-agent = {
    description = "Polkit GNOME Authentication Agent";
    wantedBy = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
      # At logout the compositor socket is gone; without this the agent
      # restart-looped ("cannot open display") until systemd hit the start
      # limit. A failing ExecCondition stops the unit cleanly, no restart.
      ExecCondition = "${pkgs.bash}/bin/sh -c 'test -S \"$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY\"'";
      Restart = "on-failure";
      RestartSec = 1;
    };
  };

}
