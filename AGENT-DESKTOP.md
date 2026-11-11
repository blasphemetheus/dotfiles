# Agent Desktop — future direction

A theorized direction, not a plan of record. First written 2026-11-11.

## The idea

You open the computer and the first thing there is a **place to say what you want**,
by voice or by typing, in plain English. A language model running **on this machine**
turns that into actions (open things, arrange windows, change settings, run commands),
and the desktop's windows and animations are still there, opened *from* that surface
and used to show what the model is doing.

Today the voice and model pieces are side features bolted onto a normal desktop. The
direction is to make them the thing the session is organized around. Others are
exploring the same space; this is the personal, hackable, NixOS version, built to
experiment with.

**Scope:** a usable laptop and desktop environment that incorporates language models so
that someone can use the computer **as if they were an experienced coder, by
communicating in English**: arranging the desktop, running and understanding shell
commands, and working on code. The **laptop is the target**: if it doesn't work on the
Aspire (Ryzen 5 7520U, 16 GB, no discrete GPU), it isn't done.

## Ground rules

1. **Own hardware first; cloud supported later, never required.** Speech-to-text and
   the router always run on the machine. Bigger jobs may use the desktop's GPU over the
   home network. A cloud backend is a later, opt-in addition, not something the
   design depends on. See "Where models run" below.
2. **The model proposes, deterministic code disposes.** The model's output is data: an
   action ID plus arguments, validated against a catalog. It is never piped to a shell.
   (`voice-command.sh` already works this way.)
3. **The model picks *what*, code resolves *which*.** "Open firefox" → the model says
   `open_app("firefox")`; code fuzzy-matches that against the real list of installed
   apps. Same for windows, workspaces, files. The model never invents a path or a
   window address.
4. **A ladder of trust.** Every action has a tier (see "Executor" below): some run
   immediately, some show a preview and wait for a yes, some are never reachable by voice.
5. **Undo is a feature.** Every action records how to reverse it. "Undo that" is a
   command.
6. **Show, don't just do.** The UI shows the action before and while it happens. The
   animations are how the human follows what the model is doing.
7. **Declarative, both machines.** Everything lives in this repo and builds on the
   desktop (RTX 5090) and the laptop (Ryzen 5 7520U, no discrete GPU), gated by profile
   where they differ.

## Where models run

Three places a model can run, and which jobs may use which:

| Backend | What it is | Used for | When |
|---|---|---|---|
| **On-device** | The machine's own CPU/GPU (laptop: CPU or Radeon 610M; desktop: RTX 5090) via ollama / llama.cpp | Speech-to-text, routing desktop actions, English → one shell command, explaining a command | Always. Must work with no network |
| **Home GPU** | The desktop's ollama, reached from the laptop over the LAN (or a private VPN such as Tailscale away from home) | Coding-agent work and anything too big or slow for the laptop: larger models (qwen3-coder:30b) | Phase 1. Optional: the laptop falls back to on-device when the desktop is off or unreachable |
| **Cloud** | A hosted model or a cloud coding agent (Claude Code, Codex) | Hard coding tasks beyond what local models handle | Later, opt-in. Not built in Phases 0–1 |

Bounds that hold for every backend:

- **Routing and speech never leave the machine.** The always-on, every-request path is
  on-device, so it's fast, private, and works offline.
- **A backend is a setting, not a code path.** `deskd` talks to an OpenAI-compatible
  chat endpoint (which ollama and llama.cpp both serve). Switching backend is a URL and a
  model name in config, so adding cloud later doesn't change the architecture.
- **Using a non-local backend is visible.** The pill shows where a request is going
  ("→ desktop GPU", "→ cloud"). If cloud is ever enabled, it's per request or per task,
  never silently, and context sent is the same small, reviewable bundle described below.
- **Cloud coding agents stay apps.** The way you use Claude Code today (a terminal you
  drive) keeps working and is a fine thing to hand off to. What `deskd` doesn't do is
  run a cloud agent unattended on your behalf.

What this means for the laptop, honestly: a small on-device model can route desktop
actions and turn plain English into a single shell command reliably enough to test.
Multi-step coding work (reading a repo, editing files, running tests) on a 4-core
laptop CPU will be slow and weak with local models. The Home GPU backend is how the
laptop gets real coding help without the cloud; the eval set measures where the line is.

## What exists today

