# Rumal Rush — complete v1 source and Studio place

A small, self-contained Roblox courtyard game inspired by Rumal Jhapatta / Steal the Bacon. Two runners contest one scarf: take it home, or tag the carrier. This is a new game implementation, not an update to the earlier Pocket Parade prototype.

## Just open and play

Open **RumalRush.rbxl** from the release ZIP in Roblox Studio using **File → Open from File**. Press **Play**, then click **PLAY A MATCH** in the game. You do not need Python, Rojo, plugins, API keys, or pasted scripts to try the game. The .rbxlx file is an alternate XML version of the same place.

One player gets Milo, the practice bot. For friends, start a Studio server with 2–8 clients and click Play a Match in each client during the 8-second intermission. One runner from each team plays per round; other teammates watch and rotate in. Late arrivals join the next match.

## Included

- An already-built courtyard arena visible in edit mode: 115 anchored parts, four house facades, trees, bunting, home lines, and viewing deck.
- Solo practice with Easy and Standard bot difficulty.
- Multiplayer team-duel rotation, first to three points, nine-round cap, draws, respawn/leave handling, and optional rematches.
- A central pickup that moves to offset positions between rounds.
- Grab, short dash with cooldown, automatic close-range tagging, pickup grace, home-line scoring, and server movement validation.
- Keyboard, touch buttons, and gamepad action bindings; arena and follow camera options.
- Coin cosmetics, persistent progress when Roblox DataStores are available, and one optional permanent cosmetic game pass.
- A compact interface with instructions, timer, scoreboard, locker, feedback, and a low-effects option.

## Controls and rules

| Action | Keyboard | Gamepad | Touch |
| --- | --- | --- | --- |
| Move | WASD | Left stick | Roblox thumbstick |
| Grab nearby scarf | E | X | GRAB button / proximity prompt |
| Short dash | Shift | B | DASH button |

Before pickup nobody can tag. After pickup the other runner can tag by getting close. The carrier scores by reaching their own colored home line. A tag on the line wins the tie. There is 0.8 seconds of pickup grace; dashing does not grant invulnerability. If time expires with a carrier, defense wins; without a pickup, the round is a draw.

The match ends at three points or after nine rounds. No login streak penalties, paid stat boosts, random paid rewards, or forced rematches.

## Saves

An unpublished local file works in practice mode, with session-only coins. To use real saves, privately publish a test experience and configure Studio API access there. Use a separate test experience to avoid modifying a live game's data.

The server uses session leases, sanitizes stored values, retries failed requests, autosaves every 45 seconds, and saves on exit/shutdown. A failed initial load or busy session enters practice mode and never overwrites existing data. Online DataStore behavior still requires Studio/live testing. The optional pass is rechecked through Roblox each join; equip its cosmetic in the locker.

## Optional Robux pass

Buying is disabled by default. In Creator Dashboard, create a game pass for your experience named **Neon Club**, set its price, then enter the real pass ID in **ReplicatedStorage → RumalShared → Config → NeonPassId** in Studio. Publish the updated place. The client retrieves the current price before showing Roblox's own confirmation dialog. The server checks ownership; a client event cannot grant it.

Only the cosmetic scarf color and short trail change. Speed, dash, tagging, rewards, and matchmaking stay equal. No credentials belong in the source. Earnings are not guaranteed.

## Validation and limits

45 automated tests passed: 27 rules, 11 persistence tests using a mocked service, and 7 bot decision tests using vector fixtures. All 7 production Luau scripts compiled. The complete place was imported by Rojo and built into binary and XML outputs with its embedded source verified.

**Roblox Studio was not available on the build machine.** Actual playtesting, Roblox networking/physics, UI fit on devices, live saving, payment confirmation, and low-end FPS have not been measured. Read docs/TESTING.md before a public launch. The preview image is a render of the build geometry, not a Studio screenshot.

## Rebuild from source (optional)

Python 3 alone can rebuild an XML place:

    python tools/build.py --output RumalRush.rbxlx

For Linux x86_64 compilation checks and a binary release:

    python tools/bootstrap.py
    python tools/verify.py
    python tools/release.py

The bootstrap downloads pinned official Luau 0.743 and Rojo 7.7.1 releases over verified HTTPS, checks SHA-256, and installs them outside the checkout under /workspace/rumal-tools. No runtime dependency downloads are required by the game. Tool paths and output directories can be overridden with command-line arguments.

The default.project.json file also supports Rojo. The assets/Arena.rbxmx file is generated from tools/arena_layout.py; run the build script after changing the layout.

## Originality research

Roblox's public search endpoint returned mostly unrelated results for Rumal, Steal the Bacon, Lagori and Pithu. This is not proof that the real-life rules have never appeared on Roblox. See docs/RESEARCH.md. The design was selected for clear decisions, solo practice, short competitive rounds, and a modest rendering budget.
