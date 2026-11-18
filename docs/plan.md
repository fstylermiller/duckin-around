# Duck co-op game (Godot) — implementation plan

Researched: 2026-11-18. Status: plan only; nothing has been built.

A 3D, pastel, simple-shapes story game for two local players, each controlling a duck. **The only
build target is Windows** (the PC, RTX 4090). The living-room TV is reached by **Steam Link
streaming** from the PC to `MiniBambo` (Raspberry Pi 5, HDMI → LG TV), which is already that
device's job. **Builds, exports, linting and tests happen in the container.** The Godot editor runs
as a self-contained portable app on Windows so it can use the RTX 4090, Forward+, and the PC's
controllers directly. Docker Desktop, WSL2 and Steam are already installed; Godot is kept as a
project-local portable app, not installed system-wide. Streaming stays on the LAN, so there are
**no router, firewall, or WireGuard changes**.

## 1. Key decisions

| Decision | Choice | Why |
| --- | --- | --- |
| Engine | **Godot 4.7.2 stable**, pinned. Do not use 4.8 (beta as of 2026-11-09). | Current stable release, with an official Windows x86_64 export template. |
| Language | **GDScript** (not C#/.NET) | No .NET SDK in the toolchain and smaller exports. |
| Platform | **Windows only.** No native Pi build. | Decided 2026-11-18: Steam Link gives the TV the PC's graphics, so a Pi build would only cost quality and effort. |
| TV play | **Steam Link**: the exe is added to Steam on the PC as a *non-Steam game* and streamed to MiniBambo | Nothing is uploaded to Steam or published. A local library shortcut is enough. The Pi's paired pads are forwarded to the PC. |
| Renderer | **Forward+** (Vulkan or D3D12 on Windows) | Real-time soft shadows, SSAO, glow (string lights), volumetric fog, real-time global illumination (SDFGI), and TAA. All of these are affordable on a 4090. |
| Co-op view | **Shared camera** with a soft tether between ducks | Suits a "wander together" story, and the visibility system (§6) is built around it. |
| Animation | **Rigid-part ducks** (no skeleton) animated by `AnimationTree` and procedural layers | No rigging pipeline is needed, and waddle, wag, and quack are naturally procedural. Performance is no longer the reason. |

### Steam Link: why it's the better choice here

| | Native Pi build (old plan) | Steam Link from the PC (new plan) |
| --- | --- | --- |
| Graphics | Compatibility (OpenGL) renderer, blob shadows, baked light, ≈720p internal | Forward+ with everything in the Renderer row, at full output resolution |
| Builds and testing | Two exports, Pi GL driver quirks, thermals, `deploy-pi.sh` | One Windows exe |
| Controllers on the TV | Paired to the Pi | Same pads, same pairing; Steam forwards them to the PC |
| Costs | — | The PC must be on with Steam running. A little added latency (fine for a cozy game). Video compression can band smooth pastel gradients and fog; Phase 0 checks this. Network quality matters, and a wired Pi is best. |

Not needed: a Steamworks partner account, the $100 app fee, or a store page. Those are only for
publishing to other people. If that's ever wanted, the Steamworks SDK can be added then.

### Development environment: portable host editor, container toolchain

The Godot GUI editor runs natively on Windows so Forward+ uses the RTX 4090 and in-editor play sees
the wired Xbox controller. Builds, exports, linting, tests and their pinned dependencies stay in
the container. This is the chosen option D, not a fallback.

- `scripts/editor.ps1` downloads or launches the official **portable, self-contained Godot 4.7.2
  editor** in `duck-game/.tools/`. An `_sc_` marker keeps editor settings in that folder. Nothing
  is installed, and no settings are written to the registry or `%APPDATA%`. Delete `.tools/` to
  remove it. The script verifies the expected editor version and SHA-512 before extracting the
  pinned official release.
- The project opens from `P:\homelab\duck-game\`. Its `.godot/` import cache is local to the
  project and gitignored. Exports and tests use the container's separate cache and templates.
- `scripts/editor.ps1` checks the host editor binary's version when it launches. `check-version.sh`
  is required before exports and tests: it checks the container Godot version and
  `config/features` in `project.godot` against the pinned 4.7.2 release. Both checks use the same
  version constant and release checksum.
- Native editor play (F6/F5) reads the wired Xbox pad directly. Steam Link play uses the two
  Bluetooth Xbox pads paired to the Pi. No USB/IP setup or pad-bridge script is needed.
- **Forward+ lighting:** use SDFGI and SSAO for real-time global illumination and soft contact
  shading, with no lightmap baking requirement. The editor can bake only if later profiling shows
  SDFGI is unnecessary; it is not part of the baseline.

The container editor, WSLg, Vulkan-on-D3D12, and software-renderer alternatives are no longer part
of the workflow.

## 2. Repository layout

Lives in `homelab/duck-game/`, with the same layout style as [rust-template](../../rust-template/).

```text
duck-game/
  .devcontainer/devcontainer.json   # uses ./compose.yaml; VS Code + godot-tools extension (LSP on 6005)
  Dockerfile                        # dev toolchain + editor image (see §3)
  compose.yaml                      # headless build/test toolchain, named Godot cache volume
  .gitignore                        # .tools/, builds/, game/.godot/
  builds/                           # gitignored: export output + .playdata/ for dev runs
  scripts/
    lint.sh  test.sh  export.sh                                         # container
    editor.ps1  playtest.ps1                                            # host, built-in PowerShell
    check-version.sh                                                    # validates container Godot + project version
  game/                             # Godot project root
    project.godot  export_presets.cfg
    addons/gut/                     # unit tests (vendored, pinned commit)
    autoload/       # PlayerSlots, StoryDirector, ChapterLoader, SaveGame, Settings
    duck/           # duck.tscn + motor/animator/actions/interaction scripts, tall/short variants
    camera/         # coop_camera.tscn
    world/
      kit/          # shared props kit, edibles
      chapters/     # ch01/ … ch12/, one environment scene each (see §6)
    story/          # story beats (pictogram bubbles) + chapter .tres resources
    ui/             # join screen, pause, chapter select, pictogram bubbles
    art/            # palette.png, toon.gdshader, models (.glb), materials
    audio/          # quacks, footsteps, music (CC0, see CREDITS.md)
    tests/
  CREDITS.md        # every third-party asset + license
  README.md
```

## 3. Dev container

All images and downloads are pinned and verified, per homelab rule 6.

- Base: `debian:trixie-slim@sha256:<digest>`. Resolve the digest at implementation time; never use
  `:latest`.
- Godot `4.7.2-stable` `linux.x86_64` for headless tests and exports, plus the Windows
  `export_templates.tpz` from the official GitHub release. **SHA-512 values are hard-coded in the
  Dockerfile**, copied once from that release's `SHA512-SUMS.txt`. Never fetch and trust the sums
  at build time.
- Templates are unpacked to `~/.local/share/godot/export_templates/4.7.2.stable/`.
- `gdtoolkit` (`gdlint`/`gdformat`) at a pinned version from a hashed `requirements.txt`
  (`pip install --require-hashes`).
- No `rcedit`/Wine. The Windows export works without it; only the exe icon and version info are lost.
- No GUI stack, GPU passthrough, WSLg mounts, or gamepad bridge is needed in the container.
- Runs as a non-root user. The workspace is bind-mounted; the Godot cache uses a named volume.

Scripts, all runnable inside the container except the portable editor launcher and Steam playtest:

| Script | Does |
| --- | --- |
| `lint.sh` | `gdformat --check` + `gdlint` on `game/` |
| `test.sh` | `godot --headless --path game -s addons/gut/gut_cmdln.gd -gexit` |
| `check-version.sh` | Confirms container Godot and project feature version match |
| `export.sh` | Checks versions, exports Windows → `builds/<version>/`, then refreshes `builds/current/` |
| `editor.ps1` | Verifies and launches the portable Godot editor from `.tools/` |
| `playtest.ps1` | Adds/launches `builds/current/DuckGame.exe` for Steam Link play; no remote debugger is needed when editing natively |

## 4. Platform target and performance budget

One target: Windows, Forward+, on the RTX 4090. It is played either on the PC's monitor or streamed
by Steam Link to the TV. The game renders at whatever resolution Steam Link asks for.

| Budget | Target |
| --- | --- |
| Frame rate | Locked 60 with vsync, which matches the stream. The 4090 has headroom, so no tiers are needed. |
| Shadows | One directional light with soft shadows, plus a few omni lights (string lights, lanterns) |
| Global illumination | SDFGI + SSAO, with no baking |
| Post-processing | Glow, volumetric fog, TAA with `use_debanding` on |
| Content | Low-poly by style, not by budget. Triangle and draw-call counts are watched only to keep the editor responsive. |
| Foliage | `MultiMeshInstance3D` |

**Streaming-specific rules.** Video compression is hardest on smooth gradients, fine noise, and
large flat pastel areas, which is exactly this art style. So: keep debanding on, add a faint film
grain or dither in the sky and fog, avoid high-frequency detail like shimmering grass, and check the
stream's quality setting on MiniBambo in Phase 0.

A `Settings` autoload still exposes render scale and effect toggles for the pause menu.

## 5. Art direction: "one step up from low-fi"

- **Shapes**: low-poly but smooth-shaded, with chamfered and bevelled edges and rounded silhouettes.
  Ducks are about 1–2k triangles; props are 50–500.
- **Color**: a 16-swatch pastel palette in `palette.png`, with **one row per chapter** (16×12, plus
  spare rows). Every mesh UV-maps into the swatch columns, so the whole world shares **one
  material** and the colors stay consistent. Each chapter picks its row through a global
  shader uniform, so the same props get each environment's colors. Later, chapter transitions can
  blend between two rows as the ducks walk from one environment into the next.
- **Shading**: a custom `toon.gdshader` with a two- or three-band soft ramp, a pastel hemisphere
  ambient (sky-tinted top, warm ground bounce), and a subtle rim light. The shader receives real
  shadows and SSAO from Forward+. Inverted-hull outlines are optional and decided in the art pass.
- **Atmosphere**: pastel volumetric and depth fog, glow on string lights and lanterns, and a
  gradient sky shader with no HDRI.
- **The two ducks** share the same coloring and have no names or color markers. They differ in
  shape only:
  - The **tall duck** is about 1.25× the height of the other, with a longer neck.
  - The **short duck** is rounder and wears a **small necklace**. It is a simple bead or pendant
    mesh that catches the rim light so it reads from the shared camera.
  - Quack pitch follows size: the tall duck is lower and the short duck is higher.
  - If the two are hard to tell apart when overlapping in playtests, an **optional** setting (off by
    default) can show a brief outline. It is an accessibility aid, not an identifier.
- **Pipeline**: Phase 1 ducks are built from Godot primitive meshes (capsule body, sphere head,
  flattened bills), which already fits "simple shapes". Refined models come from **portable
  Blender** (zip, no install), exported as `.glb`. Commit `.glb` files rather than `.blend` imports,
  so the container never needs Blender.

## 6. Gameplay architecture

### Duck (`duck.tscn`)

```text
Duck (CharacterBody3D)
├─ Visual (Node3D)                  # rigid parts, animated
│  ├─ Body ─ Tail, WingL, WingR
│  ├─ Head ─ BillUpper, BillLower
│  └─ FootL, FootR
├─ InteractArea (Area3D, in front of bill)   # edibles / story interactables
├─ QuackAudio (AudioStreamPlayer3D)
└─ AnimationTree                    # locomotion blend + action one-shots
```

| Ability | Implementation |
| --- | --- |
| Walk / run | `DuckMotor`: camera-relative stick input, acceleration and turn-rate curves. Run is held. Waddle is a procedural body roll and bob, scaled by speed. Feet cycle via `AnimationTree` blend space. |
| Jump | Coyote time and jump buffer. Variable height (release early to cut). A short, comic flap of the wings at the apex for a small hang time. |
| Quack | An **overlay** that works while moving: bill opens, head bobs, body squashes. Random pitch ±8% around each duck's base pitch. Emits a `quacked` signal (NPCs, story beats, and the other duck can react). |
| Tail wag | Overlay: procedural sine on `Tail` rotation, with amplitude and decay. Triggered by button, automatically when idle, and on "happy" story beats. |
| Eat | Targets the nearest `Edible` in `InteractArea`. Briefly locks movement for a dabble or head-dip animation, then consumes or shrinks the edible and emits `ate(item)`. With no target, it plays a cute "peck at nothing" animation. |

State model: a small state machine for locomotion (`Idle`, `Walk`, `Run`, `Airborne`, `Eating`).
Quack and wag are independent overlay layers that do not change state.

**Two sizes, one scene.** `duck.tscn` takes a `DuckProfile` resource (`tall.tres`, `short.tres`)
holding the scale, a collider that matches the body, quack base pitch, and whether to show the
necklace. Abilities and controls are identical. The height difference is expected to matter in
gameplay eventually. How it is used is still undecided, so there is no plan or schedule for it yet.

### Local co-op input

Godot actions match *any* device by default, which breaks co-op. The fix:

- The `PlayerSlots` autoload owns slot 1 and slot 2, each mapped to a device id.
- **Join screen**: pressing A or Start on any pad claims the next free slot. That player then picks
  the tall or short duck with left or right on the stick. Keyboard (WASD) can claim a slot during
  development.
- On join, the base actions (`move_*`, `run`, `jump`, `quack`, `eat`, `wag`, `pause`) are cloned
  into `p1_*` / `p2_*` with each `InputEvent.device` set to that pad. Ducks read only their own
  prefixed actions, so each local player stays bound to their assigned controller.
- **Hotplug**: on `Input.joy_connection_changed`, a disconnect pauses the game and shows the
  disconnected duck's silhouette with "press A". A reconnect re-binds automatically. Bluetooth
  pads that go to sleep take this path too.
- **Controllers: Xbox pads.** Godot 4.5+ reads pads through SDL. The two Bluetooth pads stay paired
  to MiniBambo, and Steam Link forwards them to the PC when streaming, so **nothing is ever
  re-paired**. The PC's wired pad is used at the desk. In the native Windows editor, it works
  directly with no bridge.
  - For a two-pad test: stream the exported build to the TV and use the two Pi pads.
  - Phase 0 checks that the game sees the two forwarded pads as separate devices. Steam Input may
    present them as its own virtual controllers. If it merges or remaps them, turn Steam Input off
    for this shortcut.

Default pad layout: left stick to move, **A** jump, **X** quack, **Y** eat, **B** (hold) run,
**RB** wag, **Start** pause. All of these can be remapped later.

### Co-op camera (`coop_camera.tscn`)

- Follows the midpoint of the two ducks at a fixed pitch of about 45°, and zooms out as they move
  apart (clamped).
- **Soft tether**: past about 12 m apart, the ducks' outward movement is damped, so neither duck
  leaves the frame.
- Story volumes can override framing for scripted shots.
- Split-screen is out of scope. It is noted only as a Windows-only option if the story ever needs
  the ducks apart.

### Keeping the ducks visible (core system)

The ducks must be visible almost all the time, including under large roofs and overhangs. A food
cart pod with a big covered bar area is the reference case. A high camera looking down at 45° sees
the top of the roof, not the ducks under it. Pushing the camera in under the roof doesn't work with
two ducks who may be on either side of the roof edge. So the world gives way to the camera, rather
than the camera dodging the world. These are layered, from most to least common:

| Layer | What it does | When it applies |
| --- | --- | --- |
| **Cutaway volumes** | Roofs, overhangs and upper floors belong to a `Cutaway` group tied to an `Area3D` under them. While any duck is inside, the group dithers out quickly, leaving a thin outline of its edge. It switches to *shadows only* (`cast_shadow = SHADOWS_ONLY`), so the roof keeps shading the ground and the space still feels covered. | Designed covered areas: the food cart pod roof, bar awnings, a barn, a bridge underside |
| **Occluder fade** | Objects tagged `Fadeable` (posts, umbrellas, tree canopies, string-light rigs, carts) dither out when they sit between the camera and a duck. This uses a `fade` value in the shared toon shader with ordered dithering. TAA smooths the dither, and no transparency sorting is needed. | Anything incidental that drifts into view |
| **Duck silhouette** | Any part of a duck that is still hidden draws as a soft pastel silhouette through the occluder, only where it is occluded. | The safety net for whatever the first two layers miss |
| **Camera hints** | Story or camera volumes can raise the pitch, pull in, or shift framing for a specific spot. | Hand-tuned exceptions |

Rules this sets for building chapters:

- **Every mesh is tagged** as `Solid`, `Fadeable` or `Cutaway`. `Solid` geometry must never be able
  to sit between the camera and a walkable spot. Walls tall enough to block the view are either
  `Fadeable` or kept on the far side of the camera's view.
- Lighting under cover stays bright enough to read pastel ducks. The duck's rim light is never
  turned off.
- The short duck is the harder case, so it is the one checked.

**Automated visibility check.** `tests/visibility_audit.gd` runs headless in the container for
each chapter. It samples walkable points from the navigation mesh, places the short duck there with
the tall duck at varied offsets, positions the camera rig as in play, and applies the cutaway
volumes. It then raycasts from the camera to several points on each duck. It fails if any duck is
blocked by `Solid` geometry at more than 1% of walkable points, and writes a top-down heatmap of the
problem spots. This turns "visible almost all the time" into a number that `test.sh` checks.

Two things to confirm in Phase 0 rather than assume, on Forward+: per-object fade through `instance
uniform` values, and the occluded-only silhouette through the stencil support added in Godot 4.5.
The fallback for the silhouette is a faint always-on-top ghost of the duck. The fallback for the
fade is one material copy per fadeable group.

### Story and chapters

**Tone: cozy and wholesome.** There are no fail states, enemies, timers or deaths. Falling in water
means a short swim back to shore. Missing a jump costs a few seconds at most. There are no named
characters; the ducks, NPCs (a frog, a heron, and so on) and places are all unnamed.

**Twelve chapters, each its own environment, flowing into the next.** Transitions are deliberately
left for later, but the structure keeps them possible:

- Each chapter is a self-contained scene in `world/chapters/chNN/` with its own lighting and
  environment settings, its own palette row (§5), and an `EntrySeam` and `ExitSeam` marker. The
  exit area of one chapter and the entry area of the next are designed as matching edges, so a
  future transition can stitch them together.
- **`ChapterLoader` autoload**: loads the next chapter in the background with
  `ResourceLoader.load_threaded_request` as the ducks approach the exit, then swaps scenes and frees
  the old one. Only two chapters are ever in memory. Until transitions are designed, the swap is a
  plain fade to a pastel color.
- Swaps must not hitch. The main risk on Forward+ is a stutter the first time a new shader is used.
  Godot 4.4+ compiles shaders ahead of time, and the shared single material keeps the number of
  shaders small. This is measured in milestone 5.

Systems:

- **`StoryDirector` autoload**: chapter progression and a `flags` dictionary. It listens to duck
  signals (`quacked`, `ate`, `entered_area`).
- **`StoryTrigger` (Area3D)**: has a condition (flags, "both ducks inside", "a duck quacked here")
  and an action list (bubble, camera shot, spawn, set flag, next chapter).
- **Storytelling without names**: mostly wordless. NPCs "talk" in **pictogram bubbles** (a berry, a
  lost egg, a heart) with babble audio. The ducks reply only with quacks and emote bubbles. Short
  text captions are optional per beat, which also keeps translation out of scope. The data is
  custom `Resource` files. A dialogue plugin is not needed for this style.
- **Save**: checkpoint JSON in `user://save.json` (flags, chapter, checkpoint id), written when a
  chapter or checkpoint is reached. A chapter-select screen unlocks chapters already reached.

## 7. Milestones

Each milestone ends with lint, tests, and the Windows export passing in the container, plus a
manual playtest both at the PC and **streamed to the TV through Steam Link**.

| # | Milestone | Exit criteria |
| --- | --- | --- |
| 0 | **Toolchain + streaming spike** (de-risk first) | Container builds with pinned hashes. The portable Windows editor launches in Forward+ on the RTX 4090, opens the project, and the PC's wired Xbox pad controls the test scene directly. The editor launcher and container each report the pinned version, and the container's project-version check passes. A debug Windows build exports from the container and runs locally. The test scene has 100 pastel shapes, one duck capsule, fog, glow, and **one large roof on posts**. **Steam Link: `builds/current/DuckGame.exe` is added to Steam as a non-Steam game and streamed to MiniBambo. The two Pi pads show up as two separate devices in the game, there is no visible banding in the sky and fog, and latency feels fine.** Also confirm that `instance uniform` fade and stencil silhouettes work on Forward+. |
| 1 | Duck movement | One duck from primitives. Walk, run, and jump feel good on a pad. Placeholder camera. Unit tests for the motor and state transitions. |
| 2 | Duck expression | Quack, wag, and eat with animation and audio. `Edible` items. Signals wired. |
| 3 | Local co-op + visibility | Join screen with tall/short pick, two ducks, per-device input, hotplug pause and resume, co-op camera with tether. **All four visibility layers and the visibility audit, proven on a test diorama in grey boxes modeled on a food cart pod (a big covered bar area, carts, picnic tables, posts, string lights).** Tests for slot assignment. The audit passes on the diorama. |
| 4 | Art pass | Palette atlas with per-chapter rows, toon shader (with fade and silhouette), sky, fog, glow, SDFGI and SSAO tuned. Blender-refined tall and short ducks (with necklace) and a 20–30 piece environment kit, every piece tagged `Solid`, `Fadeable` or `Cutaway`. The look is checked through the stream as well as on the monitor. |
| 5 | Story vertical slice | `StoryDirector`, triggers, pictogram bubbles, scripted camera, checkpoints, `ChapterLoader`. **Chapter 1** (about 10 minutes) playable start to finish and passing the visibility audit, ending in a fade into a stub chapter 2 that was loaded in the background with no hitch. |
| 6 | Polish and packaging | Pause and settings menu (volume, rumble, render scale, effect toggles, optional duck outline). Chapter select. Credits. Versioned exports. A Steam non-Steam-game entry with library artwork. |
| 7 | Chapter transitions | Design how one environment blends into the next (palette blend between rows, stitched seams, or a walking transition). Deferred on purpose until a few chapters exist. |
| 8+ | Chapters 2–12 | One environment per chapter, each passing the visibility audit. Settings are chosen later. Add new mechanics only when the story needs them. |

## 8. Risks

| Risk | Mitigation |
| --- | --- |
| Ducks hidden under roofs, overhangs or behind props | The core visibility system (§6) with four layers, plus the headless audit that fails builds above 1% blocked. Proven on the food-cart-pod diorama in milestone 3, before any real chapter is built. |
| Cutaway roofs look odd (popping, or covered spaces stop feeling covered) | Quick dither fade instead of a hard pop, the roof kept as a shadow caster, and an outline of its edge left in place. Tuned on the diorama. |
| Streamed pastel gradients band or blur | Debanding, faint grain in the sky and fog, avoiding fine shimmering detail, and the Steam Link quality setting. Checked in Phase 0 and again in the art pass. |
| Steam Input merges, remaps or hides the forwarded pads | Phase 0 check. Turn Steam Input off for this one shortcut if needed. |
| Streaming needs the PC on and Steam running | Accepted. Playing at the PC monitor needs nothing extra. |
| Shader-compile hitch on chapter swap | Godot 4.4+ compiles shaders ahead of time, and one shared material keeps the count small. Measured in milestone 5. |
| Portable editor and container versions drift | `check-version.sh` runs at the start of `export.sh` and `test.sh`; launchers use the same pinned Godot release. |
| Co-op camera feels bad in tight spaces | Design chapters as open "dioramas" first. Add camera hint volumes where needed. |
| Story scope creep (12 chapters is a lot) | Ship chapter 1 as a complete slice first. Each later chapter reuses the shared kit and a new palette row before any new mechanic. |
| Asset licensing | CC0 only (Kenney, CC0 Freesound) or self-made. Track everything in `CREDITS.md`. |

## 9. Decisions log

Answered 2026-11-18:

| Question | Answer | Effect on the plan |
| --- | --- | --- |
| Editor location | Portable Windows editor (option D) | Forward+ on the 4090 and direct access to the wired Xbox pad; build/test toolchain stays containerized (§1) |
| Controllers in the editor? | Yes | Wired Xbox pad works directly in native Windows editor play; no bridge required |
| Pi support | Dropped in favor of Steam Link streaming and the better renderer | Windows-only Forward+ build; TV play over Steam Link (§1, §4) |
| Controllers | Xbox. Two pads paired to the Pi over Bluetooth; one more pad wired to the PC | Pi pads are forwarded by Steam Link, so nothing is re-paired (§6 input) |
| Location | `homelab/duck-game/` | §2 |
| Story | Cozy, no named characters, about 12 chapters, each its own environment blending into the next; transitions later | §6 Story and chapters, milestones 7–8 |
| Ducks | No identifiers; one taller, the shorter wears a small necklace | §5 and §6 `DuckProfile` |
| Settings | Not yet. Keeping ducks visible is the hard part; a food cart pod with a large overhang is the reference case | Visibility system (§6), food-cart-pod test diorama in milestone 3 |
| Height difference | Should matter in gameplay, but how is undecided | Deferred: no mechanics or schedule in this plan |

## 10. Open questions

None blocking. The next step is milestone 0: the container toolchain, portable editor, and Steam
Link streaming spike.
