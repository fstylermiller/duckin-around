# Duck Game

A cozy, wholesome 3D co-op game for two players. Each player controls a duck, and together they
wander through a wordless story of about twelve chapters. Every chapter has its own environment,
and each one blends into the next.

> **Status: milestone 0 toolchain is ready.** The pinned dev container, verified portable editor,
> and a small Forward+ test scene are in place; container lint, tests, and Windows export pass.
> The fade and stencil probes have been visually checked on the RTX 4090; Steam Link checks remain.
> The full design is in [docs/plan.md](docs/plan.md).

## Cozy first

**Coziness is the most important thing about this game.** Every feature, asset, sound and story
beat is checked against six pillars:

1. **Nothing can go wrong.** No fail states, enemies, timers, scores or deaths.
2. **Together, never competing.** Being close is rewarded with small shared moments: quack duets,
   synced wags, sharing food, and napping side by side.
3. **Soft to every sense.** Pastel colors, warm light, gentle sounds, a camera that never shakes.
4. **Unhurried.** Walking feels good, and idle ducks preen, sit and nap.
5. **Kindness is the story.** Each chapter is a small errand of kindness for a friendly neighbor.
6. **Low friction.** Fast to start, autosaves constantly, drop the pad any time.

A cozy audit (planned for milestone 1, see [docs/plan.md](docs/plan.md) §0) will enforce what can
be measured: pastel palette bounds, audio levels, camera speed, and no flashes. A cozy review on
the TV ends every milestone.

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

The current layout includes the development toolchain and a milestone 0 test scene. Gameplay systems
are still planned.

```text
duck-game/
  .devcontainer/        # VS Code dev container (uses compose.yaml)
  Dockerfile            # headless toolchain: Godot, Windows export templates, gdtoolkit
  compose.yaml          # dev container and persistent Godot template cache
  scripts/
    editor.ps1          # host: verify + launch the portable Godot editor
    playtest.ps1        # host: launch builds/current/DuckGame.exe for Steam Link play
    lint.sh test.sh export.sh check-version.sh   # container
  game/                 # Godot project root (project.godot, milestone 0 test scene)
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

1. **Edit.** Run `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\editor.ps1`.
   - The first run downloads the official portable, self-contained Godot editor into `.tools/` and
     checks its SHA-512 hash. An `_sc_` marker file keeps all editor settings in that folder.
   - It then opens `game/`. Play in the editor with F5 or F6 using the PC's wired Xbox pad.
     Use the left stick to move the yellow capsule relative to the camera. This is a temporary
     controller test, not the finished duck movement.
   - The two purple boxes share a material: one continuously fades with an instance shader uniform,
     while the other stays solid. Move the duck under the roof: the covered parts should appear
     pink through it, and exposed parts should remain yellow. These are Forward+ milestone 0
     probes, not the final visibility system.
   - Add `-VerifyOnly` to download and verify the editor without opening its window. The execution
     policy override applies only to this PowerShell process; it does not change system policy.
2. **Lint and test.** Run these in the container (VS Code: *Reopen in Container*, or
   `docker compose run --rm dev bash scripts/lint.sh`):
   - `bash scripts/lint.sh` runs `gdformat --check` and `gdlint`.
   - `bash scripts/test.sh` runs the GUT tests and a headless scene smoke test. The visibility and
     cozy audits are added with the gameplay systems they check.
3. **Export.** `scripts/export.sh` checks that the container's Godot version matches the project,
   exports a Windows build to `builds/<version>/`, and refreshes `builds/current/DuckGame.exe`.
   Run it as `bash scripts/export.sh` in the container.
4. **Playtest on the TV.**
   - Add `builds/current/DuckGame.exe` to Steam once as a non-Steam game. Every export updates the
     same path, so the shortcut keeps working.
   - Start Steam Link on the Pi. The two Bluetooth pads paired to the Pi are forwarded to the PC.
   - `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\playtest.ps1` launches the
     current build locally.

Every milestone ends with lint, tests, and the export passing in the container, plus a playtest
both at the PC and through Steam Link, and a cozy review.

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
| 2 | Duck expression (quack, wag, eat, idle life) |
| 3 | Local co-op, together moments, visibility system (food-cart-pod grey-box diorama) |
| 4 | Art and sound pass (palette, toon shader, warm lighting, final ducks, music, environment kit) |
| 5 | Story vertical slice (chapter 1) |
| 6 | Polish and packaging |
| 7 | Chapter transitions |
| 8+ | Chapters 2–12 |

See [docs/plan.md](docs/plan.md) for exit criteria, risks, and the decisions log.
