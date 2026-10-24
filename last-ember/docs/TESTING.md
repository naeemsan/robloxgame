# Build verification and Studio acceptance

## Executed

- Six production scripts compiled with Luau 0.743.
- 45 pure rules tests passed: input validation, interaction phase/range/hold gates, inventory limits, fuse progression, burning gate, exactly six seals, escape, stamina, hiding eligibility, co-op downed/escape outcomes, timeout, threat progression, line-of-sight/hearing target choice and movement budgets.
- 7,237 connected grid cells in a conservative horizontal clearance model. All loot locations, hiding exits, patrol regions, generator, furnace and exit can be approached.
- Deterministic layout and XML; exact source embedding; third-person camera limits; realistic-lighting properties.
- Six-script DataModel imported and built by Rojo 7.7.1 into .rbxl and .rbxlx.
- Seven valid mono 44.1 kHz / 16-bit original PCM WAV files.
- Runtime gameplay has no external models, texture downloads or unverified marketplace audio IDs.

## Still needs Roblox Studio / private experience testing

1. Solo: complete a mission, check both fuses and all seals, furnace fire, actual gate escape, caught state and single automatic second chance.
2. Two and four clients: ready together, simultaneous pickup/deposit, revive hold completion, no duplicate seals, dropped-item recovery, partial escape, and all-downed loss.
3. Reset/disconnect while carrying, hiding, downed and escaped. Confirm resources remain available and the next mission resets correctly.
4. Monster rig locomotion, navmesh paths through all doors, line-of-sight occlusion, hearing, hunting memory, attack distance and grace after revival. The offline clearance grid is NOT Roblox pathfinding.
5. ProximityPrompt hold begin/end/trigger ordering under latency. The server permits a short completion-event grace window; final distance, phase, status and line-of-sight are checked.
6. Camera and interface on desktop, gamepad, phone and tablet. Verify touch buttons remain reachable and third-person camera collision works indoors.
7. Built-in fallback audio playback on the current Roblox client; uploaded original sound permissions in the published experience.
8. Cinematic, Balanced and Low modes on the actual target PC. No measured FPS claim is made.
9. Optional pass disabled at ID 0; verify real price, cancellation and server ownership if the owner configures it.
10. Use a private published experience before a public launch. Set the intended server size to four in experience settings.

## Known scope

One manor and one mission, randomized item placement, one procedural creature, no checkpoint save, no voice chat system, no inventory marketplace and no photorealistic custom mesh pack. Generated WAVs require owner-side Roblox upload before they replace fallback cues. No live service action or purchase was executed.

The implementation is an original adaptation of co-op objective-horror mechanics. It does not copy Pacify's characters, assets, story, branding or exact map.
