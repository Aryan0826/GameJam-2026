# Conqueror’s Chess

Pilot the Horizon as Commander Valeria, explore a solar system, and answer alien challenges from the ship’s cockpit. Each destination has a five-ship tactics duel on a 9 × 9 board. Play against the computer or share the keyboard and mouse in a local duel.

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
4. Press **Enter** to finish the incoming transmission and again to accept the solo challenge. Choose **Local duel** after the transmission for two-player play. **Q** leaves from the communication screen. During a match, use the orbit exit button to end the duel and resume flight.

## Board controls

- Click a ship, then a highlighted destination. Drag the board to rotate and tilt the camera. With the board focused, use the arrow keys to move the cursor and **Enter** to select.
- Move one square orthogonally or one or two squares diagonally. A two-square diagonal can jump over an intervening ship. Capture one square diagonally forward. Pilots capture toward the top of the board and Aliens toward the bottom.
- **Rules** opens the current planet’s guide. **View log** shows recent events and lets you copy replay data. **Rematch** swaps the starting side. **Take Over Aliens** switches a solo match to local control on an Alien turn boundary.
- Adjust **Music** and **Effects** on the title screen. Press **M** to mute or unmute. **FX** controls visual motion.

### Kalypso · The Fractured Flag

Hold the center flag with the same ship through three opposing turns, or eliminate every opposing ship. The match draws after eight rounds if neither side wins. The outer rims collapse in stages, and ships on falling tiles are lost. Empty flag squares can only be entered from an adjacent square.

1. Draft a different one-use ability for each of two ships, then lock the draft. Local players pass the device between private drafts.
2. **Shuffle** to draw a power. Select a ship for a regular move or choose its drafted ability from its hologram. The drafted ability uses the move for that turn.
3. Click the drawn card and a highlighted target to use the power. You can move then use the power, move only, or use the power alone.
4. Choose **Finish / skip turn** to pass control.

| Drafted ability | Effect |
| --- | --- |
| **Shield** | Blocks one capture. Entering the flag clears it. |
| **Fracture Tile** | Marks a tile outside the flag to fall after the next turn. |
| **Teleport** | Jumps to an empty, intact, uninfected square outside the flag. |
| **Borrow Tomorrow** | Moves two friendly ships one orthogonal square each. The first returns to its original square after your next turn if it’s still available. |

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
  core/               Expedition state and audio service
art/
  audio/              Music, effects and audio attribution
  flight/             Horizon sprite, exhaust and celestial bodies
  cockpit/            Cockpit surfaces, decals and sky art
  fleet/              3D board units and relay model
  cards/              Ability card icons
  results/            Crew and alien portraits
  fonts/              Fonts and license notices
  guides/             Illustrated movement references
shaders/              Starfield, rotation and prologue shaders
tests/                Rules, camera, cards, holograms, travel and results
tools/                Movement-guide screenshot generator
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
godot --headless --path . --export-release Windows builds/windows/ConquerorsChess.exe
godot --headless --path . --export-release Web builds/web/index.html
~~~

On Windows, keep the exported `ConquerorsChess.pck` beside the executable. For the browser build, run `python -m http.server 8080 --directory builds/web` and open [localhost:8080](http://localhost:8080/). The Web preset uses a single-threaded export.

## Credits

Developed by the Conqueror’s Chess game jam team. See the [asset credits](ASSET_CREDITS.md) for individual files, licenses, modifications, and supplied assets whose origin still needs confirmation.

- **Horizon art:** Luis Zuno (Ansimuz). **Animated exhaust:** KlenchAndrei. [Sideview Sci-Fi](https://opengameart.org/content/sideview-sci-fi-patreon-collection) · [Free Pixel Rocket Exhaust](https://klenchandrei.itch.io/exhaust-free)
- **Board models and sound effects:** Kenney. **Cockpit textures:** cheerful sprite. **Cockpit planets:** Screaming Brain Studios. [Space Kit](https://kenney.nl/assets/space-kit) · [Spaceship Interior](https://opengameart.org/content/spaceship-interior-0) · [Tiny Planet Pack](https://screamingbrainstudios.itch.io/tiny-planet-pack)
- **Result art:** Emcee Flesher. **Card icons:** Gerrit Halfmann. **Nebula photography:** NASA, ESA and the Westerlund 2 imaging team. [Sci-Fi RogueLike Pixel Art](https://opengameart.org/content/sci-fi-roguelike-pixel-art) · [Pixelarticons](https://github.com/halfmage/pixelarticons/tree/v1.8.1) · [Westerlund 2](https://esahubble.org/images/heic1509a/)
- **Music:** yd. **Infected Trail sound:** spookymodem. [Observing the Star](https://opengameart.org/content/another-space-background-track) · [My Very Own Dead Ship](https://opengameart.org/content/background-space-track) · [Bubbling Acid](https://opengameart.org/content/bubbling-acid)
- **Typography:** Florian Karsten and IBM Corp. [Space Grotesk](https://github.com/floriankarsten/space-grotesk) · [IBM Plex Mono](https://github.com/IBM/plex)
