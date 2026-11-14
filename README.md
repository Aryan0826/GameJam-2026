# Conqueror’s Chess · The Fractured Flag

A pawn-only tactics duel on a collapsing 3D orbital arena. Five pawns per side start in mirrored lines on a 9 × 9 board. Hold the center flag through three opposing turns or eliminate every opposing pawn. The game draws after eight rounds if neither side wins.

## Play

Kalypso hosts **The Fractured Flag** and the red planet Cinder hosts **Drift Circuit**. Select **Cinder** in the flight HUD to turn on its red pointer and mark it on the minimap. Fly toward the planet and release thrust inside its capture ring to enter orbit. Press **Enter / Space** in stable orbit or wait for the descent to open the cockpit communication screen.

Both games begin with an alien exchange typed directly onto the cockpit's computer display, with a blinking `_` cursor and subtle scan lines. The envoy asks why the Horizon is there, Valeria explains that the crew is looking for friends away from home, and the aliens challenge the crew to their game. Win to be welcomed as friends; lose and leave in peace. Press **Enter** to accept once the exchange finishes, or press it during the exchange to reveal the whole conversation first. **Q** declines immediately and resumes exploration outside that planet's gravity and capture boundaries. **Local duel**, **How to play**, **System map**, and **Replay prologue** sit in the bottom bar beside **Asset credits**.

Use **Leave orbit** from either duel, or **Q** from the communication screen, to return directly to exploration at the same planet. Leaving an active duel ends that match. There is no destination-selection menu when quitting; choose a new course from the flight HUD after returning to exploration.

During both games the cockpit shows animated reactor-output and thermal-load graphs plus ship-reserve gauges. These are procedural Godot graphics in `scripts/cockpit.gd`, with IBM Plex Mono labels; no graph image assets are imported. Their credits are listed under **Asset credits**.

In Drift Circuit, the tiles on row 4 lift and slide right and those on row 6 slide left after both sides act. Pieces ride with them and wrap around the edges. Each occupied gold relay scores one point after the shift, then jumps to another column on its own row (4, 5, or 6). Add remaining units to relay points: the first side to reach 8 wins. If both sides reach 8 on the same shift, the match draws; a draw also occurs after round 12 if neither side wins.

Open `project.godot` in Godot 4.7.2 Standard and press **F5**. The opening crawl leads into the solar-system flight and then the Horizon cockpit. After the communication, press **Enter** to face the Aliens or choose **Local duel** for two people on one device. **Replay prologue** returns to the opening crawl.

For the Windows build, extract the ZIP and run `ConquerorsChess.exe` beside its `ConquerorsChess.pck`.

