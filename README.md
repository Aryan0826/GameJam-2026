# Conqueror’s Chess · The Fractured Flag

A pawn-only tactics duel on a collapsing 3D orbital arena. Five pawns per side start in mirrored lines on a 9 × 9 board. Hold the center flag through three opposing turns or eliminate every opposing pawn. The game draws after eight rounds if neither side wins.

## Play

Open `project.godot` in Godot 4.7.2 Standard and press **F5**. Choose **Play solo** to face the Aliens or **Play local duel** for two people on one device.

For the Windows build, extract the ZIP and run `ConquerorsChess.exe` beside its `ConquerorsChess.pck`.

For the browser build, serve `output/web` from the workspace root. For example, run `python -m http.server 8080 --directory output/web` and visit [localhost:8080](http://localhost:8080/). For a jam upload, the Web ZIP contains `index.html` at the archive root. It uses Godot’s single-threaded WebGL 2 export and can be served on HTTPS.

## Controls

- Click a pawn, choose an action in the right panel if needed, and click a highlighted target. The arrow keys move the board cursor, Enter selects, and Esc clears the selection.
- **Roll ability** gives your side one optional die power for the current round. The roll does not consume your turn. Normal moves are always available when legal.
- In the draft, select two different pawns, assign them different abilities, and lock your choices. In local mode, pass the device when prompted.
- **Take Over Aliens** queues the switch to a second player for the next Alien turn boundary. **Rematch** keeps the current mode, swaps the starter, and rolls a new setup.
- **Rules** shows the complete gameplay reference. **FX** toggles movement effects. **View log** can copy the match seed, starting side, committed actions, first flag round, duration, and outcome.

## Project

- `main.tscn` and `scripts/main.gd` own screens, draft privacy, input, replay capture, and mode transitions.
- `scripts/board.gd` renders the 3D arena and animated pawn meshes into the 2D HUD, and maps pointer input to board squares.
- `scripts/rules.gd` implements the seeded state machine and validates the full legal action list.
- `scripts/bot.gd` chooses from that same list using the visible board and roll.
- `tests/rules_test.gd` covers rules, spell interactions, deterministic replay, and bot behavior.

The revised rules allow one orthogonal step or one or two diagonal steps in any direction. A two-square diagonal can jump blockers. Regular captures are one square diagonally forward. A distant entry onto the flag requires a capture. Fracture and Teleport are drafted abilities alongside Shield and Borrow Tomorrow.

The six-sided die gives equal odds to Infected Trail, Spy, and Long Capture. Infection covers the departure tile's 3 × 3 neighborhood except the flag. Spy's control lasts three subsequent turns of the caster. While stolen, a pawn can stand on the flag without scoring and cannot capture a pawn on it. Long Capture works one or two squares diagonally in any direction. The browser build uses Godot’s Compatibility renderer.

## Build and verify

Run these from this project folder using the Godot console executable on Windows. The release presets require matching Godot 4.7.2 export templates. Create the two output directories before exporting.

```powershell
godot --headless --path . --editor --import --quit
godot --headless --path . --script tests/rules_test.gd
godot --headless --path . --export-release Web ../output/web/index.html
godot --headless --path . --export-release Windows ../output/windows/ConquerorsChess.exe
```

The revised rules suite passed 823 checks. Chrome verification covered private local drafts, manual rolling and reroll prevention, Teleport, Fracture, a win after three flag replies, rematch, solo drafting, and resizing to 850 × 550. The Windows release started successfully with its Compatibility renderer. Human match pacing remains open.

See [Asset credits](ASSET_CREDITS.md) for every imported asset, its creator, source, and license.
