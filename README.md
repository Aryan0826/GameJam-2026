# The Fractured Flag and Drift Circuit

Lead the Horizon crew as Captain Valeria, explore a solar system, and answer alien challenges from the ship’s cockpit. Each destination has a five-ship tactics duel on a 9 × 9 board. Play against the computer or share the keyboard and mouse in a local duel.

| Destination | Challenge | Objective |
| --- | --- | --- |
| **Kalypso** | **The Fractured Flag** | Hold the center flag through three opposing turns or eliminate the opposing fleet. |
| **Cinder** | **Drift Circuit** | Reach eight combined points from relay claims and surviving ships. |

## Start the game

Open [project.godot](project.godot) in **Godot 4.7.2 Standard** and press **F5**. Choose **Explore** on the title screen. Press **Enter** or **Esc** to skip the prologue, or hold **Space** to speed it up.

For a quick playtest, open [Fractured Flag](scenes/fractured_flag.tscn) or [Drift Circuit](scenes/drift_circuit.tscn) in Godot and press **F6**.

## Fly to a planet

1. Choose **Kalypso** or **Cinder** in the flight HUD. The course marker and minimap track the target.
2. Hold **W / ↑** to thrust, **A / D** or **← / →** to steer, and **S / ↓** to brake. Hold **Shift** or **Space** while thrusting to boost. The ship coasts when you release thrust.
3. Slow down inside the planet’s capture ring and release thrust. Once orbit settles, press **Enter** or **Space** to land, or wait for the two-second descent countdown.
4. A centered cockpit looks straight ahead into black space. A freely licensed star animation makes forward motion clear. An incoming envoy hologram rises from the console and expands into the conversation screen. Press **Esc**, **Enter**, or **Skip descent** to skip the flight sequence.
5. Press **Enter** or the highlighted **Continue** button directly beneath the message to reveal a line, then advance at your own pace. **Skip story** opens the challenge briefing. Accept to play solo, or choose **Local duel** for two people on one device. **Q** opens a farewell; Q again returns directly to flight. During a match, **Leave orbit** ends the duel and resumes flight.

## The Horizon expedition

Captain Valeria and Navigator Sol seek peaceful contact. Kalypso’s envoy Lyra tests your leadership on the collapsing arena; Cinder’s envoy Vesper tests your foresight in the shifting circuit. Each uses an existing freely licensed pixel character.

Win to earn the planet’s alliance. Kalypso grants landing clearance; Cinder opens its navigation network. Lose and you are marked **Unproven**, with access denied until a successful retry. Declining or drawing applies no new penalty. Return visits use shorter dialogue, and friendly rematches cannot revoke an alliance. Standings last for the current expedition; **Replay prologue** starts a new one. Winning both planets unlocks the expedition epilogue.

Each result shows a crew or alien lineup under a colored spotlight, a short exchange (**Next** to read more), the round, and how the match ended. **Return to flight** resumes exploration near the same planet. **Rematch** and **View board** remain available.

## Board controls

- Click a ship, then a highlighted destination. Drag the board to rotate and tilt the camera. With the board focused, use the arrow keys to move the cursor and **Enter** to select.
- Move one square orthogonally or one or two squares diagonally. A two-square diagonal can jump over an intervening ship. Capture one square diagonally forward. Crew capture toward the top of the board and Aliens toward the bottom.
- **Rules** opens the current planet’s guide. The compact flight log wraps entries and scrolls vertically for long messages. **View log** opens the history and lets you copy replay data. **Rematch** swaps the starting side. **Take Over Aliens** switches a solo match to local control on an Alien turn boundary.
- Adjust **Music** and **Effects** on the title screen. Press **M** to mute or unmute. **FX** controls visual motion.

### Kalypso · The Fractured Flag

Hold the center flag with the same ship through three opposing turns, or eliminate every opposing ship. The match draws after eight rounds if neither side wins. The outer rims collapse in stages, and ships on falling tiles are lost. Empty flag squares can only be entered from an adjacent square.

1. Draft a different single use ability for each of two ships, then lock the draft. Each player may choose **Doom Bringer or Teleport**, but cannot draft both across their fleet. Local players pass the device between private drafts.
2. **Shuffle** to draw a power. Select a ship for a regular move or choose its drafted ability from its hologram. The drafted ability uses the move for that turn.
3. Click the drawn card and a highlighted target to use the power. You can move then use the power, move only, or use the power alone.
4. Choose **Finish / skip turn** to pass control.

| Drafted ability | Effect |
| --- | --- |
| **Shield** | Blocks one capture. Entering the flag clears it. |
| **Fracture Tile** | Marks a tile outside the flag to fall after the next turn. |
| **Teleport** | Jumps to an empty, intact, uninfected square outside the flag. |
| **Doom Bringer** | Destroys one empty or enemy tile immediately, removing even a shielded enemy. Cannot target friendly ships or the flag. All launches are locked while an enemy occupies the flag. |

To launch, draft **Doom Bringer** onto a ship. After shuffling, select that ship, choose **Use Doom Bringer** in its hologram, then click a highlighted enemy or empty tile. The launcher stays in place. This single use ability replaces your move; you can still use the drawn power before finishing your turn.