| Piece | Where | Reused how |
|---|---|---|
| Dictation | `hyprwhspr-rs` (`configuration.nix`), `hyprwhspr/` config | Unchanged; still types into the focused window |
| Voice command router | `hypr/.config/hypr/scripts/voice-command.sh` (Super+U, desktop only) | **The prototype of Phase 0**: push-to-talk → whisper-cli → ollama → one of ~20 allowlisted actions via a `case` table |
| Status pills | `ags/.config/ags/widget/{Dictation,Command}Pill.tsx` | Command pill grows into the preview/confirm UI |
| Local LLM | `services.ollama` in `hosts/slanka` (qwen3-coder:30b, qwen3:8b on CUDA) | Desktop router model. The laptop has none yet |
| Window state | `hyprctl -j clients/activewindow/workspaces/monitors` | Context for the router, and targets for resolution |
| Terminal state | kitty remote control (`allow_remote_control yes`, sockets at `/tmp/kitty-<pid>`) | `kitty @ ls` gives each window's cwd and foreground process |
| Rollback | NixOS generations, git/jj | Undo for system-level changes |

What's missing: the router only knows toggles, there's no typed input, no context, no
confirmation step, no undo, no log, and nothing runs on the laptop.

---

## Phase 0 in detail — a local command layer inside Hyprland

**Goal:** press a key (or hold one and talk), say or type an instruction, and have it
carried out by an on-device model within a couple of seconds, on both machines, with
preview, confirmation, undo and a log. Two kinds of instruction:

- **Desktop:** "put firefox on the left", "open a terminal in hyprdisplays".
- **Shell:** "how much space is left", "find the big files in Downloads", "what's
  using port 8080". English becomes one shell command, shown with a plain-English
  explanation, run only after you confirm. This is the first step toward "use the
  computer like an experienced coder": you see the real command every time, so you
  learn it.

No compositor changes; everything is a daemon, a catalog, and AGS widgets.

**Done when:** on both machines, ~40 everyday desktop instructions (the eval set below)
route correctly ≥95% of the time, the median time from key release to action is under
the latency targets, and every executed action can be undone and appears in the log.

### Components

```
  typed bar (AGS) ──┐
                    ├─► deskd ─► context ─► router (local LLM) ─► resolver ─► executor
  push-to-talk ─────┘    │                   (JSON schema-       (fuzzy     (tier check,
  (pw-record → STT)      │                    constrained)        match)     run, undo,
                         │                                                    log)
                         └──── state events ──► AGS pill (listening / thinking /
                                                 preview / confirm / done / error)
```

#### 1. `deskd`, the daemon (Rust)

One long-running user service replaces the per-press bash pipeline. It's in Rust because
that's where Phase 2 lives too (Smithay), so the code carries over.

- **Socket:** `$XDG_RUNTIME_DIR/deskd.sock`, newline-delimited JSON.
- **Requests:** `{"type":"text","text":"put firefox on the left"}`,
  `{"type":"voice_start"}` / `{"type":"voice_stop"}`, `{"type":"confirm","id":…}`,
  `{"type":"cancel"}`, `{"type":"undo"}`.
- **Events out:** `{"state":"thinking","text":"…"}`, `{"state":"preview","id":…,
  "summary":"Move Firefox to the left half","tier":"confirm"}`, `{"state":"done",…}`,
  `{"state":"error",…}`. AGS subscribes instead of polling a state file.
- **CLI:** `desk "open a terminal in ~/git/hyprdisplays"` talks to the same socket.
  Handy for testing and for scripting.
- **Packaging:** `pkgs/deskd.nix` (`rustPlatform.buildRustPackage`), a Home Manager
  `systemd.user.services.deskd` in a new `modules/home/desk.nix`, enabled on both hosts.
  `voice-command.sh` shrinks to a thin client, then goes away.

Migration path: before writing Rust, grow `voice-command.sh` into the catalog-driven
shape (catalog file, schema-constrained output, resolver) so the design gets tested
cheaply, then port.

#### 2. Speech-to-text

- **Push-to-talk only.** No wake word, no always-on mic.
- **Model:** Parakeet TDT (already used by dictation; the laptop gets the int8 build).
  `deskd` loads it in-process through the `parakeet-rs` crate, the same library
  `hyprwhspr-rs` uses, so it stays resident and there's no per-utterance reload.
  Today's whisper-cli path reloads `large-v3-turbo` on every press and the laptop has
  neither the model nor the GPU for it.
- **Cost:** a second resident copy of the model (dictation keeps its own). Fine on the
  desktop; on the laptop, measure RAM. A later option is a dictation mode inside `deskd`
  so one process owns the model.
