# Hyprland crash dossier

Running record of compositor crashes on `nixosslanka`, what caused each one,
and what was done. Kept so the next "Hyprland just loaded in safe mode" has a
starting point instead of a cold investigation.

Where the evidence lives:

| What | Where |
|---|---|
| Hyprland's own crash report (backtrace, plugins, version) | `~/.cache/hyprland/hyprlandCrashReport<PID>.txt` |
| Compositor debug log for the session | `~/.local/state/hyprland/hyprland-<date>.log` (`latest.log` symlink; note it is NOT re-pointed when the watchdog relaunches) |
| Kernel-side core dump with full thread stacks | `coredumpctl list`, `coredumpctl info <PID>` |
| Journal lines from the compositor | `journalctl --user -b -t hyprland` |

"Safe mode" = Hyprland 0.56's crash handler re-exec'd itself as
`Hyprland --watchdog-fd N --safe-mode` (check with `pgrep -a Hyprland`).
It is a fresh compositor, so every client that was alive at the crash
(hypridle, awww-daemon, waybar, …) lost its Wayland socket and usually dumped
core too. Those secondary dumps are collateral, not separate bugs. Recover
with `hyprctl dispatch exit`; greetd autologin + hyprlock brings up a normal
session.

---

## The output-teardown race family (crashes #1–#6)

Every compositor crash on this machine so far is the same family: a DRM
output (almost always DP-2 = VY279HGR, which sits behind a DP→HDMI adapter and
drops its hotplug line going into deep sleep) disconnects, aquamarine tears the
output down, and either aquamarine or Hyprland then touches state belonging to
the dead output. Which function crashes depends on which callback fires first.

| # | Date | Version | Trigger | Crash site | Status |
|---|---|---|---|---|---|
| 1–3 | 2026-08-01, 08-09, 08-10 | 0.55.4 | DP-2 link flap at DPMS wake | aquamarine output teardown (via `aquamarineFDWrite`) | Fixed by bumping to 0.56.2 (flake.nix) |
| 4 | 2026-08-30 | 0.56.2 + aquamarine 0.14.0 | DP-2 link flap at DPMS wake | `CBackend::dispatchIdle` (stale idle callback) | Fixed by overriding aquamarine to 0.15.0 → 0.15.1 (flake.nix) |
| 5 | 2026-10-17 16:15 | 0.56.2 + aquamarine 0.15.1 | Compositor exit while DP-2 was wedged | `CDRMBackend::~CDRMBackend → SDRMConnector::disconnect → cancelAsyncOutput → flushAsyncCommitEvents` | Open. Shutdown-path only, no crash-report file written. Low impact |
| 6 | 2026-10-25 21:12 | 0.56.2 + aquamarine 0.15.1 | **Hot-unplugging DP-2's HDMI leg mid-session** | `IHyprRenderer::damageMirrorsWith ← renderMonitor ← CMonitorFrameScheduler::onFrame ← CDRMBackend::handlePageFlip` | **Open.** This is the one that put the session in safe mode |

### Crash #6 in detail

Sequence from `hyprland-2026-10-17_175740.log` lines 53642–53657:

```
drm: Connector DP-2 disconnected
drm: Disabled KMS output DP-2 before disconnect
ERR drm: Cannot commit a disconnected output
drm: DP-2 is not connected, clearing stale crtc 100
```

Then a page-flip event for the already-torn-down output reached the frame
scheduler, which called `renderMonitor` and segfaulted in
`damageMirrorsWith`. Points worth knowing:

- **A mirror WAS involved.** Earlier in the session hyprdisplays mirrored DP-2
  onto the TV (HDMI-A-1); the log shows HDMI-A-1 re-enabled at line 53114,
  shortly before the fatal DP-2 disconnect, and both desk monitors had been
  through DPMS sleep/wake cycles with that mirror in place. So DP-2's
  `m_mirrors` held the TV. This is exactly upstream #16115 (mirror configured,
  one side disconnects mid-session). Two latent bugs in v0.56.2 make it fatal:
  - `src/render/Renderer.cpp:2820` `damageMirrorsWith` dereferences each
    weak pointer (`mirror->addDamage`) *before* `.lock()`ing it.
  - `src/output/Monitor.cpp:439-445` `onDisconnect` range-for's over
    `m_mirrors` while each `m->setMirror("")` erases from that same vector
    (`Monitor.cpp:1354`), and both `erase(find_if(...))` sites never check for
    `end()`. Iterating a vector you are erasing from is UB and leaves stale
    entries behind.
  A mirror set via hyprdisplays is a monitor *rule*, so the `scheduleReload()`
  in `onDisconnect` re-applies it on every DP-2 reconnect. Every deep-sleep
  flap re-ran this code path.
- Log forensics are thin: Hyprland does not log mirror rule application, so
  `grep -i mirror` on the compositor log finds nothing. Reconstruct mirror
  history from HDMI-A-1 enable/disable lines and the user's memory.
- **This session had 34 DP-2 disconnect events** before the fatal one (deep
  sleep flaps plus `dp-wake.sh` / `dp-link-bounce.service` bounces). Each one
  is a roll of the same dice. The hot-unplug just happened to lose.