| Drawn power | Effect |
| --- | --- |
| **Infected Trail** | Blocks entry to the 3 × 3 area around your chosen ship through the enemy turn, excluding the flag. |
| **Spy** | Temporarily takes control of a nearby enemy ship for three subsequent turns. A stolen ship can occupy the flag without scoring and cannot capture there. |
| **Long Capture** | Captures an enemy one or two squares diagonally away in any direction. |

### Cinder · Drift Circuit

Take one move or capture per turn. After both sides act, row **4** shifts right and row **6** shifts left, carrying their ships and wrapping at the edges. Hover over a highlighted move on either row to preview the landing.

Each occupied gold relay scores one point after the shift, then relocates to another column on its own row. Row **5** stays still while its relay can relocate too. Your total is **relay points + surviving ships**. If only one side reaches eight on a shift, that side wins. If both reach eight on the same shift, or neither reaches it by round 12, the match draws.

## Project layout

~~~text
project.godot         Godot entry point and autoloads
scenes/               Home, prologue, flight and both duel scenes
scripts/
  battle/             Shared cockpit, board, HUD and battle flow
  rules/              Match rules and computer opponents
  flight/             Ship handling, orbit, planets and minimap
  ui/                 Title screen and prologue
  core/               Expedition state, story and audio service
art/
  audio/              Music, effects and audio attribution
  flight/             Horizon sprite, exhaust and celestial bodies
  cockpit/            Cockpit surfaces, decals and sky art
  descent/            Centered cockpit photograph and forward star video
  fleet/              3D board units and relay model
  cards/              Ability card icons
  results/            Crew and alien portraits
  fonts/              Fonts and license notices
  guides/             Illustrated movement references
shaders/              Starfield, rotation and prologue shaders
tests/                Rules, camera, cards, holograms, travel, story and results
tools/                Movement-guide, story and descent preview capture
builds/               Local exports, ignored by Git
~~~

## Verify and export

Run these commands from the project root with the Godot console executable. Use the **Compatibility** renderer and matching Godot **4.7.2** export templates.

~~~powershell
godot --headless --path . --editor --import --quit
Get-ChildItem tests -Filter '*_test.gd' | Sort-Object Name | ForEach-Object {
    godot --headless --path . --script ("res://tests/" + $_.Name)
    if ($LASTEXITCODE -ne 0) { throw "Test failed: $($_.Name)" }
}
~~~

~~~powershell
New-Item -ItemType Directory -Force builds/windows, builds/web
godot --headless --path . --export-release Windows builds/windows/FracturedFlag.exe
godot --headless --path . --export-release Web builds/web/index.html
~~~

On Windows, keep the exported `FracturedFlag.pck` beside the executable. For the browser build, run `python -m http.server 8080 --directory builds/web` and open [localhost:8080](http://localhost:8080/). The Web preset uses a single-threaded export.

## Credits

Developed by the Horizon game jam team. See the [asset credits](ASSET_CREDITS.md) for individual files, licenses, modifications, and supplied assets whose origin still needs confirmation.

- **Horizon art:** Luis Zuno (Ansimuz). **Animated exhaust:** KlenchAndrei. [Sideview Sci-Fi](https://opengameart.org/content/sideview-sci-fi-patreon-collection) · [Free Pixel Rocket Exhaust](https://klenchandrei.itch.io/exhaust-free)
- **Board models and sound effects:** Kenney. **Cockpit textures:** cheerful sprite. **Cockpit planets:** Screaming Brain Studios. [Space Kit](https://kenney.nl/assets/space-kit) · [Spaceship Interior](https://opengameart.org/content/spaceship-interior-0) · [Tiny Planet Pack](https://screamingbrainstudios.itch.io/tiny-planet-pack)
- **Result art:** Emcee Flesher. **Card icons:** Gerrit Halfmann. **Nebula photography:** NASA, ESA and the Westerlund 2 imaging team. [Sci-Fi RogueLike Pixel Art](https://opengameart.org/content/sci-fi-roguelike-pixel-art) · [Pixelarticons](https://github.com/halfmage/pixelarticons/tree/v1.8.1) · [Westerlund 2](https://esahubble.org/images/heic1509a/)
- **Music:** yd. **Infected Trail sound:** spookymodem. [Observing the Star](https://opengameart.org/content/another-space-background-track) · [My Very Own Dead Ship](https://opengameart.org/content/background-space-track) · [Bubbling Acid](https://opengameart.org/content/bubbling-acid)
- **Typography:** Florian Karsten and IBM Corp. [Space Grotesk](https://github.com/floriankarsten/space-grotesk) · [IBM Plex Mono](https://github.com/IBM/plex)

Story and travel checks: `godot --headless --path . --script tests/expedition_story_test.gd`. UI wrapping, message controls, natural descent and skipping: `godot --headless --path . --script tests/ui_descent_test.gd`. Rebuild actual previews with `godot --path . --script tools/render_story_preview.gd -- /absolute/output/folder` or `tools/render_descent_preview.gd`.

The descent uses Jahobr’s 2017 CC0 star animation and DMolybdenum’s public domain Atlantis cockpit panorama. Full source links and adaptation details are in [descent credits](art/descent/SOURCE.md) and the in-game Asset credits. Doom Bringer uses the supplied PixelProjectiles rocket (whose README describes AI-assisted, programmatically generated artwork) and Luis Zuno’s CC0 explosion animation; see [missile asset details](art/effects/missile/SOURCE.md).