- **Vocabulary fixes:** reuse the `word_overrides` table from the hyprwhspr config, so
  "hyper land" still becomes Hyprland.

#### 3. Context collector

Built fresh for every request, kept small (aim < 300 tokens), and placed at the **end**
of the prompt so the static part can stay cached (see Router).

- Focused window: class, title, workspace (`hyprctl -j activewindow`).
- Open windows: class + short title + workspace, capped (`hyprctl -j clients`).
- Workspaces and monitors: IDs, which is active, monitor names.
- Focused terminal, if it's kitty: cwd and foreground command (`kitty @ ls` over the
  window's socket).
- Last action taken (so "undo that", "no, the other one", "and make it bigger" work).
- **Not** included by default: clipboard contents, shell history, screen contents.
  Opt-in later, per item, because they're the privacy-sensitive ones.

#### 4. Action catalog

One file in the repo, `desk/actions.toml`, is the single source of truth. The router
prompt, the JSON schema, the resolver and the executor are all generated from it.

```toml
[[action]]
id = "open_app"
says = "Launch an application"
examples = ["open firefox", "start a terminal", "launch discord"]
args = { app = { type = "app" } }          # resolved against .desktop entries
tier = "free"
run = { spawn = "{app.exec}" }
undo = { close_window = "{spawned.address}" }

[[action]]
id = "move_window"
says = "Move a window to a workspace or monitor"
examples = ["put firefox on workspace 3", "send this to the tv"]
args = { window = { type = "window", default = "focused" },
         to = { type = "workspace_or_monitor" } }
tier = "free"
run = { dispatch = "hl.dsp.window.move({ workspace = '{to}', window = 'address:{window.address}' })" }
undo = { dispatch = "hl.dsp.window.move({ workspace = '{before.workspace}', window = 'address:{window.address}' })" }

[[action]]
id = "run_in_terminal"
says = "Run a shell command in a new terminal"
examples = ["run the tests in hyprdisplays", "show disk usage"]
args = { command = { type = "string" }, cwd = { type = "dir", default = "focused_terminal" } }
tier = "confirm"                            # the exact command is shown before running
run = { spawn = "kitty --hold --directory {cwd} -- fish -c {command}" }
```

**Arg types**, each with a resolver: `app` (.desktop entries), `window` (open windows,
by class/title), `workspace_or_monitor`, `dir` (zoxide database first, then
fuzzy-matched under `$HOME`), `enum` (fixed list), `int` (with range), `string`
(free text; only allowed in `confirm`-tier actions).

**Starter set (~20):** open_app, close_window, focus_window, move_window,
resize/snap_window (left/right/full/float), switch_workspace, fullscreen, open_url,
open_file, open_folder, search_files, run_in_terminal, volume, brightness,
media (play/pause/next), dnd, power_profile, wallpaper, screenshot, lock (keyboard-only,
see tiers), plus today's toggles (opacity, blue light, caffeine, zoom, record).
`clarify` and `none` are always available.

#### 5. Router (the local model)

- **Output is schema-constrained.** The JSON schema is generated from the catalog: an
  object with an `action` enum of every ID and per-action `args`. Ollama's structured
  output (`format` = a JSON schema) or llama.cpp's `json_schema` makes the model unable
  to emit anything else. That removes today's code-fence stripping and "didn't parse"
  failures.
- **Sequences:** output is a list of 1–3 steps (`"open firefox and put it on 2"`). The
  whole plan takes the highest tier among its steps.
- **Clarify, don't guess:** `{"action":"clarify","question":"Which Firefox window?"}` is
  a valid answer. The question shows in the pill; the next utterance is the answer.
- **Prompt layout for speed:** static system prompt + catalog + few-shot examples first,
  identical on every call, so the inference server reuses its cached prefix. Only
  context + utterance are new tokens. This matters most on the laptop, where processing
  a 1–2k-token prompt from scratch on CPU would take seconds.
- **Temperature 0**, short max output (~150 tokens), and a `keep_alive` long enough that
  the model stays loaded between presses (on the desktop, short enough to not starve
  the hourly notif-digest job; see the `OLLAMA_KEEP_ALIVE` note in `hosts/slanka`).

**Models per machine:**

