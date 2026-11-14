# Conqueror’s Chess · The Fractured Flag

A pawn-only tactics duel on a collapsing 3D orbital arena. Five pawns per side start in mirrored lines on a 9 × 9 board. Hold the center flag through three opposing turns or eliminate every opposing pawn. The game draws after eight rounds if neither side wins.

## Play

Open `project.godot` in Godot 4.7.2 Standard and press **F5**. The opening crawl leads into the solar-system flight and then the Horizon cockpit. Choose **Accept challenge** to face the Aliens or **Local duel** for two people on one device. **Replay prologue** returns to the opening crawl.

For the Windows build, extract the ZIP and run `ConquerorsChess.exe` beside its `ConquerorsChess.pck`.

For the browser build, serve `output/web` from the workspace root. For example, run `python -m http.server 8080 --directory output/web` and visit [localhost:8080](http://localhost:8080/). For a jam upload, the Web ZIP contains `index.html` at the archive root. It uses Godot’s single-threaded WebGL 2 export and can be served on HTTPS.

## Controls

- During solar-system flight, hold **W / Up** to accelerate; the ship coasts on release. Exhaust runs while accelerating and during automatic orbit entry. Hold **Shift / Space** while accelerating to boost, **A / D** or **Left / Right** to steer, and **S / Down** to brake. Descent begins after **2 seconds** in stable orbit.
- The rocket begins in open space with a wide camera view. The planets orbit the sun in this order: Ember, Kalypso (home), Cinder, and Aurelia. Their separate orbits and colored gravity boundaries appear on the minimap. Kalypso is the landing destination; the gravity indicator identifies the local planetary well.
- After the first battle, choose **Travel to Azure Reach** after a win or draw, or **Withdraw to Azure Reach** after a loss. The second system uses the same flight, gravity, orbit entry, two-second descent, and chess duel, with a cyan star and the planet Verdant. **Rematch** stays in the current system; **Replay prologue** restarts the journey in Kalypso.
- Click a pawn, choose an action in the right panel if needed, and click a highlighted target. The arrow keys move the board cursor, Enter selects, and Esc clears the selection.
- **Roll ability** before moving or using a drafted ability; roll once per round. Choose a path: **Move → Use power** (both), **Move → Finish / skip turn** (move only), or **Use power → Finish / skip turn** (power only). To move, select a unit, click **Move / capture**, then a highlighted destination. To use power, click **Use power** and a highlighted target: your unit for Infected Trail, an enemy for Spy or Long Capture. The die panel names the power.
- In the draft, select two different pawns, assign them different abilities, and lock your choices. In local mode, pass the device when prompted.
- **Take Over Aliens** queues the switch to a second player for the next Alien turn boundary. **Rematch** keeps the current mode, swaps the starter, and rolls a new setup.
- **Rules** shows the complete gameplay reference. **FX** toggles movement effects. **View log** can copy the match seed, starting side, committed actions, first flag round, duration, and outcome.

## Project

- `main.tscn` and `scripts/main.gd` own screens, draft privacy, input, replay capture, and mode transitions.
- `scripts/board.gd` renders the landing pads, survey rovers, and interceptors from a low perspective camera and maps pointer input to the grid.
- `scripts/cockpit.gd` draws the windshield, envoy comms, and orbital map.
- `scripts/rules.gd` implements the seeded state machine and validates the full legal action list.
- `scripts/bot.gd` chooses from that same list using the visible board and roll.
- `tests/rules_test.gd` covers rules, spell interactions, deterministic replay, and bot behavior.

The revised rules allow one orthogonal step or one or two diagonal steps in any direction. A two-square diagonal can jump blockers. Regular captures are one square diagonally forward. A distant entry onto the flag requires a capture. Fracture and Teleport are drafted abilities alongside Shield and Borrow Tomorrow.

The six-sided die gives equal odds to Infected Trail, Spy, and Long Capture. Use the power separately from a normal move or use it alone: Infection covers a selected unit's tile and its 3 × 3 neighborhood except the flag; Spy can control an enemy within two orthogonal steps of an ally; Long Capture lets one of your pawns capture one or two squares diagonally in any direction. Spy's control lasts three subsequent turns of the caster. While stolen, a pawn can stand on the flag without scoring and cannot capture a pawn on it. The browser build uses Godot’s Compatibility renderer.

## Build and verify

Run these from this project folder using the Godot console executable on Windows. The release presets require matching Godot 4.7.2 export templates. Create the two output directories before exporting.

```powershell
godot --headless --path . --editor --import --quit
godot --headless --path . --script tests/rules_test.gd
godot --headless --path . --export-release Web ../output/web/index.html
godot --headless --path . --export-release Windows ../output/windows/ConquerorsChess.exe
```

The rules suite covers gameplay transitions, rolled powers, deterministic replays, and bot choices. Chrome verification covered private local drafts, manual rolling and reroll prevention, Teleport, Fracture, a win after three flag replies, rematch, solo drafting, and resizing to 850 × 550. The Windows release started successfully with its Compatibility renderer. Human match pacing remains open.

See [Asset credits](ASSET_CREDITS.md) for every imported asset, its creator, source, and license.
