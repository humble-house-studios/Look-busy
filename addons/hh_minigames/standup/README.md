# standup — Killin' in Comedy

The whole stand-up roguelike: pick a path, play live sets (cards, mic time,
the Room chart, LAND IT), earn cards, hire crew, beat the Headline Show. The
comedy app runs this as its main game; the office runs it on the main desk's
monitor.

- Entry: `main.tscn` (`main.gd`). Layout follows the screen shape (portrait
  phones, landscape Steam) and only touches the window when it owns it.
- `start({"dev": bool})`: dev shortcuts in the pause menu and the next-set
  screen (default on).
- `finished`: once per run. `score` = sets cleared; `outcome` "win" (headline
  show won) or "lose"; extras `laughs`, `why` ("light" / "room") on a loss.
- Rules in `engine/` (no scene dependencies), cards and crowds in `data/`, all
  numbers in `engine/balance.gd`, jokes in `data/jokes.gd`.
- Hosts may read these variable names (the Loot Machine's office link does):
  don't rename `_run`, `_battle` and friends lightly.
- Balance: `godot --headless -s res://addons/hh_minigames/standup/tools/tune.gd`
  (300 autopilot runs; `TUNE="open_mic=8000:60"`).
- Screenshots: `standup/tools/screenshot.gd` (see its header).
- Tests: `tests/` (battle, chains, library, patter, run).