| | Desktop | Laptop |
|---|---|---|
| Runtime | ollama-cuda (already running) | `ollama-vulkan` or `llama-cpp` (both in nixpkgs), gated on the laptop profile |
| Router model | qwen3:8b (already pulled) — try before the 30B; routing doesn't need a coder | Candidates: a ~1.5–4B instruct model, Q4; pick by the eval set |
| Where it runs | GPU | CPU vs. the Radeon 610M iGPU via Vulkan; measure both (the iGPU is small and shares RAM, so CPU may win) |
| RAM budget | not a concern | ~3 GB for model + KV; 16 GB total, dictation and apps share it |

**Latency targets** (key release → action visibly starts): desktop under 1 s, laptop
under 3 s. These are targets to measure against, not measurements.

#### 6. Resolver

Runs after the model, before anything executes. Turns `"firefox"` into a real `.desktop`
entry, `"the tv"` into a monitor name, `"hyprdisplays"` into `~/git/hyprdisplays`.
Fuzzy matching (e.g. `nucleo` or `fuzzy-matcher` crates) with a confidence threshold:

- One clear match → use it.
- Several close matches → turn the step into `clarify` with the candidates listed.
- None → error toast naming what wasn't found. Never fall back to the raw string.

#### 7. Executor

**Tiers:**

| Tier | Runs | Examples |
|---|---|---|
| `free` | Immediately; pill flashes what happened | open, focus, move, switch workspace, volume, toggles |
| `confirm` | Pill shows the exact effect (and exact command line); Enter / say "yes" runs, Esc / "no" cancels, times out to cancel after 10 s | run_in_terminal, close a window with unsaved work, anything with a free-text `string` arg |
| `typed_only` | Only from the typed bar, never from voice; still confirmed | lock, logout, power off |
| (absent) | Not in the catalog at all | deleting files, git push, sudo, anything with money or credentials |

- **Undo stack:** each executed step records the state its `undo` template needs (the
  window's previous workspace, the spawned window's address). `undo` pops one step.
  Actions without an undo say so in the preview.
- **Log:** one JSON line per request in `~/.local/state/desk/log.jsonl` (time, input
  source, transcript, model, raw model output, resolved plan, tier, outcome, latency
  per stage) plus a journal line. That log is also the source of new eval cases.

#### 8. Shell lane (English → command)

The `run_in_terminal` action, done carefully, since it's the one with free text:

- The model returns `{"command": "...", "explain": "..."}`, where `explain` is one or two
  sentences in plain English, including what each flag does.
- **Static checks before the preview**, in code, not by the model: parse with a shell
  parser (e.g. the `tree-sitter-bash` or `conch-parser` crates) and flag anything that
  writes or deletes (`rm`, `mv`, `>`, `dd`, `chmod`, `git push`, `sudo`, package
  installs). Flagged commands get a red preview and can't be confirmed by voice.
  `sudo` is refused outright in Phase 0.
- **Runs visibly** in a new kitty window in the resolved cwd (`--hold`, so output
  stays), never in the background. The human sees exactly what happened.
- **Explain mode:** "what does this do?" with a command selected or on the clipboard
  returns only the explanation, no execution. Cheap, safe, and a big part of learning.
- **Logged** like every other action, including the exact command line.

#### 9. UI (AGS)

- **Typed bar:** a new AGS window, centered and slim like a launcher, opened by a key
  (pick one free on both keymaps; Super+U is voice today, Super+A launches Claude Code
  on the laptop). Enter submits, Esc closes, Up recalls history.
- **Pill:** CommandPill grows states: listening (timer) → transcribing → thinking
  (shows transcript) → preview/confirm (shows the plan) → done/error. Driven by
  `deskd` events, not a polled state file.