For the browser build, serve `output/web` from the workspace root. For example, run `python -m http.server 8080 --directory output/web` and visit [localhost:8080](http://localhost:8080/). For a jam upload, the Web ZIP contains `index.html` at the archive root. It uses Godot’s single-threaded WebGL 2 export and can be served on HTTPS.

## Controls

- Adjust **Music** and **Effects** separately on the title screen. Press **M** at any time to mute or unmute the mix. **FX** in the cockpit controls visual motion.

- During solar-system flight, hold **W / Up** to accelerate; the ship coasts on release. Exhaust runs while accelerating and during automatic orbit entry. Hold **Shift / Space** while accelerating to boost, **A / D** or **Left / Right** to steer, and **S / Down** to brake. Descent begins after **2 seconds** in stable orbit.
- The rocket begins in open space with a wide camera view. The planets orbit the sun in this order: Ember, Kalypso (home), Cinder, and Aurelia. Their separate orbits and colored gravity boundaries appear on the minimap. The gravity indicator identifies the local planetary well.
- After the Kalypso battle, choose **Return to flight** to resume flying near Kalypso. Choose a destination from the flight HUD. **Rematch** stays at the current planet. **Replay prologue** restarts the journey.
- Click a pawn, choose an action in the right panel if needed, and click a highlighted target. The arrow keys move the board cursor, Enter selects, and Esc clears the selection.
- Click and drag on the board to rotate the camera horizontally and tilt it vertically. Release without dragging to select a pawn or target.
- **Shuffle** before moving or using a drafted ability; draw once per round. Pixel cards shuffle and flip to reveal your ability, which stays visible as a clickable card above **Finish / skip turn**. Click the card to choose a power target; the large reveal stays on screen for 3.6 seconds. **FX off** reveals it immediately. Choose a path: **Move → Use power** (both), **Move → Finish / skip turn** (move only), or **Use power → Finish / skip turn** (power only). To move, select a unit, click **Move / capture**, then a highlighted destination. To use power, click **Use power** and a highlighted target: your unit for Infected Trail, an enemy for Spy or Long Capture. The drawn card names the power.
- In the draft, select two different pawns, assign them different abilities, and lock your choices. In local mode, pass the device when prompted.
- **Take Over Aliens** queues the switch to a second player for the next Alien turn boundary. **Rematch** keeps the current mode, swaps the starter, and creates a new setup.
- **Rules** opens Kalypso’s brief guide with the goal, quick-start steps, separate marked movement and capture screenshots, and current abilities. Drift Circuit keeps its separate rules. **FX** toggles movement effects. **View log** can copy the match seed, starting side, committed actions, first flag round, duration, and outcome.

## Project

- `main.tscn` and `scripts/main.gd` own screens, draft privacy, input, replay capture, and mode transitions.
- `scripts/board.gd` renders the landing pads, survey rovers, and interceptors from a low perspective camera and maps pointer input to the grid.
- `scripts/cockpit.gd` draws the windshield, envoy comms, and orbital map.
- `scripts/rules.gd` implements the seeded state machine and validates the full legal action list.
- `scripts/bot.gd` chooses from that same list using the visible board and drawn ability.
- `tests/rules_test.gd` covers rules, spell interactions, deterministic replay, and bot behavior.

The revised rules allow one orthogonal step or one or two diagonal steps in any direction. A two-square diagonal can jump blockers. Regular captures are one square diagonally forward. A distant entry onto the flag requires a capture. Fracture and Teleport are drafted abilities alongside Shield and Borrow Tomorrow.

The ability deck gives equal odds to Infected Trail, Spy, and Long Capture. Each shuffle is an independent draw; cards are not removed from the deck. Use the power separately from a normal move or use it alone: Infection covers a selected unit's tile and its 3 × 3 neighborhood except the flag; Spy can control an enemy within two orthogonal steps of an ally; Long Capture lets one of your pawns capture one or two squares diagonally in any direction. Spy's control lasts three subsequent turns of the caster. While stolen, a pawn can stand on the flag without scoring and cannot capture a pawn on it. The browser build uses Godot’s Compatibility renderer.

## Build and verify

Run these from this project folder using the Godot console executable on Windows. The release presets require matching Godot 4.7.2 export templates. Create the two output directories before exporting.

```powershell
godot --headless --path . --editor --import --quit
godot --headless --path . --script tests/rules_test.gd
godot --headless --path . --export-release Web ../output/web/index.html
godot --headless --path . --export-release Windows ../output/windows/ConquerorsChess.exe
```

The rules suite covers gameplay transitions, rolled powers, deterministic replays, and bot choices. Chrome verification covered private local drafts, ability draws and repeat-draw prevention, Teleport, Fracture, a win after three flag replies, rematch, solo drafting, and resizing to 850 × 550. The Windows release started successfully with its Compatibility renderer. Human match pacing remains open.

See [Asset credits](ASSET_CREDITS.md) for every imported asset, its creator, source, and license.

The custom ability cards use existing MIT-licensed [Pixelarticons 1.8.1](https://github.com/halfmage/pixelarticons/tree/v1.8.1) artwork by Gerrit Halfmann: a green bug for Infected Trail, a purple eye for Spy, an orange target for Long Capture, and a shared shield back. Nearest-neighbor filtering keeps the icons crisp. Card frames, names, and short descriptions are drawn in Godot. No AI-generated artwork is used for cards. The internal `roll` replay action is retained for compatibility with existing matches.

Card shuffle regression checks: `godot --headless --path . --script tests/card_shuffle_test.gd`. Covers reveal timing, duplicate-click prevention, deterministic outcomes, reduced motion, match cancellation, the solo opponent, clicking the persistent card to highlight targets, and disabling used cards.

On Kalypso, selecting a ship with an unused drafted ability projects a hologram above it. Choose **Move normally** or **Use ability**, then click a highlighted target. Choosing an option does not spend the ability. The hologram follows camera rotation, explains blocked actions, and stays static with **FX off**. It is drawn with ordinary interface primitives; ship artwork is unchanged.
