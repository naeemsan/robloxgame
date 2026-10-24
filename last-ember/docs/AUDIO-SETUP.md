# Enable the supplied original horror sound design

The game works with built-in fallback cues by default. Original WAVs are supplied separately because Roblox requires audio assets to be uploaded and permitted for the target experience.

1. Publish a private test experience from your own Roblox account or group.
2. In Creator Dashboard, open your creation/development items and upload the seven files from assets/audio as Audio assets.
3. Wait for processing/moderation and grant the experience permission to use each audio asset.
4. Copy the audio asset IDs into ReplicatedStorage → EmberShared → Config → Audio:
   Drone.id, Whisper.id, Impact.id, Scream.id, Bell.id, Heartbeat.id, Burn.id.
5. Leave fallback strings and volume settings intact. The client uses the uploaded sound at its original playback rate whenever id is greater than zero.
6. Publish the updated place and test in the private experience. Check Output for load/permission errors.

No credentials are required in code or chat. These steps cannot be performed on the owner's account from this cloud environment.

Included sources are original nonverbal synthesis made by tools/audio.py:
- Drone: detuned low tones and filtered noise.
- Whisper: modulated wind-like noise, no recorded speech.
- Impact: decaying low-frequency strike.
- Scream: synthetic dissonant shriek, no sampled person.
- Bell: inharmonic metallic decay.
- Heartbeat: two low pulses.
- Burn: filtered crackle and noise.

Roblox-bundled fallback references were checked against the current character sound script:
https://github.com/MaximumADHD/Roblox-Client-Tracker/blob/roblox/scripts/PlayerScripts/StarterPlayerScriptsCommon/RbxCharacterSounds.lua

Bundled fallback recordings are not redistributed in this repository.