- **Target highlight:** while a plan is previewed, mark the target window (e.g. a
  temporary border color or tag through Hyprland's window rules) so it's obvious which
  window "this" meant. Exact mechanism to be found in the Hyprland Lua API.

#### 10. Evals

`desk/evals/utterances.jsonl`, one case per line:

```json
{"say": "put firefox on the left", "context": "fixtures/two-windows.json",
 "expect": [{"action": "snap_window", "args": {"window": "firefox", "side": "left"}}]}
```

- `desk eval` runs every case through router + resolver (not the executor) against a
  frozen context fixture, and reports accuracy, which cases broke, and latency per
  stage.
- Run on both machines before changing the prompt, the catalog, or the model. A model
  swap on the laptop is decided by this, not by vibes.
- Seed it with ~40 cases from today's voice-command list and the starter catalog; grow
  it from real misses in `log.jsonl`.

### Milestones

| # | Deliverable | Done when |
|---|---|---|
| M0 | `voice-command.sh` reads a catalog file and uses schema-constrained output; eval set + runner in bash | Desktop eval ≥ 90%, no parse failures |
| M1 | Laptop gets an on-device runtime + router model (profile-gated Nix) | Same eval runs on the laptop; latency measured, model chosen. **The laptop numbers decide everything after this** |
| M2 | `deskd` in Rust: socket, router, resolver, executor with tiers, log | Both machines; voice-command.sh is a thin client |
| M3 | Typed bar + pill states + confirm flow + undo | Every catalog action reachable by typing; undo works for each `free` action |
| M4 | Shell lane: English → command + explanation, static checks, explain mode | Shell eval cases pass on the laptop; every destructive command in the eval is flagged |
| M5 | In-process Parakeet STT in `deskd` | Voice works on the laptop; no whisper-cli reload |
| M6 | Context (kitty cwd, last action) + clarify loop + target highlight | "run the tests here", "no, the other one" work |

---

## Phase 1 — the session is the surface

Same pieces, different default. At login the typed bar is already open on an empty
workspace instead of a blank desktop, with recent requests listed. Apps open beside or
behind it. Additions:

- A **request history** view: what was asked, what ran, undo per entry (from the log).
- **Workspace intents:** "set up for coding hyprdisplays" opens the terminal in the
  repo, the editor, and docs on the second monitor. Stored as named, reviewable
  sequences of catalog actions, not as model output to replay.
- **Coding agent handoff:** for requests that are really programming tasks ("add a
  dark mode toggle to this app"), open a terminal running a coding agent in the right
  directory, with the request pre-filled. Default is `opencode` on the **Home GPU**
  backend (the desktop's qwen3-coder:30b over the LAN); on-device when the desktop is
  unreachable, with a warning that it'll be slow. A handoff to an app the human then
  drives and watches, not something `deskd` runs on its own.
- **Home GPU backend:** the desktop's ollama listens on the LAN (firewall opened for the
  laptop only, or Tailscale), the laptop's `deskd` config lists it as a second backend
  with on-device as fallback, and the pill shows which one answered.

## Later — cloud backend (opt-in)

Not built in Phases 0–1; the design keeps the door open:

- Same OpenAI-compatible backend slot, so a hosted model is a config entry.
- Only for the coding-agent lane, chosen per task ("use the cloud for this one"), never
  for routing or speech.
- Handing off to a cloud coding agent like Claude Code is just the coding handoff with
  a different app; it's how this repo is already being worked on.

## Phase 2 — a Smithay compositor fork

What only the compositor can do, once Phase 0–1 show what's worth it:

- **An agent layer** above windows that the compositor draws itself: the plan, the
  target outline, an animated path showing where a window is about to move.
- **A private Wayland protocol** (e.g. `desk_agent_v1`) between `deskd` and the
  compositor: structured window tree with stable IDs, highlight/animate requests,
  "freeze input while confirming". Replaces scraping `hyprctl` output.
- **Better context** from the compositor's own knowledge of every surface (app ID,
  title, geometry, focus history) instead of screenshots.
- Base: Smithay, experimenting with Pinnacle as the starting point. Smithay accepts
  AI-assisted code only with disclosure in commit messages (its `AI.md`), so upstream
  patches follow that; the fork sets its own rules.

## Deliberately out of scope

- Cloud backends in Phases 0–1 (designed for, not built; see "Later").
- Cloud models for routing or speech, ever.
- Always-listening microphone or wake words.
- Autonomous loops: `deskd` acts once per request, never on its own initiative.
- Reading screen contents (screenshots / OCR / vision models). Maybe later, local only.
- Any action that touches credentials, payments, `sudo`, or pushes to a remote.

## Open questions

- Which laptop model clears ≥95% on the eval set within 3 s, on CPU or the 610M iGPU?
  Is a 4B model necessary, or does ~1.5B suffice for routing?
- How good is a coding agent on the Home GPU backend (qwen3-coder:30b) at the tasks a
  non-coder would ask for? Needs its own eval set of small, real tasks.
- What does the laptop do away from home without Tailscale: on-device coding only,
  or queue the task until the desktop is reachable?
- One resident Parakeet in `deskd` that also serves dictation, or two processes?
- Is a 10 s confirm timeout right, and should "yes" by voice be allowed for every
  `confirm` action or only some?
- How much of the catalog should be generated from existing scripts vs. hand-written?
- How should multi-step plans undo: all at once, or one step per "undo"?
