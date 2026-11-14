extends RefCounted
## Judge-facing instructions. Describes the current Kalypso rules without changing them.

const OBJECTIVE = "Hold the center flag with the same ship through 3 enemy turns, or eliminate every enemy ship."
const QUICK_START = """[color=#f8d587]BEFORE YOU START[/color]
Give two ships different one-use abilities. Lock your draft.

[color=#83e1fa]YOUR TURN[/color]
1. [b]Shuffle[/b] to reveal your power card.
2. Select a ship. Its hologram lets you choose a normal move or its one-use ability. Then click a highlighted target.
3. Click your [b]power card[/b], then a highlighted target to use it.
4. Click [b]Finish / skip turn[/b] to pass control.

Choose: move → power, move only, or power only. You may skip.

[color=#f8d587]WATCH YOUR FOOTING[/color]
Cracked rim tiles fall after both turns; ships on them are lost. No winner after 8 rounds means a draw."""

const MOVEMENT = """Move 1 tile up, down, left or right; or 1–2 tiles diagonally.
[color=#83e1fa]1 / 2 = tiles travelled.[/color] A 2-tile diagonal can jump a ship or hole."""

const CAPTURES = """Land on an enemy 1 tile diagonally [b]forward[/b].
[color=#ff937e]X = enemy you can capture.[/color]
Pilots move up ↑; Aliens move down ↓."""

const ABILITIES = """[color=#f8d587]DRAFTED · ONE USE · REPLACES YOUR MOVE[/color]
[b]Shield[/b] — Blocks one capture. Stops working on the flag.
[b]Fracture Tile[/b] — Cracks a tile now; it falls after the next turn, taking any ship with it. Cannot target the flag.
[b]Teleport[/b] — Jump to an empty, intact, uninfected tile. Cannot land on the flag.
[b]Borrow Tomorrow[/b] — Move this ship and an ally 1 tile straight each. The first returns after your next turn. It cannot enter or leave the flag.

[color=#83e1fa]SHUFFLED CARD · OPTIONAL POWER[/color]
[b]Spy[/b] — Control a nearby enemy for 3 of your turns. It can capture, but cannot claim or capture on the flag.
[b]Infected Trail[/b] — Blocks entry to the 3 × 3 area around your chosen ship through the enemy turn. The flag stays safe; occupants are not killed.
[b]Long Capture[/b] — Capture an enemy 1 or 2 tiles diagonally away, in any direction.

Click your card, then a highlighted target. No targets? Move or finish your turn."""
