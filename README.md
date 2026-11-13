# Conqueror’s Chess · The Fractured Flag

A 2D, pawn-only tactics duel on a collapsing orbital arena. Hold the flag through two opposing turns or eliminate every opposing pawn. The game draws after eight rounds if neither side wins.

## Play

Open `project.godot` in Godot 4.7.2 Standard and press **F5**. Choose **Play solo** to face the Aliens or **Play local duel** for two people on one device.

For the Windows build, extract the ZIP and run `ConquerorsChess.exe` beside its `ConquerorsChess.pck`.

For the browser build, serve `output/web` from the workspace root. For example, run `python -m http.server 8080 --directory output/web` and visit [localhost:8080](http://localhost:8080/). For a jam upload, the Web ZIP contains `index.html` at the archive root. It uses Godot’s single-threaded WebGL 2 export and can be served on HTTPS.

## Controls

- Click a pawn, choose an action in the right panel if needed, and click a highlighted target. The arrow keys move the board cursor, Enter selects, and Esc clears the selection.
- In the draft, select two different pawns, assign them different abilities, and lock your choices. In local mode, pass the device when prompted.
- **Take Over Aliens** queues the switch to a second player for the next Alien turn boundary. **Rematch** keeps the current mode, swaps the starter, and rolls a new setup.
- **Rules** shows the complete gameplay reference. **FX** toggles movement effects. **View log** can copy the match seed, starting side, committed actions, first flag round, duration, and outcome.

## Project

- `main.tscn` and `scripts/main.gd` own screens, draft privacy, input, replay capture, and mode transitions.
- `scripts/board.gd` draws the 2D board, pawns, legal targets, and status effects.
- `scripts/rules.gd` implements the seeded state machine and validates the full legal action list.
- `scripts/bot.gd` chooses from that same list using the visible board and roll.
- `tests/rules_test.gd` covers rules, spell interactions, deterministic replay, and bot behavior.

The PDF’s board and turn rules were implemented in GDScript. Borrow Tomorrow follows the drafted-spell table order: move the assigned pawn, then the second pawn. The browser build uses Godot’s Compatibility renderer.

## Build and verify

Run these from this project folder using the Godot console executable on Windows. The release presets require matching Godot 4.7.2 export templates. Create the two output directories before exporting.

```powershell
godot --headless --path . --editor --import --quit
godot --headless --path . --script tests/rules_test.gd
godot --headless --path . --export-release Web ../output/web/index.html
godot --headless --path . --export-release Windows ../output/windows/ConquerorsChess.exe
```

The rules suite passed 1,779 assertions. The Chrome release playthrough covered solo and local drafting, a Borrow Tomorrow return after takeover, flag scoring during collapse, rematch, and an 850 × 550 window. The Windows release passed a headless launch. Eight automated matches averaged 13.5 turns. First-time player feedback and the 4–6 minute pacing target still need a human playtest.

See [Asset credits](ASSET_CREDITS.md) for every imported asset, its creator, source, and license.