- Upstream has an identical report: hyprwm/Hyprland#16115 "Crash in
  damageMirrorsWith after mirrored monitor (HDMI-A-1) disconnects
  mid-session" (0.56.2, 2026-09-02). It was auto-closed because the repo no
  longer accepts issues; there is no linked fix. `damageMirrorsWith` is
  byte-identical on `main` as of 2026-10-25, so **no release fixes this yet.**
  `main` does carry adjacent monitor-removal fixes since 0.56.2
  (`render: guard monitor reentry` 2026-10-02, screenshare crash on stale
  monitors #16451 / #16533, floating-client reconnect #16596) that may
  change the timing.
- The crash report lists hyprexpo as a loaded plugin, so upstream will blame
  the plugin first. The backtrace has no plugin frames.

### Collateral from #6 (not bugs to chase)

- `awww-daemon` SIGABRT (Rust `unwrap` panic when the socket died)
- `hypridle` SIGABRT
- Safe-mode Hyprland still shows hyprexpo in `hyprctl plugin list`, so safe
  mode on 0.56 is not plugin-free. Don't rely on it to rule out plugins.

---

## Next steps (proactive)

In rough order of value per effort.

1. **Clear mirrors before sleeping or unplugging.** A mirror that outlives
   a DPMS cycle or a hot-unplug of either side is the trigger. Toggle it off
   (Super+Shift+T / hyprdisplays) when done, and disable an output before
   pulling its cable. Until the patch lands, treat "mirror + monitor sleep"
   as a known crasher.

2. **Get line-level backtraces for the next one.** The nix Hyprland has no
   build-id and no debug info, so `coredumpctl debug` resolves nothing. The
   upstream flake exports `packages.hyprland-debug`. Switch
   `modules/system/compositors.nix` to it (same ABI for hyprsplit/hyprexpo?
   verify: plugins are built against `inputs.hyprland` and `hyprland-debug`
   is a separate derivation, so the plugin flake inputs would also need to
   point at the debug package, or build them yourself). Cheaper alternative:
   `overrideAttrs (o: { separateDebugInfo = true; })` on the existing package
   and install the `debug` output. One confirmed line number is worth more to
   upstream than six crash reports.

3. **Carry a local patch until upstream fixes it.** Minimal hardening in
   `src/render/Renderer.cpp` `damageMirrorsWith`:
   lock the weak pointer first, skip if null, and iterate over a copy of
   `m_mirrors`. And in `src/output/Monitor.cpp` `onDisconnect` /
   `setMirror`, check `find_if` against `end()` before `erase`. Add via
   `overrideAttrs (o: { patches = (o.patches or []) ++ [ ./pkgs/hyprland-mirror-uaf.patch ]; })`
   in `compositors.nix`. Given the mirror history, this patch very likely
   fixes the actual crash rather than moving it. Also iterate over a copy of
   `m_mirrors` in `onDisconnect`.

4. **Report upstream as a Discussion**, not an issue (issues are locked).
   Reference #16115, attach `hyprlandCrashReport64644.txt`, state the mirror
   history (DP-2 → HDMI-A-1 via monitor rule, multiple DPMS cycles, then
   DP-2 hot-unplug) and that hyprexpo has no frames in the trace. Note
   hyprwm's AI policy: file it yourself, in your own words.

5. **Consider pinning Hyprland `main`** (a specific commit) instead of
   v0.56.2. Last tag is 2026-08-05; `main` has two months of monitor-removal
   fixes. Cost: hyprsplit (Lua lib) and hyprexpo (sandwichfarm fork) must
   follow the same commit, and 0.57-era changes may break them (see memory
   note on 0.56 breaking hyprsplit+hyprspace). Try in the nested-Hyprland
   test recipe first.

6. **Reduce the flap count.** 34 DP-2 disconnects in 8 days means the
   deep-sleep wedge machinery is doing a lot of bouncing. Options: keep DP-2
   from entering DPMS (hypridle `dpms off` only for DP-3), or lengthen the
   bounce so each wake is one clean disconnect/reconnect instead of several.
   Fewer teardowns = fewer chances for the race.

7. **Fix `latest.log`.** The watchdog relaunch does not re-point the symlink,
   so after a safe-mode relaunch `latest.log` is the *crashed* session's log.
   Useful for forensics, misleading for live debugging. Nothing to do except
   know it.

---

## Other crashers seen in `coredumpctl` (2026-10)

Checked while investigating #6. None are compositor bugs.

| Process | When | Cause | Status |
|---|---|---|---|
| hyprlock ×5 | 2026-10-17 16:12–16:15 | `malloc_printerr` inside `enqueueForceUpdateTimers`: heap corruption from the PAM/glibc ABI mismatch | Fixed by commit a384436 (hyprlock from system nixpkgs). No recurrence since |
| waybar ×5 | 2026-10-20, 10-22 | `std::terminate` in `modules::hyprland::IPC::~IPC` during `exit()`. Happens on `pkill waybar` restarts | Benign (exit path). Upstream waybar bug; not worth local work |
| rustc, appimage, melee_core | various | Unrelated userland | Ignore |

---

## Checklist when it happens again

1. `pgrep -a Hyprland` — confirm `--safe-mode`.
2. `ls -t ~/.cache/hyprland/ | head -1` — read the new crash report; note
   version, plugins, top 3 frames.
3. `coredumpctl list --since -1h` — note which clients died with it.
4. `grep -n "Connector .* disconnected" ~/.local/state/hyprland/<log>` —
   find the teardown just before the crash; which output, and how many
   disconnects this session.
5. Add a row to the table above.
6. `hyprctl dispatch exit` to get a normal session back.
