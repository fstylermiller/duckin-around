# Duck Game

A cozy, wholesome 3D co-op game for two players. Each player controls a duck, and together they
wander through a wordless story of about twelve chapters. Every chapter has its own environment,
and each one blends into the next.

> **Status: planning only.** Nothing has been built yet. The full design is in
> [docs/plan.md](docs/plan.md). The next step is milestone 0 (toolchain and streaming spike).

## Overview

| Aspect | Choice |
| --- | --- |
| Engine | Godot **4.7.2 stable** (pinned), GDScript |
| Renderer | Forward+ (SDFGI, SSAO, fog, glow) |
| Platform | **Windows x86_64 only** |
| TV play | Steam Link: the exe is added to Steam on the PC as a *non-Steam game* and streamed to the Raspberry Pi 5 on the TV. Nothing is published to Steam. |
| Players | Two-player local co-op on Xbox controllers with a shared camera that keeps both ducks in view |
| Art | Pastel palette and simple shapes, one step up from low-poly: toon shading, soft lighting |

### The ducks

There are two ducks with no names or labels. One is taller, and the shorter one wears a small
necklace. Both ducks can walk, run, jump, quack, wag their tails, and eat.

| Pad button | Action |
| --- | --- |
| Left stick | Walk |
| B (hold) | Run |
| A | Jump |
| X | Quack |
| Y | Eat |
| RB | Wag tail |
| Start | Pause |

### Keeping the ducks visible

Many settings include roofs and overhangs, such as a covered food-cart pod. The ducks must stay
visible almost all the time, and four layers handle this:

- Roofs are cut away when a duck is under them.
- Props between the camera and a duck fade out.
- A duck that is still hidden is drawn as a silhouette.
- Camera hint volumes adjust the view in tight spots.

A headless visibility audit fails the build if a duck is hidden more than 1% of the time.

## Repository layout

The planned layout is below. Most of it does not exist yet.

```text
duck-game/
  .devcontainer/        # VS Code dev container (uses compose.yaml)
  Dockerfile            # headless toolchain: Godot, Windows export templates, gdtoolkit
  compose.yaml
  scripts/
    editor.ps1          # host: verify + launch the portable Godot editor
    playtest.ps1        # host: launch builds/current/DuckGame.exe for Steam Link play
    lint.sh test.sh export.sh check-version.sh   # container
  game/                 # Godot project root (project.godot)
    autoload/ duck/ camera/ world/ story/ ui/ art/ audio/ tests/
  docs/plan.md          # implementation plan
  CREDITS.md            # third-party assets and licenses (CC0 only)
  .tools/               # gitignored: portable editor
  builds/               # gitignored: exports
```

## Development flow

Godot is never installed on the machine. The editor runs on Windows so it can use the GPU and a
wired controller. Everything else runs in a container.

```text
 Windows host                              Container (headless)
 ┌──────────────────────────────┐          ┌──────────────────────────────┐
 │ scripts/editor.ps1           │          │ check-version.sh             │
 │  └ portable Godot (.tools/)  │  game/   │ lint.sh   (gdformat/gdlint)  │
 │     edit + F5 play with the  │ ◄──────► │ test.sh   (GUT)              │
 │     wired Xbox pad           │ bind     │ export.sh → builds/<ver>/    │
 └──────────────────────────────┘ mount    │          → builds/current/   │
                                           └──────────────┬───────────────┘
 Steam (non-Steam game shortcut) ◄── builds/current/DuckGame.exe
   └ Steam Link ──► Raspberry Pi 5 + TV (two Bluetooth Xbox pads)
```

1. **Edit.** Run `.\scripts\editor.ps1`.
   - The first run downloads the official portable, self-contained Godot editor into `.tools/` and
     checks its SHA-512 hash. An `_sc_` marker file keeps all editor settings in that folder.
   - It then opens `game/`. Play in the editor with F5 or F6 using the PC's wired Xbox pad.
2. **Lint and test.** Run these in the container (VS Code: *Reopen in Container*, or
   `docker compose run --rm dev <script>`):
   - `scripts/lint.sh` runs `gdformat --check` and `gdlint`.
   - `scripts/test.sh` runs the GUT unit tests and the visibility audit headless.
3. **Export.** `scripts/export.sh` checks that the container's Godot version matches the project,
   exports a Windows build to `builds/<version>/`, and refreshes `builds/current/DuckGame.exe`.
4. **Playtest on the TV.**
   - Add `builds/current/DuckGame.exe` to Steam once as a non-Steam game. Every export updates the
     same path, so the shortcut keeps working.
   - Start Steam Link on the Pi. The two Bluetooth pads paired to the Pi are forwarded to the PC.
   - `.\scripts\playtest.ps1` launches the current build locally.

Every milestone ends with lint, tests, and the export passing in the container, plus a playtest
both at the PC and through Steam Link.

### Rules

- **Everything is pinned:** the Godot version, the export templates, and gdtoolkit (with SHA
  hashes). Container images use digests (`image@sha256:...`) and never `:latest`.
- **Godot 4.7.2 stays pinned** until an upgrade is a deliberate change. `check-version.sh` and
  `editor.ps1` enforce it.
- **Only CC0 or self-made assets** are allowed. Record each one in `CREDITS.md`.
- **No network changes are needed.** Steam Link streaming stays on the LAN.

## Milestones

| # | Milestone |
| --- | --- |
| 0 | Toolchain + Steam Link streaming spike |
| 1 | Duck movement (walk, run, jump) |
| 2 | Duck expression (quack, wag, eat) |
| 3 | Local co-op + visibility system (food-cart-pod grey-box diorama) |
| 4 | Art pass (palette, toon shader, final ducks, environment kit) |
| 5 | Story vertical slice (chapter 1) |
| 6 | Polish and packaging |
| 7 | Chapter transitions |
| 8+ | Chapters 2–12 |

See [docs/plan.md](docs/plan.md) for exit criteria, risks, and the decisions log.
