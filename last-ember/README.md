# The Last Ember

An original **third-person, 1–4 player co-op horror** build for Roblox. Enter an abandoned manor, restore its generator, burn six cursed seals, and escape while the Mourner hunts your team. This replaces the overhead-arena direction; the previous Rumal Rush files remain preserved.

## Open the game

Open **TheLastEmber.rbxl** in Roblox Studio with **File → Open from File**, press **Play**, then choose **ENTER THE HOUSE**. No script pasting or plugin is required. The camera stays behind your character, with a 5–10 stud zoom range.

For co-op testing, use Studio's local server with 2–4 clients. Everyone should click Enter during the seven-second ready countdown. Late arrivals queue for the next mission.

## Mission

1. Search the chapel, ward, kitchen, archives and corridors for two blue fuses.
2. Carry each fuse to the generator at the west end of the cross-corridor. Hold the interaction prompt to install it.
3. Find six gold cursed seals and take them to the furnace in the north ash chamber.
4. Hold the burn prompt. Each burned seal increases the Mourner's aggression.
5. When all six are gone, return to the front gate and escape.

Players carry one item. A downed player drops their item, and a teammate can revive them before their light fades. If the whole team falls, the mission ends. A solo player receives one automatic second chance. The mission has a 15-minute limit; sessions do not save mid-mission.

## Controls

| Action | Keyboard | Gamepad | Touch |
| --- | --- | --- | --- |
| Move / look | WASD / mouse | Sticks | Roblox thumbstick / drag |
| Interact | Hold E | Hold X | Hold proximity prompt |
| Sprint | Hold Shift | Hold L3 | Sprint toggle |
| Flashlight | F | Y | Light button |
| Drop item | G | D-pad down | Drop button |
| Leave hiding place | H | B | Leave button |
| Call teammates | Q | D-pad up | Call team button |

Wardrobes provide at most 12 seconds of refuge. They cannot hide you if the Mourner watches you enter at close range. Sprinting can be heard. Turning off your light is not invisibility.

## Visuals and horror presentation

The manor contains 507 architecture/furnishing parts, authored room layouts, material-based walls/floors, portraits, a furnace, shelves, beds, candles and 15 fixed lights. It uses Roblox's Realistic lighting style, local flashlight shadows, color grading, restrained bloom, fog, third-person movement, and an original procedural creature.

Settings offer **Cinematic / Balanced / Low**, sound volume, and reduced scares. Full scares include a creature close-up, a short blackout, proximity heartbeat and mild camera shake. The default camera is never an overhead stadium camera.

This is an atmospheric stylized build, **not a photorealistic asset pack or a claim of measured HD performance**. Roblox quality, device capability and display brightness affect appearance. Any included offline interior render is a layout/material illustration, not a Studio screenshot or FPS measurement.

## Audio: included and ready to configure

The place starts with Roblox-bundled sound fallbacks: ambience, lowered impact/groan cues, proximity heartbeat and spatial enemy footsteps. They use built-in content paths referenced by Roblox's character-sound scripts, not unverified marketplace IDs.

Seven **original generated WAV files** are also included under assets/audio:
Drone, Whisper, Impact, Scream, Bell, Heartbeat and Burn.

**Custom WAV files cannot be embedded as playable Roblox audio in a place file.** To hear the original sound design, upload those WAV files through your Roblox creator account/group, grant the experience audio permissions, and put their IDs into **ReplicatedStorage → EmberShared → Config → Audio**. Keep each ID at 0 to use its fallback. No passwords or API keys belong in the game.

The generated sounds are nonverbal synthesis, with no sampled recordings. You may use them for this project. Their loudest sample is normalized below full scale; the in-game mixer has Full / Low / Off.

## Optional cosmetic purchase

The Spectral Lantern game pass only changes the lantern tint. It does not increase brightness, range, speed, stamina or protection. Its ID defaults to 0 and buying is disabled. To enable it, the owner must create a real pass and set SpectralLanternPassId. The server verifies ownership and the client reads the current price before opening Roblox's own purchase dialog. Earnings are not guaranteed.

## What was validated

- All 6 production Luau scripts compile.
- 45 offline rules tests pass, including mission completion, item limits, power gating, escape, downed states, stamina, hiding eligibility and target selection.
- A conservative clearance model reaches all 12 possible loot positions, all refuge exits, patrol regions and mission stations.
- XML generation is deterministic and embeds the exact source.
- Rojo imports the complete place and produces binary and XML files.
- All 7 WAVs have valid mono 44.1 kHz / 16-bit PCM headers.

**Roblox Studio is unavailable on the build machine.** Monster locomotion/pathfinding, interaction event timing, actual co-op play, camera/UI on real devices, live audio permissions, payment behavior and performance still need Studio validation. See docs/TESTING.md. The file is a playable-build candidate for that validation, not a falsely certified public release.

## Rebuild

Python can rebuild the XML place:

    python tools/build.py --output TheLastEmber.rbxlx

Pinned Linux tools can compile/test and build the binary:

    python tools/bootstrap.py
    python tools/verify.py
    python tools/release.py

The bootstrap installs checksum-verified Luau 0.743 and Rojo 7.7.1 outside the checkout at /workspace/rumal-tools. NumPy is only needed to regenerate the original audio with tools/audio.py; it is not a game runtime dependency. The generated audio and manor model are already included.

The static map comes from tools/manor_layout.py. Server gameplay is in src/ServerScriptService/EmberServer; the interface, camera presentation and audio mix are in EmberClient.client.lua.
