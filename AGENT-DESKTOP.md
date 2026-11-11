# Agent Desktop — future direction

A theorized direction, not a plan of record. Written 2026-11-11.

## The idea

You open the computer and the first thing there is not a desktop, it's a **place to say
what you want**: by voice or by typing, in plain English. A language model turns that
into actions on the machine (open things, arrange them, run commands, change settings,
write code), and the rest of the desktop — windows, animations, the pretty parts other
people have built — is still there, opened *from* that surface instead of in place of it.

Today the model is an app you go to (a terminal running `claude`, a browser tab). The idea
is to make it the thing the session is organized around, the way the shell was before
desktops. Claude Cowork and others are exploring the same space; this is the personal,
hackable, NixOS-flavored version to experiment with.

## What already exists in this repo

More of the pieces are here than it looks:

| Piece | Where | What it gives |
|---|---|---|
| Dictation | `hyprwhspr-rs` (`configuration.nix`), `hyprwhspr/` config, `scripts/dictation.sh` | Speech → text into any focused window; Parakeet on CPU, resident model |
| Voice commands | `hypr/.config/hypr/scripts/voice-command.sh` (Super+U, desktop) | Speech → whisper → local LLM → **one allowlisted command**. LLM output is parsed as data, never shelled |
| Status pills | `ags/.config/ags/widget/{Dictation,Command}Pill.tsx` | Animated, click-through overlays for listening / thinking / done |
| Background agents | `scripts/agent-watchers.sh`, the health advisor | `claude -p` with **no tools** turning logs into prose reports |
| Coding agents | `claude`, `codex`, `opencode` | Full agents in a terminal, with permission prompts |
| Rollback | NixOS generations | Any system change the agent makes through the flake can be undone |

What's missing is the **middle**: something between "one of eight toggles" (voice-command)
and "an unrestricted coding agent in a terminal" (claude), that is the default surface
of the session.

## Principles

1. **The model proposes, something deterministic disposes.** Keep voice-command's rule:
   model output is data. It's matched against known actions, or shown to the human,
   never piped to a shell unseen.
2. **A ladder of trust, not one switch.** Each action has a tier:
   - *Free*: read-only and reversible (open an app, focus a window, search files, show
     a status). Runs immediately.
   - *Confirm*: changes state (write a file, install a package, run a command). Shows
     exactly what will run; one keypress or "yes" to go.
   - *Never by voice*: destructive or one-way (delete, push, lock, payments).
     Voice-command already draws this line (session-restore and lock are excluded).
3. **Undo is a feature.** Prefer actions that are reversible: system changes go through
   the flake (so a generation exists), file edits through git or jj, window changes are
   inherently undoable. "Undo that" should be a command.
4. **Show, don't just do.** The animations are not decoration: they make the agent's
   actions legible (the window it's about to move glows, the command it's about to run
   is on screen before it runs).
5. **Local first, cloud when it's worth it.** Small local model for routing and quick
   intents (fast, private, works offline); a frontier model for real tasks. The router
   decides which.
6. **Everything in this repo.** Declarative, rebuildable on both machines, gated by
   profile where the hardware differs (the laptop has no GPU for local models).

## Sketch

```
 voice ─┐                                ┌─► free actions ──► compositor IPC / apps
        ├─► transcript ─► intent router ─┼─► confirm tier ──► preview pill ─► run
 typing ┘     (dictation)  (local model) └─► real task ─────► coding agent session
                                                               (claude / codex, scoped)
            ▲                                                         │
            └──────── context: focused window, workspace, cwd, ◄──────┘
                      recent commands, what's on screen
```

- **Home surface**: a terminal-first launcher that's open at login and returns on a key
  (a dropdown already exists: `scripts/dropdown.sh`). Text box plus a mic button, history
  of what was asked and what happened.
- **Intent router**: grows voice-command's allowlist into a typed action catalog
  (`open`, `focus`, `move-window`, `search`, `run`, `edit-config`, …) with a tier each.
  Anything that doesn't fit becomes a scoped agent session instead of a guess.
- **Context**: the router is only as good as what it knows. `hyprctl -j` already exposes
  windows, workspaces and monitors; add cwd of the focused terminal, clipboard, and recent
  shell history (atuin).
- **Executor**: one place where actions run, so tiers, confirmations, logging and undo
  live in one spot instead of in every script.

## Paths

- **Phase 0 — inside Hyprland, no compositor work.** Typed + spoken input box, action
  catalog over `hyprctl`, preview pill in AGS, agent handoff. Everything here is scripts
  and widgets; it works on both machines today (laptop: cloud model or a small CPU model
  for routing).
- **Phase 1 — the session is the surface.** Log in to the home surface instead of an
  empty workspace; apps open beside it. Still Hyprland.
- **Phase 2 — a Smithay compositor fork.** Things a script can't do from outside: the
  compositor itself knows what the agent is doing (highlight the window being acted on,
  animate an action before it lands, a first-class "agent layer" above windows, an
  accessibility-tree-style view of every client for context). Built in Rust on Smithay,
  experimenting with Pinnacle as a base. Smithay accepts AI-assisted code only with
  disclosure in commit messages (`AI.md` there), so upstream contributions follow that;
  the fork sets its own rules.

## Open questions

- Which model does routing on the laptop, with no GPU? CPU small model vs. always cloud.
- How does the agent "see" non-terminal apps — screenshots, accessibility APIs, or only
  what the compositor knows?
- Where's the line between this and just running Claude Code with a voice front end?
  (Maybe there isn't one, and Phase 0 is exactly that, plus window management.)
- Wake word or push-to-talk only? (Push-to-talk so far, deliberately: no always-on mic.)
- What gets logged, and where? An agent acting on the desktop needs an audit trail the
  human can read.
