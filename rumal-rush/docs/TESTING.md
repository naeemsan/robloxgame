# Verification report

## Passed in the cloud build environment

- **7 production Luau scripts** compiled with official Luau 0.743.
- **27 rule tests**: finite inputs, bounds, phase-gated pickup, duplicate pickup, cooldowns, pre-pickup tagging exclusion, both home lines, wrong-line rejection, grace, line/tag ties, vertical distance, timeouts, match cap, cosmetic purchases, forged purchases, movement budgeting and a complete rules-level match simulation.
- **11 persistence tests with a mocked DataStore boundary**: session acquisition, saved reward/purchase restoration, busy and expired leases, lost lease, initial-load failure, save retry, cosmetic ownership validation, corrupt values, departure during load and lease release.
- **7 bot decision tests with vector fixtures**: reaction delay, pickup approach, both home directions, pursuit, difficulty difference, dash cooldown and court bounds.
- Deterministic XML output, exact source embedding, unique instance references, anchored arena part budget and project manifest checks.
- Rojo 7.7.1 imported the full DataModel and built both binary .rbxl and canonical XML .rbxlx files; embedded source matches the production files.
- Build tools were downloaded from pinned official release URLs with TLS verification and SHA-256 checks.
- Arena geometry rendered in a separate preview to inspect layout. This does not test Studio rendering or UI.

## Not executed: Roblox Studio / live service checks

1. **Single player:** open the place, press Play, enter a match. Confirm the player spawns on the teal side, Milo approaches, E/touch pickup works, Shift dash expires, both score paths occur, and a first-to-three match returns to the menu.
2. **Two clients:** join during intermission. Verify only one client claims the scarf, tagging is server-decided, both sides can score, and no countdown scoring is possible.
3. **Four/eight clients:** each side rotates runners; spectators cannot interact. Test a late joiner, sitting out, reset/death, and leaving during countdown and live play.
4. **Latency:** test simulated latency/jitter. Movement validation has a burst allowance but needs tuning from real network observations.
5. **Persistence:** privately publish a separate test experience, enable Studio API access, earn/spend coins, rejoin and verify. Disable access and confirm practice-mode feedback. Actual Roblox throttling/outage behavior is untested.
6. **Cosmetic pass:** set the owner's real pass ID; check price, cancellation, real ownership verification and later rejoin. Default ID 0 must never prompt a purchase.
7. **Devices:** check small landscape phone, tablet, laptop and gamepad. Verify the action controls do not conflict with the Roblox thumbstick, and all menu buttons remain reachable. Test both cameras and reduced-effects mode.
8. **Performance:** measure on the target low-end PC. The design uses 115 static parts, one scarf, one simple bot when needed, no imported meshes/textures, short trails, and a 20 Hz server rule loop. No measured FPS or memory claim is made.
9. **Public launch:** choose experience name/icon, review Roblox settings and accessibility, and test the published private version before making it public.

## Scope limitations

- One courtyard arena; round variety comes from pickup position and opponents, not a library of maps.
- Team matches are rotating one-versus-one duels, not simultaneous three-versus-three combat.
- The practice bot is a simple deterministic opponent, with no pathfinding obstacles or generated dialogue.
- No custom audio assets are included.
- A server that loses its session lease enters practice mode. Unsaved progress during a Roblox outage can still be lost.
- Movement checks are basic server validation, not a comprehensive anti-cheat solution.
- The paid cosmetic can be equipped from the locker after Roblox ownership is checked each visit.
- No account login, public publishing, paid product creation, or monetization eligibility verification was performed.
