extends RefCounted
## Drift Circuit instructions, paired with screenshots from the real board.

const OBJECTIVE = "Reach %d points: relay points + surviving ships. Each captured ship costs its side 1 point."

const QUICK_START = """[color=#f8d587]YOUR TURN[/color]
1. Select one of your [b]ships[/b].
2. Click a highlighted tile to [b]move or capture[/b].
3. The other side takes its turn. Then the lanes shift.

[color=#83e1fa]WATCH THE LANES[/color]
Row [b]4[/b] moves right. Row [b]6[/b] moves left. Ships wrap at the edges. Row [b]5[/b] stays still.

[color=#f8d587]SCORE POINTS[/color]
After the shift, each occupied gold relay earns [b]+1 point[/b], then moves to a new square on its row. Follow it to score again.
You start with [b]5 points[/b]. Lose a ship, lose [b]1 point[/b]. Reach [b]%d points[/b] to win.

No draft or power cards in this challenge. Click a ship to see its moves; drag the board to rotate."""

const SCORING = """[color=#f8d587]YOUR POINTS[/color]
[b]Relay points + surviving ships = total points.[/b]
Five starting ships give you 5 points. Each captured ship reduces your total by 1. Capturing an enemy reduces their score; it does not add a point to yours.

[color=#83e1fa]AFTER BOTH TURNS[/color]
The lanes shift. Each occupied relay scores +1, then moves along its row. You must follow the relay to keep scoring.

[color=#f8d587]WIN OR DRAW[/color]
Reach %d points after a shift to win. If both sides reach the goal together, or neither wins by round %d, the match draws."""

const MOVEMENT = """Move 1 tile up, down, left or right; or 1 or 2 tiles diagonally.
[color=#83e1fa]1 / 2 = tiles travelled.[/color] A 2 tile diagonal can jump a ship."""

const CAPTURES = """Land on an enemy 1 tile diagonally [b]forward[/b].
[color=#ff937e]X = enemy you can capture.[/color]
Crew move up ↑; Aliens move down ↓."""

const LANES = "After both turns, row 4 moves right and row 6 moves left. Ships wrap at the edges. Row 5 stays still."
